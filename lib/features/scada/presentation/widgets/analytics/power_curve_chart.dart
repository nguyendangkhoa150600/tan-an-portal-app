import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';

import '../../providers/scada_provider.dart';

class PowerCurveChart extends StatelessWidget {
  const PowerCurveChart({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final turbines = [...provider.dg1Turbines, ...provider.dg2Turbines]
        .where(
          (item) =>
              item['signalDelayed'] != true &&
              item['wind'] is num &&
              (item['wind'] as num).isFinite &&
              item['power'] is num &&
              (item['power'] as num).isFinite,
        )
        .toList();

    if (turbines.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1.7,
        child: Center(
          child: Text(
            'Chưa có dữ liệu turbine realtime',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final spots = turbines
        .map(
          (item) => FlSpot(
            (item['wind'] as num).toDouble(),
            max(0, (item['power'] as num).toDouble()),
          ),
        )
        .toList();
    final maxWind = spots.map((spot) => spot.x).reduce(max);
    final maxPower = spots.map((spot) => spot.y).reduce(max);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return AspectRatio(
      aspectRatio: isMobile ? 1.2 : 1.7,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: const FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              axisNameWidget: Text('Tốc độ gió (m/s)'),
              sideTitles: SideTitles(showTitles: true, reservedSize: 30),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text('Công suất (kW)'),
              sideTitles: SideTitles(showTitles: true, reservedSize: 48),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: AppTheme.border),
          ),
          minX: 0,
          maxX: max(1, maxWind * 1.1),
          minY: 0,
          maxY: max(1, maxPower * 1.1),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: Colors.transparent,
              barWidth: 0,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final status = turbines[index]['status']?.toString();
                  final color = switch (status) {
                    'running' => AppTheme.success,
                    'alarm' => AppTheme.error,
                    'standby' => AppTheme.warning,
                    _ => AppTheme.inactive,
                  };
                  return FlDotCirclePainter(
                    radius: 5,
                    color: color,
                    strokeColor: Colors.white,
                    strokeWidth: 1.5,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
