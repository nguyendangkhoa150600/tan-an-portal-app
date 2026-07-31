import 'package:flutter/material.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import 'package:tan_an_portal/features/scada/data/models/overlay_models.dart';
import 'package:tan_an_portal/features/scada/data/models/scada_models.dart';

class OneLineValueOverlay extends StatelessWidget {
  final List<ValueOverlay> valueOverlays;
  final ScadaSnapshot snapshot;
  final double containerWidth;
  final double containerHeight;

  const OneLineValueOverlay({
    super.key,
    required this.valueOverlays,
    required this.snapshot,
    required this.containerWidth,
    required this.containerHeight,
  });

  @override
  Widget build(BuildContext context) {
    final double scaleX = containerWidth / 1920.0;
    final double scaleY = containerHeight / 1028.0;

    return Stack(
      children: valueOverlays.map((overlay) {
        final tag = snapshot.tags[overlay.tag];
        final good = ScadaHelpers.isGoodQuality(tag);
        final value = good
            ? ScadaHelpers.readNumber(snapshot, overlay.tag)
            : null;
        final text = ScadaHelpers.formatMeasurement(value, overlay.digits);

        // Adjust positioning based on React source masking logic
        final masksLiveCapture = overlay.tag != 'Subs::Oneline::Hz';
        final double leftMask = masksLiveCapture
            ? (overlay.fontSize * 0.45).clamp(8.0, double.infinity)
            : 0.0;

        final double adjustedX = (overlay.x - leftMask) * scaleX;
        final double adjustedWidth = (overlay.width + leftMask) * scaleX;
        final double adjustedY = overlay.y * scaleY;
        final double adjustedHeight = overlay.height * scaleY;

        final double calculatedFontSize = (overlay.fontSize * scaleX).clamp(
          7.0,
          15.0,
        );

        return Positioned(
          left: adjustedX,
          top: adjustedY,
          width: adjustedWidth,
          height: adjustedHeight,
          child: Container(
            alignment: masksLiveCapture
                ? Alignment.centerRight
                : Alignment.center,
            padding: EdgeInsets.only(
              right: masksLiveCapture ? (overlay.fontSize * 0.28 * scaleX) : 0,
            ),
            decoration: BoxDecoration(
              color: masksLiveCapture
                  ? const Color(0xFF1E293B)
                  : Colors.transparent, // Dark mask for diagram readability
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: good
                    ? const Color(0xFF38BDF8)
                    : AppTheme
                          .scadaIntermediate, // Cyan for live active values, Orange for bad quality
                fontSize: calculatedFontSize,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          ),
        );
      }).toList(),
    );
  }
}
