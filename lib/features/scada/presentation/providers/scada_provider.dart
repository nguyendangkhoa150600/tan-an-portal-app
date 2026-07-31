import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../data/models/scada_models.dart';
import '../../data/sources/scada_api_client.dart';

class ScadaProvider with ChangeNotifier {
  final ScadaApiClient _api;
  Timer? _pollTimer;
  bool _disposed = false;

  SnapshotEnvelope _envelope = SnapshotEnvelope(
    origin: 'empty',
    snapshot: ScadaSnapshot(
      source: '',
      station: 'TANAN',
      screen: 'ONELINE_1',
      snapshotUtc: '',
      tags: const {},
    ),
  );
  String _activeView = 'tongquan';
  String _activeSceneId = 'oneline-1';
  String _vestasMode = 'live';
  String _pollState = 'connecting';
  bool _streamHealthy = false;
  DateTime _observedAt = DateTime.now();
  bool _focusMode = false;
  bool _operationsOpen = false;
  String _windPark = 'dg1';
  String _analyticsGranularity = 'day';
  DateTime _analyticsAnchor = DateTime.now();
  bool _windConnected = false;
  int? _windAgeSeconds;
  bool _vestasConnected = false;
  int? _vestasAgeSeconds;
  String? _lastError;
  bool _isWindCompactMode = true;

  List<Map<String, dynamic>> _dg1Turbines = [];
  List<Map<String, dynamic>> _dg2Turbines = [];
  List<Map<String, dynamic>> _dg2IecTurbines = [];
  bool _vestasIecConnected = false;
  List<Map<String, dynamic>> _trendPoints = [];
  List<Map<String, dynamic>> _todayHourlyBuckets = [];
  List<Map<String, dynamic>> _yesterdayHourlyBuckets = [];
  List<Map<String, dynamic>> _todayMonthlyBuckets = [];
  List<Map<String, dynamic>> _yesterdayMonthlyBuckets = [];
  List<Map<String, dynamic>> _forecastHours = [];
  Map<String, dynamic>? _analyticsOverview;
  Map<String, dynamic> _analyticsRange = {};
  Map<String, String> _health = {
    'database': 'unknown',
    'persistence': 'unknown',
  };

  ScadaProvider({ScadaApiClient? api}) : _api = api ?? ScadaApiClient() {
    unawaited(refreshAll());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(refreshRealtime()),
    );
  }

  SnapshotEnvelope get envelope => _envelope;
  String get activeView => _activeView;
  String get activeSceneId => _activeSceneId;
  String get vestasMode => _vestasMode;
  String get pollState => _pollState;
  bool get streamHealthy => _streamHealthy;
  DateTime get observedAt => _observedAt;
  bool get focusMode => _focusMode;
  bool get operationsOpen => _operationsOpen;
  String get windPark => _windPark;
  String get analyticsGranularity => _analyticsGranularity;
  DateTime get analyticsAnchor => _analyticsAnchor;
  bool get windConnected => _windConnected;
  int? get windAgeSeconds => _windAgeSeconds;
  bool get vestasConnected => _vestasConnected;
  int? get vestasAgeSeconds => _vestasAgeSeconds;
  String? get lastError => _lastError;
  bool get isWindCompactMode => _isWindCompactMode;
  List<Map<String, dynamic>> get dg1Turbines => _dg1Turbines;
  List<Map<String, dynamic>> get dg2Turbines => _dg2Turbines;
  List<Map<String, dynamic>> get dg2IecTurbines => _dg2IecTurbines;
  bool get vestasIecConnected => _vestasIecConnected;
  List<Map<String, dynamic>> get trendPoints => _trendPoints;
  List<Map<String, dynamic>> get todayHourlyBuckets => _todayHourlyBuckets;
  List<Map<String, dynamic>> get yesterdayHourlyBuckets =>
      _yesterdayHourlyBuckets;
  List<Map<String, dynamic>> get todayMonthlyBuckets => _todayMonthlyBuckets;
  List<Map<String, dynamic>> get yesterdayMonthlyBuckets =>
      _yesterdayMonthlyBuckets;
  List<Map<String, dynamic>> get forecastHours => _forecastHours;
  Map<String, dynamic>? get analyticsOverview => _analyticsOverview;
  Map<String, dynamic> get analyticsRange => _analyticsRange;
  Map<String, String> get health => _health;

  set activeView(String value) => _set(value != _activeView, () {
    _activeView = value;
    if (value == 'analytics') unawaited(refreshAnalytics());
    if (value == 'forecast') unawaited(refreshForecast());
  });
  set activeSceneId(String value) =>
      _set(value != _activeSceneId, () => _activeSceneId = value);
  set vestasMode(String value) {
    if (value == _vestasMode) return;
    _vestasMode = value;
    _safeNotify();
    if (value == 'iec') unawaited(refreshVestasIec());
  }

  set pollState(String value) =>
      _set(value != _pollState, () => _pollState = value);
  set streamHealthy(bool value) =>
      _set(value != _streamHealthy, () => _streamHealthy = value);
  set focusMode(bool value) =>
      _set(value != _focusMode, () => _focusMode = value);
  set operationsOpen(bool value) =>
      _set(value != _operationsOpen, () => _operationsOpen = value);
  set windPark(String value) =>
      _set(value != _windPark, () => _windPark = value);
  set windConnected(bool value) =>
      _set(value != _windConnected, () => _windConnected = value);
  set windAgeSeconds(int? value) =>
      _set(value != _windAgeSeconds, () => _windAgeSeconds = value);
  set vestasConnected(bool value) =>
      _set(value != _vestasConnected, () => _vestasConnected = value);
  set vestasAgeSeconds(int? value) =>
      _set(value != _vestasAgeSeconds, () => _vestasAgeSeconds = value);
  set isWindCompactMode(bool value) =>
      _set(value != _isWindCompactMode, () => _isWindCompactMode = value);

  set analyticsGranularity(String value) {
    if (_analyticsGranularity == value) return;
    _analyticsGranularity = value;
    _safeNotify();
    unawaited(refreshAnalytics());
  }

  set analyticsAnchor(DateTime value) {
    _analyticsAnchor = value;
    _safeNotify();
    unawaited(refreshAnalytics());
  }

  void _set(bool changed, VoidCallback update) {
    if (!changed) return;
    update();
    _safeNotify();
  }

  Future<void> refreshAll() async {
    await refreshRealtime();
    await Future.wait([refreshAnalytics(), refreshTrend(), refreshForecast()]);
  }

  Future<void> refreshRealtime() async {
    final iecRequest = _api.vestasIecSnapshot();
    try {
      final responses = await Future.wait([
        _api.health(),
        _api.realtimeDiagram(),
        _api.realtimeTurbines(),
      ]);
      _applyHealth(responses[0]);
      _applyDiagram(responses[1]);
      _applyTurbines(responses[2]);
      _pollState = 'live';
      _streamHealthy = true;
      _lastError = null;
      _observedAt = DateTime.now();
    } catch (error) {
      _pollState = 'error';
      _streamHealthy = false;
      _lastError = error.toString();
    }
    try {
      _applyVestasIec(await iecRequest);
    } catch (error) {
      _vestasIecConnected = false;
      _dg2IecTurbines = [];
      _lastError = error.toString();
    }
    _safeNotify();
  }

  Future<void> refreshVestasIec() async {
    try {
      _applyVestasIec(await _api.vestasIecSnapshot());
    } catch (error) {
      _vestasIecConnected = false;
      _dg2IecTurbines = [];
      _lastError = error.toString();
    }
    _safeNotify();
  }

  Future<void> refreshAnalytics() async {
    final anchor = _analyticsGranularity == 'day'
        ? DateFormat('yyyy-MM-dd').format(_analyticsAnchor)
        : DateFormat('yyyy-MM').format(_analyticsAnchor);
    final previousDate = _analyticsGranularity == 'day'
        ? _analyticsAnchor.subtract(const Duration(days: 1))
        : DateTime(_analyticsAnchor.year, _analyticsAnchor.month - 1);
    final previousAnchor = _analyticsGranularity == 'day'
        ? DateFormat('yyyy-MM-dd').format(previousDate)
        : DateFormat('yyyy-MM').format(previousDate);
    try {
      final responses = await Future.wait([
        _api.analyticsOverview(
          granularity: _analyticsGranularity,
          anchor: anchor,
        ),
        _api.analyticsOverview(
          granularity: _analyticsGranularity,
          anchor: previousAnchor,
        ),
      ]);
      final response = responses[0];
      final previousResponse = responses[1];
      _analyticsRange = response['range'] is Map
          ? Map<String, dynamic>.from(response['range'] as Map)
          : {};
      _analyticsOverview = response['overview'] is Map
          ? Map<String, dynamic>.from(response['overview'] as Map)
          : null;
      final total = _analyticsOverview?['total'];
      final buckets = total is Map ? total['buckets'] : null;
      final parsed = _mapList(buckets);
      final previousOverview = previousResponse['overview'];
      final previousTotal = previousOverview is Map
          ? previousOverview['total']
          : null;
      final previous = _mapList(
        previousTotal is Map ? previousTotal['buckets'] : null,
      );
      if (_analyticsGranularity == 'day') {
        _todayHourlyBuckets = parsed;
        _yesterdayHourlyBuckets = previous;
      } else {
        _todayMonthlyBuckets = parsed;
        _yesterdayMonthlyBuckets = previous;
      }
      _lastError = null;
    } catch (error) {
      _analyticsOverview = null;
      _analyticsRange = {};
      if (_analyticsGranularity == 'day') {
        _todayHourlyBuckets = [];
        _yesterdayHourlyBuckets = [];
      } else {
        _todayMonthlyBuckets = [];
        _yesterdayMonthlyBuckets = [];
      }
      _lastError = error.toString();
    }
    _safeNotify();
  }

  Future<void> refreshTrend() async {
    try {
      final response = await _api.analyticsTrend();
      _trendPoints = _mapList(response['points']);
    } catch (error) {
      _trendPoints = [];
      _lastError = error.toString();
    }
    _safeNotify();
  }

  Future<void> refreshForecast() async {
    try {
      final response = await _api.windForecast();
      final site = response['site'];
      final siteHours = site is Map ? site['hours'] : null;
      if (siteHours is List && siteHours.isNotEmpty) {
        _forecastHours = _mapList(siteHours);
      } else {
        final forecast = response['forecast'];
        _forecastHours = forecast is Map ? _mapList(forecast['horizon']) : [];
      }
    } catch (error) {
      _forecastHours = [];
      _lastError = error.toString();
    }
    _safeNotify();
  }

  void _applyHealth(Map<String, dynamic> response) {
    _health = {
      'database': response['database']?.toString() ?? 'unknown',
      'persistence': response['persistence']?.toString() ?? 'unknown',
    };
  }

  void _applyDiagram(Map<String, dynamic> response) {
    final raw = response['snapshot'];
    if (response['status'] != 'ready' || raw is! Map) {
      _envelope = SnapshotEnvelope(
        origin: 'empty',
        snapshot: ScadaSnapshot(
          source: '',
          station: 'TANAN',
          screen: 'ONELINE_1',
          snapshotUtc: '',
          tags: const {},
        ),
      );
      return;
    }
    _envelope = SnapshotEnvelope(
      origin: 'bridge',
      receivedAt: response['receivedAt']?.toString(),
      snapshot: ScadaSnapshot.fromJson(Map<String, dynamic>.from(raw)),
    );
  }

  void _applyTurbines(Map<String, dynamic> response) {
    final sources = response['sources'];
    if (sources is Map) {
      _windConnected = _sourceReady(sources['wind']);
      _vestasConnected = _sourceReady(sources['vestas']);
      _windAgeSeconds = _sourceAge(sources['wind']);
      _vestasAgeSeconds = _sourceAge(sources['vestas']);
    }
    final turbines = _mapList(response['turbines']).map(_toUiTurbine).toList();
    _dg1Turbines = turbines
        .where((item) => item['parkCode'] == 'windmmcs')
        .toList();
    _dg2Turbines = turbines
        .where((item) => item['parkCode'] == 'vestas')
        .toList();
  }

  void _applyVestasIec(Map<String, dynamic> response) {
    final snapshot = response['snapshot'];
    if (snapshot is! Map) {
      _vestasIecConnected = false;
      _dg2IecTurbines = [];
      return;
    }

    final collectedAt = DateTime.tryParse(
      snapshot['collected_utc']?.toString() ?? '',
    );
    final turbines = _mapList(snapshot['turbines']);
    _dg2IecTurbines = turbines
        .map((raw) => _toUiIecTurbine(raw, collectedAt))
        .toList();
    _vestasIecConnected = _dg2IecTurbines.isNotEmpty;
  }

  Map<String, dynamic> _toUiIecTurbine(
    Map<String, dynamic> raw,
    DateTime? collectedAt,
  ) {
    final power = _nullableNumber(raw['power_kw']);
    final alarm = _nullableNumber(raw['alarm_no']);
    final signalAt = DateTime.tryParse(raw['ts_utc']?.toString() ?? '');
    final ageSeconds = signalAt == null || collectedAt == null
        ? null
        : collectedAt
              .toUtc()
              .difference(signalAt.toUtc())
              .inSeconds
              .clamp(0, 1 << 31);
    final delayed = ageSeconds != null && ageSeconds > 1500;

    String status;
    String stateLabel;
    if (delayed) {
      status = 'offline';
      stateLabel = 'Tín hiệu chậm ${(ageSeconds / 60).round()}p';
    } else if (power == null) {
      status = 'offline';
      stateLabel = 'Mất kết nối';
    } else if (alarm != null && alarm != 0) {
      status = 'alarm';
      stateLabel = 'Cảnh báo #${alarm.toInt()}';
    } else if (power > 10) {
      status = 'running';
      stateLabel = 'Phát điện';
    } else if (power > 0) {
      status = 'running';
      stateLabel = 'Công suất thấp';
    } else {
      status = 'standby';
      stateLabel = 'Chờ / dừng';
    }

    return {
      ...raw,
      'id': raw['serial'] ?? raw['turbine'] ?? '',
      'name': raw['turbine']?.toString() ?? 'Mất kết nối',
      'label': raw['turbine']?.toString() ?? 'Mất kết nối',
      'serial': raw['serial']?.toString() ?? 'Mất kết nối',
      'power': power ?? double.nan,
      'wind': _nullableNumber(raw['wind_ms']) ?? double.nan,
      'windDir': _nullableNumber(raw['wind_dir']),
      'nacPos': _nullableNumber(raw['nacelle_dir']),
      'nacDir': _nullableNumber(raw['nacelle_dir']),
      'yawErr': null,
      'tmpAmb': _nullableNumber(raw['amb_temp']),
      'ambTemp': _nullableNumber(raw['amb_temp']),
      'reactive': _nullableNumber(raw['reactive_kvar']),
      'genRpm': _nullableNumber(raw['gen_rpm']),
      'rotorRpm': _nullableNumber(raw['rotor_rpm']),
      'pitch': _nullableNumber(raw['pitch_deg']),
      'alarm': alarm,
      'possibleKw': _nullableNumber(raw['possible_kw']),
      'status': status,
      'stateLabel': stateLabel,
      'signalAt': raw['ts_utc']?.toString(),
      'signalAgeSeconds': ageSeconds,
      'signalDelayed': delayed,
      'parkCode': 'vestas',
      'sourceType': 'iec10',
    };
  }

  Map<String, dynamic> _toUiTurbine(Map<String, dynamic> raw) {
    final parkCode = raw['parkCode']?.toString() ?? '';
    final tone = raw['tone']?.toString() ?? 'offline';
    return {
      ...raw,
      'id': raw['id'] ?? raw['name'] ?? '',
      'label': raw['sourceLabel'] ?? raw['name'] ?? '',
      'serial': parkCode == 'vestas' ? raw['sourceLabel'] : null,
      'power': _telemetryNumber(raw['powerKw']),
      'wind': _telemetryNumber(raw['windMs']),
      'windDir': _nullableNumber(raw['windDirectionDeg']),
      'nacPos': _nullableNumber(raw['nacelleDirectionDeg']),
      'nacDir': _nullableNumber(raw['nacelleDirectionDeg']),
      'yawErr': _nullableNumber(raw['yawErrorDeg']),
      'tmpAmb': _nullableNumber(raw['ambientC']),
      'ambTemp': _nullableNumber(raw['ambientC']),
      'reactive': _nullableNumber(raw['reactiveKvar']),
      'genRpm': _nullableNumber(raw['generatorRpm']),
      'rotorRpm': _nullableNumber(raw['rotorRpm']),
      'pitch': _nullableNumber(raw['pitchDeg']),
      'alarm': raw['alarmCode'],
      'status': raw['alarmed'] == true ? 'alarm' : tone,
      'stateLabel': raw['stateLabel']?.toString() ?? 'Không có dữ liệu',
      'signalAt': raw['signalAt']?.toString(),
      'signalAgeSeconds': raw['signalAgeSeconds'],
      'signalDelayed': raw['signalDelayed'] == true,
      'parkCode': parkCode,
    };
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : [];

  static bool _sourceReady(dynamic source) =>
      source is Map && source['status'] == 'ready';

  static int? _sourceAge(dynamic source) {
    if (source is! Map) return null;
    final receivedAt = DateTime.tryParse(
      source['receivedAt']?.toString() ?? '',
    );
    return receivedAt == null
        ? null
        : DateTime.now()
              .toUtc()
              .difference(receivedAt)
              .inSeconds
              .clamp(0, 1 << 31);
  }

  static double? _nullableNumber(dynamic value) => (value as num?)?.toDouble();
  static double _telemetryNumber(dynamic value) =>
      (value as num?)?.toDouble() ?? double.nan;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _api.close();
    super.dispose();
  }
}
