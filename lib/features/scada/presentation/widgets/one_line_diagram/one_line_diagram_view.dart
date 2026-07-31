import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tan_an_portal/core/theme/app_theme.dart';
import 'package:tan_an_portal/features/scada/data/models/overlay_models.dart';
import 'package:tan_an_portal/features/scada/presentation/providers/scada_provider.dart';
import 'one_line_canvas_painter.dart';
import 'one_line_value_overlay.dart';
import 'one_line_warning_overlay.dart';

class OneLineDiagramView extends StatefulWidget {
  const OneLineDiagramView({super.key});

  @override
  State<OneLineDiagramView> createState() => _OneLineDiagramViewState();
}

class _OneLineDiagramViewState extends State<OneLineDiagramView> {
  bool _isLoading = true;
  List<BreakerOverlay> _breakers = [];
  List<StatusSymbolOverlay> _statusSymbols = [];
  List<ValueOverlay> _valueOverlays = [];
  List<WarningOverlay> _warningOverlays = [];
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOverlayData();
    });
  }

  Future<void> _loadOverlayData() async {
    try {
      final bundle = DefaultAssetBundle.of(context);

      final breakersStr = await bundle.loadString(
        'assets/data/oneline-breaker-overlays.json',
      );
      final statusSymbolsStr = await bundle.loadString(
        'assets/data/oneline-status-symbol-overlays.json',
      );
      final valueOverlaysStr = await bundle.loadString(
        'assets/data/oneline-value-overlays.json',
      );
      final warningOverlaysStr = await bundle.loadString(
        'assets/data/oneline-warning-overlays.json',
      );

      final List<dynamic> breakersJson = jsonDecode(breakersStr);
      final List<dynamic> statusSymbolsJson = jsonDecode(statusSymbolsStr);
      final List<dynamic> valueOverlaysJson = jsonDecode(valueOverlaysStr);
      final List<dynamic> warningOverlaysJson = jsonDecode(warningOverlaysStr);

      if (mounted) {
        setState(() {
          _breakers = breakersJson
              .map((x) => BreakerOverlay.fromJson(x))
              .toList();
          _statusSymbols = statusSymbolsJson
              .map((x) => StatusSymbolOverlay.fromJson(x))
              .toList();
          _valueOverlays = valueOverlaysJson
              .map((x) => ValueOverlay.fromJson(x))
              .toList();
          _warningOverlays = warningOverlaysJson
              .map((x) => WarningOverlay.fromJson(x))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading overlay data: $e');
      }
    }
  }

  void _zoom(double factor) {
    final Matrix4 currentMatrix = _transformationController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    final double newScale = (currentScale * factor).clamp(0.5, 4.0);
    final double scaleRatio = newScale / currentScale;
    final Matrix4 newMatrix = currentMatrix.clone()
      ..multiply(Matrix4.diagonal3Values(scaleRatio, scaleRatio, 1.0));
    _transformationController.value = newMatrix;
  }

  void _zoomIn() => _zoom(1.25);
  void _zoomOut() => _zoom(0.8);
  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenDiagramScreen(
          breakers: _breakers,
          statusSymbols: _statusSymbols,
          valueOverlays: _valueOverlays,
          warningOverlays: _warningOverlays,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    final provider = context.watch<ScadaProvider>();
    final snapshot = provider.envelope.snapshot;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isNarrow = width < 900;

        return Padding(
          padding: isNarrow
              ? const EdgeInsets.all(12.0)
              : const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // View Title & Legend Row
              if (isNarrow) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sơ đồ HMI nhất thứ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'TBA 110kV Tân An · Kéo/Phóng to thu nhỏ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _legendItem(AppTheme.scadaClosed, 'Đóng'),
                        _legendItem(AppTheme.scadaOpen, 'Mở'),
                        _legendItem(AppTheme.scadaIntermediate, 'Chuyển tiếp'),
                        _legendItem(AppTheme.scadaUnknown, 'Mất tín hiệu'),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sơ đồ HMI nhất thứ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Trạm biến áp 110kV Tân An · Hỗ trợ phóng to/thu nhỏ và kéo rê sơ đồ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    // Legend
                    Row(
                      children: [
                        _legendItem(AppTheme.scadaClosed, 'Đóng (Closed)'),
                        const SizedBox(width: 14),
                        _legendItem(AppTheme.scadaOpen, 'Mở (Open)'),
                        const SizedBox(width: 14),
                        _legendItem(
                          AppTheme.scadaIntermediate,
                          'Chuyển tiếp (Interm)',
                        ),
                        const SizedBox(width: 14),
                        _legendItem(
                          AppTheme.scadaUnknown,
                          'Mất tín hiệu (Unknown)',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Substation Diagram Card with Interactive Viewer
              Expanded(
                child: Card(
                  color: const Color(
                    0xFF0F172A,
                  ), // Dark slate background specifically for high-contrast SCADA HMI
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRect(
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: 0.5,
                            maxScale: 4.0,
                            boundaryMargin: const EdgeInsets.all(80.0),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio:
                                    1920.0 /
                                    1028.0, // Match the original HMI canvas aspect ratio
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final double canvasWidth =
                                        constraints.maxWidth;
                                    final double canvasHeight =
                                        constraints.maxHeight;

                                    return Stack(
                                      children: [
                                        // 1. Reference diagram raster image
                                        Positioned.fill(
                                          child: Image.asset(
                                            'assets/scada/oneline-1-live-reference.png',
                                            fit: BoxFit.fill,
                                            filterQuality: FilterQuality.high,
                                          ),
                                        ),

                                        // 2. Custom Painter layer for switches & breakers
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: OneLineCanvasPainter(
                                              statusSymbols: _statusSymbols,
                                              breakers: _breakers,
                                              snapshot: snapshot,
                                            ),
                                          ),
                                        ),

                                        // 3. Live Values textual overlays
                                        Positioned.fill(
                                          child: OneLineValueOverlay(
                                            valueOverlays: _valueOverlays,
                                            snapshot: snapshot,
                                            containerWidth: canvasWidth,
                                            containerHeight: canvasHeight,
                                          ),
                                        ),

                                        // 4. Blinking Warning overlays
                                        Positioned.fill(
                                          child: OneLineWarningOverlay(
                                            warningOverlays: _warningOverlays,
                                            snapshot: snapshot,
                                            containerWidth: canvasWidth,
                                            containerHeight: canvasHeight,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: const Icon(
                                  Icons.zoom_in_rounded,
                                  color: AppTheme.textPrimary,
                                ),
                                onPressed: _zoomIn,
                                tooltip: 'Phóng to',
                              ),
                              IconButton(
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: const Icon(
                                  Icons.zoom_out_rounded,
                                  color: AppTheme.textPrimary,
                                ),
                                onPressed: _zoomOut,
                                tooltip: 'Thu nhỏ',
                              ),
                              IconButton(
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: const Icon(
                                  Icons.restart_alt_rounded,
                                  color: AppTheme.textPrimary,
                                ),
                                onPressed: _resetZoom,
                                tooltip: 'Đặt lại',
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 1,
                                height: 16,
                                color: AppTheme.border,
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                iconSize: 16,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: const Icon(
                                  Icons.fullscreen_rounded,
                                  color: AppTheme.textPrimary,
                                ),
                                onPressed: () => _openFullscreen(context),
                                tooltip: 'Toàn màn hình',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _FullscreenDiagramScreen extends StatefulWidget {
  final List<BreakerOverlay> breakers;
  final List<StatusSymbolOverlay> statusSymbols;
  final List<ValueOverlay> valueOverlays;
  final List<WarningOverlay> warningOverlays;

  const _FullscreenDiagramScreen({
    required this.breakers,
    required this.statusSymbols,
    required this.valueOverlays,
    required this.warningOverlays,
  });

  @override
  State<_FullscreenDiagramScreen> createState() =>
      _FullscreenDiagramScreenState();
}

class _FullscreenDiagramScreenState extends State<_FullscreenDiagramScreen> {
  final TransformationController _transformationController =
      TransformationController();

  void _zoom(double factor) {
    final Matrix4 currentMatrix = _transformationController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    final double newScale = (currentScale * factor).clamp(0.5, 4.0);
    final double scaleRatio = newScale / currentScale;
    final Matrix4 newMatrix = currentMatrix.clone()
      ..multiply(Matrix4.diagonal3Values(scaleRatio, scaleRatio, 1.0));
    _transformationController.value = newMatrix;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScadaProvider>();
    final snapshot = provider.envelope.snapshot;

    return Scaffold(
      backgroundColor: const Color(0xFF070B19),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Fullscreen interactive canvas
            Positioned.fill(
              child: ClipRect(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(150.0),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1920.0 / 1028.0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double width = constraints.maxWidth;
                          final double height = constraints.maxHeight;

                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/scada/oneline-1-live-reference.png',
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: OneLineCanvasPainter(
                                    breakers: widget.breakers,
                                    statusSymbols: widget.statusSymbols,
                                    snapshot: snapshot,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: OneLineValueOverlay(
                                  valueOverlays: widget.valueOverlays,
                                  snapshot: snapshot,
                                  containerWidth: width,
                                  containerHeight: height,
                                ),
                              ),
                              Positioned.fill(
                                child: OneLineWarningOverlay(
                                  warningOverlays: widget.warningOverlays,
                                  snapshot: snapshot,
                                  containerWidth: width,
                                  containerHeight: height,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Close button top-left
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // 3. Zoom controls bottom-right
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.zoom_in_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => _zoom(1.25),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.zoom_out_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => _zoom(0.8),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.restart_alt_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          _transformationController.value = Matrix4.identity(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
