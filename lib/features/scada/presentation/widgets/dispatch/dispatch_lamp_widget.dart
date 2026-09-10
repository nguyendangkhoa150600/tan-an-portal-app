import 'package:flutter/material.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import '../../../data/models/dispatch_models.dart';

class DispatchLampWidget extends StatelessWidget {
  final String label;
  final String? value;
  final DispatchLampState state;

  const DispatchLampWidget({
    super.key,
    required this.label,
    this.value,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    BoxBorder? dotBorder;
    List<BoxShadow>? dotShadow;

    if (state == DispatchLampState.on) {
      dotColor = const Color(0xFF10B981);
      dotShadow = [
        BoxShadow(
          color: const Color(0xFF10B981).withOpacity(0.5),
          blurRadius: 5,
          spreadRadius: 1,
        )
      ];
    } else if (state == DispatchLampState.off) {
      dotColor = const Color(0xFF64748B);
    } else {
      dotColor = Colors.transparent;
      dotBorder = Border.all(color: const Color(0xFF64748B), width: 1.5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: dotBorder,
              boxShadow: dotShadow,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          if (value != null && value!.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              value!,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.textStrong,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProjectDispatchRow extends StatelessWidget {
  final String label;
  final double outputMw;
  final DispatchLamp? lamp;

  const ProjectDispatchRow({
    super.key,
    required this.label,
    required this.outputMw,
    required this.lamp,
  });

  @override
  Widget build(BuildContext context) {
    final state = lamp?.state ?? DispatchLampState.unknown;
    final limitMw = lamp?.mw;

    Color dotColor;
    BoxBorder? dotBorder;
    List<BoxShadow>? dotShadow;

    if (state == DispatchLampState.on) {
      dotColor = const Color(0xFF10B981);
      dotShadow = [
        BoxShadow(
          color: const Color(0xFF10B981).withOpacity(0.5),
          blurRadius: 5,
          spreadRadius: 1,
        )
      ];
    } else if (state == DispatchLampState.off) {
      dotColor = const Color(0xFF64748B);
    } else {
      dotColor = Colors.transparent;
      dotBorder = Border.all(color: const Color(0xFF64748B), width: 1.5);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: dotBorder,
                  boxShadow: dotShadow,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '${outputMw.toStringAsFixed(1)} ',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textStrong,
                ),
              ),
              const Text(
                '/',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.border,
                ),
              ),
              Text(
                ' ${limitMw == null ? "--" : limitMw.toStringAsFixed(1)} MW',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AgcChip extends StatelessWidget {
  final WindAgcStatus agc;
  const AgcChip({super.key, required this.agc});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    Color textColor;
    String text;

    if (agc.agcActive == true) {
      chipColor = AppTheme.success.withOpacity(0.12);
      textColor = AppTheme.success;
      final mwStr = agc.agcCmdMw != null
          ? ' ${agc.agcCmdMw!.toStringAsFixed(2)} MW'
          : '';
      final commErrorStr = agc.commOk == false ? ' · comm LỖI' : '';
      text = 'AGC$mwStr$commErrorStr';
    } else if (agc.agcActive == false) {
      chipColor = AppTheme.textSecondary.withOpacity(0.12);
      textColor = AppTheme.textSecondary;
      text = 'APC: ${agc.modeLabel}';
    } else {
      chipColor = AppTheme.textSecondary.withOpacity(0.08);
      textColor = AppTheme.textSecondary;
      text = 'APC: mất dữ liệu';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.24), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textColor,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class EvnSetpointChip extends StatelessWidget {
  final VestasLivePpc ppc;
  const EvnSetpointChip({super.key, required this.ppc});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    Color textColor;
    String text;

    if (ppc.activeControlEnabled == true) {
      chipColor = AppTheme.success.withOpacity(0.12);
      textColor = AppTheme.success;
      final mwStr = ppc.activeSetpointKw != null
          ? ' ${(ppc.activeSetpointKw! / 1000.0).toStringAsFixed(1)} MW'
          : '';
      text = 'EVN$mwStr';
    } else if (ppc.activeControlEnabled == false) {
      chipColor = AppTheme.textSecondary.withOpacity(0.12);
      textColor = AppTheme.textSecondary;
      text = 'EVN: Tắt';
    } else {
      chipColor = AppTheme.textSecondary.withOpacity(0.08);
      textColor = AppTheme.textSecondary;
      text = 'EVN: Không rõ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withOpacity(0.24), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textColor,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class PpcLampStrip extends StatelessWidget {
  final List<PpcStatus> statuses;
  const PpcLampStrip({super.key, required this.statuses});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PPC · TRẠM 110 KV:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          const SizedBox(width: 12),
          ...statuses.map((ppc) {
            Color dotColor;
            BoxBorder? dotBorder;
            List<BoxShadow>? dotShadow;

            if (ppc.on == true) {
              dotColor = const Color(0xFF10B981);
              dotShadow = [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ];
            } else if (ppc.on == false) {
              dotColor = const Color(0xFF64748B);
            } else {
              dotColor = Colors.transparent;
              dotBorder = Border.all(color: const Color(0xFF64748B), width: 1.5);
            }

            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: dotBorder,
                      boxShadow: dotShadow,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ppc.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
}
}

