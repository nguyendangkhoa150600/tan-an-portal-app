import 'package:flutter/material.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../../../data/models/overlay_models.dart';
import '../../../data/models/scada_models.dart';

class OneLineCanvasPainter extends CustomPainter {
  final List<StatusSymbolOverlay> statusSymbols;
  final List<BreakerOverlay> breakers;
  final ScadaSnapshot snapshot;

  OneLineCanvasPainter({
    required this.statusSymbols,
    required this.breakers,
    required this.snapshot,
  });

  Color _getStateColor(PositionState state) {
    switch (state) {
      case PositionState.closed:
        return AppTheme.scadaClosed; // Red
      case PositionState.open:
        return AppTheme.scadaOpen; // Green
      case PositionState.intermediate:
        return AppTheme.scadaIntermediate; // Yellow
      case PositionState.unknown:
        return AppTheme.scadaUnknown; // Grey
    }
  }

  PositionState _getStatusSymbolState(StatusSource source) {
    if (source.kind == 'position') {
      return ScadaHelpers.readPositionState(snapshot, source.tag ?? '');
    } else {
      return ScadaHelpers.readServiceTestState(
        snapshot,
        source.inServiceTag ?? '',
        source.inTestTag ?? '',
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / 1920.0;
    final double scaleY = size.height / 1028.0;

    // SmartHMI's state shapes offset
    const double stateOffset = 4.0;

    final paintMask = Paint()
      ..color =
          const Color(0xFF1E293B) // Slate 800 mask
      ..style = PaintingStyle.fill;

    // 1. Draw Status Symbols
    for (final overlay in statusSymbols) {
      final state = _getStatusSymbolState(overlay.stateSource);
      final stateColor = _getStateColor(state);

      final paintLine = Paint()
        ..color = stateColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final paintFill = Paint()
        ..color = stateColor
        ..style = PaintingStyle.fill;

      canvas.save();
      // Apply offset scaling
      canvas.translate(stateOffset * scaleX, stateOffset * scaleY);

      for (final shape in overlay.shapes) {
        final path = Path();
        if (shape.points.isEmpty) continue;

        // Map points to canvas coordinates
        final firstPoint = Offset(
          shape.points[0].dx * scaleX,
          shape.points[0].dy * scaleY,
        );
        path.moveTo(firstPoint.dx, firstPoint.dy);

        for (int i = 1; i < shape.points.length; i++) {
          final pt = Offset(
            shape.points[i].dx * scaleX,
            shape.points[i].dy * scaleY,
          );
          path.lineTo(pt.dx, pt.dy);
        }

        if (shape.kind == 'polygon') {
          path.close();
          // Draw mask first
          canvas.drawPath(path, paintMask);
          // Draw state fill
          canvas.drawPath(path, paintFill);
        } else {
          // Draw state line
          canvas.drawPath(path, paintLine);
        }
      }
      canvas.restore();
    }

    // 2. Draw Breakers
    for (final overlay in breakers) {
      final state = ScadaHelpers.readPositionState(snapshot, overlay.tag);
      final stateColor = _getStateColor(state);

      final paintBreakerFill = Paint()
        ..color = stateColor
        ..style = PaintingStyle.fill;

      final paintBreakerStroke = Paint()
        ..color = stateColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.save();
      canvas.translate(stateOffset * scaleX, stateOffset * scaleY);

      final path = Path();
      if (overlay.points.isNotEmpty) {
        final firstPoint = Offset(
          overlay.points[0].dx * scaleX,
          overlay.points[0].dy * scaleY,
        );
        path.moveTo(firstPoint.dx, firstPoint.dy);

        for (int i = 1; i < overlay.points.length; i++) {
          final pt = Offset(
            overlay.points[i].dx * scaleX,
            overlay.points[i].dy * scaleY,
          );
          path.lineTo(pt.dx, pt.dy);
        }
        path.close();

        // Draw breaker background mask
        canvas.drawPath(path, paintMask);
        // Draw breaker color state
        canvas.drawPath(path, paintBreakerFill);
        canvas.drawPath(path, paintBreakerStroke);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant OneLineCanvasPainter oldDelegate) {
    return oldDelegate.snapshot.snapshotUtc != snapshot.snapshotUtc;
  }
}
