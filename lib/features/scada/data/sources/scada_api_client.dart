import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ScadaApiException implements Exception {
  final int statusCode;
  final String message;

  const ScadaApiException(this.statusCode, this.message);

  @override
  String toString() => 'ScadaApiException($statusCode): $message';
}

typedef SessionExpiredCallback = Future<bool> Function();
typedef CookiesChangedCallback = void Function(String? cookieHeader);

/// API Client for Savina Platform (`https://monitor.svndts.com`)
/// Providing access to SCADA feeds, authentication, and factory modules.
class ScadaApiClient {
  static const String defaultBaseUrl = 'https://monitor.svndts.com';
  static const String configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  /// Production UUID for Tân Ân 1 factory module in savina-platform
  static const String defaultFactoryModuleId = '01a04643-27bf-70a3-ae33-d5cf3e33f008';
  /// Production UUID for Tân Ân 1 factory in savina-platform
  static const String defaultFactoryId = '01a04643-2684-726e-ae59-ea3664bb9016';

  final String baseUrl;
  String factoryModuleId;
  String factoryId;
  String workspacePath;
  final http.Client _http;
  final Map<String, String> _cookies = {};

  SessionExpiredCallback? onSessionExpired;
  CookiesChangedCallback? onCookiesChanged;
  Future<bool>? _refreshFuture;

  ScadaApiClient({
    String? baseUrl,
    String? factoryModuleId,
    String? factoryId,
    http.Client? httpClient,
  })  : baseUrl = (baseUrl ?? configuredBaseUrl).replaceFirst(RegExp(r'/$'), ''),
        factoryModuleId = factoryModuleId ?? defaultFactoryModuleId,
        factoryId = factoryId ?? defaultFactoryId,
        workspacePath = '/workspace/${factoryModuleId ?? defaultFactoryModuleId}/diagram',
        _http = httpClient ?? http.Client();

  String? get sessionToken => _cookieHeader();
  http.Client get httpClient => _http;
  String get meteringPath => '/workspace/$factoryModuleId/metering';
  String get meteringUrl => '$baseUrl$meteringPath';
  String get membersPath => '/factories/$factoryId/members?workspace=$factoryModuleId';
  String get membersUrl => '$baseUrl$membersPath';
  String get accessRolesPath => '/factories/$factoryId/access-roles?workspace=$factoryModuleId';
  String get accessRolesUrl => '$baseUrl$accessRolesPath';

  List<String> userRoles = [];
  Set<String>? allowedPageKeys; // null = không giới hạn (xem tất cả các trang)
  bool canManageMembers = true;

  String? savedUsername;
  String? savedPassword;

  String? get savedEmail {
    if (savedUsername == null || savedUsername!.isEmpty) return null;
    final u = savedUsername!.trim();
    if (u.contains('@')) return u;
    if (u == 'admin') return 'savinahub@gmail.com';
    return '$u@svndts.com';
  }

  void setSavedCredentials(String? username, String? password) {
    savedUsername = username;
    savedPassword = password;
  }

  Future<void> ensureSavedCredentialsLoaded() async {
    if (savedUsername != null && savedPassword != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final u = prefs.getString('remembered_username') ?? prefs.getString('username');
      final p = prefs.getString('remembered_password');
      if (u != null && p != null) {
        setSavedCredentials(u, p);
      }
    } catch (_) {}
  }

  /// Tạo đoạn mã JavaScript để tự động đăng nhập in-WebView khi bị chuyển hướng về login
  String buildInWebViewAutoLoginScript(String targetUrl) {
    final email = savedEmail ?? '';
    final password = savedPassword ?? '';
    final emailJson = jsonEncode(email);
    final passwordJson = jsonEncode(password);
    final targetJson = jsonEncode(targetUrl);

    return '''
      (async function() {
        try {
          var email = $emailJson;
          var password = $passwordJson;
          if (!email || !password) return 'NO_CREDENTIALS';

          var meta = document.querySelector('meta[name="csrf-token"]');
          var csrf = meta ? meta.getAttribute('content') : '';
          if (!csrf) {
            var m = document.cookie.match(/XSRF-TOKEN=([^;]+)/);
            if (m) csrf = decodeURIComponent(m[1]);
          }

          if (!csrf) {
            try {
              var sRes = await fetch('/api/v1/auth/session', {
                headers: { 'Accept': 'application/json' },
                credentials: 'include'
              });
              var m2 = document.cookie.match(/XSRF-TOKEN=([^;]+)/);
              if (m2) csrf = decodeURIComponent(m2[1]);
            } catch(e) {}
          }

          var res = await fetch('/api/v1/auth/login', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-CSRF-TOKEN': csrf || '',
              'X-XSRF-TOKEN': csrf || ''
            },
            body: JSON.stringify({ email: email, password: password }),
            credentials: 'include'
          });

          if (res.ok) {
            window.location.replace($targetJson);
            return 'OK';
          }
          return 'FAIL_' + res.status;
        } catch(e) {
          return 'ERR_' + (e ? e.message : 'unknown');
        }
      })();
    ''';
  }

  Future<bool> _handleSessionExpired() async {
    final callback = onSessionExpired;
    if (callback == null) return false;

    if (_refreshFuture != null) {
      return await _refreshFuture!;
    }

    _refreshFuture = () async {
      try {
        return await callback();
      } catch (_) {
        return false;
      } finally {
        _refreshFuture = null;
      }
    }();

    return await _refreshFuture!;
  }

  void setSessionToken(String? token) {
    _cookies.clear();
    if (token != null && token.isNotEmpty) {
      final parts = token.split(';');
      for (final part in parts) {
        final idx = part.indexOf('=');
        if (idx > 0) {
          final k = part.substring(0, idx).trim();
          final v = part.substring(idx + 1).trim();
          _cookies[k] = v;
        }
      }
      syncCookiesToWebView();
    }
  }

  void clearSession() {
    _cookies.clear();
    userRoles.clear();
    allowedPageKeys = null;
    canManageMembers = true;
    savedUsername = null;
    savedPassword = null;
    try {
      WebViewCookieManager().clearCookies();
    } catch (_) {}
  }

  /// Đồng bộ toàn bộ cookies phiên đăng nhập vào WebViewCookieManager
  /// để các WebView (Sơ đồ điện, Vai trò truy cập, Thành viên, Doanh thu)
  /// luôn giữ được phiên làm việc và không bị bắt đăng nhập lại trên Android release.
  Future<void> syncCookiesToWebView() async {
    if (_cookies.isEmpty) return;

    final cookieManager = WebViewCookieManager();
    final Uri baseUri = Uri.parse(baseUrl);
    final host = baseUri.host;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    // Thiết lập cho tất cả các biến thể domain hợp lệ (host-only, wildcard, scheme URL)
    final domains = <String>{
      'https://$host',
      'https://$host/',
      host,
      '.$host',
    };
    if (host.contains('.')) {
      final parts = host.split('.');
      if (parts.length >= 2) {
        final rootDomain = '${parts[parts.length - 2]}.${parts.last}';
        domains.add('https://$rootDomain');
        domains.add('https://$rootDomain/');
        domains.add(rootDomain);
        domains.add('.$rootDomain');
      }
    }

    for (final entry in _cookies.entries) {
      final rawValue = entry.value;
      // Trên Android, webview_flutter_android gọi Uri.encodeComponent(cookie.value),
      // nên cần decode trước để không bị biến thành %253D làm hỏng giải mã session của Laravel.
      String val = rawValue;
      if (isAndroid) {
        try {
          val = Uri.decodeComponent(rawValue);
        } catch (_) {
          val = rawValue;
        }
      }

      for (final domain in domains) {
        try {
          await cookieManager.setCookie(
            WebViewCookie(
              name: entry.key,
              value: val,
              domain: domain,
              path: '/',
            ),
          );
        } catch (_) {}
      }
    }
  }

  String? _cookieHeader() {
    if (_cookies.isEmpty) return null;
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  String? _getXsrfToken() {
    final raw = _cookies['XSRF-TOKEN'];
    if (raw == null || raw.isEmpty) return null;
    return Uri.decodeComponent(raw);
  }

  void _extractCookies(http.Response response) {
    final rawSetCookie = response.headers['set-cookie'];
    if (rawSetCookie == null || rawSetCookie.isEmpty) return;

    bool updated = false;
    // Splits headers separated by commas that start a new cookie
    final cookieRegex = RegExp(r'(?:^|,\s*)([A-Za-z0-9_.-]+)=([^;,]+)');
    final matches = cookieRegex.allMatches(rawSetCookie);
    for (final m in matches) {
      final name = m.group(1);
      final value = m.group(2);
      if (name != null && value != null) {
        // Skip directives like Path, Domain, Expires, SameSite, Max-Age
        final lower = name.toLowerCase();
        if (lower == 'path' ||
            lower == 'domain' ||
            lower == 'expires' ||
            lower == 'samesite' ||
            lower == 'max-age') {
          continue;
        }
        if (_cookies[name] != value) {
          _cookies[name] = value;
          updated = true;
        }
      }
    }
    if (updated) {
      onCookiesChanged?.call(_cookieHeader());
      syncCookiesToWebView();
    }
  }

  /// Ensure we have a valid CSRF token from Laravel session before POSTing
  Future<void> _ensureCsrfToken() async {
    if (_cookies.containsKey('XSRF-TOKEN')) return;
    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/session');
      final res = await _http.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));
      _extractCookies(res);
    } catch (_) {}
  }

  /// System healthcheck
  Future<Map<String, dynamic>> health() async {
    try {
      final uri = Uri.parse('$baseUrl/up');
      final res = await _http.get(uri).timeout(const Duration(seconds: 6));
      final bool isUp = res.statusCode == 200;
      return {
        'status': isUp ? 'ready' : 'degraded',
        'database': isUp ? 'ready' : 'unknown',
        'persistence': isUp ? 'ready' : 'unknown',
      };
    } catch (_) {
      return {
        'status': 'offline',
        'database': 'unknown',
        'persistence': 'unknown',
      };
    }
  }

  /// Sơ đồ nhất thứ trạm 110kV (feed: oneline)
  Future<Map<String, dynamic>> realtimeDiagram() async {
    final res = await _getData('oneline');
    final payload = res['payload'];
    final snapshot = payload is Map
        ? (payload['snapshot'] is Map ? payload['snapshot'] : payload)
        : <String, dynamic>{};
    return {
      'status': res['available'] == true || snapshot.isNotEmpty ? 'ready' : 'empty',
      'receivedAt': res['receivedAt'] ?? DateTime.now().toIso8601String(),
      'snapshot': snapshot,
    };
  }

  /// Giám sát 24 tuabin gió (feed: turbines + sources status)
  Future<Map<String, dynamic>> realtimeTurbines() async {
    final res = await _getData('turbines');
    final payload = res['payload'];

    List<dynamic> turbines = [];
    Map<String, dynamic> sources = {
      'wind': {'ready': true, 'ageSeconds': 3},
      'vestas': {'ready': true, 'ageSeconds': 3},
    };

    if (payload is Map) {
      if (payload['turbines'] is List) {
        turbines = payload['turbines'] as List;
      }
      if (payload['sources'] is Map) {
        sources = Map<String, dynamic>.from(payload['sources'] as Map);
      }
    } else if (payload is List) {
      turbines = payload;
    } else if (res['turbines'] is List) {
      turbines = res['turbines'] as List;
    }

    return {
      'status': 'ready',
      'sources': sources,
      'turbines': turbines,
    };
  }

  /// Thông số nhà máy điện gió 1 - Windey (feed: wind)
  Future<Map<String, dynamic>> windSnapshot() async {
    final res = await _getData('wind');
    final payload = res['payload'];
    final snapshot = payload is Map
        ? (payload['snapshot'] is Map ? payload['snapshot'] : payload)
        : <String, dynamic>{};
    return {
      'status': res['available'] == true || snapshot.isNotEmpty ? 'ready' : 'empty',
      'receivedAt': res['receivedAt'] ?? DateTime.now().toIso8601String(),
      'snapshot': snapshot,
    };
  }

  /// Thông số IEC tuabin Vestas - ĐG2 (feed: vestas)
  Future<Map<String, dynamic>> vestasIecSnapshot() async {
    final res = await _getData('vestas');
    final payload = res['payload'];
    final snapshot = payload is Map
        ? (payload['snapshot'] is Map ? payload['snapshot'] : payload)
        : <String, dynamic>{};
    return {
      'status': res['available'] == true || snapshot.isNotEmpty ? 'ready' : 'empty',
      'receivedAt': res['receivedAt'] ?? DateTime.now().toIso8601String(),
      'snapshot': snapshot,
    };
  }

  /// Thông số Vestas Live & điều độ EVN - ĐG2 (feed: vestas-live)
  Future<Map<String, dynamic>> vestasLive() async {
    final res = await _getData('vestas-live');
    final payload = res['payload'];
    final snapshot = payload is Map
        ? (payload['snapshot'] is Map ? payload['snapshot'] : payload)
        : <String, dynamic>{};
    return {
      'status': res['available'] == true || snapshot.isNotEmpty ? 'ready' : 'empty',
      'receivedAt': res['receivedAt'] ?? DateTime.now().toIso8601String(),
      'snapshot': snapshot,
    };
  }

  /// Phân tích sản lượng (feed: overview)
  Future<Map<String, dynamic>> analyticsOverview({
    required String granularity,
    required String anchor,
  }) async {
    final res = await _getData(
      'overview',
      query: {
        'granularity': granularity,
        'anchor': anchor,
        'date': anchor,
      },
    );
    final payload = res['payload'];
    if (payload is Map<String, dynamic>) {
      return payload;
    } else if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return res;
  }

  /// Xu hướng công suất (feed: trend)
  Future<Map<String, dynamic>> analyticsTrend({int hours = 24}) async {
    final res = await _getData(
      'trend',
      query: {'hours': '$hours'},
    );
    final payload = res['payload'];
    if (payload is Map<String, dynamic>) {
      return payload;
    } else if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return res;
  }

  /// Dự báo sản lượng điện gió (feed: wind-forecast)
  Future<Map<String, dynamic>> windForecast({int days = 7}) async {
    final res = await _getData(
      'wind-forecast',
      query: {'days': '$days'},
    );
    final payload = res['payload'];
    if (payload is Map<String, dynamic>) {
      return payload;
    } else if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return res;
  }

  /// Fetch telemetry feed from platform control-plane
  Future<Map<String, dynamic>> _getData(
    String feed, {
    Map<String, String>? query,
  }) async {
    return _get(
      '/api/v1/factory-modules/$factoryModuleId/data/$feed',
      query: query,
      acceptedStatuses: const {200, 502, 503, 530},
    );
  }

  /// Đăng nhập vào Savina Platform
  Future<Map<String, dynamic>> login(String usernameOrEmail, String password) async {
    try {
      await _ensureCsrfToken();

      // Normalize username/email
      final String email = usernameOrEmail.contains('@')
          ? usernameOrEmail.trim()
          : (usernameOrEmail.trim() == 'admin'
              ? 'savinahub@gmail.com'
              : '${usernameOrEmail.trim()}@svndts.com');

      final uri = Uri.parse('$baseUrl/api/v1/auth/login');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Origin': baseUrl,
      };

      final cookieStr = _cookieHeader();
      if (cookieStr != null) {
        headers['Cookie'] = cookieStr;
      }
      final xsrf = _getXsrfToken();
      if (xsrf != null) {
        headers['X-XSRF-TOKEN'] = xsrf;
      }

      final body = jsonEncode({
        'email': email,
        'password': password,
      });

      final response = await _http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 12));

      _extractCookies(response);

      if (response.statusCode == 200) {
        setSavedCredentials(usernameOrEmail, password);
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final userData = decoded is Map ? decoded['data'] : null;

        // Resolve active factory module ID for Tan An dynamically
        await resolveFactoryModule();
        await fetchPermissionsAndBootstrap();

        return {
          'success': true,
          'token': _cookieHeader() ?? 'authenticated',
          'user': userData,
        };
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMsg = decoded is Map
          ? (decoded['message'] ?? decoded['error'] ?? 'Đăng nhập không thành công')
          : 'Đăng nhập không thành công';

      return {
        'success': false,
        'error': errorMsg.toString(),
      };
    } catch (e) {
      final errStr = e.toString();
      final bool isNetErr = errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup') ||
          errStr.contains('ClientException') ||
          errStr.contains('Connection refused') ||
          errStr.contains('Network is unreachable');
      return {
        'success': false,
        'isNetworkError': isNetErr,
        'error': isNetErr
            ? 'Không thể kết nối máy chủ ($baseUrl). Vui lòng kiểm tra lại kết nối mạng.'
            : 'Không thể kết nối máy chủ: $e',
      };
    }
  }

  /// Đăng xuất khỏi Savina Platform
  Future<void> logout() async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/logout');
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      final cookieStr = _cookieHeader();
      if (cookieStr != null) {
        headers['Cookie'] = cookieStr;
      }
      final xsrf = _getXsrfToken();
      if (xsrf != null) {
        headers['X-XSRF-TOKEN'] = xsrf;
      }
      await _http.post(uri, headers: headers).timeout(const Duration(seconds: 6));
    } catch (_) {}
    clearSession();
  }

  /// Lấy danh sách module và gán FactoryModuleId cho Tân Ân
  Future<void> resolveFactoryModule() async {
    try {
      final res = await _get('/api/v1/modules');
      final list = res['data'];
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            final key = item['key']?.toString();
            final id = item['id']?.toString();
            if (key == 'tanan' && id != null && id.isNotEmpty) {
              factoryModuleId = id;
              if (item['factory'] is Map) {
                final fId = item['factory']['id']?.toString();
                if (fId != null && fId.isNotEmpty) {
                  factoryId = fId;
                }
              }
              final wsUrl = item['workspace_url']?.toString();
              workspacePath = wsUrl != null && wsUrl.isNotEmpty
                  ? '$wsUrl/diagram'
                  : '/workspace/$id/diagram';
              break;
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Phân giải vai trò người dùng và danh sách các trang được phân quyền
  Future<void> fetchPermissionsAndBootstrap() async {
    try {
      // 1. Lấy thông tin phiên & vai trò của tài khoản
      try {
        final sessionRes = await _get('/api/v1/auth/session');
        final userData = sessionRes['data'];
        if (userData is Map) {
          final rawRoles = userData['roles'];
          if (rawRoles is List) {
            userRoles = rawRoles.map((e) => e.toString()).toList();
          }
        }
      } catch (_) {}

      final bool isSuperOrAdmin = userRoles.contains('super_admin') ||
          userRoles.contains('distributor_admin') ||
          userRoles.contains('factory_admin');

      // 2. Tải HTML của workspace để trích xuất danh sách pages thực tế từ server
      final targetPath = '/workspace/$factoryModuleId';
      final uri = Uri.parse('$baseUrl$targetPath');
      final Map<String, String> headers = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
      };
      final cookieStr = _cookieHeader();
      if (cookieStr != null) {
        headers['Cookie'] = cookieStr;
      }

      final response = await _http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      _extractCookies(response);

      if (response.statusCode == 200) {
        final html = utf8.decode(response.bodyBytes);
        final match = RegExp(
          r'<script id="module-bootstrap"[^>]*>(.*?)</script>',
          dotAll: true,
        ).firstMatch(html);
        if (match != null) {
          final jsonStr = match.group(1);
          if (jsonStr != null && jsonStr.isNotEmpty) {
            final data = jsonDecode(jsonStr);
            if (data is Map && data['pages'] is List) {
              final pages = data['pages'] as List;
              final keys = <String>{};
              for (final item in pages) {
                if (item is Map && item['key'] != null) {
                  keys.add(item['key'].toString());
                }
              }
              if (isSuperOrAdmin) {
                allowedPageKeys = null; // Toàn quyền
                canManageMembers = true;
              } else {
                allowedPageKeys = keys;
                canManageMembers = false;
              }
              return;
            }
          }
        }
      }

      // 3. Fallback theo vai trò
      if (isSuperOrAdmin) {
        allowedPageKeys = null;
        canManageMembers = true;
      } else if (userRoles.contains('operator')) {
        canManageMembers = false;
        allowedPageKeys ??= {'overview', 'diagram', 'turbines', 'analytics'};
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
    Set<int> acceptedStatuses = const {200},
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final Map<String, String> headers = {
      'Accept': 'application/json',
    };

    final cookieStr = _cookieHeader();
    if (cookieStr != null) {
      headers['Cookie'] = cookieStr;
      final xsrf = _getXsrfToken();
      if (xsrf != null) {
        headers['X-XSRF-TOKEN'] = xsrf;
      }
    }

    http.Response response;
    try {
      response = await _http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      final isTransientSocketErr = errStr.contains('connection reset') ||
          errStr.contains('connection closed') ||
          errStr.contains('clientexception') ||
          errStr.contains('socketexception');
      if (isTransientSocketErr) {
        await Future.delayed(const Duration(milliseconds: 200));
        response = await _http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 12));
      } else {
        rethrow;
      }
    }

    _extractCookies(response);

    if (response.statusCode == 401) {
      if (!isRetry && onSessionExpired != null) {
        final renewed = await _handleSessionExpired();
        if (renewed) {
          return _get(
            path,
            query: query,
            acceptedStatuses: acceptedStatuses,
            isRetry: true,
          );
        }
      }
      throw const ScadaApiException(401, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      if (decoded is List) {
        return {'data': decoded};
      }
      throw const FormatException('API response must be a JSON object');
    }
    if (!acceptedStatuses.contains(response.statusCode)) {
      throw ScadaApiException(
        response.statusCode,
        decoded['error']?.toString() ?? decoded['message']?.toString() ?? 'API request failed',
      );
    }
    return decoded;
  }

  void close() => _http.close();
}
