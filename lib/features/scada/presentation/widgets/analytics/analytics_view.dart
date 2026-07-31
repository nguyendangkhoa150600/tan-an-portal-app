import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../../providers/scada_provider.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final granularity = provider.analyticsGranularity;
    final anchor = provider.analyticsAnchor;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    final firstHistoryDay =
        provider.analyticsRange['firstDay']?.toString() ?? 'Mất kết nối';
    final lastHistoryDay =
        provider.analyticsRange['lastDay']?.toString() ?? 'Mất kết nối';

    // Yield Calculations depending on granularity
    final List<Map<String, dynamic>> chartBuckets = granularity == 'day'
        ? provider.todayHourlyBuckets
        : provider.todayMonthlyBuckets;

    final double totalYieldKwh = chartBuckets.isEmpty
        ? double.nan
        : chartBuckets.fold<double>(
            0.0,
            (s, b) => s + (b['energyKwh'] as num).toDouble(),
          );

    final overview = provider.analyticsOverview;
    final total = overview?['total'] is Map
        ? Map<String, dynamic>.from(overview!['total'] as Map)
        : const <String, dynamic>{};
    final parks = overview?['parks'] is List
        ? (overview!['parks'] as List).whereType<Map>()
        : const <Map>[];
    Map<dynamic, dynamic> parkByCode(String code) => parks.firstWhere(
      (park) => park['code'] == code,
      orElse: () => const <dynamic, dynamic>{},
    );
    final windPark1 = parkByCode('windmmcs');
    final windPark2 = parkByCode('vestas');
    double parkValue(Map<dynamic, dynamic> park, String key) =>
        (park[key] as num?)?.toDouble() ?? double.nan;
    final capacityFactor =
        (total['capacityFactor'] as num?)?.toDouble() ?? double.nan;
    final fullLoadHours =
        (total['fullLoadHours'] as num?)?.toDouble() ?? double.nan;
    final peakKw = (total['peakKw'] as num?)?.toDouble() ?? double.nan;
    final meanKw = (total['meanKw'] as num?)?.toDouble() ?? double.nan;
    final windValues = parks
        .map((park) => park['meanWindMs'])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();
    final avgWind = windValues.isEmpty
        ? double.nan
        : windValues.reduce((a, b) => a + b) / windValues.length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // 1. Controls Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: isMobile
                ? Column(
                    children: [
                      // Granularity selection centered
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _granularityButton(
                              label: 'Theo ngày',
                              isActive: granularity == 'day',
                              onTap: () =>
                                  provider.analyticsGranularity = 'day',
                            ),
                            _granularityButton(
                              label: 'Theo tháng',
                              isActive: granularity == 'month',
                              onTap: () =>
                                  provider.analyticsGranularity = 'month',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Date Picker buttons row centered
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (granularity == 'day') {
                                provider.analyticsAnchor = anchor.subtract(
                                  const Duration(days: 1),
                                );
                              } else {
                                provider.analyticsAnchor = DateTime(
                                  anchor.year,
                                  anchor.month - 1,
                                  1,
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 20,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: anchor,
                                firstDate: DateTime(2025, 1, 1),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppTheme.primary,
                                        surface: AppTheme.surface,
                                        onSurface: AppTheme.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                provider.analyticsAnchor = picked;
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  granularity == 'day'
                                      ? DateFormat('dd/MM').format(anchor)
                                      : DateFormat('MM/yyyy').format(anchor),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textStrong,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed:
                                anchor.isBefore(
                                  DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                                )
                                ? () {
                                    if (granularity == 'day') {
                                      provider.analyticsAnchor = anchor.add(
                                        const Duration(days: 1),
                                      );
                                    } else {
                                      provider.analyticsAnchor = DateTime(
                                        anchor.year,
                                        anchor.month + 1,
                                        1,
                                      );
                                    }
                                  }
                                : null,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.history_toggle_off_rounded,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Lịch sử: $firstHistoryDay → $lastHistoryDay',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Select Granularity
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            _granularityButton(
                              label: 'Theo ngày',
                              isActive: granularity == 'day',
                              onTap: () =>
                                  provider.analyticsGranularity = 'day',
                            ),
                            _granularityButton(
                              label: 'Theo tháng',
                              isActive: granularity == 'month',
                              onTap: () =>
                                  provider.analyticsGranularity = 'month',
                            ),
                          ],
                        ),
                      ),

                      // Center: Date Picker buttons
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (granularity == 'day') {
                                provider.analyticsAnchor = anchor.subtract(
                                  const Duration(days: 1),
                                );
                              } else {
                                provider.analyticsAnchor = DateTime(
                                  anchor.year,
                                  anchor.month - 1,
                                  1,
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 20,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: anchor,
                                firstDate: DateTime(2025, 1, 1),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: AppTheme.primary,
                                        surface: AppTheme.surface,
                                        onSurface: AppTheme.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                provider.analyticsAnchor = picked;
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  granularity == 'day'
                                      ? DateFormat('dd/MM/yyyy').format(anchor)
                                      : DateFormat('MM/yyyy').format(anchor),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textStrong,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed:
                                anchor.isBefore(
                                  DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                                )
                                ? () {
                                    if (granularity == 'day') {
                                      provider.analyticsAnchor = anchor.add(
                                        const Duration(days: 1),
                                      );
                                    } else {
                                      provider.analyticsAnchor = DateTime(
                                        anchor.year,
                                        anchor.month + 1,
                                        1,
                                      );
                                    }
                                  }
                                : null,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),

                      // Right: History range notes
                      Row(
                        children: [
                          const Icon(
                            Icons.history_toggle_off_rounded,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Lịch sử: $firstHistoryDay → $lastHistoryDay',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // 2. Metrics Row
          if (isMobile) ...[
            Row(
              children: [
                _metricCard(
                  icon: Icons.bolt_rounded,
                  title: 'Sản lượng',
                  value: ScadaHelpers.formatTelemetry(
                    totalYieldKwh / 1000,
                    unit: 'MWh',
                  ),
                  sub: fullLoadHours.isFinite
                      ? '≈ ${fullLoadHours.toStringAsFixed(1)} giờ đầy tải'
                      : 'Mất kết nối',
                ),
                const SizedBox(width: 12),
                _metricCard(
                  icon: Icons.offline_bolt_rounded,
                  title: 'Hệ số công suất',
                  value: ScadaHelpers.formatTelemetry(
                    capacityFactor * 100,
                    unit: '%',
                  ),
                  sub: 'Cos φ',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _metricCard(
                  icon: Icons.trending_up_rounded,
                  title: 'Đỉnh / Trung bình',
                  value: ScadaHelpers.formatTelemetry(
                    peakKw / 1000,
                    unit: 'MW',
                  ),
                  sub: meanKw.isFinite
                      ? 'TB ${(meanKw / 1000).toStringAsFixed(1)} MW'
                      : 'Mất kết nối',
                ),
                const SizedBox(width: 12),
                _metricCard(
                  icon: Icons.air_rounded,
                  title: 'Gió trung bình',
                  value: ScadaHelpers.formatTelemetry(avgWind, unit: 'm/s'),
                  sub: '24/24 giờ có số liệu',
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                _metricCard(
                  icon: Icons.bolt_rounded,
                  title: 'Sản lượng',
                  value: ScadaHelpers.formatTelemetry(
                    totalYieldKwh / 1000,
                    unit: 'MWh',
                  ),
                  sub: fullLoadHours.isFinite
                      ? '≈ ${fullLoadHours.toStringAsFixed(1)} giờ đầy tải'
                      : 'Mất kết nối',
                ),
                const SizedBox(width: 12),
                _metricCard(
                  icon: Icons.offline_bolt_rounded,
                  title: 'Hệ số công suất',
                  value: ScadaHelpers.formatTelemetry(
                    capacityFactor * 100,
                    unit: '%',
                  ),
                  sub: 'Cos φ',
                ),
                const SizedBox(width: 12),
                _metricCard(
                  icon: Icons.trending_up_rounded,
                  title: 'Đỉnh / Trung bình',
                  value: ScadaHelpers.formatTelemetry(
                    peakKw / 1000,
                    unit: 'MW',
                  ),
                  sub: meanKw.isFinite
                      ? 'TB ${(meanKw / 1000).toStringAsFixed(1)} MW'
                      : 'Mất kết nối',
                ),
                const SizedBox(width: 12),
                _metricCard(
                  icon: Icons.air_rounded,
                  title: 'Gió trung bình',
                  value: ScadaHelpers.formatTelemetry(avgWind, unit: 'm/s'),
                  sub: '24/24 giờ có số liệu',
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // 3. Bar Chart Card
          Card(
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sản lượng theo ${granularity == 'day' ? 'giờ' : 'ngày'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textStrong,
                        ),
                      ),
                      Text(
                        ScadaHelpers.formatTelemetry(
                          totalYieldKwh / 1000,
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
                  const SizedBox(height: 20),
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
                                if (granularity == 'day') {
                                  if (val % 4 == 0)
                                    return Text(
                                      '${val}h',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 9,
                                      ),
                                    );
                                } else {
                                  if (val == 1 || val % 5 == 0 || val == 30)
                                    return Text(
                                      '$val',
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
                              reservedSize: 32,
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
                        barGroups: chartBuckets.map((b) {
                          final h = b['bucket'] as int;
                          final energy = (b['energyKwh'] as num).toDouble();
                          return BarChartGroupData(
                            x: h,
                            barRods: [
                              BarChartRodData(
                                toY: energy,
                                color: AppTheme.primary,
                                width: granularity == 'day' ? 6 : 4,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Park Breakdown Table
          Card(
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
                  Table(
                    columnWidths: isMobile
                        ? const {
                            0: FlexColumnWidth(1.5),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(1.0),
                            3: FlexColumnWidth(1.2),
                          }
                        : const {
                            0: FlexColumnWidth(1.5),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(1.0),
                            3: FlexColumnWidth(1.0),
                            4: FlexColumnWidth(1.0),
                            5: FlexColumnWidth(1.0),
                            6: FlexColumnWidth(1.0),
                          },
                    border: TableBorder.all(
                      color: AppTheme.border,
                      width: 1,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: AppTheme.panel2),
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Nhà máy',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Sản lượng (MWh)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'HS công suất',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          if (!isMobile) ...[
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Đỉnh (MW)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'TB (MW)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Giờ đầy tải',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Gió TB (m/s)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Điện gió 1',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              ScadaHelpers.formatTelemetry(
                                parkValue(windPark1, 'energyKwh') / 1000,
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              ScadaHelpers.formatTelemetry(
                                parkValue(windPark1, 'capacityFactor') * 100,
                                unit: '%',
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          if (!isMobile) ...[
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                ScadaHelpers.formatTelemetry(
                                  parkValue(windPark1, 'peakKw') / 1000,
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                ScadaHelpers.formatTelemetry(
                                  parkValue(windPark1, 'meanKw') / 1000,
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                ScadaHelpers.formatTelemetry(
                                  parkValue(windPark1, 'fullLoadHours'),
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              ScadaHelpers.formatTelemetry(
                                parkValue(windPark1, 'meanWindMs'),
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Điện gió 2',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              ScadaHelpers.formatTelemetry(
                                parkValue(windPark2, 'energyKwh') / 1000,
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              ScadaHelpers.formatTelemetry(
                                parkValue(windPark2, 'capacityFactor') * 100,
                                unit: '%',
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          if (!isMobile) ...[
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                ScadaHelpers.formatTelemetry(
                                  parkValue(windPark2, 'peakKw') / 1000,
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                ScadaHelpers.formatTelemetry(
                                  parkValue(windPark2, 'meanKw') / 1000,
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                ScadaHelpers.formatTelemetry(
                                  parkValue(windPark2, 'fullLoadHours'),
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              ScadaHelpers.formatTelemetry(
                                parkValue(windPark2, 'meanWindMs'),
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Parameter summary table
          Card(
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng hợp thông số quan trọng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textStrong,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Table(
                    columnWidths: isMobile
                        ? const {
                            0: FlexColumnWidth(2.0),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(1.0),
                          }
                        : const {
                            0: FlexColumnWidth(2.0),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(1.2),
                            3: FlexColumnWidth(1.2),
                            4: FlexColumnWidth(1.0),
                          },
                    border: TableBorder.all(
                      color: AppTheme.border,
                      width: 1,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: AppTheme.panel2),
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Thông số',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Trung bình',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          if (!isMobile) ...[
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Min',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Max',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Đơn vị',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _paramRow(
                        isMobile,
                        'Công suất · Điện gió 1',
                        ScadaHelpers.formatTelemetry(
                          parkValue(windPark1, 'meanKw') / 1000,
                        ),
                        'Mất kết nối',
                        ScadaHelpers.formatTelemetry(
                          parkValue(windPark1, 'peakKw') / 1000,
                        ),
                        'MW',
                      ),
                      _paramRow(
                        isMobile,
                        'Công suất · Điện gió 2',
                        ScadaHelpers.formatTelemetry(
                          parkValue(windPark2, 'meanKw') / 1000,
                        ),
                        'Mất kết nối',
                        ScadaHelpers.formatTelemetry(
                          parkValue(windPark2, 'peakKw') / 1000,
                        ),
                        'MW',
                      ),
                      _paramRow(
                        isMobile,
                        'Tốc độ gió · Điện gió 1',
                        ScadaHelpers.formatTelemetry(
                          parkValue(windPark1, 'meanWindMs'),
                        ),
                        'Mất kết nối',
                        'Mất kết nối',
                        'm/s',
                      ),
                      _paramRow(
                        isMobile,
                        'Tốc độ gió · Điện gió 2',
                        ScadaHelpers.formatTelemetry(
                          parkValue(windPark2, 'meanWindMs'),
                        ),
                        'Mất kết nối',
                        'Mất kết nối',
                        'm/s',
                      ),
                      _paramRow(
                        isMobile,
                        'Nhiệt độ môi trường · ĐG1',
                        'Mất kết nối',
                        'Mất kết nối',
                        'Mất kết nối',
                        '°C',
                      ),
                      _paramRow(
                        isMobile,
                        'Nhiệt độ môi trường · ĐG2',
                        'Mất kết nối',
                        'Mất kết nối',
                        'Mất kết nối',
                        '°C',
                      ),
                      _paramRow(
                        isMobile,
                        'Tần số lưới · TBA',
                        'Mất kết nối',
                        'Mất kết nối',
                        'Mất kết nối',
                        'Hz',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _granularityButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.panel2 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required String sub,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.textStrong,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 9.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _paramRow(
    bool isMobile,
    String title,
    String avg,
    String min,
    String max,
    String unit,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(avg, style: const TextStyle(fontSize: 11)),
        ),
        if (!isMobile) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(min, style: const TextStyle(fontSize: 11)),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(max, style: const TextStyle(fontSize: 11)),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(unit, style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }
}
