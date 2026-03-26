import 'package:fbpmn/src/services/input_handler.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:fbpmn/src/services/zoom_manager.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/app.model.dart';
import '../models/image_tile.dart';
import 'canvas_thumbnail.dart';
import 'performance_metrics.dart';
import 'state_widget.dart';
import 'zoom_panel.dart';

class ZoomContainer extends StatefulWidget {
  final EditorState state;
  final ZoomManager zoomManager;
  final InputHandler inputHandler;
  final ScrollHandler scrollHandler;
  final TileManager tileManager;
  final EventApp? appEvent;

  const ZoomContainer({
    super.key,
    required this.state,
    required this.zoomManager,
    required this.inputHandler,
    required this.scrollHandler,
    required this.tileManager,
    required this.appEvent,
  });

  @override
  State<ZoomContainer> createState() => _ZoomContainerState();
}

class _ZoomContainerState extends State<ZoomContainer> with StateWidget<ZoomContainer> {
  double get scale => widget.state.scale;
  double get canvasWidth => widget.zoomManager.scrollHandler.dynamicCanvasWidth;
  double get canvasHeight => widget.zoomManager.scrollHandler.dynamicCanvasHeight;
  Offset get canvasOffset => widget.state.offset;
  Offset get delta => widget.state.delta;
  Size get viewportSize => widget.state.viewportSize;
  Map<String, ImageTile> get imageTiles => widget.state.imageTiles;

  @override
  void initState() {
    super.initState();
    widget.zoomManager.setOnStateUpdate('ZoomContainer', () {
      timeoutSetState();
    });
    widget.inputHandler.setOnStateUpdate('ZoomContainer', () {
      timeoutSetState();
    });
    widget.scrollHandler.setOnStateUpdate('ZoomContainer', () {
      timeoutSetState();
    });
    widget.tileManager.setOnStateUpdate('ZoomContainer', () {
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
          if (widget.state.showPerformance) ...[
            PerformanceMetrics(panelWidth: containerWidth),
            const SizedBox(height: 8),
          ],

          // Миниатюра холста (отображается если включена)
          if (widget.state.showThumbnail) ...[
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
              onInteractionStart: widget.zoomManager.handleThumbnailInteractionStart,
            ),
            const SizedBox(height: 8),
          ],

          // Панель управления зумом (ширина равна ширине контейнера)
          ZoomPanel(
            scale: scale,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            panelWidth: containerWidth,
            onResetZoom: widget.zoomManager.resetZoom,
            onZoomIn: widget.zoomManager.zoomInStep,
            onZoomOut: widget.zoomManager.zoomOutStep,
            showTileBorders: widget.state.showTileBorders,
            showThumbnail: widget.state.showThumbnail,
            showPerformance: widget.state.showPerformance,
            snapEnabled: widget.state.snapEnabled,
            useCurves: widget.state.useCurves,
            onlyConnectors: widget.state.onlyConnectors,
            selectAndHide: widget.state.selectAndHide,
          ),
        ],
      ),
    );
  }
}
