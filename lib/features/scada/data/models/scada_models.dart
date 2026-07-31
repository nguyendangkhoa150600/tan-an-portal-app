enum PositionState { closed, open, intermediate, unknown }

class ScadaTag {
  final dynamic value;
  final String quality;
  final int? qualityCode;
  final String? timestamp;
  final String? error;

  ScadaTag({
    required this.value,
    required this.quality,
    this.qualityCode,
    this.timestamp,
    this.error,
  });

  factory ScadaTag.fromJson(dynamic json) {
    if (json is! Map) {
      return ScadaTag(
        value: json,
        quality: 'UNKNOWN',
        qualityCode: null,
        timestamp: null,
        error: null,
      );
    }
    return ScadaTag(
      value: json['value'],
      quality: (json['quality'] as String? ?? 'UNKNOWN').toUpperCase(),
      qualityCode: json['quality_code'] as int?,
      timestamp: json['timestamp'] as String?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'quality': quality,
      'quality_code': qualityCode,
      'timestamp': timestamp,
      'error': error,
    };
  }

  bool get isGoodQuality => quality.contains('GOOD');
}

class ScadaSnapshot {
  final String source;
  final String? version;
  final String station;
  final String screen;
  final String snapshotUtc;
  final bool readOnly;
  final String? relay;
  final Map<String, ScadaTag> tags;

  ScadaSnapshot({
    required this.source,
    this.version,
    required this.station,
    required this.screen,
    required this.snapshotUtc,
    this.readOnly = true,
    this.relay,
    required this.tags,
  });

  factory ScadaSnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawTags =
        json['tags'] as Map<String, dynamic>? ?? {};
    final Map<String, ScadaTag> tags = rawTags.map(
      (key, value) => MapEntry(key, ScadaTag.fromJson(value)),
    );

    return ScadaSnapshot(
      source: json['source'] as String? ?? 'ats-scada-bridge',
      version: json['version'] as String?,
      station: json['station'] as String? ?? 'TANAN',
      screen: json['screen'] as String? ?? 'ONELINE_1',
      snapshotUtc:
          json['snapshot_utc'] as String? ?? DateTime.now().toIso8601String(),
      readOnly: json['read_only'] as bool? ?? true,
      relay: json['relay'] as String?,
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'version': version,
      'station': station,
      'screen': screen,
      'snapshot_utc': snapshotUtc,
      'read_only': readOnly,
      'relay': relay,
      'tags': tags.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

class SnapshotEnvelope {
  final String origin; // 'empty' | 'bridge'
  final String? receivedAt;
  final ScadaSnapshot snapshot;

  SnapshotEnvelope({
    required this.origin,
    this.receivedAt,
    required this.snapshot,
  });

  factory SnapshotEnvelope.fromJson(Map<String, dynamic> json) {
    return SnapshotEnvelope(
      origin: json['origin'] as String? ?? 'empty',
      receivedAt: json['received_at'] as String?,
      snapshot: ScadaSnapshot.fromJson(
        json['snapshot'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      'received_at': receivedAt,
      'snapshot': snapshot.toJson(),
    };
  }
}
