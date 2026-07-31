import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../../providers/scada_provider.dart';
import 'windfarm_1_view.dart' show SpinningTurbineIcon, CompassRose;

class WindFarmAllView extends StatefulWidget {
  final bool directView;

  const WindFarmAllView({super.key, this.directView = false});

  @override
  State<WindFarmAllView> createState() => _WindFarmAllViewState();
}

class _WindFarmAllViewState extends State<WindFarmAllView> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final dg1Turbines = provider.dg1Turbines;
    final dg2Turbines = provider.dg2Turbines;

    // Merge both fleets
    final List<Map<String, dynamic>> turbines = [];
    turbines.addAll(dg1Turbines);
    turbines.addAll(dg2Turbines);

    final liveTurbines = turbines
        .where(
          (t) =>
              !(t['signalDelayed'] as bool? ?? false) &&
              (t['power'] as num).toDouble().isFinite &&
              (t['wind'] as num).toDouble().isFinite,
        )
        .toList();
    final int delayedCount = turbines.length - liveTurbines.length;

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
    final double windDirAvg = _calcCircularMean(
      liveTurbines.map((t) => (t['windDir'] as num?)?.toDouble()).toList(),
    );

    final double ratedKw = (7 * 4200.0) + (17 * 4000.0); // 97.4 MW total
    final double cf = liveTurbines.isNotEmpty && ratedKw > 0
        ? (powerTotal / ratedKw)
        : double.nan;

    final int runningCount = liveTurbines.where((t) => t['status'] == 'running').length;
    final int standbyCount = liveTurbines.where((t) => t['status'] == 'standby').length;
    final int offlineCount = liveTurbines.where((t) => t['status'] == 'offline' || t['status'] == 'alarm').length;
    final int alarmCount = liveTurbines.where((t) => t['status'] == 'alarm').length;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    // Build the grid widget
    final Widget gridWidget = Padding(
      padding: const EdgeInsets.all(12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 3;
          double spacing = 12;
          if (widget.directView) {
            // In TV fitting mode, design grid cells dynamically to fit perfectly
            if (constraints.maxWidth > 1400) {
              crossAxisCount = 8; // 8x3 grid
            } else if (constraints.maxWidth > 1000) {
              crossAxisCount = 6; // 6x4 grid
            } else {
              crossAxisCount = 4; // 4x6 grid
            }
            final double cellWidth = (constraints.maxWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
            final int rows = (turbines.length / crossAxisCount).ceil();
            final double cellHeight = (constraints.maxHeight - (rows - 1) * spacing) / rows;
            final double ratio = (cellHeight > 0 && cellWidth > 0) ? (cellWidth / cellHeight) : 1.15;

            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: ratio,
              ),
              itemCount: turbines.length,
              itemBuilder: (context, index) {
                final t = turbines[index];
                return _turbineCard(t, compactLayout: true);
              },
            );
          } else {
            // Normal view grid
            if (constraints.maxWidth < 600) {
              crossAxisCount = 1;
            } else if (constraints.maxWidth < 900) {
              crossAxisCount = 2;
            }
            return GridView.builder(
              shrinkWrap: isMobile,
              physics: isMobile ? const NeverScrollableScrollPhysics() : null,
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
          }
        },
      ),
    );

    // Build the compact widget
    final Widget compactWidget = Padding(
      padding: const EdgeInsets.all(12.0),
      child: ListView.builder(
        shrinkWrap: isMobile,
        physics: isMobile ? const NeverScrollableScrollPhysics() : null,
        itemCount: turbines.length,
        itemBuilder: (context, index) {
          final t = turbines[index];
          return CompactTurbineCardAll(turbine: t);
        },
      ),
    );

    // Direct TV Wallboard mode rendering
    if (widget.directView) {
      return Container(
        color: AppTheme.background,
        child: Column(
          children: [
            _buildDirectHeader(
              runningCount: runningCount,
              alarmCount: alarmCount,
              powerTotal: powerTotal,
              cf: cf,
              windAvg: windAvg,
              provider: provider,
              isMobile: isMobile,
            ),
            const Divider(height: 1, color: AppTheme.border),
            Expanded(child: gridWidget),
            _buildDirectFooter(
              runningCount: runningCount,
              standbyCount: standbyCount,
              offlineCount: offlineCount,
              delayedCount: delayedCount,
            ),
          ],
        ),
      );
    }

    // Normal Combined Portal rendering
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
            children: const [
              Icon(
                Icons.analytics_rounded,
                color: AppTheme.primary,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Toàn cảnh nhà máy',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textStrong,
                ),
              ),
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
                _mobileInfoText('Đang phát', '$runningCount / 24'),
                if (delayedCount > 0)
                  _mobileInfoText(
                    'Tín hiệu chậm',
                    '$delayedCount trụ',
                    color: AppTheme.warning,
                  ),
              ],
            ),
          ] else ...[
            const Text(
              'TỔNG CÔNG SUẤT PHÁT',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  ScadaHelpers.formatTelemetry(
                    powerTotal,
                    fractionDigits: 0,
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'kW',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            Text(
              '${(powerTotal / 1000).toStringAsFixed(2)} MW',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'HIỆU SUẤT ĐỊNH MỨC',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cf.isFinite ? '${(cf * 100).toStringAsFixed(1)}%' : '—',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.textStrong,
              ),
            ),
            Text(
              'định mức ${(ratedKw / 1000).toStringAsFixed(1)} MW',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'GIÓ TRUNG BÌNH TOÀN CỤM',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  ScadaHelpers.formatTelemetry(windAvg),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textStrong,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'm/s',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 12),
          const Text(
            'TRẠNG THÁI VẬN HÀNH',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _statItem(AppTheme.success, 'Đang phát điện', '$runningCount trụ'),
          const SizedBox(height: 8),
          _statItem(AppTheme.primary, 'Dừng / Chờ gió', '$standbyCount trụ'),
          const SizedBox(height: 8),
          _statItem(AppTheme.dim, 'Mất kết nối', '$offlineCount trụ'),
          if (delayedCount > 0) ...[
            const SizedBox(height: 8),
            _statItem(AppTheme.warning, 'Tín hiệu chậm', '$delayedCount trụ'),
          ],
        ],
      ),
    );

    return isMobile
        ? SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sidebarWidget,
                const Divider(height: 1, color: AppTheme.border),
                provider.isWindCompactMode ? compactWidget : gridWidget,
              ],
            ),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sidebarWidget,
              Expanded(
                child: provider.isWindCompactMode ? compactWidget : gridWidget,
              ),
            ],
          );
  }

  Widget _buildDirectHeader({
    required int runningCount,
    required int alarmCount,
    required double powerTotal,
    required double cf,
    required double windAvg,
    required ScadaProvider provider,
    required bool isMobile,
  }) {
    final nowText = DateFormat('HH:mm:ss').format(_currentTime);
    final String windAgeLabel = provider.windAgeSeconds == null ? 'LIVE' : '${provider.windAgeSeconds}s';
    final String vestasAgeLabel = provider.vestasAgeSeconds == null ? 'LIVE' : '${provider.vestasAgeSeconds}s';

    if (isMobile) {
      return Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'TOÀN CẢNH NHÀ MÁY',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'Tổng trụ gió · 24 trụ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textStrong,
                      ),
                    ),
                  ],
                ),
                Text(
                  nowText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _directKpiCell('Tổng công suất', '${(powerTotal / 1000).toStringAsFixed(1)} MW', '${(cf * 100).toStringAsFixed(0)}% định mức'),
                _directKpiCell('Đang phát', '$runningCount/24', 'trụ'),
                _directKpiCell('Gió TB', '${windAvg.isFinite ? windAvg.toStringAsFixed(1) : "—"} m/s', ''),
                _directKpiCell('Cảnh báo', '$alarmCount', '', isAlarm: alarmCount > 0),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left segment
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.radio_button_checked_rounded, size: 12, color: AppTheme.primary),
                  SizedBox(width: 6),
                  Text(
                    'TOÀN CẢNH NHÀ MÁY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                'Tổng trụ gió',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textStrong,
                ),
              ),
              Text(
                '24 trụ · 2 cụm vận hành',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Middle Segment: KPIs Rail
          Row(
            children: [
              _directKpiCell('Tổng công suất', '${(powerTotal / 1000).toStringAsFixed(2)} MW', '${(cf * 100).toStringAsFixed(0)}% định mức'),
              const SizedBox(width: 16),
              _directKpiCell('Đang phát', runningCount.toString(), '/24'),
              const SizedBox(width: 16),
              _directKpiCell('Gió trung bình', windAvg.isFinite ? windAvg.toStringAsFixed(1) : '—', ' m/s'),
              const SizedBox(width: 16),
              _directKpiCell('Cảnh báo', alarmCount.toString(), '', isAlarm: alarmCount > 0),
            ],
          ),

          // Right Segment: Data source states
          Row(
            children: [
              _sourceStateChip('ĐG1 · Windey', provider.windConnected, windAgeLabel),
              const SizedBox(width: 8),
              _sourceStateChip('ĐG2 · Vestas', provider.vestasConnected, vestasAgeLabel),
              const SizedBox(width: 12),
              Text(
                nowText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textStrong,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _directKpiCell(String label, String value, String unit, {bool isAlarm = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8.5,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isAlarm
                    ? AppTheme.error
                    : (label.contains('suất') ? AppTheme.primary : AppTheme.textStrong),
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 1),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _sourceStateChip(String label, bool connected, String suffix) {
    final statusColor = connected ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textStrong,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            connected ? suffix.toUpperCase() : 'CHỜ DỮ LIỆU',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectFooter({
    required int runningCount,
    required int standbyCount,
    required int offlineCount,
    required int delayedCount,
  }) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _footerLegendItem(AppTheme.success, 'Phát điện', runningCount),
          const SizedBox(width: 16),
          _footerLegendItem(AppTheme.primary, 'Dừng / chờ', standbyCount),
          const SizedBox(width: 16),
          _footerLegendItem(AppTheme.dim, 'Mất dữ liệu / sự cố', offlineCount),
          if (delayedCount > 0) ...[
            const SizedBox(width: 16),
            _footerLegendItem(AppTheme.warning, 'Tín hiệu chậm', delayedCount),
          ],
          const Spacer(),
          const Icon(Icons.bolt_rounded, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          const Text(
            'Chọn một trụ để xem chi tiết và dự báo 24 giờ',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerLegendItem(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textStrong,
          ),
        ),
      ],
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

  Widget _turbineCard(Map<String, dynamic> t, {bool compactLayout = false}) {
    final status = t['status'] as String;
    final stateLabel = t['stateLabel'] as String;
    final power = (t['power'] as num).toDouble();
    final wind = (t['wind'] as num).toDouble();
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
              AppTheme.warning.withValues(alpha: 0.08),
              AppTheme.surface,
            )
          : AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: signalDelayed
              ? AppTheme.warning.withValues(alpha: 0.72)
              : AppTheme.border,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            // Top segment
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
                          fontSize: 12,
                          color: AppTheme.textStrong,
                        ),
                      ),
                      Text(
                        t['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      displayStateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Middle segment
            Row(
              children: [
                SpinningTurbineIcon(
                  rotorRpm: rotorRpm,
                  status: status,
                  signalDelayed: signalDelayed,
                ),
                const SizedBox(width: 8),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 1),
                          const Text(
                            'kW',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.air_rounded,
                            size: 10,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            ScadaHelpers.formatTelemetry(wind, unit: 'm/s'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Bottom parameters readouts
            if (!compactLayout)
              Expanded(
                child: GridView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3,
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
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniHorizontalReadout('Gió', ScadaHelpers.formatTelemetry(wind, unit: 'm/s')),
                  _miniHorizontalReadout('Pitch', ScadaHelpers.formatTelemetry(pitch, unit: '°')),
                  _miniHorizontalReadout('Temp', ScadaHelpers.formatTelemetry(tmpAmb, unit: '°C')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniHorizontalReadout(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _miniReadout(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  double _calcCircularMean(List<double?> angles) {
    double sinSum = 0;
    double cosSum = 0;
    int count = 0;
    for (final angle in angles) {
      if (angle != null && angle.isFinite) {
        final rad = angle * pi / 180.0;
        sinSum += sin(rad);
        cosSum += cos(rad);
        count++;
      }
    }
    if (count == 0) return double.nan;
    final avgRad = atan2(sinSum / count, cosSum / count);
    final avgDeg = avgRad * 180.0 / pi;
    return (avgDeg + 360.0) % 360.0;
  }

  String _getCompassLabel(double? deg) {
    if (deg == null || !deg.isFinite) return '—';
    const sectors = ['B', 'ĐB', 'Đ', 'ĐN', 'N', 'TN', 'T', 'TB'];
    final idx = ((deg + 22.5) % 360 / 45).floor();
    return sectors[idx];
  }

  Widget _mobileInfoText(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
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
}

class CompactTurbineCardAll extends StatefulWidget {
  final Map<String, dynamic> turbine;

  const CompactTurbineCardAll({super.key, required this.turbine});

  @override
  State<CompactTurbineCardAll> createState() => _CompactTurbineCardAllState();
}

class _CompactTurbineCardAllState extends State<CompactTurbineCardAll> {
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
              AppTheme.warning.withValues(alpha: 0.08),
              AppTheme.surface,
            )
          : AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: signalDelayed
              ? AppTheme.warning.withValues(alpha: 0.72)
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
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
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
                if (_isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 10),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.8,
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
                        ScadaHelpers.formatTelemetry(
                          ScadaHelpers.telemetryNumber(t, 'yawErr'),
                          unit: '°',
                        ),
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
          style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 2),
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
