import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../../../providers/scada_provider.dart';

class ProductionChartsSection extends StatelessWidget {
  const ProductionChartsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    final double todayYieldKwh = provider.todayHourlyBuckets.isEmpty
        ? double.nan
        : provider.todayHourlyBuckets.fold<double>(
            0.0,
            (sum, b) => sum + (b['energyKwh'] as num).toDouble(),
          );

    if (isMobile) {
      return Column(
        children: [
          _buildPowerTrendCard(provider),
          const SizedBox(height: 12),
          _buildHourlyYieldCard(provider, todayYieldKwh),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: _buildPowerTrendCard(provider)),
          const SizedBox(width: 12),
          Expanded(child: _buildHourlyYieldCard(provider, todayYieldKwh)),
        ],
      );
    }
  }

  Widget _buildPowerTrendCard(ScadaProvider provider) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Xu hướng công suất · 24 giờ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  provider.trendPoints.isEmpty
                      ? 'Mất kết nối'
                      : ScadaHelpers.formatTelemetry(
                          provider.trendPoints
                                  .map(
                                    (point) =>
                                        (point['totalKw'] as num?)?.toDouble(),
                                  )
                                  .whereType<double>()
                                  .where((value) => value.isFinite)
                                  .fold<double>(
                                    0,
                                    (peak, value) =>
                                        value > peak ? value : peak,
                                  ) /
                              1000,
                          unit: 'MW',
                        ),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20000,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 6,
                        getTitlesWidget: (value, meta) {
                          final hour = (value.toInt() % 24);
                          return Text(
                            '${hour.toString().padLeft(2, '0')}h',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 20000,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value / 1000).toStringAsFixed(0)}M',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: 85000,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getTrendSpots(provider.trendPoints, 'windmmcs'),
                      color: AppTheme.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      isCurved: true,
                    ),
                    LineChartBarData(
                      spots: _getTrendSpots(provider.trendPoints, 'vestas'),
                      color: Colors.blueAccent,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      isCurved: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _chartLegendItem(AppTheme.primary, 'Điện gió 1 (Windey)'),
                const SizedBox(width: 20),
                _chartLegendItem(Colors.blueAccent, 'Điện gió 2 (Vestas)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyYieldCard(ScadaProvider provider, double todayYieldKwh) {
    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Sản lượng theo giờ · hôm nay',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ScadaHelpers.formatTelemetry(
                    todayYieldKwh / 1000,
                    unit: 'MWh',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final val = value.toInt();
                          if (val % 4 == 0) {
                            return Text(
                              '${val.toString().padLeft(2, '0')}h',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 9,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value / 1000).toStringAsFixed(1)}M',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: provider.todayHourlyBuckets.map((b) {
                    final h = b['bucket'] as int;
                    final energy = (b['energyKwh'] as num).toDouble();
                    return BarChartGroupData(
                      x: h,
                      barRods: [
                        BarChartRodData(
                          toY: energy,
                          color: AppTheme.primary,
                          width: 6,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Sản lượng tích luỹ mỗi giờ phát (MWh)',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _getTrendSpots(
    List<Map<String, dynamic>> trend,
    String parkCode,
  ) {
    final List<FlSpot> spots = [];
    final parkPoints = trend.where((p) => p['parkCode'] == parkCode).toList();
    for (int i = 0; i < parkPoints.length; i++) {
      final double power = (parkPoints[i]['powerKw'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), power));
    }
    return spots;
  }
}
