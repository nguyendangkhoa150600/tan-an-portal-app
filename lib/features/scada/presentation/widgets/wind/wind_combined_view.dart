import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import '../../providers/scada_provider.dart';
import 'windfarm_1_view.dart';
import 'windfarm_2_view.dart';
import 'windfarm_all_view.dart';

class WindCombinedView extends StatefulWidget {
  final bool directView;
  const WindCombinedView({super.key, this.directView = false});

  @override
  State<WindCombinedView> createState() => _WindCombinedViewState();
}

class _WindCombinedViewState extends State<WindCombinedView> {
  @override
  void initState() {
    super.initState();
    if (widget.directView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ScadaProvider>().windPark = 'all';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.directView) {
      return const WindFarmAllView(directView: true);
    }

    final provider = context.watch<ScadaProvider>();
    final park = provider.windPark;
    final vestasMode = provider.vestasMode;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Switch segments Row/Column
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              bottom: BorderSide(color: AppTheme.border, width: 1),
            ),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          Expanded(
                            child: _segmentButton(
                              label: 'Tổng 24 trụ',
                              isActive: park == 'all',
                              onTap: () {
                                provider.windPark = 'all';
                              },
                              centerText: true,
                            ),
                          ),
                          Expanded(
                            child: _segmentButton(
                              label: 'Điện gió 1',
                              isActive: park == 'dg1',
                              onTap: () {
                                provider.windPark = 'dg1';
                              },
                              centerText: true,
                            ),
                          ),
                          Expanded(
                            child: _segmentButton(
                              label: 'Điện gió 2',
                              isActive: park == 'dg2',
                              onTap: () {
                                provider.windPark = 'dg2';
                              },
                              centerText: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (park == 'dg2')
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.border),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _segmentButton(
                                      label: 'Vận hành Live',
                                      isActive: vestasMode == 'live',
                                      onTap: () {
                                        provider.vestasMode = 'live';
                                      },
                                      centerText: true,
                                    ),
                                  ),
                                  Expanded(
                                    child: _segmentButton(
                                      label: 'Báo cáo IEC 10′',
                                      isActive: vestasMode == 'iec',
                                      onTap: () {
                                        provider.vestasMode = 'iec';
                                      },
                                      centerText: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (park == 'dg2') const SizedBox(width: 8) else const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.border),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              _iconToggle(
                                icon: Icons.grid_view_rounded,
                                isActive: !provider.isWindCompactMode,
                                onTap: () => provider.isWindCompactMode = false,
                              ),
                              const SizedBox(width: 2),
                              _iconToggle(
                                icon: Icons.view_headline_rounded,
                                isActive: provider.isWindCompactMode,
                                onTap: () => provider.isWindCompactMode = true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 1. Select Wind Park Segment
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          _segmentButton(
                            label: 'Tổng trụ gió · 24 trụ',
                            isActive: park == 'all',
                            onTap: () {
                              provider.windPark = 'all';
                            },
                          ),
                          _segmentButton(
                            label: 'Điện gió 1 · Windey',
                            isActive: park == 'dg1',
                            onTap: () {
                              provider.windPark = 'dg1';
                            },
                          ),
                          _segmentButton(
                            label: 'Điện gió 2 · Vestas',
                            isActive: park == 'dg2',
                            onTap: () {
                              provider.windPark = 'dg2';
                            },
                          ),
                        ],
                      ),
                    ),

                    // 2. Select Vestas Data Source Mode Segment + Layout Switcher
                    Row(
                      children: [
                        if (park == 'dg2') ...[
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.border),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Row(
                              children: [
                                _segmentButton(
                                  label: 'Live',
                                  isActive: vestasMode == 'live',
                                  onTap: () {
                                    provider.vestasMode = 'live';
                                  },
                                ),
                                _segmentButton(
                                  label: 'IEC 10′',
                                  isActive: vestasMode == 'iec',
                                  onTap: () {
                                    provider.vestasMode = 'iec';
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Layout Switcher
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.border),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              _iconToggle(
                                icon: Icons.grid_view_rounded,
                                isActive: !provider.isWindCompactMode,
                                onTap: () => provider.isWindCompactMode = false,
                              ),
                              const SizedBox(width: 2),
                              _iconToggle(
                                icon: Icons.view_headline_rounded,
                                isActive: provider.isWindCompactMode,
                                onTap: () => provider.isWindCompactMode = true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),

        // 3. Body View
        Expanded(
          child: Container(
            color: AppTheme.background,
            child: park == 'all'
                ? const WindFarmAllView(directView: false)
                : park == 'dg1'
                    ? const WindFarm1View()
                    : WindFarm2View(mode: vestasMode),
          ),
        ),
      ],
    );
  }

  Widget _segmentButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool centerText = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.panel2 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        width: centerText ? double.infinity : null,
        child: Text(
          label,
          textAlign: centerText ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _iconToggle({
    required IconData icon,
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
        child: Icon(
          icon,
          size: 16,
          color: isActive ? AppTheme.primary : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
