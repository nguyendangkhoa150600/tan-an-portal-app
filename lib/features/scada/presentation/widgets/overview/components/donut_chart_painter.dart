import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';

class DonutChartPainter extends CustomPainter {
  final int running;
  final int standby;
  final int offline;
  final int alarm;
  final int delayed;

  DonutChartPainter({
    required this.running,
    required this.standby,
    required this.offline,
    required this.alarm,
    required this.delayed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double total = (running + standby + offline + alarm + delayed).toDouble();
    if (total == 0) return;

    final double strokeWidth = 8.0;
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -pi / 2;

    // Running (Good)
    if (running > 0) {
      paint.color = AppTheme.success;
      final sweepAngle = (running / total) * 2 * pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Standby (Accent/Blue)
    if (standby > 0) {
      paint.color = AppTheme.primary;
      final sweepAngle = (standby / total) * 2 * pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Offline (Dim)
    if (offline > 0) {
      paint.color = AppTheme.dim;
      final sweepAngle = (offline / total) * 2 * pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Alarm (Bad)
    if (alarm > 0) {
      paint.color = AppTheme.error;
      final sweepAngle = (alarm / total) * 2 * pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Delayed (Warning)
    if (delayed > 0) {
      paint.color = AppTheme.warning;
      final sweepAngle = (delayed / total) * 2 * pi;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
