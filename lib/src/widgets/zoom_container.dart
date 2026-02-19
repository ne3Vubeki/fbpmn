import 'package:fbpmn/src/services/zoom_manager.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../wasmapi/app.model.dart';
import '../models/image_tile.dart';
import 'canvas_thumbnail.dart';
import 'performance_metrics.dart';
import 'state_widget.dart';
import 'zoom_panel.dart';

class ZoomContainer extends StatefulWidget {
  final EditorState state;
  final ZoomManager zoomManager;
  final EventApp? appEvent;

  const ZoomContainer({
    super.key,
    required this.state,
    required this.zoomManager,
    required this.appEvent,
  });

  @override
  State<ZoomContainer> createState() => _ZoomContainerState();
}

class _ZoomContainerState extends State<ZoomContainer> with StateWidget<ZoomContainer> {
  double get scale => widget.state.scale;
  bool get showTileBorders => widget.state.showTileBorders;
  double get canvasWidth => widget.zoomManager.scrollHandler.dynamicCanvasWidth;
  double get canvasHeight => widget.zoomManager.scrollHandler.dynamicCanvasHeight;
  Offset get canvasOffset => widget.state.offset;
  Offset get delta => widget.state.delta;
  Size get viewportSize => widget.state.viewportSize;
  List<ImageTile> get imageTiles => widget.state.imageTiles;

  onToggleTileBorders() => widget.zoomManager.toggleTileBorders();

  @override
  void initState() {
    super.initState();
    widget.zoomManager.setOnStateUpdate('ZoomContainer', () {
      timeoutSetState();
    });
  }


  @override
  Widget build(BuildContext context) {
    // Ширина контейнера (равна ширине миниатюры или минимальная ширина панели)
    final double containerWidth = 360;

    return Container(
      margin: const EdgeInsets.only(right: 20, bottom: 20),
      width: containerWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Метрики производительности (отображаются над миниатюрой)
          if (widget.state.showPerformance) ...[PerformanceMetrics(panelWidth: containerWidth), const SizedBox(height: 8)],

          // Миниатюра холста (отображается если включена)
          if (widget.zoomManager.showThumbnail) ...[
            CanvasThumbnail(
              canvasWidth: canvasWidth,
              canvasHeight: canvasHeight,
              canvasOffset: canvasOffset,
              panelWidth: containerWidth,
              delta: delta, // Передаем delta
              viewportSize: viewportSize,
              scale: scale,
              imageTiles: imageTiles,
              onThumbnailClick: widget.zoomManager.handleThumbnailClick,
            ),
            const SizedBox(height: 8),
          ],

          // Панель управления зумом (ширина равна ширине контейнера)
          ZoomPanel(
            scale: scale,
            showTileBorders: showTileBorders,
            showThumbnail: widget.zoomManager.showThumbnail,
            showCurves: widget.state.useCurves,
            snapEnabled: widget.state.snapEnabled,
            showPerformance: widget.state.showPerformance,
            onAutoLayout: widget.zoomManager.colaLayoutService != null ? widget.zoomManager.runAutoLayout : null,
            isLayoutRunning: widget.zoomManager.isLayoutRunning,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            panelWidth: containerWidth,
            onResetZoom: widget.zoomManager.resetZoom,
            onToggleTileBorders: onToggleTileBorders,
            onToggleThumbnail: widget.zoomManager.toggleThumbnail,
            onToggleCurves: widget.zoomManager.toggleCurves,
            onToggleSnap: widget.zoomManager.toggleSnap,
            onTogglePerformance: widget.zoomManager.togglePerformance,
          ),
        ],
      ),
    );
  }
}
