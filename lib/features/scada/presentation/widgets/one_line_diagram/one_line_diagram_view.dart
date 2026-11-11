import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/features/scada/data/models/dispatch_models.dart';
import 'package:tan_an_portal/features/scada/presentation/providers/scada_provider.dart';

class OneLineDiagramView extends StatefulWidget {
  const OneLineDiagramView({super.key});

  @override
  State<OneLineDiagramView> createState() => _OneLineDiagramViewState();
}

class _OneLineDiagramViewState extends State<OneLineDiagramView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _initialized = false;
  int _autoLoginAttempts = 0;
  DateTime? _lastAutoLoginTime;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF05070A))
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
            if (mounted) setState(() { _isLoading = true; _hasError = false; });
          },
          onPageFinished: (url) async {
            final uri = Uri.tryParse(url);
            final path = uri?.path.toLowerCase() ?? '';
            final provider = context.read<ScadaProvider>();
            final baseUri = Uri.parse(provider.apiClient.baseUrl);

            // Kiểm tra xem trang có bị chuyển hướng về trang chủ / login hay không
            final bool isTargetDomain = uri?.host == baseUri.host;
            final bool isAtLoginOrRoot = isTargetDomain &&
                (path.isEmpty ||
                    path == '/' ||
                    path == '/login' ||
                    path.contains('/auth/login') ||
                    !path.contains('/workspace/'));

            if (isAtLoginOrRoot) {
              // Tự động khôi phục phiên đăng nhập in-WebView
              final handled = await _attemptInWebViewAutoLogin();
              if (handled) return;
            }

            _autoLoginAttempts = 0;
            if (mounted) setState(() => _isLoading = false);

            // Execute client script: maximize diagram canvas & hide platform shell chrome
            await _injectDiagramStyles();
            await _controller.runJavaScript(provider.apiClient.buildInWebViewKeepAliveScript());
          },
          onWebResourceError: (error) {
            if (error.errorCode == -999 || error.description.contains('net::ERR_ABORTED')) {
              return;
            }
            if (mounted) setState(() { _isLoading = false; _hasError = true; });
          },
        ),
      );
  }

  Future<bool> _attemptInWebViewAutoLogin() async {
    final now = DateTime.now();
    if (_lastAutoLoginTime != null && now.difference(_lastAutoLoginTime!).inSeconds > 30) {
      _autoLoginAttempts = 0;
    }
    _lastAutoLoginTime = now;

    if (_autoLoginAttempts >= 3) {
      if (mounted) setState(() => _isLoading = false);
      return false;
    }
    _autoLoginAttempts++;

    final provider = context.read<ScadaProvider>();
    final api = provider.apiClient;
    await api.ensureSavedCredentialsLoaded();

    final targetUrl = '${api.baseUrl}${api.workspacePath}';
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

  Future<void> _injectDiagramStyles() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          function setupDiagramView() {
            try {
              // 1. Hide chrome elements safely (nav rail, top header, etc.)
              var elementsToHide = document.querySelectorAll(
                '.master-rail, .master-header, aside, header, nav, .master-navigation, .master-sidebar, footer'
              );
              elementsToHide.forEach(function(el) {
                if (el) el.style.setProperty('display', 'none', 'important');
              });

              // 2. Expand workspace container to full viewport
              var wrappers = document.querySelectorAll(
                'html, body, main, .master-workspace, .module-workspace, section, .module-island, #tanan-app'
              );
              wrappers.forEach(function(w) {
                if (w) {
                  w.style.setProperty('margin', '0', 'important');
                  w.style.setProperty('padding', '0', 'important');
                  w.style.setProperty('width', '100%', 'important');
                  w.style.setProperty('height', '100%', 'important');
                  w.style.setProperty('min-height', '100vh', 'important');
                  w.style.setProperty('background', '#05070a', 'important');
                  w.style.setProperty('overflow', 'hidden', 'important');
                }
              });

              // 3. Trigger focus mode if button exists
              var focusBtn = document.querySelector('button[title*="Toàn màn hình"], button[aria-label*="Toàn màn hình"]');
              if (focusBtn) {
                focusBtn.click();
              }
            } catch(e) {}
          }

          setupDiagramView();
          setTimeout(setupDiagramView, 150);
          setTimeout(setupDiagramView, 500);
          setTimeout(setupDiagramView, 1200);
          setTimeout(setupDiagramView, 2500);
        })();
      ''');
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    final provider = context.read<ScadaProvider>();
    final apiClient = provider.apiClient;
    final token = apiClient.sessionToken;
    final baseUrl = apiClient.baseUrl;

    await apiClient.syncCookiesToWebView();
    await Future.delayed(const Duration(milliseconds: 150));

    final Map<String, String> headers = {
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
    };
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = token;
    }

    final targetUrl = '$baseUrl${apiClient.workspacePath}';
    await _controller.loadRequest(
      Uri.parse(targetUrl),
      headers: headers,
    );
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _isLoading = true);
    await _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final dispatchLamps = provider.dispatchLamps;

    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. One-Line Diagram Embedded Workspace View
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),

            // 2. Top Dispatch Control Overlay Strip (if active)
            if (dispatchLamps.isNotEmpty)
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xE60D131F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ĐIỀU ĐỘ TRẠM 110KV',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      ...dispatchLamps.take(3).map((lamp) => Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: lamp.state == DispatchLampState.on
                                ? const Color(0x3310B981)
                                : const Color(0x221E293B),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: lamp.state == DispatchLampState.on
                                  ? const Color(0xFF10B981)
                                  : AppTheme.border,
                            ),
                          ),
                          child: Text(
                            lamp.label,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: lamp.state == DispatchLampState.on
                                  ? const Color(0xFF10B981)
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ),

            // 3. Top Action Buttons: Reload
            Positioned(
              top: dispatchLamps.isNotEmpty ? 52 : 12,
              right: 12,
              child: FloatingActionButton.small(
                heroTag: 'refresh_diagram_webview',
                backgroundColor: const Color(0xCC0D131F),
                foregroundColor: AppTheme.textPrimary,
                elevation: 3,
                onPressed: _reload,
                child: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ),

            // 4. Loading Indicator Overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color(0xCC05070A),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 2.5,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Đang tải Sơ đồ điện Savina Platform...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 5. Error State Overlay
            if (_hasError)
              Positioned.fill(
                child: Container(
                  color: const Color(0xF005070A),
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Không thể tải Sơ đồ điện',
                          style: TextStyle(
                            color: AppTheme.textStrong,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vui lòng kiểm tra kết nối với platform (${provider.apiClient.baseUrl})',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Thử lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
