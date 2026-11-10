import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import '../../providers/scada_provider.dart';

/// Màn hình quản lý Thành viên nhà máy (Tài khoản & phân quyền)
class FactoryMembersScreen extends StatelessWidget {
  const FactoryMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ScadaProvider>().apiClient;
    return AdminWebViewScreen(
      title: 'Thành viên nhà máy',
      subtitle: 'Nhà máy Tân Ân 1',
      targetUrl: api.membersUrl,
    );
  }
}

/// Màn hình cấu hình Vai trò truy cập (Chức năng & nhóm quyền)
class AccessRolesScreen extends StatelessWidget {
  const AccessRolesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ScadaProvider>().apiClient;
    return AdminWebViewScreen(
      title: 'Vai trò truy cập',
      subtitle: 'Nhà máy Tân Ân 1',
      targetUrl: api.accessRolesUrl,
    );
  }
}

/// Wrapper tương thích ngược cho RolesAndPermissionsScreen
class RolesAndPermissionsScreen extends StatefulWidget {
  final int initialTab; // 0: Thành viên, 1: Vai trò truy cập

  const RolesAndPermissionsScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<RolesAndPermissionsScreen> createState() =>
      _RolesAndPermissionsScreenState();
}

class _RolesAndPermissionsScreenState
    extends State<RolesAndPermissionsScreen> {
  @override
  Widget build(BuildContext context) {
    return widget.initialTab == 1
        ? const AccessRolesScreen()
        : const FactoryMembersScreen();
  }
}

/// Màn hình nhúng WebView quản trị dành cho Thành viên & Vai trò
class AdminWebViewScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String targetUrl;

  const AdminWebViewScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.targetUrl,
  });

  @override
  State<AdminWebViewScreen> createState() => _AdminWebViewScreenState();
}

class _AdminWebViewScreenState extends State<AdminWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _initialized = false;
  int _autoLoginAttempts = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A1120))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            final path = uri?.path.toLowerCase() ?? '';
            final provider = context.read<ScadaProvider>();
            final baseUri = Uri.parse(provider.apiClient.baseUrl);

            if (uri?.host == baseUri.host &&
                (path == '/login' ||
                    path.endsWith('/login') ||
                    path.contains('/auth/login'))) {
              _attemptInWebViewAutoLogin();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (url) async {
            final uri = Uri.tryParse(url);
            final path = uri?.path.toLowerCase() ?? '';
            final provider = context.read<ScadaProvider>();
            final baseUri = Uri.parse(provider.apiClient.baseUrl);

            final bool isTargetDomain = uri?.host == baseUri.host;
            final bool isAtLoginOrRoot = isTargetDomain &&
                (path.isEmpty ||
                    path == '/' ||
                    path == '/login' ||
                    path.contains('/auth/login') ||
                    (!path.contains('/factories/') && !path.contains('/workspace/')));

            if (isAtLoginOrRoot) {
              final handled = await _attemptInWebViewAutoLogin();
              if (handled) return;
            }

            _autoLoginAttempts = 0;
            if (mounted) {
              setState(() => _isLoading = false);
            }
            await _injectMobileStyles();
          },
          onWebResourceError: (error) {
            if (error.errorCode == -999 || error.description.contains('net::ERR_ABORTED')) {
              return;
            }
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMessage = error.description;
              });
            }
          },
        ),
      );
  }

  Future<bool> _attemptInWebViewAutoLogin() async {
    if (_autoLoginAttempts >= 3) {
      if (mounted) setState(() => _isLoading = false);
      return false;
    }
    _autoLoginAttempts++;

    final provider = context.read<ScadaProvider>();
    final api = provider.apiClient;
    await api.ensureSavedCredentialsLoaded();

    final targetUrl = widget.targetUrl;
    final js = api.buildInWebViewAutoLoginScript(targetUrl);

    try {
      final dynamic res = await _controller.runJavaScriptReturningResult(js);
      final resStr = res.toString();
      if (resStr.contains('OK')) {
        return true;
      }
    } catch (_) {}

    await api.syncCookiesToWebView();
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      await _loadPage();
    }
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadPage();
    }
  }

  Future<void> _injectMobileStyles() async {
    const js = '''
      (function() {
        function setup() {
          try {
            // Viewport meta
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
              meta = document.createElement('meta');
              meta.name = 'viewport';
              document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

            var styleId = 'roles-mobile-injected-style';
            var style = document.getElementById(styleId);
            if (!style) {
              style = document.createElement('style');
              style.id = styleId;
              document.head.appendChild(style);
            }
            style.textContent = `
              *, *::before, *::after {
                box-sizing: border-box !important;
              }

              :focus, :focus-visible, [tabindex]:focus {
                outline: none !important;
              }

              html, body {
                overflow-x: hidden !important;
                background: #0a1120 !important;
                margin: 0 !important;
                padding: 0 !important;
                width: 100% !important;
                max-width: 100vw !important;
                -webkit-font-smoothing: antialiased;
              }

              /* Hide platform desktop sidebar, header, footer chrome */
              body[data-ui-master] .master-sidebar,
              .master-sidebar,
              body[data-ui-master] .master-header,
              .master-header,
              body[data-ui-master] .master-footer,
              .master-footer,
              footer,
              .master-navigation-label,
              .master-sidebar-foot,
              .master-back-link,
              .fi-sidebar,
              .fi-topbar {
                display: none !important;
              }

              /* Make shell fluid 100% */
              body[data-ui-master] .master-shell,
              .master-shell {
                display: block !important;
                width: 100% !important;
                max-width: 100vw !important;
                min-width: 0 !important;
                margin: 0 !important;
                padding: 0 !important;
                background: #0a1120 !important;
                overflow-x: hidden !important;
              }

              body[data-ui-master] .master-workspace,
              .master-workspace {
                display: block !important;
                width: 100% !important;
                max-width: 100vw !important;
                min-width: 0 !important;
                margin: 0 !important;
                padding: 10px 12px 32px 12px !important;
                box-sizing: border-box !important;
                background: #0a1120 !important;
                overflow-x: hidden !important;
              }

              .portal-content,
              .workspace-stack {
                display: block !important;
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
                margin: 0 !important;
                padding: 0 !important;
                gap: 16px !important;
              }

              /* Floating 2s Alarm Toast Notification */
              .workspace-message,
              [role="status"] {
                position: fixed !important;
                top: 14px !important;
                left: 50% !important;
                transform: translateX(-50%) !important;
                z-index: 99999999 !important;
                display: inline-flex !important;
                align-items: center !important;
                justify-content: center !important;
                text-align: center !important;
                gap: 8px !important;
                background: rgba(15, 23, 42, 0.95) !important;
                -webkit-backdrop-filter: blur(14px) !important;
                backdrop-filter: blur(14px) !important;
                border: 1px solid rgba(52, 211, 153, 0.55) !important;
                color: #f1f5f9 !important;
                box-shadow: 0 12px 34px rgba(0, 0, 0, 0.75), 0 0 18px rgba(52, 211, 153, 0.25) !important;
                border-radius: 9999px !important;
                padding: 9px 20px !important;
                font-size: 13px !important;
                font-weight: 600 !important;
                line-height: 1.4 !important;
                max-width: calc(100vw - 32px) !important;
                margin: 0 !important;
                box-sizing: border-box !important;
                cursor: pointer !important;
                user-select: none !important;
                -webkit-user-select: none !important;
                animation: alarmToastIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards,
                           alarmToastOut 0.35s cubic-bezier(0.16, 1, 0.3, 1) 2s forwards !important;
              }

              .workspace-message.workspace-message-error,
              [role="alert"].workspace-message {
                border-color: rgba(248, 113, 113, 0.6) !important;
                box-shadow: 0 12px 34px rgba(0, 0, 0, 0.75), 0 0 18px rgba(248, 113, 113, 0.25) !important;
                color: #fecaca !important;
                animation: alarmToastIn 0.3s cubic-bezier(0.16, 1, 0.3, 1) forwards,
                           alarmToastOut 0.35s cubic-bezier(0.16, 1, 0.3, 1) 3s forwards !important;
              }

              @keyframes alarmToastIn {
                from {
                  opacity: 0;
                  transform: translate(-50%, -24px) scale(0.92);
                }
                to {
                  opacity: 1;
                  transform: translate(-50%, 0) scale(1);
                }
              }

              @keyframes alarmToastOut {
                from {
                  opacity: 1;
                  transform: translate(-50%, 0) scale(1);
                }
                to {
                  opacity: 0;
                  transform: translate(-50%, -18px) scale(0.92);
                  visibility: hidden;
                  pointer-events: none;
                }
              }

              /* Sections & Panels */
              .fi-section,
              .workspace-panel {
                background: #111a2e !important;
                border: 1px solid #22304d !important;
                border-radius: 12px !important;
                margin-bottom: 16px !important;
                overflow: hidden !important;
              }

              .admin-table-scroll {
                overflow-x: auto !important;
                -webkit-overflow-scrolling: touch !important;
                width: 100% !important;
                max-width: 100% !important;
                border-radius: 8px !important;
              }

              .admin-table {
                width: 100% !important;
                min-width: 100% !important;
              }

              /* Buttons & inputs fit mobile */
              input, select, textarea {
                color-scheme: dark !important;
              }

              /* Fieldset & Form controls for Access Roles & Permissions */
              fieldset {
                border: 1px solid rgba(255, 255, 255, 0.12) !important;
                border-radius: 10px !important;
                padding: 12px 14px !important;
                margin-bottom: 12px !important;
                background: rgba(255, 255, 255, 0.02) !important;
              }

              legend {
                color: #94a3b8 !important;
                font-weight: 600 !important;
                font-size: 13px !important;
                padding: 0 6px !important;
              }

              label {
                color: #e2e8f0 !important;
                font-size: 13.5px !important;
                display: flex !important;
                align-items: center !important;
                gap: 10px !important;
              }

              input[type="checkbox"] {
                width: 18px !important;
                height: 18px !important;
                accent-color: #38bdf8 !important;
                cursor: pointer !important;
              }

              input[type="text"],
              input[type="email"],
              input[type="password"],
              select {
                background: #0d1527 !important;
                border: 1px solid #22304d !important;
                color: #f1f5f9 !important;
                border-radius: 8px !important;
                padding: 9px 12px !important;
                font-size: 13.5px !important;
                width: 100% !important;
                max-width: 100% !important;
                box-sizing: border-box !important;
              }

              input:focus,
              select:focus {
                border-color: #38bdf8 !important;
                box-shadow: 0 0 0 2px rgba(56, 189, 248, 0.25) !important;
              }

              .profile-help {
                color: #94a3b8 !important;
                font-size: 12px !important;
              }
            `;

            // Function to handle alarm toasts: auto-dismiss in 2s and clean up DOM
            function handleAlarmToast(el) {
              if (!el || el.dataset.alarmHandled === 'true') return;
              el.dataset.alarmHandled = 'true';

              // Add leading badge icon if not present
              if (!el.querySelector('.alarm-icon-badge')) {
                var iconSpan = document.createElement('span');
                iconSpan.className = 'alarm-icon-badge';
                var isError = el.classList.contains('workspace-message-error') || el.getAttribute('role') === 'alert';
                if (isError) {
                  iconSpan.innerHTML = '<svg width="15" height="15" viewBox="0 0 20 20" fill="#f87171" style="vertical-align:middle;margin-right:6px;flex-shrink:0;"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>';
                } else {
                  iconSpan.innerHTML = '<svg width="15" height="15" viewBox="0 0 20 20" fill="#34d399" style="vertical-align:middle;margin-right:6px;flex-shrink:0;"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>';
                }
                el.insertBefore(iconSpan, el.firstChild);
              }

              var isError = el.classList.contains('workspace-message-error') || el.getAttribute('role') === 'alert';
              var displayTimeMs = isError ? 3000 : 2000;

              // Auto remove after 2s (or 3s for errors)
              setTimeout(function() {
                el.style.transition = 'opacity 0.35s cubic-bezier(0.16, 1, 0.3, 1), transform 0.35s cubic-bezier(0.16, 1, 0.3, 1)';
                el.style.opacity = '0';
                el.style.transform = 'translate(-50%, -18px) scale(0.92)';
                el.style.pointerEvents = 'none';
                setTimeout(function() {
                  if (el && el.parentNode) {
                    el.parentNode.removeChild(el);
                  }
                }, 380);
              }, displayTimeMs);

              // Click to dismiss immediately
              el.addEventListener('click', function() {
                el.style.transition = 'opacity 0.15s ease, transform 0.15s ease';
                el.style.opacity = '0';
                el.style.transform = 'translate(-50%, -14px) scale(0.92)';
                setTimeout(function() {
                  if (el && el.parentNode) el.parentNode.removeChild(el);
                }, 160);
              });
            }

            function processAllMessages() {
              var messages = document.querySelectorAll('.workspace-message, [role="status"]');
              for (var i = 0; i < messages.length; i++) {
                handleAlarmToast(messages[i]);
              }
            }

            processAllMessages();

            // Observe for dynamic messages added later
            if (window.MutationObserver && !window._alarmObserverAttached) {
              window._alarmObserverAttached = true;
              var observer = new MutationObserver(function() {
                processAllMessages();
              });
              observer.observe(document.body || document.documentElement, {
                childList: true,
                subtree: true
              });
            }
          } catch (e) {
            console.error(e);
          }
        }

        setup();
        setTimeout(setup, 300);
        setTimeout(setup, 1200);
      })();
    ''';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  Future<void> _loadPage() async {
    final provider = context.read<ScadaProvider>();
    final apiClient = provider.apiClient;
    final token = apiClient.sessionToken;

    await apiClient.syncCookiesToWebView();
    await Future.delayed(const Duration(milliseconds: 150));

    final Map<String, String> headers = {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
    };
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = token;
    }

    if (kDebugMode) {
      print('Loading ${widget.title}: ${widget.targetUrl}');
    }

    await _controller.loadRequest(
      Uri.parse(widget.targetUrl),
      headers: headers,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1120),
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppTheme.textStrong,
            ),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                await _controller.goBack();
              } else if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textStrong,
                ),
              ),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.sync_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              tooltip: 'Làm mới',
              onPressed: _reload,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
              if (_hasError)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppTheme.error,
                          size: 44,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Không thể tải dữ liệu ${widget.title.toLowerCase()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textStrong,
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _reload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text(
                            'Thử lại',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
