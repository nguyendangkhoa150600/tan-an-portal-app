import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/scada_models.dart';
import '../../data/models/dispatch_models.dart';
import '../../data/sources/scada_api_client.dart';

class ScadaProvider with ChangeNotifier {
  final ScadaApiClient _api;
  Timer? _pollTimer;
  bool _disposed = false;

  bool _isLoggedIn = false;
  String? _username;

  List<PpcStatus>? _ppcStatuses;
  WindAgcStatus? _windAgc;
  List<VestasLivePark> _vestasParks = [];
  List<DispatchLamp> _dispatchLamps = [];


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
    _api.onSessionExpired = _onSessionExpired;
    _api.onCookiesChanged = (cookieStr) async {
      if (cookieStr != null && cookieStr.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('session_token', cookieStr);
        } catch (_) {}
      }
    };
    unawaited(_init());
  }

  Future<void> _init() async {
    await _loadSavedSession();
    if (_isLoggedIn) {
      await refreshAll();
    }
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (_isLoggedIn) {
          unawaited(refreshRealtime());
        }
      },
    );
  }

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  ScadaApiClient get apiClient => _api;
  bool get canManageMembers => _api.canManageMembers;

  bool isPageAllowed(String pageKey) {
    if (_api.allowedPageKeys == null) return true;
    final key = switch (pageKey) {
      'tongquan' => 'overview',
      'oneline' => 'diagram',
      'wind' => 'turbines',
      'analytics' => 'analytics',
      'forecast' => 'forecast',
      'diagnostics' => 'diagnostics',
      'metering' => 'reports',
      _ => pageKey,
    };
    if (key == 'danhmuc') return true;
    if (key == 'metering') {
      return _api.allowedPageKeys!.contains('metering') ||
          _api.allowedPageKeys!.contains('reports');
    }
    return _api.allowedPageKeys!.contains(key);
  }

  void _ensureActiveViewAllowed() {
    if (!isPageAllowed(_activeView)) {
      const candidates = ['tongquan', 'oneline', 'wind', 'analytics', 'danhmuc'];
      for (final c in candidates) {
        if (isPageAllowed(c)) {
          _activeView = c;
          _safeNotify();
          break;
        }
      }
    }
  }

  Future<bool> _onSessionExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final manualLogout = prefs.getBool('manual_logout') ?? false;
      if (manualLogout) return false;

      final savedUser = prefs.getString('remembered_username') ?? prefs.getString('username');
      final savedPass = prefs.getString('remembered_password');

      if (savedUser != null && savedUser.isNotEmpty && savedPass != null && savedPass.isNotEmpty) {
        if (kDebugMode) {
          print('Token hết hạn (401). Đang tự động gia hạn phiên đăng nhập cho $savedUser...');
        }
        final res = await _api.login(savedUser, savedPass);
        if (res['success'] == true) {
          _isLoggedIn = true;
          final token = _api.sessionToken;
          if (token != null) {
            await prefs.setString('session_token', token);
          }
          await _api.syncCookiesToWebView();
          if (kDebugMode) {
            print('Tự động gia hạn phiên đăng nhập thành công!');
          }
          _safeNotify();
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Lỗi khi tự động gia hạn phiên đăng nhập: $e');
      }
    }
    return false;
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final manualLogout = prefs.getBool('manual_logout') ?? false;
      if (manualLogout) {
        _isLoggedIn = false;
        _safeNotify();
        return;
      }

      final token = prefs.getString('session_token');
      final user = prefs.getString('username');
      final savedUser = prefs.getString('remembered_username');
      final savedPass = prefs.getString('remembered_password');

      if (token != null && token.isNotEmpty) {
        _api.setSessionToken(token);
        _isLoggedIn = true;
        _username = user ?? savedUser;
        if (savedUser != null && savedPass != null) {
          _api.setSavedCredentials(savedUser, savedPass);
        }
        await _api.syncCookiesToWebView();
        _safeNotify();

        // Verify session and touch keep-alive
        try {
          await _api.resolveFactoryModule();
          await _api.fetchPermissionsAndBootstrap();
          _ensureActiveViewAllowed();
        } catch (_) {}
      } else if (savedUser != null && savedUser.isNotEmpty && savedPass != null && savedPass.isNotEmpty) {
        // Auto-login with saved credentials
        final res = await _api.login(savedUser, savedPass);
        if (res['success'] == true) {
          _isLoggedIn = true;
          _username = savedUser;
          final newToken = _api.sessionToken;
          if (newToken != null) {
            await prefs.setString('session_token', newToken);
            await prefs.setString('username', savedUser);
          }
          await _api.syncCookiesToWebView();
          _safeNotify();
        }
      }
    } catch (_) {}
  }

  Future<String?> login(String username, String password) async {
    try {
      final res = await _api.login(username, password);
      if (res['success'] == true) {
        _isLoggedIn = true;
        final userData = res['user'];
        _username = userData is Map
            ? (userData['name']?.toString() ?? userData['email']?.toString() ?? username)
            : username;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('manual_logout', false);
        await prefs.setString('session_token', _api.sessionToken ?? 'authenticated');
        await prefs.setString('username', _username!);
        await prefs.setString('remembered_username', username);
        await prefs.setString('remembered_password', password);
        await prefs.setBool('remember_me_flag', true);
        await _api.syncCookiesToWebView();
        _safeNotify();
        _ensureActiveViewAllowed();
        unawaited(refreshAll());
        return null;
      }
      return res['error']?.toString() ?? 'Đăng nhập thất bại';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _isLoggedIn = false;
    _username = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      await prefs.remove('username');
      await prefs.setBool('manual_logout', true);
    } catch (_) {}
    _safeNotify();
  }

  SnapshotEnvelope get envelope => _envelope;
  List<PpcStatus>? get ppcStatuses => _ppcStatuses;
  WindAgcStatus? get windAgc => _windAgc;
  List<VestasLivePark> get vestasParks => _vestasParks;
  List<DispatchLamp> get dispatchLamps => _dispatchLamps;
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
    if (!_isLoggedIn) return;
    await refreshRealtime();
    await Future.wait([refreshAnalytics(), refreshTrend(), refreshForecast()]);
  }

  Future<void> refreshRealtime() async {
    if (!_isLoggedIn) return;
    final iecRequest = _api.vestasIecSnapshot();
    final vestasLiveRequest = _api.vestasLive();
    final windSnapshotRequest = _api.windSnapshot();
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
    try {
      _applyVestasLive(await vestasLiveRequest);
    } catch (error) {
      if (kDebugMode) {
        final errStr = error.toString().toLowerCase();
        if (!errStr.contains('connection reset') && !errStr.contains('401')) {
          print('Error loading vestas live data: $error');
        }
      }
    }
    try {
      _applyWindSnapshot(await windSnapshotRequest);
    } catch (error) {
      if (kDebugMode) {
        final errStr = error.toString().toLowerCase();
        if (!errStr.contains('connection reset') && !errStr.contains('401')) {
          print('Error loading wind snapshot data: $error');
        }
      }
    }
    _safeNotify();
  }

  Future<void> refreshVestasIec() async {
    if (!_isLoggedIn) return;
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
    if (!_isLoggedIn) return;
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
    if (!_isLoggedIn) return;
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
    if (!_isLoggedIn) return;
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
    final snapshot = _envelope.snapshot;
    _ppcStatuses = hasPpcStatuses(snapshot) ? derivePpcStatuses(snapshot) : null;
    _updateDispatchLamps();
  }

  void _applyWindSnapshot(Map<String, dynamic> response) {
    final raw = response['snapshot'];
    if (raw is Map) {
      final snapshot = ScadaSnapshot.fromJson(Map<String, dynamic>.from(raw));
      _windAgc = deriveWindAgc(snapshot);
      _updateDispatchLamps();
    }
  }

  void _applyVestasLive(Map<String, dynamic> response) {
    final snapshot = response['snapshot'];
    if (snapshot is Map) {
      final parksJson = snapshot['parks'];
      if (parksJson is List) {
        _vestasParks = parksJson
            .whereType<Map>()
            .map((p) => VestasLivePark.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        _updateDispatchLamps();
      }
    }
  }

  void _updateDispatchLamps() {
    final vestasSetpoints = vestasSetpointsOf(_vestasParks);
    _dispatchLamps = buildDispatchLamps(_windAgc, vestasSetpoints);
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
      'label': raw['model']?.toString() ?? 'V150-4000 MK3E',
      'serial': raw['serial']?.toString() ?? raw['turbine']?.toString() ?? 'V150-4000 MK3E',
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

    final rawName = raw['name']?.toString() ?? '';
    final sourceLabel = raw['sourceLabel']?.toString() ?? '';
    final model = raw['model']?.toString() ??
        (parkCode == 'windmmcs' ? 'WD156-4200' : 'V150-4000 MK3E');

    final bool isWindey = parkCode == 'windmmcs' ||
        sourceLabel.startsWith('WT') ||
        rawName.startsWith('T3-');

    String turbineName;
    String turbineSubtitle;

    if (isWindey) {
      if (sourceLabel.startsWith('WT')) {
        turbineName = sourceLabel;
      } else {
        final t3Match = RegExp(r'^T3-(\d+)').firstMatch(rawName);
        if (t3Match != null) {
          turbineName =
              'WT${int.parse(t3Match.group(1)!).toString().padLeft(2, '0')}';
        } else {
          turbineName = sourceLabel.isNotEmpty
              ? sourceLabel
              : (rawName.isNotEmpty ? rawName : 'WT');
        }
      }
      turbineSubtitle = model;
    } else {
      turbineName = rawName.isNotEmpty ? rawName : sourceLabel;
      turbineSubtitle = model;
    }

    return {
      ...raw,
      'id': raw['id'] ?? turbineName,
      'name': turbineName,
      'label': turbineSubtitle,
      'model': model,
      'operatorName': rawName,
      'sourceLabel': sourceLabel.isNotEmpty ? sourceLabel : turbineName,
      'serial': raw['serial']?.toString() ??
          (parkCode == 'vestas' && sourceLabel.isNotEmpty
              ? sourceLabel
              : turbineSubtitle),
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
