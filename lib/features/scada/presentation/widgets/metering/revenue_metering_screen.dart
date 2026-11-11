import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import '../../providers/scada_provider.dart';

class RevenueMeteringScreen extends StatefulWidget {
  final bool isEmbedded;

  const RevenueMeteringScreen({super.key, this.isEmbedded = false});

  @override
  State<RevenueMeteringScreen> createState() => _RevenueMeteringScreenState();
}

class _RevenueMeteringScreenState extends State<RevenueMeteringScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _initialized = false;
  bool _isFullscreen = false;
  bool _isLandscape = false;
  int _autoLoginAttempts = 0;
  DateTime? _lastAutoLoginTime;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A1120))
      ..addJavaScriptChannel(
        'FlutterApp',
        onMessageReceived: (JavaScriptMessage msg) {
          if (msg.message == 'enter_table_fullscreen' ||
              msg.message == 'open_fullscreen_choice' ||
              msg.message == 'toggle_fullscreen_landscape' ||
              msg.message == 'toggle_fullscreen') {
            _enterTableFullscreen();
          } else if (msg.message == 'exit_fullscreen') {
            _exitFullscreen();
          } else if (msg.message == 'toggle_orientation') {
            _toggleOrientation();
          }
        },
      )
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
                    !path.contains('/metering'));

            if (isAtLoginOrRoot) {
              final handled = await _attemptInWebViewAutoLogin();
              if (handled) return;
            }

            _autoLoginAttempts = 0;
            if (mounted) {
              setState(() => _isLoading = false);
            }
            await _injectMobileStyles();
            await _controller.runJavaScript(provider.apiClient.buildInWebViewKeepAliveScript());
            if (_isFullscreen) {
              await _controller.runJavaScript(
                'if (window.setTableFullscreenMode) window.setTableFullscreenMode(true);',
              );
            }
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

    final targetUrl = api.meteringUrl;
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
  void dispose() {
    // Reset system orientations and UI mode on leaving screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadPage();
    }
  }

  Future<void> _enterTableFullscreen() async {
    setState(() {
      _isFullscreen = true;
    });
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await _controller.runJavaScript(
      'if (window.setTableFullscreenMode) window.setTableFullscreenMode(true);',
    );
  }

  Future<void> _exitFullscreen() async {
    setState(() {
      _isFullscreen = false;
      _isLandscape = false;
    });
    await _controller.runJavaScript(
      'if (window.setTableFullscreenMode) window.setTableFullscreenMode(false);',
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _toggleOrientation() async {
    final nextState = !_isLandscape;
    setState(() {
      _isLandscape = nextState;
    });
    if (nextState) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      _controller.runJavaScript('window.dispatchEvent(new Event("resize"));');
    });
  }

  Future<void> _injectMobileStyles() async {
    const js = '''
      (function() {
        function setup() {
          try {
            // 0. Ensure viewport meta is strict for mobile fitting
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
              meta = document.createElement('meta');
              meta.name = 'viewport';
              document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

            // 1. Inject or update declarative mobile CSS
            var styleId = 'mobile-portal-injected-style';
            var style = document.getElementById(styleId);
            if (!style) {
              style = document.createElement('style');
              style.id = styleId;
              document.head.appendChild(style);
            }
            style.textContent = `
              /* 1. Global Box-Sizing & Viewport Containment: strictly 100% width, no horizontal spill */
              *, *::before, *::after {
                box-sizing: border-box !important;
              }

              :focus, :focus-visible, .mtr-page :focus-visible, [tabindex]:focus, [tabindex]:focus-visible {
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

              /* 2. Hide platform shell chrome (desktop sidebar, master header, footer) */
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

              /* 3. Convert desktop 2-column grid shell to fluid 100% block */
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
                padding: 8px 10px 24px 10px !important;
                box-sizing: border-box !important;
                background: #0a1120 !important;
                overflow-x: hidden !important;
              }

              .portal-content,
              .mtr-page {
                display: block !important;
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
                margin: 0 !important;
                padding: 0 !important;
                overflow-x: hidden !important;
              }

              .mtr-body {
                display: flex !important;
                flex-direction: column !important;
                gap: 10px !important;
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
                overflow-x: hidden !important;
              }

              /* 4. Top Bar (Plant name & Month Selector) */
              .mtr-top {
                display: flex !important;
                flex-direction: column !important;
                align-items: stretch !important;
                gap: 8px !important;
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
              }

              .mtr-plant {
                display: inline-flex !important;
                align-self: flex-start !important;
                max-width: 100% !important;
              }

              .mtr-actions {
                display: flex !important;
                align-items: center !important;
                gap: 8px !important;
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
              }

              /* 1. Hộp chọn thời gian tích hợp liền mạch (Unified Date Capsule) */
              #mtr-date-unified-group {
                display: inline-flex !important;
                align-items: center !important;
                background: #111a2e !important;
                border: 1px solid rgba(56, 189, 248, 0.32) !important;
                border-radius: 10px !important;
                height: 38px !important;
                box-shadow: 0 2px 8px rgba(0, 0, 0, 0.35) !important;
                cursor: pointer !important;
                position: relative !important;
                overflow: hidden !important;
                flex-shrink: 0 !important;
                -webkit-tap-highlight-color: transparent !important;
                transition: border-color 0.2s ease, background 0.2s ease !important;
              }

              #mtr-date-unified-group:active {
                background: #16213a !important;
                border-color: rgba(56, 189, 248, 0.55) !important;
              }

              #mtr-date-unified-group .mtr-months {
                display: inline-flex !important;
                align-items: center !important;
                background: transparent !important;
                border: none !important;
                box-shadow: none !important;
                padding: 0 10px 0 12px !important;
                height: 100% !important;
                margin: 0 !important;
                overflow: visible !important;
                pointer-events: none !important;
              }

              #mtr-date-unified-group .mtr-months .mtr-thumb {
                display: none !important;
              }

              #mtr-date-unified-group .mtr-months a:not([aria-current="page"]) {
                display: none !important;
              }

              #mtr-date-unified-group .mtr-months a[aria-current="page"] {
                display: inline-flex !important;
                align-items: center !important;
                gap: 8px !important;
                height: 100% !important;
                padding: 0 !important;
                margin: 0 !important;
                background: transparent !important;
                border: none !important;
                color: #f1f5f9 !important;
                font-size: 13.5px !important;
                font-weight: 700 !important;
                letter-spacing: 0.2px !important;
                text-decoration: none !important;
                white-space: nowrap !important;
                pointer-events: none !important;
              }

              #mtr-date-unified-group .mtr-months a[aria-current="page"] .mtr-src {
                width: 7px !important;
                height: 7px !important;
                border-radius: 50% !important;
                background: #38bdf8 !important;
                box-shadow: 0 0 8px rgba(56, 189, 248, 0.8) !important;
                flex-shrink: 0 !important;
              }

              /* Vạch ngăn mỏng & Nút icon lịch liền mạch bên trong cùng capsule */
              #mtr-date-unified-group .mtr-pick {
                display: inline-flex !important;
                align-items: center !important;
                border-left: 1px solid rgba(255, 255, 255, 0.12) !important;
                height: 100% !important;
                position: static !important;
                margin: 0 !important;
              }

              #mtr-date-unified-group .mtr-pick > summary.mtr-ib {
                display: inline-grid !important;
                place-items: center !important;
                width: 36px !important;
                height: 100% !important;
                background: transparent !important;
                border: none !important;
                box-shadow: none !important;
                border-radius: 0 9px 9px 0 !important;
                color: #38bdf8 !important;
                cursor: pointer !important;
                padding: 0 !important;
                margin: 0 !important;
                pointer-events: none !important;
              }

              #mtr-date-unified-group .mtr-pick > summary.mtr-ib svg {
                width: 17px !important;
                height: 17px !important;
              }

              /* Form & Input phủ toàn bộ capsule 100% trong suốt, chạm vào mở ngay date wheel */
              #mtr-date-unified-group .mtr-pop {
                position: absolute !important;
                inset: 0 !important;
                width: 100% !important;
                height: 100% !important;
                margin: 0 !important;
                padding: 0 !important;
                border: none !important;
                background: transparent !important;
                box-shadow: none !important;
                z-index: 20 !important;
                display: block !important;
                cursor: pointer !important;
                animation: none !important;
              }

              #mtr-date-unified-group .mtr-pop .mtr-input {
                position: absolute !important;
                inset: 0 !important;
                width: 100% !important;
                height: 100% !important;
                opacity: 0 !important;
                cursor: pointer !important;
                z-index: 21 !important;
                border: none !important;
                margin: 0 !important;
                padding: 0 !important;
                background: transparent !important;
                -webkit-appearance: none !important;
                -webkit-tap-highlight-color: transparent !important;
              }

              #mtr-date-unified-group .mtr-pop button[type="submit"],
              #mtr-date-unified-group .mtr-pop .mtr-sr {
                display: none !important;
              }

              /* 2. Nhóm nút chức năng bên phải: Cài đặt và Tải xuống */
              .mtr-gear {
                margin-left: auto !important;
                flex-shrink: 0 !important;
                width: 38px !important;
                height: 38px !important;
                border-radius: 10px !important;
                background: #111a2e !important;
                border: 1px solid rgba(255, 255, 255, 0.12) !important;
              }

              .mtr-primary {
                flex-shrink: 0 !important;
                width: 38px !important;
                height: 38px !important;
                border-radius: 10px !important;
              }

              /* 5. KPI Cards: 2-Column Responsive Grid strictly constrained within 100% */
              .mtr-kpis {
                display: grid !important;
                grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
                gap: 8px !important;
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
                margin: 0 !important;
              }

              .mtr-kpi-hero {
                grid-column: span 2 !important;
              }

              .mtr-kpi {
                display: flex !important;
                flex-direction: column !important;
                gap: 4px !important;
                min-width: 0 !important;
                max-width: 100% !important;
                padding: 10px 12px !important;
                box-sizing: border-box !important;
                overflow: hidden !important;
              }

              .mtr-val {
                font-size: clamp(17px, 4.4vw, 22px) !important;
                overflow: hidden !important;
                text-overflow: ellipsis !important;
                white-space: nowrap !important;
              }

              .mtr-kpi-hero .mtr-val {
                font-size: clamp(21px, 5.5vw, 28px) !important;
              }

              .mtr-lab {
                font-size: 11.5px !important;
                overflow: hidden !important;
                text-overflow: ellipsis !important;
                white-space: nowrap !important;
              }

              /* 6. Main section: Chart & Side info */
              .mtr-main {
                display: flex !important;
                flex-direction: column !important;
                gap: 10px !important;
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
              }

              .mtr-chart-card {
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
                box-sizing: border-box !important;
                overflow: hidden !important;
              }

              .mtr-bar {
                display: flex !important;
                flex-wrap: wrap !important;
                align-items: center !important;
                gap: 6px !important;
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
              }

              .mtr-legend {
                margin-left: 0 !important;
                display: flex !important;
                flex-wrap: wrap !important;
                gap: 4px !important;
              }

              .mtr-chart {
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
                overflow: hidden !important;
              }

              .mtr-side {
                display: flex !important;
                flex-direction: column !important;
                gap: 10px !important;
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
              }

              .mtr-side .mtr-card {
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
                box-sizing: border-box !important;
              }

              /* 7. Details / Table Section: contained table scroll */
              .mtr-details {
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
                box-sizing: border-box !important;
                overflow: hidden !important;
              }

              .mtr-details .mtr-tabs {
                display: flex !important;
                align-items: center !important;
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
                box-sizing: border-box !important;
                overflow-x: auto !important;
                -webkit-overflow-scrolling: touch !important;
                scrollbar-width: none !important;
              }
              .mtr-details .mtr-tabs::-webkit-scrollbar {
                display: none !important;
              }

              .mtr-details .mtr-twrap {
                width: 100% !important;
                max-width: 100% !important;
                min-width: 0 !important;
                box-sizing: border-box !important;
                overflow-x: auto !important;
                -webkit-overflow-scrolling: touch !important;
                max-height: 380px !important;
              }

              .mtr-details .mtr-twrap table {
                width: max-content !important;
                min-width: 100% !important;
              }

              /* ---------------- FULLSCREEN TABLE ONLY MODE ---------------- */
              body.mtr-table-fs-active {
                overflow: hidden !important;
                margin: 0 !important;
                padding: 0 !important;
                background: #0a1120 !important;
              }

              /* In fullscreen mode, ONLY show the table card. Hide all other sections */
              body.mtr-table-fs-active .mtr-top,
              body.mtr-table-fs-active .mtr-kpis,
              body.mtr-table-fs-active .mtr-main,
              body.mtr-table-fs-active .master-sidebar,
              body.mtr-table-fs-active .master-header,
              body.mtr-table-fs-active .master-footer,
              body.mtr-table-fs-active footer,
              body.mtr-table-fs-active .workspace-message,
              body.mtr-table-fs-active .mtr-tip {
                display: none !important;
              }

              body.mtr-table-fs-active html,
              body.mtr-table-fs-active .master-shell,
              body.mtr-table-fs-active .master-workspace,
              body.mtr-table-fs-active .portal-content,
              body.mtr-table-fs-active .mtr-page {
                display: flex !important;
                flex-direction: column !important;
                width: 100vw !important;
                height: 100vh !important;
                height: 100dvh !important;
                max-width: 100vw !important;
                max-height: 100vh !important;
                margin: 0 !important;
                padding: 0 !important;
                overflow: hidden !important;
                background: #0a1120 !important;
              }

              body.mtr-table-fs-active .mtr-body {
                display: flex !important;
                flex-direction: column !important;
                flex: 1 1 auto !important;
                width: 100% !important;
                height: 100% !important;
                margin: 0 !important;
                padding: 0 !important;
                gap: 0 !important;
                overflow: hidden !important;
                background: #0a1120 !important;
              }

              body.mtr-table-fs-active .mtr-details {
                display: flex !important;
                flex-direction: column !important;
                flex: 1 1 auto !important;
                width: 100% !important;
                height: 100% !important;
                max-height: 100% !important;
                margin: 0 !important;
                padding: 6px 10px 10px 10px !important;
                border-radius: 0 !important;
                border: none !important;
                box-sizing: border-box !important;
                overflow: hidden !important;
                background: #0a1120 !important;
              }

              body.mtr-table-fs-active .mtr-details .mtr-tabs {
                flex-shrink: 0 !important;
                margin-bottom: 6px !important;
                background: #111a2e !important;
                border-radius: 8px !important;
                padding: 4px 8px !important;
                border-bottom: 1px solid rgba(56, 189, 248, 0.25) !important;
              }

              body.mtr-table-fs-active .mtr-details .mtr-twrap {
                flex: 1 1 0% !important;
                height: 100% !important;
                max-height: none !important;
                overflow: auto !important;
                -webkit-overflow-scrolling: touch !important;
                border-radius: 8px !important;
                background: #111a2e !important;
                border: 1px solid rgba(255, 255, 255, 0.08) !important;
              }

              /* Tooltip styling for mobile chart hover / tap */
              .mtr-tip {
                position: fixed !important;
                z-index: 9999999 !important;
                pointer-events: none !important;
                max-width: min(320px, calc(100vw - 20px)) !important;
                box-shadow: 0 12px 36px rgba(0, 0, 0, 0.85) !important;
                background: rgba(22, 33, 58, 0.98) !important;
                border: 1px solid rgba(255, 255, 255, 0.16) !important;
                border-radius: 10px !important;
                padding: 9px 12px !important;
              }

              .mtr-tip.mtr-on {
                opacity: 1 !important;
                display: block !important;
                visibility: visible !important;
                transform: none !important;
              }

              /* Hide the unwanted platform status toast */
              [data-toast],
              .mtr-toast {
                display: none !important;
              }
            `;

            // 2. Window helper to set table fullscreen mode
            window.setTableFullscreenMode = function(enable) {
              if (enable) {
                document.body.classList.add('mtr-table-fs-active');
              } else {
                document.body.classList.remove('mtr-table-fs-active');
              }
              var btnFs = document.getElementById('mtr-btn-fs-choice');
              if (btnFs) {
                if (enable) {
                  btnFs.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M8 3v3a2 2 0 0 1-2 2H3m18 0h-3a2 2 0 0 1-2-2V3m0 18v-3a2 2 0 0 1 2-2h3M3 16h3a2 2 0 0 1 2 2v3"/></svg>';
                  btnFs.title = 'Thu nhỏ';
                  btnFs.style.background = 'rgba(239, 68, 68, 0.18)';
                  btnFs.style.color = '#f87171';
                  btnFs.style.borderColor = 'rgba(239, 68, 68, 0.45)';
                } else {
                  btnFs.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/></svg>';
                  btnFs.title = 'Toàn bảng';
                  btnFs.style.background = 'rgba(56, 189, 248, 0.15)';
                  btnFs.style.color = '#38bdf8';
                  btnFs.style.borderColor = 'rgba(56, 189, 248, 0.45)';
                }
              }
            };

            // 3. Inject Action buttons into .mtr-tabs (Icon-only buttons)
            var tabs = document.querySelector('.mtr-tabs');
            if (tabs && !document.getElementById('mtr-btn-expand-tab')) {
              var group = document.createElement('div');
              group.id = 'mtr-btn-expand-tab';
              group.style.cssText = 'margin-left: auto; display: inline-flex; align-items: center; gap: 6px; flex-shrink: 0; padding-left: 6px;';

              // Button 1: Xoay (Icon only)
              var btnRot = document.createElement('button');
              btnRot.id = 'mtr-btn-rot-quick';
              btnRot.type = 'button';
              btnRot.title = 'Xoay màn hình';
              btnRot.style.cssText = 'display: inline-grid; place-items: center; width: 32px; height: 32px; padding: 0; border-radius: 7px; background: rgba(148, 163, 184, 0.12); color: #94a3b8; border: 1px solid rgba(148, 163, 184, 0.3); cursor: pointer; -webkit-tap-highlight-color: transparent;';
              btnRot.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg>';
              btnRot.onclick = function(e) {
                e.preventDefault();
                e.stopPropagation();
                if (window.FlutterApp) {
                  window.FlutterApp.postMessage('toggle_orientation');
                }
              };

              // Button 2: Toàn bảng (Icon only)
              var btnFs = document.createElement('button');
              btnFs.id = 'mtr-btn-fs-choice';
              btnFs.type = 'button';
              var isCurrentFs = document.body.classList.contains('mtr-table-fs-active');
              btnFs.title = isCurrentFs ? 'Thu nhỏ' : 'Toàn bảng';
              btnFs.style.cssText = isCurrentFs
                ? 'display: inline-grid; place-items: center; width: 32px; height: 32px; padding: 0; border-radius: 7px; background: rgba(239, 68, 68, 0.18); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.45); cursor: pointer; -webkit-tap-highlight-color: transparent;'
                : 'display: inline-grid; place-items: center; width: 32px; height: 32px; padding: 0; border-radius: 7px; background: rgba(56, 189, 248, 0.15); color: #38bdf8; border: 1px solid rgba(56, 189, 248, 0.45); cursor: pointer; -webkit-tap-highlight-color: transparent;';
              btnFs.innerHTML = isCurrentFs
                ? '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M8 3v3a2 2 0 0 1-2 2H3m18 0h-3a2 2 0 0 1-2-2V3m0 18v-3a2 2 0 0 1 2-2h3M3 16h3a2 2 0 0 1 2 2v3"/></svg>'
                : '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/></svg>';
              btnFs.onclick = function(e) {
                e.preventDefault();
                e.stopPropagation();
                var isFs = document.body.classList.contains('mtr-table-fs-active');
                window.setTableFullscreenMode(!isFs);
                if (window.FlutterApp) {
                  window.FlutterApp.postMessage(isFs ? 'exit_fullscreen' : 'enter_table_fullscreen');
                }
              };

              group.appendChild(btnRot);
              group.appendChild(btnFs);
              tabs.appendChild(group);
            }

            // 4. Mobile Chart Hover & Tap Tooltip Handler
            var chartHost = document.querySelector('[data-chart]');
            var tip = document.querySelector('[data-tip-box]');

            if (chartHost && tip && !window._mobileChartTouchAttached) {
              window._mobileChartTouchAttached = true;

              // Hook tip.classList.remove to prevent native 'pointerleave' from hiding the tip immediately on finger lift
              var origRemove = tip.classList.remove.bind(tip.classList);
              tip.classList.remove = function(cls) {
                if (cls === 'mtr-on' && window._keepMobileTip) {
                  return;
                }
                return origRemove.apply(this, arguments);
              };

              function showMobileDayTooltip(clientX, clientY) {
                var svg = chartHost.querySelector('svg');
                if (!svg) return;

                var hit = svg.querySelector('rect[fill="transparent"]');
                if (hit) {
                  var pEvent = new PointerEvent('pointermove', {
                    clientX: clientX,
                    clientY: clientY,
                    bubbles: true,
                    cancelable: true
                  });
                  hit.dispatchEvent(pEvent);
                }

                // If native handler hasn't populated tip, build from JSON data as fallback
                var source = document.getElementById('metering-page-data');
                if (source && (!tip.classList.contains('mtr-on') || !tip.innerHTML)) {
                  try {
                    var D = JSON.parse(source.textContent);
                    var activeM = document.querySelector('[data-months] [aria-current="page"]')?.dataset.v ||
                                  document.querySelector('[data-months] [aria-pressed="true"]')?.dataset.v || D.month;
                    var m = D.months ? D.months[activeM] : null;
                    if (m && m.chart) {
                      var r = svg.getBoundingClientRect();
                      var W = Math.max(320, Math.round(r.width));
                      var P = { l: 58, r: 20 };
                      var pw = W - P.l - P.r;
                      var xInSvg = (clientX - r.left) * (W / r.width);
                      var dim = m.days || 31;
                      var sw = pw / dim;
                      var dayIndex = Math.max(0, Math.min(dim - 1, Math.floor((xInSvg - P.l) / sw)));
                      var day = m.chart[dayIndex];
                      if (day) {
                        var T = D.text || {};
                        var G = D.groups ? D.groups.length : 0;
                        var activeMeasure = document.querySelector('[data-measure] [aria-pressed="true"]')?.dataset.v || 'revenue';
                        var isEnergy = activeMeasure === 'energy';
                        var weekdays = T.weekdays || ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
                        var dateTitle = (weekdays[day[1]] || '') + ' ' + (day[0] < 10 ? '0' + day[0] : day[0]) + '/' + activeM.slice(5, 7);
                        var html = '<div class="mtr-t">' + dateTitle + '</div>';

                        var css = getComputedStyle(document.querySelector('[data-metering-page]') || document.body);
                        var vals = isEnergy ? day[3] : day[4];
                        var sum = 0;
                        if (Array.isArray(vals)) {
                          for (var g = 0; g < G; g++) {
                            var v = vals[g] || 0;
                            sum += v;
                            var color = css.getPropertyValue('--mtr-s' + Math.min(g + 1, 8)).trim() || '#38bdf8';
                            var valStr = isEnergy
                              ? new Intl.NumberFormat(D.locale || 'vi-VN', { maximumFractionDigits: 1 }).format(v) + ' kWh'
                              : new Intl.NumberFormat(D.locale || 'vi-VN').format(Math.round(v)) + ' đ';
                            html += '<div class="mtr-r" style="--c:' + color + '"><i></i><span>' + (D.groups[g] || '') + '</span><b>' + valStr + '</b></div>';
                          }
                          var sumStr = isEnergy
                            ? new Intl.NumberFormat(D.locale || 'vi-VN', { maximumFractionDigits: 1 }).format(sum) + ' kWh'
                            : new Intl.NumberFormat(D.locale || 'vi-VN').format(Math.round(sum)) + ' đ';
                          html += '<div class="mtr-r mtr-sum"><i></i><span>' + (T.total || 'Cộng') + '</span><b>' + sumStr + '</b></div>';
                        }
                        tip.innerHTML = html;
                        tip.classList.add('mtr-on');
                      }
                    }
                  } catch(err) {}
                }

                window._keepMobileTip = true;
                setTimeout(function() {
                  if (!tip.classList.contains('mtr-on')) {
                    tip.classList.add('mtr-on');
                  }
                  var r = tip.getBoundingClientRect();
                  var left = clientX - r.width / 2;
                  if (left < 10) left = 10;
                  if (left + r.width > window.innerWidth - 10) {
                    left = window.innerWidth - r.width - 10;
                  }
                  var top = clientY - r.height - 18;
                  if (top < 10) {
                    top = clientY + 22;
                  }
                  tip.style.left = left + 'px';
                  tip.style.top = top + 'px';
                }, 10);
              }

              function onChartTouch(e) {
                var touch = e.touches ? e.touches[0] : e;
                if (!touch) return;
                window._keepMobileTip = true;
                showMobileDayTooltip(touch.clientX, touch.clientY);
              }

              chartHost.addEventListener('touchstart', onChartTouch, { passive: true });
              chartHost.addEventListener('touchmove', onChartTouch, { passive: true });
              chartHost.addEventListener('click', onChartTouch, { passive: true });

              var strip = document.querySelector('[data-strip]');
              if (strip) {
                strip.addEventListener('touchstart', function(e) {
                  var touch = e.touches ? e.touches[0] : e;
                  if (!touch) return;
                  var cell = document.elementFromPoint(touch.clientX, touch.clientY)?.closest('i[data-d]');
                  if (cell) {
                    window._keepMobileTip = true;
                    var r = cell.getBoundingClientRect();
                    showMobileDayTooltip(r.left + r.width / 2, r.bottom + 8);
                  }
                }, { passive: true });
              }

              // Tap outside hides the tooltip
              document.addEventListener('touchstart', function(e) {
                if (!e.target.closest('[data-chart]') && !e.target.closest('[data-strip]')) {
                  window._keepMobileTip = false;
                  if (tip) {
                    origRemove('mtr-on');
                  }
                }
              }, { passive: true });
            }

            // 5. Build Unified Date Selector Group (#mtr-date-unified-group)
            var actions = document.querySelector('.mtr-actions');
            var months = document.querySelector('.mtr-months');
            var pick = document.querySelector('.mtr-pick');

            if (actions && months && pick && !document.getElementById('mtr-date-unified-group')) {
              var group = document.createElement('div');
              group.id = 'mtr-date-unified-group';
              actions.insertBefore(group, months);
              group.appendChild(months);
              group.appendChild(pick);

              // Always keep details open so the transparent input overlays the entire capsule
              pick.setAttribute('open', '');
              pick.open = true;

              pick.addEventListener('toggle', function() {
                if (!pick.open) pick.open = true;
              });

              var inp = document.getElementById('metering-month');
              if (inp) {
                inp.addEventListener('change', function() {
                  if (inp.value && inp.form) {
                    inp.form.submit();
                  }
                });
              }
            }

            // Format month label to "Tháng MM/YYYY"
            var activeLink = document.querySelector('.mtr-months a[aria-current="page"]');
            if (activeLink && !activeLink._formatted) {
              activeLink._formatted = true;
              var dot = activeLink.querySelector('.mtr-src');
              var raw = activeLink.textContent.trim();
              if (raw && !raw.startsWith('Tháng')) {
                activeLink.innerHTML = '';
                if (dot) activeLink.appendChild(dot);
                var txtSpan = document.createElement('span');
                txtSpan.innerHTML = '<span style="color:#94a3b8;font-weight:500;margin-right:2px;">Tháng</span> ' + raw;
                activeLink.appendChild(txtSpan);
              }
            }

            // 6. Force browser resize event to let charts re-measure to exact fluid width
            window.dispatchEvent(new Event('resize'));
          } catch(err) {
            console.error(err);
          }
        }

        setup();
        setTimeout(setup, 200);
        setTimeout(setup, 600);
        setTimeout(setup, 1500);
        setTimeout(setup, 3000);
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

    final targetUrl = apiClient.meteringUrl;
    if (kDebugMode) {
      print('Loading metering page: $targetUrl');
    }

    await _controller.loadRequest(
      Uri.parse(targetUrl),
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
    final content = Stack(
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
                  const Text(
                    'Không thể tải dữ liệu sản lượng & doanh thu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1120),
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: AppTheme.surface,
              elevation: 0,
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppTheme.textStrong,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sản lượng & doanh thu',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textStrong,
                    ),
                  ),
                  Text(
                    'Nhà máy Tân Ân 1',
                    style: TextStyle(
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
      body: PopScope(
        canPop: !_isFullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isFullscreen) {
            _exitFullscreen();
          }
        },
        child: SafeArea(
          top: !_isFullscreen,
          bottom: !_isFullscreen,
          left: !_isFullscreen,
          right: !_isFullscreen,
          child: content,
        ),
      ),
    );
  }
}
