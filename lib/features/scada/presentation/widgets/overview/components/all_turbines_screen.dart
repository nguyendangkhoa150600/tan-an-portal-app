import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../../../providers/scada_provider.dart';

class AllTurbinesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> fleet;

  const AllTurbinesScreen({super.key, required this.fleet});

  @override
  State<AllTurbinesScreen> createState() => _AllTurbinesScreenState();
}

class _AllTurbinesScreenState extends State<AllTurbinesScreen> {
  int _currentPage = 0;
  final int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    final provider = context.watch<ScadaProvider>();

    final List<Map<String, dynamic>> currentFleet = [];
    currentFleet.addAll(provider.dg1Turbines);
    currentFleet.addAll(provider.dg2Turbines);

    final int totalItems = currentFleet.length;
    final int totalPages = (totalItems / _pageSize).ceil();
    final int startIdx = _currentPage * _pageSize;
    final int endIdx = (startIdx + _pageSize).clamp(0, totalItems);

    final pagedFleet = currentFleet.sublist(startIdx, endIdx);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        iconTheme: const IconThemeData(color: AppTheme.textStrong),
        title: const Text(
          'Dữ liệu vận hành thời gian thực',
          style: TextStyle(
            color: AppTheme.textStrong,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppTheme.border, height: 1),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Expanded(
                child: Card(
                  color: AppTheme.surface,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tất cả tua-bin ($totalItems thiết bị)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textStrong,
                                ),
                              ),
                              const Text(
                                'Đơn vị: kW · m/s',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
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
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: AppTheme.panel2,
                                ),
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
                                      'Công suất',
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
                                      'Tốc độ gió',
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
                              ...pagedFleet.map((t) {
                                final isDG2 = t.containsKey('serial');
                                final String parkLabel = isDG2 ? 'ĐG2' : 'ĐG1';
                                final double power = (t['power'] as num)
                                    .toDouble();
                                final double wind = (t['wind'] as num)
                                    .toDouble();
                                final status =
                                    t['status'] as String? ?? 'offline';
                                final stateLabel =
                                    t['stateLabel'] as String? ?? 'Mất kết nối';

                                Color statusColor = AppTheme.success;
                                if (status == 'standby')
                                  statusColor = AppTheme.primary;
                                if (status == 'offline')
                                  statusColor = AppTheme.dim;
                                if (status == 'alarm')
                                  statusColor = AppTheme.error;

                                return TableRow(
                                  children: [
                                    TableCell(
                                      child: InkWell(
                                        onTap: () {
                                          provider.windPark = isDG2
                                              ? 'dg2'
                                              : 'dg1';
                                          provider.activeView = 'wind';
                                          Navigator.pop(context);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 10,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t['name'] as String? ??
                                                    'Mất kết nối',
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
                                                    color:
                                                        AppTheme.textSecondary,
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
                                              color: statusColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: statusColor.withValues(
                                                  alpha: 0.3,
                                                ),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hiển thị ${startIdx + 1}-${endIdx} của $totalItems',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.chevron_left_rounded),
                          color: _currentPage > 0
                              ? AppTheme.primary
                              : AppTheme.textSecondary.withValues(alpha: 0.4),
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentPage + 1} / $totalPages',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textStrong,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.chevron_right_rounded),
                          color: _currentPage < totalPages - 1
                              ? AppTheme.primary
                              : AppTheme.textSecondary.withValues(alpha: 0.4),
                          onPressed: _currentPage < totalPages - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
