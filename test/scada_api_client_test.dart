import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tan_an_portal/features/scada/data/sources/scada_api_client.dart';

void main() {
  test('builds the mobile realtime turbines endpoint', () async {
    late Uri requested;
    final client = ScadaApiClient(
      baseUrl: 'https://example.test/',
      httpClient: MockClient((request) async {
        requested = request.url;
        return http.Response(
          '{"apiVersion":"1.0","status":"ready","turbines":[]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final response = await client.realtimeTurbines();

    expect(requested.toString(), 'https://example.test/api/realtime/turbines');
    expect(response['apiVersion'], '1.0');
    client.close();
  });

  test('keeps the stable 503 realtime payload for empty UI state', () async {
    final client = ScadaApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"status":"unavailable","error":{"code":"REALTIME_UNAVAILABLE"},"turbines":[]}',
          503,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final response = await client.realtimeTurbines();

    expect(response['status'], 'unavailable');
    expect(response['turbines'], isEmpty);
    client.close();
  });

  test('uses the dedicated Vestas IEC 10-minute endpoint', () async {
    late Uri requested;
    final client = ScadaApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        requested = request.url;
        return http.Response(
          '{"received_at":"2026-07-31T00:00:00Z","snapshot":{"turbines":[]}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.vestasIecSnapshot();

    expect(requested.toString(), 'https://example.test/api/vestas/snapshot');
    client.close();
  });

  test('throws on an unexpected API error', () async {
    final client = ScadaApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":"Database unavailable"}',
          500,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    expect(client.health(), throwsA(isA<ScadaApiException>()));
    client.close();
  });
}
