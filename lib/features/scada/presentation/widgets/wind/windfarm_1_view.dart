import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../../providers/scada_provider.dart';
import '../dispatch/dispatch_lamp_widget.dart';

class WindFarm1View extends StatelessWidget {
  const WindFarm1View({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final turbines = provider.dg1Turbines;

    // Filter live (non-delayed) turbines for operational aggregates
    final liveTurbines = turbines
        .where(
          (t) =>
              !(t['signalDelayed'] as bool? ?? false) &&
              (t['power'] as num).toDouble().isFinite &&
              (t['wind'] as num).toDouble().isFinite,
        )
        .toList();
    final int delayedCount = turbines.length - liveTurbines.length;

    // Total stats calculated from live turbines
    final double powerTotal = liveTurbines.fold<double>(
      0.0,
      (s, t) => s + (t['power'] as num).toDouble(),
    );
    final double windSum = liveTurbines.fold<double>(
      0.0,
      (s, t) => s + (t['wind'] as num).toDouble(),
    );
    final double windAvg = liveTurbines.isNotEmpty
        ? windSum / liveTurbines.length
        : double.nan;

    // Circular mean for wind direction from live turbines
    final double windDirAvg = _calcCircularMean(
      liveTurbines.map((t) => (t['windDir'] as num?)?.toDouble()).toList(),
    );

    final double ratedKw = 7 * 4200.0;
    final double cf = liveTurbines.isNotEmpty && ratedKw > 0
        ? (powerTotal / ratedKw)
        : double.nan;

    int runningCount = liveTurbines
        .where((t) => t['status'] == 'running')
        .length;
    int standbyCount = liveTurbines
        .where((t) => t['status'] == 'standby')
        .length;
    int offlineCount = liveTurbines
        .where((t) => t['status'] == 'offline' || t['status'] == 'alarm')
        .length;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    final Widget gridWidget = Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 3;
          if (constraints.maxWidth < 600) {
            crossAxisCount = 1;
          } else if (constraints.maxWidth < 900) {
            crossAxisCount = 2;
          }

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: turbines.length,
            itemBuilder: (context, index) {
              final t = turbines[index];
              return _turbineCard(t);
            },
          );
        },
      ),
    );

    final Widget compactWidget = Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: turbines.length,
        itemBuilder: (context, index) {
          final t = turbines[index];
          return CompactTurbineCard1(turbine: t);
        },
      ),
    );

    final Widget sidebarWidget = Container(
      width: isMobile ? double.infinity : 260,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          left: isMobile
              ? BorderSide.none
              : const BorderSide(color: AppTheme.border, width: 1),
          bottom: isMobile
              ? const BorderSide(color: AppTheme.border, width: 1)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tổng quan nhà máy',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textStrong,
                    ),
                  ),
                ],
              ),
              if (provider.windAgc != null)
                AgcChip(agc: provider.windAgc!),
            ],
          ),
          const SizedBox(height: 16),

          if (isMobile) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CÔNG SUẤT TÁC DỤNG',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ScadaHelpers.formatTelemetry(
                          powerTotal,
                          fractionDigits: 0,
                          unit: 'kW',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      Text(
                        ScadaHelpers.formatTelemetry(
                          powerTotal / 1000,
                          fractionDigits: 2,
                          unit: 'MW',
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      CompassRose(deg: windDirAvg, size: 36),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'HƯỚNG GIÓ TRUNG BÌNH',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              windDirAvg.isFinite
                                  ? '${windDirAvg.toStringAsFixed(0)}° · ${_getCompassLabel(windDirAvg)}'
                                  : 'Mất kết nối',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textStrong,
                              ),
                            ),
                            Text(
                              ScadaHelpers.formatTelemetry(
                                windAvg,
                                unit: 'm/s',
                              ),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _mobileInfoText(
                  'Hiệu suất',
                  ScadaHelpers.formatTelemetry(
                    cf * 100,
                    fractionDigits: 0,
                    unit: '%',
                  ),
                ),
                _mobileInfoText(
                  'Lắp đặt',
                  '${(ratedKw / 1000).toStringAsFixed(1)} MW',
                ),
                _mobileInfoText('Đang phát', '$runningCount / 7'),
                if (delayedCount > 0)
                  _mobileInfoText(
                    'Tín hiệu chậm',
                    '$delayedCount trụ',
                    color: AppTheme.warning,
                  ),
              ],
            ),
          ] else ...[
            // Hero Power Metric
            const Text(
              'CÔNG SUẤT TÁC DỤNG',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ScadaHelpers.formatTelemetry(
                powerTotal,
                fractionDigits: 0,
                unit: 'kW',
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
              ),
            ),
            Text(
              ScadaHelpers.formatTelemetry(
                powerTotal / 1000,
                fractionDigits: 2,
                unit: 'MW',
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Wind direction compass row
            Row(
              children: [
                CompassRose(deg: windDirAvg, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HƯỚNG GIÓ TRUNG BÌNH',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        windDirAvg.isFinite
                            ? '${windDirAvg.toStringAsFixed(0)}° · ${_getCompassLabel(windDirAvg)}'
                            : 'Mất kết nối',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ScadaHelpers.formatTelemetry(windAvg, unit: 'm/s'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 16),

            _sidebarInfoRow(
              'Hệ số công suất',
              ScadaHelpers.formatTelemetry(
                cf * 100,
                fractionDigits: 0,
                unit: '%',
              ),
            ),
            _sidebarInfoRow(
              'Công suất lắp đặt',
              '${(ratedKw / 1000).toStringAsFixed(1)} MW',
            ),
            _sidebarInfoRow('Đang phát điện', '$runningCount / 7'),
            if (delayedCount > 0)
              _sidebarInfoRow('Tín hiệu chậm', '$delayedCount trụ'),

            const SizedBox(height: 24),
            const Text(
              'THỐNG KÊ TRẠNG THÁI',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _statItem(AppTheme.success, 'Phát điện', '$runningCount'),
            const SizedBox(height: 6),
            _statItem(AppTheme.primary, 'Dừng / chờ', '$standbyCount'),
            const SizedBox(height: 6),
            _statItem(AppTheme.error, 'Sự cố / mất KN', '$offlineCount'),
            if (delayedCount > 0) ...[
              const SizedBox(height: 6),
              _statItem(AppTheme.warning, 'Tín hiệu chậm', '$delayedCount'),
            ],
          ],
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          sidebarWidget,
          Expanded(
            child: provider.isWindCompactMode ? compactWidget : gridWidget,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: provider.isWindCompactMode ? compactWidget : gridWidget,
        ),
        sidebarWidget,
      ],
    );
  }

  Widget _mobileInfoText(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color ?? AppTheme.textStrong,
          ),
        ),
      ],
    );
  }

  Widget _turbineCard(Map<String, dynamic> t) {
    final status = t['status'] as String;
    final stateLabel = t['stateLabel'] as String;
    final power = (t['power'] as num).toDouble();
    final wind = (t['wind'] as num).toDouble();
    final windDir = (t['windDir'] as num?)?.toDouble();
    final rotorRpm = (t['rotorRpm'] as num?)?.toDouble();
    final genRpm = (t['genRpm'] as num?)?.toDouble();
    final pitch = (t['pitch'] as num?)?.toDouble();
    final tmpAmb = (t['tmpAmb'] as num?)?.toDouble();
    final reactive = (t['reactive'] as num?)?.toDouble();

    final bool signalDelayed = t['signalDelayed'] as bool? ?? false;
    final int? signalAgeSeconds = t['signalAgeSeconds'] as int?;

    Color statusColor = AppTheme.success;
    if (signalDelayed) {
      statusColor = AppTheme.warning;
    } else if (status == 'standby') {
      statusColor = AppTheme.primary;
    } else if (status == 'offline') {
      statusColor = AppTheme.dim;
    } else if (status == 'alarm') {
      statusColor = AppTheme.error;
    }

    final displayStateLabel = ScadaHelpers.turbineSignalPresentation(
      delayed: signalDelayed,
      ageSeconds: signalAgeSeconds,
      normalLabel: stateLabel,
    );

    return Card(
      color: signalDelayed
          ? Color.alphaBlend(
              AppTheme.warning.withOpacity(0.08),
              AppTheme.surface,
            )
          : AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: signalDelayed
              ? AppTheme.warning.withOpacity(0.72)
              : AppTheme.border,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Top: Name and State Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textStrong,
                        ),
                      ),
                      Text(
                        t['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      displayStateLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle: Animated Icon and Primary Metrics
            Row(
              children: [
                SpinningTurbineIcon(
                  rotorRpm: rotorRpm,
                  status: status,
                  signalDelayed: signalDelayed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            ScadaHelpers.formatTelemetry(
                              power,
                              fractionDigits: 0,
                            ),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Text(
                            'kW',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.air_rounded,
                            size: 12,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ScadaHelpers.formatTelemetry(wind, unit: 'm/s'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          CompassRose(deg: windDir, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            windDir != null && windDir.isFinite
                                ? '${windDir.toStringAsFixed(0)}° ${_getCompassLabel(windDir)}'
                                : 'Mất kết nối',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bottom: Parameters Grid
            Expanded(
              child: GridView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 2.8,
                ),
                children: [
                  _miniReadout(
                    'Máy phát',
                    ScadaHelpers.formatTelemetry(
                      genRpm,
                      fractionDigits: 0,
                      unit: 'rpm',
                    ),
                  ),
                  _miniReadout(
                    'Rotor',
                    ScadaHelpers.formatTelemetry(rotorRpm, unit: 'rpm'),
                  ),
                  _miniReadout(
                    'Pitch',
                    ScadaHelpers.formatTelemetry(pitch, unit: '°'),
                  ),
                  _miniReadout(
                    'Nhiệt độ',
                    ScadaHelpers.formatTelemetry(tmpAmb, unit: '°C'),
                  ),
                  _miniReadout(
                    'P. kháng',
                    ScadaHelpers.formatTelemetry(
                      reactive,
                      fractionDigits: 0,
                      unit: 'kVar',
                    ),
                  ),
                  _miniReadout(
                    'Lệch gió',
                    ScadaHelpers.formatTelemetry(
                      ScadaHelpers.telemetryNumber(t, 'yawErr'),
                      unit: '°',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniReadout(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _sidebarInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textStrong,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(Color color, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  double _calcCircularMean(List<double?> angles) {
    final present = angles.where((a) => a != null).map((a) => a!).toList();
    if (present.isEmpty) return double.nan;

    double sumX = 0;
    double sumY = 0;
    for (var a in present) {
      final rad = a * pi / 180.0;
      sumX += cos(rad);
      sumY += sin(rad);
    }
    final meanRad = atan2(sumY, sumX);
    final meanDeg = meanRad * 180.0 / pi;
    return (meanDeg + 360.0) % 360.0;
  }

  String _getCompassLabel(double? deg) {
    if (deg == null || !deg.isFinite) return 'Mất kết nối';
    const pts = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    return pts[((deg % 360) / 22.5).round() % 16];
  }
}

class SpinningTurbineIcon extends StatefulWidget {
  final double? rotorRpm;
  final String status;
  final bool signalDelayed;

  const SpinningTurbineIcon({
    super.key,
    required this.rotorRpm,
    required this.status,
    this.signalDelayed = false,
  });

  @override
  State<SpinningTurbineIcon> createState() => _SpinningTurbineIconState();
}

class _SpinningTurbineIconState extends State<SpinningTurbineIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant SpinningTurbineIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.status == 'running' &&
        widget.rotorRpm != null &&
        widget.rotorRpm! > 0.2 &&
        !widget.signalDelayed) {
      final double secPerRev = 60.0 / widget.rotorRpm!;
      final double duration = secPerRev.clamp(1.1, 6.0);
      _controller.duration = Duration(milliseconds: (duration * 1000).toInt());
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 90,
      child: CustomPaint(
        painter: TurbineIconPainter(
          animationValue: _controller,
          status: widget.status,
          signalDelayed: widget.signalDelayed,
        ),
      ),
    );
  }
}

class TurbineIconPainter extends CustomPainter {
  final Animation<double> animationValue;
  final String status;
  final bool signalDelayed;

  TurbineIconPainter({
    required this.animationValue,
    required this.status,
    required this.signalDelayed,
  }) : super(repaint: animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint towerPaint = Paint()
      ..color = AppTheme.borderStrong
      ..style = PaintingStyle.fill;

    // Draw tower
    final Path towerPath = Path()
      ..moveTo(w * 0.48, h * 0.3)
      ..lineTo(w * 0.52, h * 0.3)
      ..lineTo(w * 0.55, h * 0.9)
      ..lineTo(w * 0.45, h * 0.9)
      ..close();
    canvas.drawPath(towerPath, towerPaint);

    // Draw nacelle
    final Paint nacellePaint = Paint()
      ..color = AppTheme.dim
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.3), width: 12, height: 7),
        const Radius.circular(3),
      ),
      nacellePaint,
    );

    // Draw spinning blades
    final Offset hubOffset = Offset(w * 0.5, h * 0.3);
    final double angle = animationValue.value * 2 * pi;

    final Paint bladePaint = Paint()
      ..color = (status == 'running' && !signalDelayed)
          ? AppTheme.success
          : AppTheme.dim
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(hubOffset.dx, hubOffset.dy);
    canvas.rotate(angle);

    final double bladeLen = 22.0;
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate(i * 2 * pi / 3);
      final Path bladePath = Path()
        ..moveTo(-1.0, 0)
        ..quadraticBezierTo(-2.0, -bladeLen * 0.5, 0, -bladeLen)
        ..quadraticBezierTo(2.0, -bladeLen * 0.5, 1.0, 0)
        ..close();
      canvas.drawPath(bladePath, bladePaint);
      canvas.restore();
    }

    // Draw hub
    final Paint hubPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 2.5, hubPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TurbineIconPainter oldDelegate) => true;
}

class CompassRose extends StatelessWidget {
  final double? deg;
  final double size;

  const CompassRose({super.key, required this.deg, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final has = deg != null && deg!.isFinite;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: CompassRosePainter(deg: deg, hasDir: has),
      ),
    );
  }
}

class CompassRosePainter extends CustomPainter {
  final double? deg;
  final bool hasDir;

  CompassRosePainter({required this.deg, required this.hasDir});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2 - 2;

    final Paint ringPaint = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(Offset(cx, cy), r, ringPaint);

    if (hasDir && deg != null) {
      final Paint needlePaint = Paint()
        ..color = AppTheme.primary
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate((deg! * pi / 180));

      final Path needle = Path()
        ..moveTo(0, -r + 4)
        ..lineTo(-3.5, 2)
        ..lineTo(0, -1)
        ..lineTo(3.5, 2)
        ..close();
      canvas.drawPath(needle, needlePaint);
      canvas.restore();
    } else {
      canvas.drawCircle(Offset(cx, cy), 2.0, Paint()..color = AppTheme.dim);
    }
  }

  @override
  bool shouldRepaint(covariant CompassRosePainter oldDelegate) => true;
}

class CompactTurbineCard1 extends StatefulWidget {
  final Map<String, dynamic> turbine;

  const CompactTurbineCard1({super.key, required this.turbine});

  @override
  State<CompactTurbineCard1> createState() => _CompactTurbineCard1State();
}

class _CompactTurbineCard1State extends State<CompactTurbineCard1> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.turbine;
    final status = t['status'] as String;
    final stateLabel = t['stateLabel'] as String;
    final power = (t['power'] as num).toDouble();
    final wind = (t['wind'] as num).toDouble();
    final rotorRpm = (t['rotorRpm'] as num?)?.toDouble();
    final genRpm = (t['genRpm'] as num?)?.toDouble();
    final pitch = (t['pitch'] as num?)?.toDouble();
    final tmpAmb = (t['tmpAmb'] as num?)?.toDouble();
    final reactive = (t['reactive'] as num?)?.toDouble();
    final yawErr = (t['yawErr'] as num?)?.toDouble();

    final bool signalDelayed = t['signalDelayed'] as bool? ?? false;
    final int? signalAgeSeconds = t['signalAgeSeconds'] as int?;

    Color statusColor = AppTheme.success;
    if (signalDelayed) {
      statusColor = AppTheme.warning;
    } else if (status == 'standby') {
      statusColor = AppTheme.primary;
    } else if (status == 'offline') {
      statusColor = AppTheme.dim;
    } else if (status == 'alarm') {
      statusColor = AppTheme.error;
    }

    final displayStateLabel = ScadaHelpers.turbineSignalPresentation(
      delayed: signalDelayed,
      ageSeconds: signalAgeSeconds,
      normalLabel: stateLabel,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: signalDelayed
          ? Color.alphaBlend(
              AppTheme.warning.withOpacity(0.08),
              AppTheme.surface,
            )
          : AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: signalDelayed
              ? AppTheme.warning.withOpacity(0.72)
              : AppTheme.border,
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Collapsed main Row
                Row(
                  children: [
                    // 1. Scaled Spinning Turbine Icon
                    SizedBox(
                      width: 24,
                      height: 34,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SpinningTurbineIcon(
                          rotorRpm: rotorRpm,
                          status: status,
                          signalDelayed: signalDelayed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 2. Turbine Name & Label
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: AppTheme.textStrong,
                            ),
                          ),
                          Text(
                            t['label'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Power
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            ScadaHelpers.formatTelemetry(
                              power,
                              fractionDigits: 0,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 1),
                          const Text(
                            'kW',
                            style: TextStyle(
                              fontSize: 8.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 4. Wind Speed
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.air_rounded,
                            size: 11,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            ScadaHelpers.formatTelemetry(wind),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 5. Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        displayStateLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 6. Expand Arrow
                    Icon(
                      _isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),

                // Expanded Section
                if (_isExpanded) ...[
                  const Divider(color: AppTheme.border, height: 12),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.5,
                        ),
                    children: [
                      _compactMiniReadout(
                        'Máy phát',
                        ScadaHelpers.formatTelemetry(
                          genRpm,
                          fractionDigits: 0,
                          unit: 'rpm',
                        ),
                      ),
                      _compactMiniReadout(
                        'Rotor',
                        ScadaHelpers.formatTelemetry(rotorRpm, unit: 'rpm'),
                      ),
                      _compactMiniReadout(
                        'Pitch',
                        ScadaHelpers.formatTelemetry(pitch, unit: '°'),
                      ),
                      _compactMiniReadout(
                        'Nhiệt độ',
                        ScadaHelpers.formatTelemetry(tmpAmb, unit: '°C'),
                      ),
                      _compactMiniReadout(
                        'P. kháng',
                        ScadaHelpers.formatTelemetry(
                          reactive,
                          fractionDigits: 0,
                          unit: 'kVar',
                        ),
                      ),
                      _compactMiniReadout(
                        'Lệch gió',
                        ScadaHelpers.formatTelemetry(yawErr, unit: '°'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactMiniReadout(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 0.5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
