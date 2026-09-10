import 'dart:convert';
import 'package:http/http.dart' as http;

class ScadaApiException implements Exception {
  final int statusCode;
  final String message;

  const ScadaApiException(this.statusCode, this.message);

  @override
  String toString() => 'ScadaApiException($statusCode): $message';
}

class ScadaApiClient {
  static const String configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tanan.svnagentic.site',
  );

  final String baseUrl;
  final http.Client _http;
  String? _sessionToken;

  ScadaApiClient({String? baseUrl, http.Client? httpClient})
    : baseUrl = (baseUrl ?? configuredBaseUrl).replaceFirst(RegExp(r'/$'), ''),
      _http = httpClient ?? http.Client();

  String? get sessionToken => _sessionToken;
  http.Client get httpClient => _http;
  void setSessionToken(String? token) => _sessionToken = token;
  void clearSession() => _sessionToken = null;

  Future<Map<String, dynamic>> health() => _get('/api/health');

  Future<Map<String, dynamic>> realtimeDiagram() =>
      _get('/api/realtime/diagram');

  Future<Map<String, dynamic>> realtimeTurbines() =>
      _get('/api/realtime/turbines', acceptedStatuses: const {200, 503, 530});

  Future<Map<String, dynamic>> windSnapshot() =>
      _get('/api/wind/snapshot', acceptedStatuses: const {200, 503, 530});

  Future<Map<String, dynamic>> vestasIecSnapshot() =>
      _get('/api/vestas/snapshot', acceptedStatuses: const {200, 503, 530});

  Future<Map<String, dynamic>> vestasLive() =>
      _get('/api/vestas/live', acceptedStatuses: const {200, 503, 530});

  Future<Map<String, dynamic>> analyticsOverview({
    required String granularity,
    required String anchor,
  }) => _get(
    '/api/analytics/overview',
    query: {'granularity': granularity, 'anchor': anchor},
  );

  Future<Map<String, dynamic>> analyticsTrend({int hours = 24}) =>
      _get('/api/analytics/trend', query: {'hours': '$hours'});

  Future<Map<String, dynamic>> windForecast({int days = 7}) =>
      _get('/api/wind/forecast', query: {'days': '$days'});

  Future<Map<String, dynamic>> login(String username, String password) async {
    final userResult = await _tryLoginEndpoint(
      path: '/api/auth/session',
      cookieName: 'tanan_user',
      username: username,
      password: password,
    );
    if (userResult['success'] == true) {
      return userResult;
    }

    final adminResult = await _tryLoginEndpoint(
      path: '/api/admin/session',
      cookieName: 'fe_tanan_admin',
      username: username,
      password: password,
    );
    if (adminResult['success'] == true) {
      return adminResult;
    }

    return userResult;
  }

  Future<Map<String, dynamic>> _tryLoginEndpoint({
    required String path,
    required String cookieName,
    required String username,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..headers.addAll({
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': baseUrl,
        })
        ..bodyFields = {
          'username': username,
          'password': password,
          'next': '/',
        };

      final streamedResponse = await _http.send(request).timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);

      String setCookieHeader = response.headers['set-cookie'] ?? '';
      if (setCookieHeader.isEmpty) {
        response.headers.forEach((key, value) {
          if (key.toLowerCase() == 'set-cookie') {
            setCookieHeader = value;
          }
        });
      }
      final locationHeader = response.headers['location'] ?? '';

      final match = RegExp('$cookieName=([^;,\\s]+)').firstMatch(setCookieHeader) ??
          RegExp(r'(fe_tanan_admin|tanan_user|tanan_admin)=([^;,\s]+)').firstMatch(setCookieHeader);

      if (match != null) {
        final token = match.groupCount >= 2 ? match.group(2)! : match.group(1)!;
        _sessionToken = token;
        return {'success': true, 'token': token};
      }

      if (response.statusCode == 303 || response.statusCode == 302 || response.statusCode == 200) {
        if (!locationHeader.contains('error')) {
          final fallbackToken = (_sessionToken != null && _sessionToken!.isNotEmpty && _sessionToken != 'authenticated')
              ? _sessionToken!
              : 'authenticated';
          _sessionToken = fallbackToken;
          return {'success': true, 'token': fallbackToken};
        }
      }

      if (locationHeader.contains('error=invalid')) {
        return {'success': false, 'error': 'Tài khoản hoặc mật khẩu không đúng'};
      } else if (locationHeader.contains('error=rate')) {
        return {'success': false, 'error': 'Đã thử quá nhiều lần. Vui lòng thử lại sau'};
      } else if (locationHeader.contains('error=config')) {
        return {'success': false, 'error': 'Hệ thống chưa cấu hình đăng nhập'};
      }

      return {'success': false, 'error': 'Đăng nhập không thành công'};
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

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
    Set<int> acceptedStatuses = const {200},
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final String token = (_sessionToken != null && _sessionToken!.isNotEmpty) ? _sessionToken! : '1';
    final Map<String, String> headers = {
      'Accept': 'application/json',
      'Cookie': 'fe_tanan_admin=$token; tanan_user=$token; tanan_admin=$token',
    };

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

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('API response must be a JSON object');
    }
    if (response.statusCode == 401) {
      throw const ScadaApiException(401, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }
    if (!acceptedStatuses.contains(response.statusCode)) {
      throw ScadaApiException(
        response.statusCode,
        decoded['error']?.toString() ?? 'API request failed',
      );
    }
    return decoded;
  }

  void close() => _http.close();
}
