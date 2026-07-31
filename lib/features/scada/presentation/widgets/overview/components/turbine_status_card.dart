import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import '../../../providers/scada_provider.dart';
import 'donut_chart_painter.dart';

class TurbineStatusCard extends StatelessWidget {
  const TurbineStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final dg1Turbines = provider.dg1Turbines;
    final dg2Turbines = provider.dg2Turbines;

    // Merge turbines list
    final List<Map<String, dynamic>> fleet = [];
    fleet.addAll(dg1Turbines);
    fleet.addAll(dg2Turbines);

    final List<Map<String, dynamic>> liveFleet = fleet
        .where((t) => !(t['signalDelayed'] as bool? ?? false))
        .toList();
    final int delayedCount = fleet.length - liveFleet.length;

    // Calculate status counts
    int runningCount = 0;
    int standbyCount = 0;
    int offlineCount = 0;
    int alarmCount = 0;

    for (final t in liveFleet) {
      final status = t['status'] as String? ?? 'offline';
      if (status == 'running') {
        runningCount++;
      } else if (status == 'standby') {
        standbyCount++;
      } else if (status == 'offline') {
        offlineCount++;
      } else if (status == 'alarm') {
        alarmCount++;
      }
    }

    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trạng thái thiết bị',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textStrong,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: DonutChartPainter(
                            running: runningCount,
                            standby: standbyCount,
                            offline: offlineCount,
                            alarm: alarmCount,
                            delayed: delayedCount,
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${fleet.length}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textStrong,
                              ),
                            ),
                            const Text(
                              'tua-bin',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendItem(
                        AppTheme.success,
                        'Đang phát',
                        '$runningCount',
                      ),
                      const SizedBox(height: 4),
                      _legendItem(
                        AppTheme.primary,
                        'Chờ / khác',
                        '$standbyCount',
                      ),
                      const SizedBox(height: 4),
                      _legendItem(
                        AppTheme.dim,
                        'Dừng / mất KN',
                        '$offlineCount',
                      ),
                      const SizedBox(height: 4),
                      _legendItem(
                        AppTheme.error,
                        'Cảnh báo',
                        '$alarmCount',
                      ),
                      if (delayedCount > 0) ...[
                        const SizedBox(height: 4),
                        _legendItem(
                          AppTheme.warning,
                          'Tín hiệu chậm',
                          '$delayedCount',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, String count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          count,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
