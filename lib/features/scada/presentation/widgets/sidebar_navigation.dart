import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/core/utils/scada_helpers.dart';
import '../providers/scada_provider.dart';

class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final isCollapsed = provider.focusMode;
    final quality = ScadaHelpers.summarizeQuality(provider.envelope.snapshot);
    final good = quality['good'] ?? 0;
    final total = quality['total'] ?? 0;
    final isLive = provider.pollState == 'live';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 64 : 198,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SAVINA Logo Area
          GestureDetector(
            onTap: () {
              provider.activeView = 'tongquan';
            },
            child: Container(
              height: 60,
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Icon(
                    Icons.cell_tower_rounded,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SAVINA',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textStrong,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            'SCADA PORTAL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _navItem(
                  context: context,
                  id: 'tongquan',
                  label: 'Tổng quan',
                  icon: Icons.dashboard_rounded,
                  isSelected: provider.activeView == 'tongquan',
                  isCollapsed: isCollapsed,
                ),
                _navItem(
                  context: context,
                  id: 'oneline',
                  label: 'Sơ đồ điện',
                  icon: Icons.hub_outlined,
                  isSelected: provider.activeView == 'oneline',
                  isCollapsed: isCollapsed,
                ),
                _navItem(
                  context: context,
                  id: 'wind',
                  label: 'Điện gió',
                  icon: Icons.wind_power_outlined,
                  isSelected: provider.activeView == 'wind',
                  isCollapsed: isCollapsed,
                ),
                _navItem(
                  context: context,
                  id: 'analytics',
                  label: 'Phân tích',
                  icon: Icons.bar_chart_rounded,
                  isSelected: provider.activeView == 'analytics',
                  isCollapsed: isCollapsed,
                ),
                _navItem(
                  context: context,
                  id: 'forecast',
                  label: 'Dự báo',
                  icon: Icons.trending_up_rounded,
                  isSelected: provider.activeView == 'forecast',
                  isCollapsed: isCollapsed,
                ),
                _navItem(
                  context: context,
                  id: 'diagnostics',
                  label: 'Chẩn đoán',
                  icon: Icons.monitor_heart_outlined,
                  isSelected: provider.activeView == 'diagnostics',
                  isCollapsed: isCollapsed,
                ),
                _navItem(
                  context: context,
                  id: 'danhmuc',
                  label: 'Danh mục',
                  icon: Icons.grid_view_rounded,
                  isSelected: provider.activeView == 'danhmuc',
                  isCollapsed: isCollapsed,
                ),
              ],
            ),
          ),

          // Signal Card at Footer if in oneline view
          if (provider.activeView == 'oneline' && !isCollapsed) ...[
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sơ đồ điện · ATS',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLive ? AppTheme.success : AppTheme.warning,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isLive ? 'LIVE' : 'CHỜ DỮ LIỆU',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isLive ? AppTheme.success : AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Polling',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const Text(
                        '5 giây',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chất lượng',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '$good/$total',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Quality Indicator Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              child: isCollapsed
                  ? Center(
                      child: Tooltip(
                        message: 'Chất lượng dữ liệu: $good/$total OK',
                        child: Icon(
                          Icons.insights_rounded,
                          color: good == total
                              ? AppTheme.success
                              : AppTheme.warning,
                          size: 18,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Chất lượng kênh',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$good/$total OK',
                              style: TextStyle(
                                fontSize: 10,
                                color: good == total
                                    ? AppTheme.success
                                    : AppTheme.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? good / total : 0,
                            backgroundColor: AppTheme.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              good == total
                                  ? AppTheme.success
                                  : AppTheme.warning,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _navItem({
    required BuildContext context,
    required String id,
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isCollapsed,
  }) {
    if (isCollapsed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.read<ScadaProvider>().activeView = id;
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pill background for icon (like the screenshot menu)
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
                  const SizedBox(height: 5),
                  // Short label text centered underneath the pill
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? AppTheme.primary.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            context.read<ScadaProvider>().activeView = id;
          },
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.textStrong
                          : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
