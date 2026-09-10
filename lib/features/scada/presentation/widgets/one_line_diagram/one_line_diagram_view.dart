import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/features/scada/data/sources/scada_api_client.dart';
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

  static const String _baseUrl = ScadaApiClient.configuredBaseUrl;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF05070A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() { _isLoading = true; _hasError = false; });
          },
          onPageFinished: (_) async {
            if (mounted) setState(() => _isLoading = false);

            // Execute client script: navigate to Sơ đồ điện tab, activate focus mode, & optimize canvas bounds
            await _controller.runJavaScript('''
              (function() {
                function setupDiagramView() {
                  try {
                    // 1. Select 'Sơ đồ điện' view tab
                    var navButtons = Array.from(document.querySelectorAll('aside nav button'));
                    var diagramBtn = navButtons.find(function(b) {
                      return b.textContent && b.textContent.indexOf('Sơ đồ điện') !== -1;
                    }) || navButtons[1];
                    if (diagramBtn) {
                      diagramBtn.click();
                    }

                    // 2. Trigger focus mode to expand workspace layout
                    var actionButtons = Array.from(document.querySelectorAll('header button'));
                    var focusBtn = actionButtons.find(function(b) {
                      return b.textContent && b.textContent.indexOf('Toàn màn hình') !== -1;
                    });
                    if (focusBtn) {
                      focusBtn.click();
                    }

                    // 3. Hide chrome elements safely after workspace is active
                    var aside = document.querySelector('aside');
                    if (aside) aside.style.display = 'none';

                    var headers = document.querySelectorAll('header');
                    headers.forEach(function(h) { h.style.display = 'none'; });

                    var footers = document.querySelectorAll('footer');
                    footers.forEach(function(f) { f.style.display = 'none'; });

                    // 4. Ensure workspace container & body fill full viewport
                    var main = document.querySelector('main');
                    if (main) {
                      main.style.padding = '0';
                      main.style.margin = '0';
                      main.style.minHeight = '100vh';
                    }
                    var workspace = document.querySelector('section');
                    if (workspace) {
                      workspace.style.height = '100vh';
                      workspace.style.minHeight = '100vh';
                      workspace.style.border = '0';
                      workspace.style.borderRadius = '0';
                    }
                    var workspaceBody = document.querySelector('section > div');
                    if (workspaceBody) {
                      workspaceBody.style.height = '100vh';
                      workspaceBody.style.flex = '1';
                    }
                  } catch(e) {}
                }

                setupDiagramView();
                setTimeout(setupDiagramView, 150);
                setTimeout(setupDiagramView, 400);
                setTimeout(setupDiagramView, 800);
                setTimeout(setupDiagramView, 1500);
              })();
            ''');
          },
          onWebResourceError: (_) {
            if (mounted) setState(() { _isLoading = false; _hasError = true; });
          },
        ),
      );
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
    final token = provider.apiClient.sessionToken;
    final Uri baseUri = Uri.parse(_baseUrl);

    final cookieManager = WebViewCookieManager();
    try {
      if (token != null && token.isNotEmpty) {
        await cookieManager.setCookie(
          WebViewCookie(
            name: 'fe_tanan_admin',
            value: token,
            domain: baseUri.host,
            path: '/',
          ),
        );
        await cookieManager.setCookie(
          WebViewCookie(
            name: 'tanan_user',
            value: token,
            domain: baseUri.host,
            path: '/',
          ),
        );
        await cookieManager.setCookie(
          WebViewCookie(
            name: 'tanan_admin',
            value: token,
            domain: baseUri.host,
            path: '/',
          ),
        );
      }
    } catch (_) {}

    final Map<String, String> headers = {
      'Accept': 'text/html',
      'Accept-Language': 'vi-VN,vi',
    };
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = 'fe_tanan_admin=$token; tanan_user=$token; tanan_admin=$token';
    }

    await _controller.loadRequest(
      Uri.parse(_baseUrl),
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
    final int tagCount = provider.envelope.snapshot.tags.length;
    final bool isLive = provider.streamHealthy;

    return Column(
      children: [
        // ── Header bar ────────────────────────────────────────────────────
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Title — takes all available space
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sơ đồ điện trạm biến áp',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textStrong,
                      ),
                    ),
                    Text(
                      'TBA 110kV Tân Ân, 35/110 kV',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Live status dot + count
              _buildStatusDot(provider, isLive, tagCount),
              const SizedBox(width: 4),

              // Reload button
              IconButton(
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.textSecondary,
                ),
                tooltip: 'Tải lại sơ đồ',
                onPressed: _reload,
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppTheme.border),

        // ── WebView body ─────────────────────────────────────────────────
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),

              // Loading overlay
              if (_isLoading)
                Container(
                  color: const Color(0xFF05070A),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 16),
                        Text(
                          'Đang tải sơ đồ…',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Error overlay
              if (_hasError && !_isLoading)
                Container(
                  color: AppTheme.background,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.signal_wifi_off_rounded,
                          size: 48,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Không thể tải sơ đồ điện',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textStrong,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Kiểm tra kết nối mạng hoặc thử tải lại',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Tải lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact status indicator: just a coloured dot + tag count
  Widget _buildStatusDot(ScadaProvider provider, bool isLive, int tagCount) {
    final color = isLive ? AppTheme.success : AppTheme.error;
    final label = isLive
        ? (tagCount > 0 ? '$tagCount Tín hiệu' : 'Online')
        : 'Mất kết nối';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
