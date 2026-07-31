import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import '../../../providers/scada_provider.dart';

class AlarmWarningsCard extends StatelessWidget {
  const AlarmWarningsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final dg1Turbines = provider.dg1Turbines;
    final dg2Turbines = provider.dg2Turbines;

    // Merge turbines list
    final List<Map<String, dynamic>> fleet = [];
    fleet.addAll(dg1Turbines);
    fleet.addAll(dg2Turbines);

    // Compute warnings list
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

    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cảnh báo & sự kiện',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textStrong,
              ),
            ),
            const SizedBox(height: 12),
            if (warnings.isEmpty)
              Container(
                height: 110,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppTheme.success,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Không có cảnh báo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.textStrong,
                          ),
                        ),
                        Text(
                          'Hệ thống hoạt động ổn định',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: min(warnings.length, 3),
                  separatorBuilder: (c, i) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final w = warnings[index];
                    final isBad = w['sev'] == 'bad';
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          provider.activeView = w['view'] as String;
                          if (w['view'] == 'wind') {
                            provider.windPark = w['text'].toString().contains('ĐG2') ? 'dg2' : 'dg1';
                          }
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: isBad ? AppTheme.error : AppTheme.warning,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                w['text'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isBad ? AppTheme.error : AppTheme.warning,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: isBad ? AppTheme.error : AppTheme.warning,
                            ),
                          ],
                        ),
                      ),
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
