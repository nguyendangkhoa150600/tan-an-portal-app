import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import '../providers/scada_provider.dart';

class HeaderBar extends StatefulWidget {
  const HeaderBar({super.key});

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _getViewTitle(String view) {
    switch (view) {
      case 'oneline':
        return 'Sơ đồ nhất thứ trạm 110kV';
      case 'vestas':
        return 'Bảng giám sát tuabin gió Vestas';
      case 'analytics':
        return 'Phân tích & Hiệu suất phát điện';
      case 'forecast':
        return 'Dự báo thời tiết & Tốc độ gió';
      default:
        return 'Hệ thống giám sát SCADA';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final isLive = provider.pollState == 'live';

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Toggle Sidebar and Page Title
          Row(
            children: [
              IconButton(
                onPressed: () {
                  provider.focusMode = !provider.focusMode;
                },
                icon: Icon(
                  provider.focusMode
                      ? Icons.menu_open_rounded
                      : Icons.menu_rounded,
                  color: AppTheme.textPrimary,
                ),
                tooltip: provider.focusMode
                    ? 'Mở thanh điều hướng'
                    : 'Thu gọn thanh điều hướng',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getViewTitle(provider.activeView),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLive
                                ? AppTheme.scadaOpen
                                : AppTheme.scadaClosed,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isLive
                              ? 'LIVE (Thời gian thực)'
                              : 'Mất kết nối nguồn dữ liệu',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isLive
                                ? AppTheme.scadaOpen
                                : AppTheme.scadaClosed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Right: System Clock & Connection Badge
          Row(
            children: [
              // System Time
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm:ss · dd/MM/yyyy').format(_currentTime),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
