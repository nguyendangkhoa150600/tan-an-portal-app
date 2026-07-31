import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../../../providers/scada_provider.dart';
import 'all_turbines_screen.dart';

class RealtimeTurbineTable extends StatelessWidget {
  const RealtimeTurbineTable({super.key});

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
                Flexible(
                  child: Text(
                    isMobile
                        ? 'Dữ liệu thời gian thực'
                        : 'Dữ liệu thời gian thực · 24 tua-bin',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ĐG1 ~5s · ĐG2 RAM ~5s',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: isMobile
                  ? const {
                      0: FlexColumnWidth(1.2),
                      1: FlexColumnWidth(1.2),
                      2: FlexColumnWidth(1.0),
                      3: FlexColumnWidth(1.5),
                    }
                  : const {
                      0: FlexColumnWidth(1.5),
                      1: FlexColumnWidth(1.0),
                      2: FlexColumnWidth(1.2),
                      3: FlexColumnWidth(1.2),
                      4: FlexColumnWidth(1.5),
                    },
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: AppTheme.border.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              children: [
                // Header Row
                TableRow(
                  decoration: const BoxDecoration(color: AppTheme.panel2),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      child: Text(
                        'Tua-bin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (!isMobile)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 10,
                        ),
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
                      padding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      child: Text(
                        'Công suất (kW)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      child: Text(
                        'Gió (m/s)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      child: Text(
                        'Trạng thái',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                // Data Rows (take first 6)
                ...fleet.take(6).map((t) {
                  final isDG2 = t.containsKey('serial');
                  final String parkLabel = isDG2 ? 'ĐG2' : 'ĐG1';
                  final double power = (t['power'] as num).toDouble();
                  final double wind = (t['wind'] as num).toDouble();
                  final status = t['status'] as String? ?? 'offline';
                  final stateLabel =
                      t['stateLabel'] as String? ?? 'Mất kết nối';

                  Color statusColor = AppTheme.success;
                  if (status == 'standby') statusColor = AppTheme.primary;
                  if (status == 'offline') statusColor = AppTheme.dim;
                  if (status == 'alarm') statusColor = AppTheme.error;

                  return TableRow(
                    children: [
                      TableCell(
                        child: InkWell(
                          onTap: () {
                            provider.windPark = isDG2 ? 'dg2' : 'dg1';
                            provider.activeView = 'wind';
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['name'] as String? ?? 'Mất kết nối',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                if (isMobile) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    parkLabel,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isMobile)
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 10,
                            ),
                            child: Text(
                              parkLabel,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 10,
                          ),
                          child: Text(
                            ScadaHelpers.formatTelemetry(
                              power,
                              fractionDigits: 0,
                            ),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 10,
                          ),
                          child: Text(
                            ScadaHelpers.formatTelemetry(wind),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 10,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                stateLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllTurbinesScreen(fleet: fleet),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppTheme.primary,
                ),
                label: const Text(
                  'Hiển thị tất cả 24 tua-bin',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
