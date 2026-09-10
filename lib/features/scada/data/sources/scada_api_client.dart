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

  ScadaApiClient({String? baseUrl, http.Client? httpClient})
    : baseUrl = (baseUrl ?? configuredBaseUrl).replaceFirst(RegExp(r'/$'), ''),
      _http = httpClient ?? http.Client();

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

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
    Set<int> acceptedStatuses = const {200},
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('API response must be a JSON object');
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
