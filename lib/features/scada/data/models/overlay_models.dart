import 'dart:ui';

class BreakerOverlay {
  final String objectId;
  final String label;
  final String tag;
  final List<Offset> points;

  BreakerOverlay({
    required this.objectId,
    required this.label,
    required this.tag,
    required this.points,
  });

  factory BreakerOverlay.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    final points = rawPoints.map((p) {
      final list = p as List<dynamic>;
      return Offset((list[0] as num).toDouble(), (list[1] as num).toDouble());
    }).toList();

    return BreakerOverlay(
      objectId: json['objectId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      points: points,
    );
  }
}

class ValueOverlay {
  final String tag;
  final double x;
  final double y;
  final double width;
  final double height;
  final double fontSize;
  final int digits;
  final double scaleX;
  final String background;

  ValueOverlay({
    required this.tag,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.digits,
    required this.scaleX,
    required this.background,
  });

  factory ValueOverlay.fromJson(Map<String, dynamic> json) {
    return ValueOverlay(
      tag: json['tag'] as String? ?? '',
      x: (json['x'] as num? ?? 0.0).toDouble(),
      y: (json['y'] as num? ?? 0.0).toDouble(),
      width: (json['width'] as num? ?? 0.0).toDouble(),
      height: (json['height'] as num? ?? 0.0).toDouble(),
      fontSize: (json['fontSize'] as num? ?? 12.0).toDouble(),
      digits: json['digits'] as int? ?? 1,
      scaleX: (json['scaleX'] as num? ?? 1.0).toDouble(),
      background: json['background'] as String? ?? '#000000',
    );
  }
}

class WarningOverlay {
  final String objectId;
  final String label;
  final String tag;
  final double x;
  final double y;
  final double width;
  final double height;

  WarningOverlay({
    required this.objectId,
    required this.label,
    required this.tag,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory WarningOverlay.fromJson(Map<String, dynamic> json) {
    return WarningOverlay(
      objectId: json['objectId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      x: (json['x'] as num? ?? 0.0).toDouble(),
      y: (json['y'] as num? ?? 0.0).toDouble(),
      width: (json['width'] as num? ?? 0.0).toDouble(),
      height: (json['height'] as num? ?? 0.0).toDouble(),
    );
  }
}

class StatusShape {
  final String kind; // 'line' | 'polygon'
  final List<Offset> points;

  StatusShape({required this.kind, required this.points});

  factory StatusShape.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    final points = rawPoints.map((p) {
      final list = p as List<dynamic>;
      return Offset((list[0] as num).toDouble(), (list[1] as num).toDouble());
    }).toList();

    return StatusShape(kind: json['kind'] as String? ?? 'line', points: points);
  }
}

class StatusSource {
  final String kind; // 'position' | 'serviceTest'
  final String? tag;
  final String? inServiceTag;
  final String? inTestTag;

  StatusSource({
    required this.kind,
    this.tag,
    this.inServiceTag,
    this.inTestTag,
  });

  factory StatusSource.fromJson(Map<String, dynamic> json) {
    return StatusSource(
      kind: json['kind'] as String? ?? 'position',
      tag: json['tag'] as String?,
      inServiceTag: json['inServiceTag'] as String?,
      inTestTag: json['inTestTag'] as String?,
    );
  }
}

class StatusSymbolOverlay {
  final String objectId;
  final String label;
  final StatusSource stateSource;
  final List<StatusShape> shapes;

  StatusSymbolOverlay({
    required this.objectId,
    required this.label,
    required this.stateSource,
    required this.shapes,
  });

  factory StatusSymbolOverlay.fromJson(Map<String, dynamic> json) {
    final rawShapes = json['shapes'] as List<dynamic>? ?? [];
    final shapes = rawShapes
        .map((s) => StatusShape.fromJson(s as Map<String, dynamic>))
        .toList();

    return StatusSymbolOverlay(
      objectId: json['objectId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      stateSource: StatusSource.fromJson(
        json['stateSource'] as Map<String, dynamic>? ?? {},
      ),
      shapes: shapes,
    );
  }
}
