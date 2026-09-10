import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../../../providers/scada_provider.dart';
import '../../../../data/models/dispatch_models.dart';
import '../../dispatch/dispatch_lamp_widget.dart';

class KpiMetricsGrid extends StatelessWidget {
  const KpiMetricsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final dg1Turbines = provider.dg1Turbines;
    final dg2Turbines = provider.dg2Turbines;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    // Merge turbines list
    final List<Map<String, dynamic>> fleet = [];
    fleet.addAll(dg1Turbines);
    fleet.addAll(dg2Turbines);

    final List<Map<String, dynamic>> liveFleet = fleet
        .where((t) => !(t['signalDelayed'] as bool? ?? false))
        .toList();

    // Instantaneous Power Calculations (excluding delayed turbines)
    final dg1Live = dg1Turbines
        .where((t) => !(t['signalDelayed'] as bool? ?? false))
        .toList();
    final dg2Live = dg2Turbines
        .where((t) => !(t['signalDelayed'] as bool? ?? false))
        .toList();

    final double dg1PowerKw = dg1Live.isEmpty
        ? double.nan
        : dg1Live.fold<double>(
            0.0,
            (sum, t) => sum + (t['power'] as num).toDouble(),
          );
    final double dg2PowerKw = dg2Live.isEmpty
        ? double.nan
        : dg2Live.fold<double>(
            0.0,
            (sum, t) => sum + (t['power'] as num).toDouble(),
          );
    final double powerNowKw = dg1PowerKw + dg2PowerKw;
    final double ratedKw =
        (7 * 4200.0) + (17 * 4000.0); // 97.4 MW total rated capacity

    // Wind Speed Calculations (excluding delayed turbines)
    final double dg1WindAvg = dg1Live.isNotEmpty
        ? dg1Live.fold<double>(
                0.0,
                (sum, t) => sum + (t['wind'] as num).toDouble(),
              ) /
              dg1Live.length
        : double.nan;
    final double dg2WindAvg = dg2Live.isNotEmpty
        ? dg2Live.fold<double>(
                0.0,
                (sum, t) => sum + (t['wind'] as num).toDouble(),
              ) /
              dg2Live.length
        : double.nan;
    final double windNowAvg = (dg1WindAvg + dg2WindAvg) / 2;

    // Yield Calculations
    final double todayYieldKwh = provider.todayHourlyBuckets.isEmpty
        ? double.nan
        : provider.todayHourlyBuckets.fold<double>(
            0.0,
            (sum, b) => sum + (b['energyKwh'] as num).toDouble(),
          );
    final double yesterdayYieldUpToNowKwh = _calcYesterdayYieldUpToNow(
      provider.yesterdayHourlyBuckets,
    );
    final double yieldDeltaPct = yesterdayYieldUpToNowKwh > 0
        ? ((todayYieldKwh - yesterdayYieldUpToNowKwh) /
                  yesterdayYieldUpToNowKwh) *
              100
        : 0.0;

    // Power Factor & Full Load Hours
    final double capacityFactor = ratedKw > 0 ? (powerNowKw / ratedKw) : 0.0;
    final double fullLoadHours = todayYieldKwh / ratedKw;

    // Warnings list
    final List<Map<String, dynamic>> warnings = [];
    final dbStatus = provider.health['database'];
    final persistStatus = provider.health['persistence'];

    if (dbStatus != 'ok') {
      warnings.add({
        'sev': 'bad',
        'text': 'Cơ sở dữ liệu: $dbStatus',
        'view': 'diagnostics',
      });
    }
    if (persistStatus != 'ok') {
      warnings.add({
        'sev': 'warn',
        'text': 'Ghi lịch sử đang suy giảm',
        'view': 'diagnostics',
      });
    }
    for (var t in fleet) {
      final status = t['status'] as String? ?? 'offline';
      final parkName = t.containsKey('serial') ? 'ĐG2' : 'ĐG1';
      if (status == 'alarm') {
        warnings.add({
          'sev': 'bad',
          'text': '$parkName ${t['name']} · ${t['stateLabel']}',
          'view': 'wind',
        });
      } else if (status == 'offline') {
        warnings.add({
          'sev': 'warn',
          'text': '$parkName ${t['name']} · ${t['stateLabel']}',
          'view': 'wind',
        });
      }
    }

    final int runningCount = liveFleet
        .where((t) => t['status'] == 'running')
        .length;

    final List<Widget> cards = [
      _kpiCard(
        icon: Icons.bolt_rounded,
        title: 'Công suất hiện tại',
        value: ScadaHelpers.formatTelemetry(powerNowKw / 1000, unit: 'MW'),
        subText:
            'định mức ${(ratedKw / 1000).toStringAsFixed(0)} MW · ${ScadaHelpers.formatTelemetry(capacityFactor * 100, fractionDigits: 0, unit: '%')}',
      ),
      _kpiCard(
        icon: Icons.query_stats_rounded,
        title: 'Sản lượng hôm nay',
        value: ScadaHelpers.formatTelemetry(
          todayYieldKwh / 1000,
          unit: 'MWh',
        ),
        subText: yesterdayYieldUpToNowKwh > 0
            ? '${yieldDeltaPct >= 0 ? "+" : ""}${yieldDeltaPct.toStringAsFixed(1)}% so với cùng giờ hôm qua'
            : 'chưa đủ dữ liệu để so sánh',
        subColor: yesterdayYieldUpToNowKwh > 0
            ? (yieldDeltaPct >= 0 ? AppTheme.success : AppTheme.error)
            : AppTheme.textSecondary,
        onTap: () {
          provider.activeView = 'analytics';
        },
      ),
      _kpiCard(
        icon: Icons.speed_rounded,
        title: 'Hệ số công suất',
        value: ScadaHelpers.formatTelemetry(
          capacityFactor * 100,
          unit: '%',
        ),
        subText: fullLoadHours.isFinite
            ? '≈ ${fullLoadHours.toStringAsFixed(1)} giờ đầy tải hôm nay'
            : 'Mất kết nối',
      ),
      _kpiCard(
        icon: Icons.mode_fan_off_rounded,
        title: 'Tua-bin đang chạy',
        value: '$runningCount / ${fleet.length}',
        subText:
            'ĐG1: ${dg1Live.where((t) => t['status'] == 'running').length}/7 · ĐG2: ${dg2Live.where((t) => t['status'] == 'running').length}/17',
      ),
      _kpiCard(
        icon: Icons.air_rounded,
        title: 'Gió trung bình',
        value: ScadaHelpers.formatTelemetry(windNowAvg, unit: 'm/s'),
        subText:
            'ĐG1: ${ScadaHelpers.formatTelemetry(dg1WindAvg, unit: 'm/s')} · ĐG2: ${ScadaHelpers.formatTelemetry(dg2WindAvg, unit: 'm/s')}',
      ),
      _kpiCard(
        icon: Icons.warning_amber_rounded,
        title: 'Cảnh báo',
        value: '${warnings.length} mục',
        subText: 'trụ · tín hiệu · hạ tầng',
        cardColor: warnings.isNotEmpty
            ? AppTheme.error.withValues(alpha: 0.08)
            : null,
      ),
      if (provider.ppcStatuses != null)
        DispatchKpiCard(
          title: 'PPC · TRẠM 110 KV',
          tooltip: 'Trạm 110 kV — Active Power Control Setpoint Enable (chỉ đọc)',
          lamps: provider.ppcStatuses!.map((ppc) => DispatchLampWidget(
            label: ppc.label,
            state: lampState(ppc.on),
          )).toList(),
        ),
      if (provider.dispatchLamps.isNotEmpty)
        DispatchKpiCard(
          title: 'AGC · LỆNH ĐIỀU ĐỘ',
          tooltip: 'Lệnh điều độ đang áp — Windy: EMS AGC (Điện gió 1); Vestas1/Vestas2: MW Setpoint từ EVN (Điện gió 2). Chỉ đọc.',
          lamps: provider.dispatchLamps.map((lamp) => DispatchLampWidget(
            label: lamp.label,
            value: lamp.value,
            state: lamp.state,
          )).toList(),
        ),
    ];

    final int columns = isMobile ? 2 : 4;
    final List<Widget> gridRows = [];

    for (int i = 0; i < cards.length; i += columns) {
      final List<Widget> rowItems = [];
      final int end = min(i + columns, cards.length);

      for (int j = i; j < end; j++) {
        rowItems.add(cards[j]);
      }

      while (rowItems.length < columns) {
        rowItems.add(const Expanded(child: SizedBox()));
      }

      final List<Widget> spacedItems = [];
      for (int k = 0; k < rowItems.length; k++) {
        spacedItems.add(rowItems[k]);
        if (k < rowItems.length - 1) {
          spacedItems.add(const SizedBox(width: 12));
        }
      }

      gridRows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: spacedItems,
      ));
      if (i + columns < cards.length) {
        gridRows.add(const SizedBox(height: 12));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: gridRows,
    );
  }


  Widget _kpiCard({
    required IconData icon,
    required String title,
    required String value,
    required String subText,
    Color? subColor,
    Color? cardColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor ?? AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textStrong,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subText,
                style: TextStyle(
                  fontSize: 9.5,
                  color: subColor ?? AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calcYesterdayYieldUpToNow(
    List<Map<String, dynamic>> yesterdayBuckets,
  ) {
    final currentHour = DateTime.now().hour;
    final currentMinute = DateTime.now().minute;
    double sum = 0;
    for (int h = 0; h < yesterdayBuckets.length; h++) {
      final double val = (yesterdayBuckets[h]['energyKwh'] as num).toDouble();
      if (h < currentHour) {
        sum += val;
      } else if (h == currentHour) {
        sum += val * (currentMinute / 60.0);
      }
    }
    return sum;
  }
}

class DispatchKpiCard extends StatelessWidget {
  final String title;
  final List<Widget> lamps;
  final String tooltip;

  const DispatchKpiCard({
    super.key,
    required this.title,
    required this.lamps,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < lamps.length; i++) ...[
                    lamps[i],
                    if (i < lamps.length - 1) const SizedBox(height: 5),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

