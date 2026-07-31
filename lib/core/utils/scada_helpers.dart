import '../../features/scada/data/models/scada_models.dart';

class ScadaHelpers {
  static bool isGoodQuality(ScadaTag? tag) {
    if (tag == null) return false;
    return tag.quality.toLowerCase().contains('good');
  }

  static double? readNumber(ScadaSnapshot snapshot, String tagName) {
    final tag = snapshot.tags[tagName];
    if (tag == null) return null;

    final val = tag.value;
    if (val is num) {
      return val.toDouble();
    }
    if (val is String && val.trim().isNotEmpty) {
      final parsed = double.tryParse(val);
      if (parsed != null && parsed.isFinite) {
        return parsed;
      }
    }
    return null;
  }

  static bool? readBoolean(ScadaSnapshot snapshot, String tagName) {
    final tag = snapshot.tags[tagName];
    if (tag == null) return null;

    final val = tag.value;
    if (val is bool) {
      return val;
    }
    if (val == 1 || val == '1' || val == 'true') {
      return true;
    }
    if (val == 0 || val == '0' || val == 'false') {
      return false;
    }
    return null;
  }

  static PositionState readPositionState(
    ScadaSnapshot snapshot,
    String tagName,
  ) {
    final tag = snapshot.tags[tagName];
    if (!isGoodQuality(tag)) {
      return PositionState.unknown;
    }
    final position = readNumber(snapshot, tagName);
    if (position == 2.0) {
      return PositionState.closed;
    }
    if (position == 1.0) {
      return PositionState.open;
    }
    if (position == 0.0) {
      return PositionState.intermediate;
    }
    return PositionState.unknown;
  }

  static PositionState readServiceTestState(
    ScadaSnapshot snapshot,
    String inServiceTag,
    String inTestTag,
  ) {
    final inService = snapshot.tags[inServiceTag];
    final inTest = snapshot.tags[inTestTag];
    if (!isGoodQuality(inService) || !isGoodQuality(inTest)) {
      return PositionState.unknown;
    }

    final inServiceVal = readBoolean(snapshot, inServiceTag);
    final inTestVal = readBoolean(snapshot, inTestTag);

    if (inServiceVal == true && inTestVal == false) {
      return PositionState.closed;
    }
    if (inServiceVal == false && inTestVal == true) {
      return PositionState.open;
    }
    if (inServiceVal == false && inTestVal == false) {
      return PositionState.intermediate;
    }
    return PositionState.unknown;
  }

  static bool readWarningActive(ScadaSnapshot snapshot, String tagName) {
    final tag = snapshot.tags[tagName];
    return isGoodQuality(tag) && readBoolean(snapshot, tagName) == true;
  }

  static String formatMeasurement(double? value, int fractionDigits) {
    if (value == null || !value.isFinite) {
      return 'Mất kết nối';
    }
    return value.toStringAsFixed(fractionDigits);
  }

  static double? telemetryNumber(Map<String, dynamic> item, String key) {
    final value = item[key];
    return value is num && value.isFinite ? value.toDouble() : null;
  }

  static String formatTelemetry(
    double? value, {
    int fractionDigits = 1,
    String unit = '',
  }) {
    if (value == null || !value.isFinite) {
      return 'Mất kết nối';
    }
    final suffix = unit.isEmpty ? '' : ' $unit';
    return '${value.toStringAsFixed(fractionDigits)}$suffix';
  }

  static String turbineSignalPresentation({
    required bool delayed,
    required int? ageSeconds,
    required String normalLabel,
  }) {
    if (!delayed) {
      return normalLabel;
    }
    if (ageSeconds == null) {
      return "Tín hiệu chậm";
    }
    if (ageSeconds < 60) {
      return "Tín hiệu chậm ${ageSeconds}s";
    }
    return "Tín hiệu chậm ${(ageSeconds / 60).round()}p";
  }

  static Map<String, int> summarizeQuality(ScadaSnapshot snapshot) {
    int good = 0;
    int total = snapshot.tags.length;
    for (final tag in snapshot.tags.values) {
      if (isGoodQuality(tag)) {
        good++;
      }
    }
    return {'good': good, 'total': total};
  }

  static int? snapshotAgeSeconds(ScadaSnapshot snapshot, int nowMs) {
    try {
      final utcTime = DateTime.parse(
        snapshot.snapshotUtc,
      ).millisecondsSinceEpoch;
      return ((nowMs - utcTime) / 1000).round();
    } catch (_) {
      return null;
    }
  }
}
