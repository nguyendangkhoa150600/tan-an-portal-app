import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../../../providers/scada_provider.dart';

class FactoryPerformanceCard extends StatelessWidget {
  const FactoryPerformanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final dg1Turbines = provider.dg1Turbines;
    final dg2Turbines = provider.dg2Turbines;

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

    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theo nhà máy',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textStrong,
              ),
            ),
            const SizedBox(height: 12),
            _parkCard(
              title: 'Điện gió 1 · Windey',
              powerKw: dg1PowerKw,
              ratedCapacityKw: 7 * 4200.0,
              windAvg: dg1WindAvg,
              runningCount: dg1Live
                  .where((t) => t['status'] == 'running')
                  .length,
              totalCount: 7,
              onTap: () {
                provider.windPark = 'dg1';
                provider.activeView = 'wind';
              },
            ),
            const SizedBox(height: 10),
            _parkCard(
              title: 'Điện gió 2 · Vestas',
              powerKw: dg2PowerKw,
              ratedCapacityKw: 17 * 4000.0,
              windAvg: dg2WindAvg,
              runningCount: dg2Live
                  .where((t) => t['status'] == 'running')
                  .length,
              totalCount: 17,
              onTap: () {
                provider.windPark = 'dg2';
                provider.activeView = 'wind';
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _parkCard({
    required String title,
    required double powerKw,
    required double ratedCapacityKw,
    required double windAvg,
    required int runningCount,
    required int totalCount,
    required VoidCallback onTap,
  }) {
    final double pct = powerKw.isFinite && ratedCapacityKw > 0
        ? (powerKw / ratedCapacityKw)
        : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.panel2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                Text(
                  '$runningCount / $totalCount phát',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ScadaHelpers.formatTelemetry(powerKw / 1000, unit: 'MW')} / ${(ratedCapacityKw / 1000).toStringAsFixed(0)} MW',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textStrong,
                  ),
                ),
                Text(
                  'Gió: ${ScadaHelpers.formatTelemetry(windAvg, unit: 'm/s')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                backgroundColor: AppTheme.background,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primary,
                ),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
