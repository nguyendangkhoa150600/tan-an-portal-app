import 'package:flutter/material.dart';

import 'components/kpi_metrics_grid.dart';
import 'components/turbine_status_card.dart';
import 'components/factory_performance_card.dart';
import 'components/alarm_warnings_card.dart';
import 'components/production_charts_section.dart';
import 'components/realtime_turbine_table.dart';

class OverviewDashboardView extends StatelessWidget {
  const OverviewDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // 1. KPI cards row / grid
          const KpiMetricsGrid(),
          const SizedBox(height: 16),

          // 2. Status & Factory Cards & Alarms row / column
          if (isMobile) ...[
            const TurbineStatusCard(),
            const SizedBox(height: 12),
            const FactoryPerformanceCard(),
            const SizedBox(height: 12),
            const AlarmWarningsCard(),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(flex: 2, child: TurbineStatusCard()),
                SizedBox(width: 12),
                Expanded(flex: 3, child: FactoryPerformanceCard()),
                SizedBox(width: 12),
                Expanded(flex: 3, child: AlarmWarningsCard()),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // 3. Trends & Hourly production charts row
          const ProductionChartsSection(),
          const SizedBox(height: 16),

          // 4. Real-time turbine grid table
          const RealtimeTurbineTable(),
        ],
      ),
    );
  }
}
