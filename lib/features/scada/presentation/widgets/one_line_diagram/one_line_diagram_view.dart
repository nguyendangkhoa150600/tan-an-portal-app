import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/features/scada/data/sources/scada_api_client.dart';
import 'package:tan_an_portal/features/scada/presentation/providers/scada_provider.dart';

class OneLineDiagramView extends StatefulWidget {
  const OneLineDiagramView({super.key});

  @override
  State<OneLineDiagramView> createState() => _OneLineDiagramViewState();
}

class _OneLineDiagramViewState extends State<OneLineDiagramView> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _initialized = false;

  static const String _baseUrl = ScadaApiClient.configuredBaseUrl;
  static const String _diagramPath = '';

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (_controller != null) return;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF05070A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) async {
            if (mounted) setState(() => _isLoading = false);

            // Clean DOM manipulation to navigate to diagram and hide portal chrome without breaking page layout
            await _controller?.runJavaScript('''
              (function() {
                function prepareDiagramView() {
                  try {
                    // 1. Click on "Sơ đồ điện" nav button if present and not active
                    var navButtons = document.querySelectorAll('nav button');
                    for (var i = 0; i < navButtons.length; i++) {
                      var text = (navButtons[i].textContent || '').trim();
                      if (text.indexOf('Sơ đồ điện') !== -1 || text.indexOf('S\\u01A1 \\u0111\\u1ED3 \\u0111i\\u1EC7n') !== -1) {
                        navButtons[i].click();
                        break;
                      }
                    }

                    // 2. Hide sidebar navigation aside and expand shell
                    var aside = document.querySelector('aside');
                    if (aside) {
                      aside.style.display = 'none';
                    }
                    var shell = document.querySelector('[class*="shell"]');
                    if (shell) {
                      shell.style.gridTemplateColumns = '1fr';
                      shell.style.display = 'grid';
                      shell.style.height = '100vh';
                      shell.style.width = '100vw';
                    }

                    // 3. Expand main and workspace to full viewport
                    var main = document.querySelector('main');
                    if (main) {
                      main.style.padding = '0';
                      main.style.margin = '0';
                      main.style.height = '100vh';
                      main.style.width = '100vw';
                    }
                    var workspace = document.querySelector('[class*="workspace"]');
                    if (workspace) {
                      workspace.style.height = '100vh';
                      workspace.style.maxHeight = '100vh';
                      workspace.style.border = 'none';
                      workspace.style.borderRadius = '0';
                    }

                    // 4. Hide portal headers and footers
                    var headers = document.querySelectorAll('header');
                    headers.forEach(function(h) { h.style.display = 'none'; });
                    var footers = document.querySelectorAll('footer');
                    footers.forEach(function(f) { f.style.display = 'none'; });
                  } catch(e) {}
                }

                prepareDiagramView();
                setTimeout(prepareDiagramView, 100);
                setTimeout(prepareDiagramView, 300);
                setTimeout(prepareDiagramView, 800);
                setTimeout(prepareDiagramView, 1500);
              })();
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            // Only show full error overlay if the main frame itself failed to load.
            // Subresource errors (e.g. Cloudflare beacon CSP block) should not break diagram display.
            if (error.isForMainFrame ?? false) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                });
              }
            }
          },
        ),
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initController();
    if (!_initialized) {
      _initialized = true;
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    _initController();
    final Map<String, String> headers = {
      'Accept': 'text/html',
      'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.8',
    };

    final uri = Uri.parse('$_baseUrl$_diagramPath');
    await _controller?.loadRequest(uri, headers: headers);
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
        // ── Header bar ──
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Title - takes all available space, ellipsis if too long
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sơ đồ nhất thứ trạm',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textStrong,
                      ),
                    ),
                    Text(
                      'Trạm biến áp 110kV Tân An',
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

        // ── WebView body ──
        Expanded(
          child: Stack(
            children: [
              if (_controller != null) _buildWebViewWidget(),

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
        ? (tagCount > 0 ? '$tagCount tín hiệu' : 'Online')
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

  Widget _buildWebViewWidget() {
    if (_controller == null) return const SizedBox.shrink();

    final controllerPlatform = _controller!.platform;
    if (controllerPlatform is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
          AndroidWebViewWidgetCreationParams(
            controller: controllerPlatform,
            displayWithHybridComposition: true,
          ),
        ),
      );
    }

    return WebViewWidget(controller: _controller!);
  }
}
