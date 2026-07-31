import 'package:flutter/material.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import 'package:tan_an_portal/features/scada/data/models/overlay_models.dart';
import 'package:tan_an_portal/features/scada/data/models/scada_models.dart';

class OneLineWarningOverlay extends StatefulWidget {
  final List<WarningOverlay> warningOverlays;
  final ScadaSnapshot snapshot;
  final double containerWidth;
  final double containerHeight;

  const OneLineWarningOverlay({
    super.key,
    required this.warningOverlays,
    required this.snapshot,
    required this.containerWidth,
    required this.containerHeight,
  });

  @override
  State<OneLineWarningOverlay> createState() => _OneLineWarningOverlayState();
}

class _OneLineWarningOverlayState extends State<OneLineWarningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double scaleX = widget.containerWidth / 1920.0;
    final double scaleY = widget.containerHeight / 1028.0;

    // Filter active warnings
    final activeWarnings = widget.warningOverlays.where((overlay) {
      return ScadaHelpers.readWarningActive(widget.snapshot, overlay.tag);
    }).toList();

    if (activeWarnings.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: activeWarnings.map((overlay) {
        final double adjustedX = overlay.x * scaleX;
        final double adjustedY = overlay.y * scaleY;
        final double adjustedWidth = overlay.width * scaleX;
        final double adjustedHeight = overlay.height * scaleY;

        return Positioned(
          left: adjustedX,
          top: adjustedY,
          width: adjustedWidth,
          height: adjustedHeight,
          child: FadeTransition(
            opacity: _blinkController,
            child: Image.asset(
              'assets/scada/warning.png',
              width: adjustedWidth,
              height: adjustedHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback icon if asset image fails
                return const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 16,
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }
}
