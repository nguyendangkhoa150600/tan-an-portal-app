import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import '../providers/scada_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/one_line_diagram/one_line_diagram_view.dart';
import '../widgets/overview/overview_dashboard_view.dart';
import '../widgets/wind/wind_combined_view.dart';
import '../widgets/analytics/analytics_view.dart';
import '../widgets/forecast/forecast_view.dart';
import '../widgets/diagnostics/diagnostics_view.dart';

class ScadaShellScreen extends StatefulWidget {
  const ScadaShellScreen({super.key});

  @override
  State<ScadaShellScreen> createState() => _ScadaShellScreenState();
}

class _ScadaShellScreenState extends State<ScadaShellScreen> {
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

  Widget _buildActiveView(String activeView) {
    switch (activeView) {
      case 'tongquan':
        return const OverviewDashboardView();
      case 'oneline':
        return const OneLineDiagramView();
      case 'wind':
        return const WindCombinedView();
      case 'analytics':
        return const AnalyticsView();
      case 'forecast':
        return const ForecastView();
      case 'diagnostics':
        return const DiagnosticsView();
      default:
        return const OverviewDashboardView();
    }
  }

  String _getViewTitle(String view) {
    switch (view) {
      case 'tongquan':
        return 'Tổng quan vận hành';
      case 'oneline':
        return 'Sơ đồ nhất thứ trạm';
      case 'wind':
        return 'Giám sát Điện gió';
      case 'analytics':
        return 'Phân tích & Hiệu suất';
      case 'forecast':
        return 'Dự báo & Thời tiết';
      case 'diagnostics':
        return 'Chẩn đoán hạ tầng';
      default:
        return 'Hệ thống SCADA';
    }
  }

  Widget _headerSegmentButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.panel2 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required BuildContext context,
    required String id,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.read<ScadaProvider>().activeView = id;
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.textStrong
                        : AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDirectView = kIsWeb && Uri.base.queryParameters['view'] == 'true';
    if (isDirectView) {
      return const Scaffold(
        body: SafeArea(
          child: WindCombinedView(directView: true),
        ),
      );
    }

    final provider = context.watch<ScadaProvider>();
    final isLive = provider.pollState == 'live';
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;
    final bool isSystemActive =
        provider.activeView == 'analytics' ||
        provider.activeView == 'forecast' ||
        provider.activeView == 'diagnostics';

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) const SidebarNavigation(),
            Expanded(
              child: Container(
                color: AppTheme.background,
                child: Column(
                  children: [
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        border: Border(
                          bottom: BorderSide(color: AppTheme.border, width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (!isMobile) ...[
                                  GestureDetector(
                                    onTap: () {
                                      provider.focusMode = !provider.focusMode;
                                    },
                                    child: Icon(
                                      provider.focusMode
                                          ? Icons.menu_rounded
                                          : Icons.menu_open_rounded,
                                      color: AppTheme.textPrimary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (isMobile && isSystemActive) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.background,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppTheme.border,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _headerSegmentButton(
                                          label: 'Phân tích',
                                          isActive:
                                              provider.activeView ==
                                              'analytics',
                                          onTap: () =>
                                              provider.activeView = 'analytics',
                                        ),
                                        _headerSegmentButton(
                                          label: 'Dự báo',
                                          isActive:
                                              provider.activeView == 'forecast',
                                          onTap: () =>
                                              provider.activeView = 'forecast',
                                        ),
                                        _headerSegmentButton(
                                          label: 'Chẩn đoán',
                                          isActive:
                                              provider.activeView ==
                                              'diagnostics',
                                          onTap: () => provider.activeView =
                                              'diagnostics',
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Flexible(
                                    child: Text(
                                      _getViewTitle(provider.activeView),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textStrong,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                if (provider.activeView == 'oneline' &&
                                    !isMobile) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLive
                                          ? AppTheme.success.withOpacity(0.15)
                                          : AppTheme.error.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isLive
                                                ? AppTheme.success
                                                : AppTheme.error,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isLive ? 'LIVE' : 'MẤT KẾT NỐI',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isLive
                                                ? AppTheme.success
                                                : AppTheme.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('HH:mm:ss').format(_currentTime),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              if (!isMobile) ...[
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(_currentTime),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                              if (provider.activeView == 'oneline') ...[
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {
                                    provider.operationsOpen =
                                        !provider.operationsOpen;
                                  },
                                  child: Icon(
                                    Icons.vertical_split_rounded,
                                    size: 18,
                                    color: provider.operationsOpen
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildActiveView(provider.activeView)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isMobile
          ? Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(
                  top: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _bottomNavItem(
                    context: context,
                    id: 'tongquan',
                    label: 'Tổng quan',
                    icon: Icons.dashboard_rounded,
                    isSelected: provider.activeView == 'tongquan',
                  ),
                  _bottomNavItem(
                    context: context,
                    id: 'oneline',
                    label: 'Sơ đồ điện',
                    icon: Icons.hub_outlined,
                    isSelected: provider.activeView == 'oneline',
                  ),
                  _bottomNavItem(
                    context: context,
                    id: 'wind',
                    label: 'Điện gió',
                    icon: Icons.wind_power_outlined,
                    isSelected: provider.activeView == 'wind',
                  ),
                  _bottomNavItem(
                    context: context,
                    id: 'analytics',
                    label: 'Hệ thống',
                    icon: Icons.settings_suggest_rounded,
                    isSelected: isSystemActive,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
