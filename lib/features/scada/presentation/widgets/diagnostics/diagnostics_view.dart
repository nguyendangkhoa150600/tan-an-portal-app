import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../../providers/scada_provider.dart';

class DiagnosticsView extends StatelessWidget {
  const DiagnosticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final health = provider.health;
    final dbStatus = health['database'] ?? 'ok';
    final persistStatus = health['persistence'] ?? 'ok';

    final dg1Turbines = provider.dg1Turbines;
    final dg2Turbines = provider.dg2Turbines;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    // Calculate status counts
    int okCount = 0;
    int infoCount = 0;
    int warnCount = 0;
    int alarmCount = 0;

    for (var t in dg1Turbines) {
      final status = t['status'] as String;
      if (status == 'running') okCount++;
      if (status == 'standby') infoCount++;
      if (status == 'offline') warnCount++;
      if (status == 'alarm') alarmCount++;
    }
    for (var t in dg2Turbines) {
      final status = t['status'] as String;
      if (status == 'running') okCount++;
      if (status == 'standby') infoCount++;
      if (status == 'offline') warnCount++;
      if (status == 'alarm') alarmCount++;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // 1. KPI grid
          if (isMobile) ...[
            Column(
              children: [
                Row(
                  children: [
                    _summaryCard(
                      'Bình thường',
                      '$okCount',
                      'tuabin đang phát',
                      AppTheme.success,
                    ),
                    const SizedBox(width: 12),
                    _summaryCard(
                      'Theo dõi',
                      '$infoCount',
                      'lệch nhẹ so với cụm',
                      AppTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _summaryCard(
                      'Cảnh báo sớm',
                      '$warnCount',
                      'khuyến nghị kiểm tra',
                      AppTheme.warning,
                    ),
                    const SizedBox(width: 12),
                    _summaryCard(
                      'Sự cố',
                      '$alarmCount',
                      'đang có mã lỗi',
                      AppTheme.error,
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                _summaryCard(
                  'Bình thường',
                  '$okCount',
                  'tuabin đang phát',
                  AppTheme.success,
                ),
                const SizedBox(width: 16),
                _summaryCard(
                  'Theo dõi',
                  '$infoCount',
                  'lệch nhẹ so với cụm',
                  AppTheme.primary,
                ),
                const SizedBox(width: 16),
                _summaryCard(
                  'Cảnh báo sớm',
                  '$warnCount',
                  'khuyến nghị kiểm tra',
                  AppTheme.warning,
                ),
                const SizedBox(width: 16),
                _summaryCard(
                  'Sự cố',
                  '$alarmCount',
                  'đang có mã lỗi',
                  AppTheme.error,
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          // 2. Database & Infrastructure status
          Card(
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.dns_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Trạng thái hạ tầng & Cơ sở dữ liệu',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textStrong,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isMobile) ...[
                    _infraStatusRow(
                      label: 'Cơ sở dữ liệu SCADA',
                      status: dbStatus == 'ok' ? 'Bình thường' : 'Suy giảm',
                      details: dbStatus == 'ok'
                          ? 'TimescaleDB tốt'
                          : 'Mất kết nối',
                      color: dbStatus == 'ok'
                          ? AppTheme.success
                          : AppTheme.error,
                    ),
                    const SizedBox(height: 12),
                    _infraStatusRow(
                      label: 'Hàng đợi ghi lịch sử',
                      status: persistStatus == 'ok'
                          ? 'Đã đồng bộ'
                          : 'Độ trễ cao',
                      details: persistStatus == 'ok'
                          ? 'Ghi liên tục vĩnh viễn'
                          : 'Đang nghẽn bộ đệm',
                      color: persistStatus == 'ok'
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                    const SizedBox(height: 12),
                    _infraStatusRow(
                      label: 'Độ trễ Điện gió 1 (Windey)',
                      status: provider.windAgeSeconds == null
                          ? 'Không có dữ liệu'
                          : '${provider.windAgeSeconds} giây',
                      details: provider.windConnected
                          ? 'Nguồn realtime hoạt động'
                          : 'Nguồn realtime chưa sẵn sàng',
                      color: provider.windConnected
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                    const SizedBox(height: 12),
                    _infraStatusRow(
                      label: 'Độ trễ Điện gió 2 (Vestas)',
                      status: provider.vestasAgeSeconds == null
                          ? 'Không có dữ liệu'
                          : '${provider.vestasAgeSeconds} giây',
                      details: provider.vestasConnected
                          ? 'Nguồn realtime hoạt động'
                          : 'Nguồn realtime chưa sẵn sàng',
                      color: provider.vestasConnected
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _infraStatusRow(
                            label: 'Cơ sở dữ liệu SCADA',
                            status: dbStatus == 'ok'
                                ? 'Bình thường'
                                : 'Suy giảm',
                            details: dbStatus == 'ok'
                                ? 'TimescaleDB hoạt động tốt'
                                : 'Mất kết nối tạm thời',
                            color: dbStatus == 'ok'
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _infraStatusRow(
                            label: 'Hàng đợi ghi lịch sử',
                            status: persistStatus == 'ok'
                                ? 'Đã đồng bộ'
                                : 'Độ trễ cao',
                            details: persistStatus == 'ok'
                                ? 'Ghi liên tục vĩnh viễn'
                                : 'Đang nghẽn bộ nhớ đệm',
                            color: persistStatus == 'ok'
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _infraStatusRow(
                            label: 'Độ trễ Điện gió 1 (Windey)',
                            status: provider.windAgeSeconds == null
                                ? 'Không có dữ liệu'
                                : '${provider.windAgeSeconds} giây',
                            details: provider.windConnected
                                ? 'Nguồn realtime hoạt động'
                                : 'Nguồn realtime chưa sẵn sàng',
                            color: provider.windConnected
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _infraStatusRow(
                            label: 'Độ trễ Điện gió 2 (Vestas)',
                            status: provider.vestasAgeSeconds == null
                                ? 'Không có dữ liệu'
                                : '${provider.vestasAgeSeconds} giây',
                            details: provider.vestasConnected
                                ? 'Nguồn realtime hoạt động'
                                : 'Nguồn realtime chưa sẵn sàng',
                            color: provider.vestasConnected
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Turbine CBM Anomaly details table
          Card(
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đánh giá hiệu suất tuabin & CBM',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textStrong,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _turbineCbmTable(
                    isMobile,
                    'Điện gió 1 (Windey)',
                    dg1Turbines,
                  ),
                  const SizedBox(height: 24),
                  _turbineCbmTable(
                    isMobile,
                    'Điện gió 2 (Vestas)',
                    dg2Turbines,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, String sub, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infraStatusRow({
    required String label,
    required String status,
    required String details,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$status · $details',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _turbineCbmTable(
    bool isMobile,
    String title,
    List<Map<String, dynamic>> turbines,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: isMobile
              ? const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1.0),
                  2: FlexColumnWidth(1.0),
                  3: FlexColumnWidth(1.2),
                }
              : const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1.0),
                  2: FlexColumnWidth(1.0),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(1.5),
                },
          border: TableBorder.all(
            color: AppTheme.border,
            width: 1,
            borderRadius: BorderRadius.circular(4),
          ),
          children: [
            // Table Header
            TableRow(
              decoration: const BoxDecoration(color: AppTheme.panel2),
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Tuabin',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                if (!isMobile)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
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
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'P (kW)',
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
                    'Lệch (%)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                if (!isMobile)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Đánh giá',
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
                    'CBM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            // Table Data rows
            ...turbines.map((t) {
              final status = t['status'] as String;
              final power = (t['power'] as num).toDouble();
              final wind = (t['wind'] as num).toDouble();

              final expected = (t['possibleKw'] as num?)?.toDouble();
              final diffPct = power.isFinite && expected != null && expected > 0
                  ? ((power - expected) / expected) * 100
                  : null;

              String verdict = expected == null
                  ? 'Chưa có chuẩn'
                  : 'Bám đường CS';
              Color verdictColor = AppTheme.textPrimary;
              String cbm = 'Bình thường';
              Color cbmColor = AppTheme.success;

              if (status == 'offline') {
                verdict = 'Dừng máy';
                verdictColor = AppTheme.textSecondary;
                cbm = 'Theo dõi';
                cbmColor = AppTheme.dim;
              } else if (status == 'alarm') {
                verdict = 'Sự cố';
                verdictColor = AppTheme.error;
                cbm = 'Cảnh báo';
                cbmColor = AppTheme.error;
              } else if (diffPct != null && diffPct < -10) {
                verdict = 'Phát thấp';
                verdictColor = AppTheme.warning;
                cbm = 'Theo dõi';
                cbmColor = AppTheme.warning;
              }

              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      t['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (!isMobile)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        ScadaHelpers.formatTelemetry(wind),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      ScadaHelpers.formatTelemetry(power, fractionDigits: 0),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      status == 'running' && diffPct != null
                          ? '${diffPct >= 0 ? "+" : ""}${diffPct.toStringAsFixed(0)}%'
                          : 'Mất kết nối',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            status == 'running' &&
                                diffPct != null &&
                                diffPct < -10
                            ? AppTheme.warning
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isMobile)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        verdict,
                        style: TextStyle(
                          fontSize: 11,
                          color: verdictColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      cbm,
                      style: TextStyle(
                        fontSize: 11,
                        color: cbmColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}
