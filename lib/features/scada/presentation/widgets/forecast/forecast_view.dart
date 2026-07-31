import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';

import '../../providers/scada_provider.dart';

class ForecastView extends StatelessWidget {
  const ForecastView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final hours = provider.forecastHours;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dự báo thời tiết & công suất điện gió',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tải lại',
                onPressed: provider.refreshForecast,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hours.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text(
                  provider.lastError ?? 'Chưa có dữ liệu dự báo',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            Card(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double tableWidth = max(480.0, constraints.maxWidth);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: hours.length + 1,
                        separatorBuilder: (_, _) =>
                            const Divider(color: AppTheme.border, height: 1),
                        itemBuilder: (context, index) {
                          if (index == 0) return const _ForecastHeader();
                          return _ForecastRow(data: hours[index - 1]);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ForecastHeader extends StatelessWidget {
  const _ForecastHeader();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        Expanded(flex: 10, child: Text('Thời gian')),
        Expanded(flex: 6, child: Text('Gió')),
        Expanded(flex: 5, child: Text('Hướng')),
        Expanded(flex: 11, child: Text('CS dự kiến')),
        Expanded(flex: 8, child: Text('Tin cậy')),
      ],
    ),
  );
}

class _ForecastRow extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ForecastRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final timeMs = (data['timeMs'] as num?)?.toInt();
    final hour = (data['hour'] as num?)?.toInt();
    final time = timeMs != null
        ? DateFormat(
            'dd/MM HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(timeMs))
        : hour != null
        ? '${hour.toString().padLeft(2, '0')}:00'
        : '—';
    final wind = (data['windMs'] ?? data['meanWindMs']) as num?;
    final direction = data['directionDeg'] as num?;
    final power = (data['totalKw'] ?? data['expectedKw']) as num?;
    final trusted =
        data['trusted'] == true ||
        data['confidence'] == 'high' ||
        data['confidence'] == 'medium';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 10, child: Text(time)),
          Expanded(
            flex: 6,
            child: Text(
              ScadaHelpers.formatTelemetry(wind?.toDouble(), unit: 'm/s'),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              ScadaHelpers.formatTelemetry(
                direction?.toDouble(),
                fractionDigits: 0,
                unit: '°',
              ),
            ),
          ),
          Expanded(
            flex: 11,
            child: Text(
              ScadaHelpers.formatTelemetry(
                power == null ? null : power / 1000,
                unit: 'MW',
              ),
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(
              trusted ? 'Có dữ liệu' : 'Tham khảo',
              style: TextStyle(
                color: trusted ? AppTheme.success : AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
