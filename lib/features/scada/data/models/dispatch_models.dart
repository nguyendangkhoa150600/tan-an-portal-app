import 'scada_models.dart';

class PpcStatus {
  final String id;
  final String label;
  final bool? on;

  const PpcStatus({
    required this.id,
    required this.label,
    this.on,
  });
}

class WindAgcStatus {
  final int? mode;
  final String modeLabel;
  final bool? agcActive;
  final bool? commOk;
  final double? agcCmdMw;
  final double? setWMw;

  const WindAgcStatus({
    this.mode,
    required this.modeLabel,
    this.agcActive,
    this.commOk,
    this.agcCmdMw,
    this.setWMw,
  });
}

enum DispatchLampState { on, off, unknown }

class DispatchLamp {
  final String key;
  final String label;
  final String? value;
  final double? mw;
  final DispatchLampState state;
  final String aria;

  const DispatchLamp({
    required this.key,
    required this.label,
    this.value,
    this.mw,
    required this.state,
    required this.aria,
  });
}

class VestasSetpoint {
  final String label;
  final double? mw;
  final bool? enabled;

  const VestasSetpoint({
    required this.label,
    this.mw,
    this.enabled,
  });
}

class VestasLivePpc {
  final double? activeMw;
  final double? activeSetpointKw;
  final bool? activeControlEnabled;
  final double? reactiveMvar;

  const VestasLivePpc({
    this.activeMw,
    this.activeSetpointKw,
    this.activeControlEnabled,
    this.reactiveMvar,
  });

  factory VestasLivePpc.fromJson(Map<String, dynamic> json) {
    final wf = json['wf'] is Map ? Map<String, dynamic>.from(json['wf'] as Map) : const <String, dynamic>{};
    final activeSetpoint = wf['ActivePowerSetpoint'];
    final activeControl = wf['ActivePowerControlEnable'];
    
    bool? controlEnabled;
    if (activeControl is bool) {
      controlEnabled = activeControl;
    } else if (activeControl is num) {
      controlEnabled = activeControl != 0;
    }

    return VestasLivePpc(
      activeMw: (wf['ActivePowerTotal'] as num?)?.toDouble(),
      activeSetpointKw: (activeSetpoint as num?)?.toDouble(),
      activeControlEnabled: controlEnabled,
      reactiveMvar: (wf['ReactivePowerTotal'] as num?)?.toDouble(),
    );
  }
}

class VestasLivePark {
  final String park;
  final VestasLivePpc? ppc;

  const VestasLivePark({
    required this.park,
    this.ppc,
  });

  factory VestasLivePark.fromJson(Map<String, dynamic> json) {
    final ppcJson = json['ppc'] is Map ? Map<String, dynamic>.from(json['ppc'] as Map) : null;
    return VestasLivePark(
      park: json['park']?.toString() ?? '',
      ppc: ppcJson != null ? VestasLivePpc.fromJson(ppcJson) : null,
    );
  }
}

const Map<int, String> apcModeLabels = {
  0: "Free",
  1: "Manual",
  2: "AGC",
  3: "Control Center",
  4: "EMS PFC",
  5: "ExPFC",
};

bool? readBoolean(ScadaSnapshot snapshot, String tag) {
  final scadaTag = snapshot.tags[tag];
  if (scadaTag == null) return null;
  final val = scadaTag.value;
  if (val is bool) return val;
  if (val == 1 || val == "1" || val == "true" || val == true) return true;
  if (val == 0 || val == "0" || val == "false" || val == false) return false;
  return null;
}

double? readNumber(ScadaSnapshot snapshot, String tag) {
  final scadaTag = snapshot.tags[tag];
  if (scadaTag == null) return null;
  final val = scadaTag.value;
  if (val is num) return val.toDouble();
  if (val is String && val.trim().isNotEmpty) {
    return double.tryParse(val);
  }
  return null;
}

double? readMw(ScadaSnapshot snapshot, String tag) {
  final scadaTag = snapshot.tags[tag];
  if (scadaTag == null || !scadaTag.isGoodQuality) return null;
  final watts = readNumber(snapshot, tag);
  return watts == null ? null : watts / 1000000.0;
}

WindAgcStatus? deriveWindAgc(ScadaSnapshot snapshot) {
  final modeTag = snapshot.tags["EMSWF.APCCalc.APCMode"];
  if (modeTag == null) return null;

  final int? mode = modeTag.isGoodQuality 
      ? readNumber(snapshot, "EMSWF.APCCalc.APCMode")?.toInt() 
      : null;
  final commTag = snapshot.tags["EMSWF.APC.AGCComm"];
  final int? commVal = commTag != null && commTag.isGoodQuality 
      ? readNumber(snapshot, "EMSWF.APC.AGCComm")?.toInt() 
      : null;
  final bool? comm = commVal == null ? null : commVal == 1;

  final String modeLabel = mode == null 
      ? "--" 
      : (apcModeLabels[mode] ?? "mode $mode");

  return WindAgcStatus(
    mode: mode,
    modeLabel: modeLabel,
    agcActive: mode == null ? null : mode == 2,
    commOk: comm,
    agcCmdMw: readMw(snapshot, "EMSWF.APC.AGC"),
    setWMw: readMw(snapshot, "EMSWF.APCCalc.SetW"),
  );
}

const ppcSetpointEnables = [
  {'id': 'ppc1', 'label': 'PPC1', 'tag': 'TAN_PPC1::P::RemEnaSt'},
  {'id': 'ppc2', 'label': 'PPC2', 'tag': 'TAN_PPC2::P::RemEnaSt'},
  {'id': 'ppc3', 'label': 'PPC3', 'tag': 'TAN_PPC3::P::RemEnaSt'},
];

bool hasPpcStatuses(ScadaSnapshot snapshot) {
  return ppcSetpointEnables.any((item) => snapshot.tags[item['tag']!] != null);
}

List<PpcStatus> derivePpcStatuses(ScadaSnapshot snapshot) {
  return ppcSetpointEnables.map((item) {
    final tag = item['tag']!;
    final scadaTag = snapshot.tags[tag];
    final bool? onVal = (scadaTag != null && scadaTag.isGoodQuality)
        ? readBoolean(snapshot, tag)
        : null;
    return PpcStatus(
      id: item['id']!,
      label: item['label']!,
      on: onVal,
    );
  }).toList();
}

DispatchLampState lampState(bool? on) {
  return on == true
      ? DispatchLampState.on
      : on == false
          ? DispatchLampState.off
          : DispatchLampState.unknown;
}

String lampMw(double? mw) {
  return mw == null ? "--" : "${mw.toStringAsFixed(1)} MW";
}

List<DispatchLamp> buildDispatchLamps(
  WindAgcStatus? windAgc,
  List<VestasSetpoint> vestasSetpoints,
) {
  final List<DispatchLamp> lamps = [];

  if (windAgc != null) {
    final offMode = windAgc.agcActive == false ? windAgc.modeLabel : null;
    final commDown = windAgc.agcActive == true && windAgc.commOk == false;
    final label = commDown 
        ? "Windy LỖI" 
        : (offMode != null ? "Windy $offMode" : "Windy");
    
    final mwValue = offMode != null ? windAgc.setWMw : windAgc.agcCmdMw;
    
    lamps.add(DispatchLamp(
      key: "windy",
      label: label,
      value: lampMw(mwValue),
      mw: mwValue,
      state: windAgc.agcActive == true
          ? (commDown ? DispatchLampState.off : DispatchLampState.on)
          : lampState(windAgc.agcActive),
      aria: windAgc.agcActive == true
          ? "Windy, Điện gió 1: AGC ${lampMw(windAgc.agcCmdMw)}, đang bám lệnh, liên lạc ${commDown ? 'lỗi' : 'bình thường'}"
          : windAgc.agcActive == false
              ? "Windy, Điện gió 1: setpoint ${lampMw(windAgc.setWMw)}, đang ở chế độ ${windAgc.modeLabel}"
              : "Windy, Điện gió 1: mất dữ liệu chế độ",
    ));
  }

  for (final sp in vestasSetpoints) {
    lamps.add(DispatchLamp(
      key: sp.label,
      label: sp.label,
      value: lampMw(sp.mw),
      mw: sp.mw,
      state: lampState(sp.enabled),
      aria: "${sp.label}, park của Điện gió 2: setpoint ${lampMw(sp.mw)}, MW control ${sp.enabled == true ? 'bật' : sp.enabled == false ? 'tắt' : 'không rõ'}",
    ));
  }

  return lamps;
}

List<VestasSetpoint> vestasSetpointsOf(List<VestasLivePark> parks) {
  final List<VestasSetpoint> setpoints = [];
  for (int i = 0; i < parks.length; i++) {
    final park = parks[i];
    if (park.ppc == null) continue;
    final match = RegExp(r'(\d+)\s*$').firstMatch(park.park);
    final ordinal = match != null ? match.group(1) : '${i + 1}';
    final activeSetpointKw = park.ppc?.activeSetpointKw;
    setpoints.add(VestasSetpoint(
      label: 'Vestas$ordinal',
      mw: activeSetpointKw == null ? null : activeSetpointKw / 1000.0,
      enabled: park.ppc?.activeControlEnabled,
    ));
  }
  return setpoints;
}

DispatchLamp? lampForProject(
  List<DispatchLamp> lamps,
  String projectName,
) {
  if (RegExp(r'wind[ei]?y', caseSensitive: false).hasMatch(projectName)) {
    final idx = lamps.indexWhere((lamp) => lamp.key == "windy");
    return idx != -1 ? lamps[idx] : null;
  }
  final match = RegExp(r'(\d+)\s*$').firstMatch(projectName.trim());
  if (match != null) {
    final ordinal = match.group(1);
    final idx = lamps.indexWhere((lamp) => lamp.key == "Vestas$ordinal");
    return idx != -1 ? lamps[idx] : null;
  }
  return null;
}
