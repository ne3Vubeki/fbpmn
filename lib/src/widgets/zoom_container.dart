import 'package:fbpmn/src/services/cola_layout_service.dart';
import 'package:fbpmn/src/services/node_manager.dart';
// TODO: УДАЛИТЬ после отладки производительности
import 'package:fbpmn/src/services/performance_tracker.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/app.model.dart';
import '../models/image_tile.dart';
import '../services/input_handler.dart';
import '../services/scroll_handler.dart';
import '../services/tile_manager.dart';
import 'canvas_thumbnail.dart';
import 'performance_metrics.dart';
import 'state_widget.dart';
import 'zoom_panel.dart';

class ZoomContainer extends StatefulWidget {
  final EditorState state;
  final InputHandler inputHandler;
  final ScrollHandler scrollHandler;
  final TileManager tileManager;
  final NodeManager nodeManager;
  final ColaLayoutService? colaLayoutService;
  final EventApp? appEvent;

  const ZoomContainer({
    super.key,
    required this.state,
    required this.scrollHandler,
    required this.inputHandler,
    required this.tileManager,
    required this.nodeManager,
    this.colaLayoutService,
    required this.appEvent,
  });

  @override
  State<ZoomContainer> createState() => _ZoomContainerState();
}

class _ZoomContainerState extends State<ZoomContainer> with StateWidget<ZoomContainer> {
  bool _showThumbnail = true;
  bool _showPerformance = false;
  bool _isLayoutRunning = false;

  double get scale => widget.state.scale;
  bool get showTileBorders => widget.state.showTileBorders;
  double get canvasWidth => widget.scrollHandler.dynamicCanvasWidth;
  double get canvasHeight => widget.scrollHandler.dynamicCanvasHeight;
  Offset get canvasOffset => widget.state.offset;
  Offset get delta => widget.state.delta;
  Size get viewportSize => widget.state.viewportSize;
  List<ImageTile> get imageTiles => widget.state.imageTiles;

  onResetZoom() async {
    if (widget.state.nodesSelected.isNotEmpty) {
      await widget.nodeManager.handleEmptyAreaClick();
    }
    widget.scrollHandler.autoFitAndCenterNodes();
  }

  onToggleTileBorders() => widget.inputHandler.toggleTileBorders();

  @override
  void initState() {
    super.initState();
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

  void onThumbnailClick(Offset newOffset) {
    // Обновляем offset в состоянии
    widget.state.offset = widget.inputHandler.constrainOffset(newOffset);
    // Обновляем скроллбары
    widget.scrollHandler.updateScrollControllers();
    // Перерисовываем
    setState(() {});
  }

  void _toggleThumbnail() {
    setState(() {
      _showThumbnail = !_showThumbnail;
    });
  }

  void _handleThumbnailClick(Offset newCanvasOffset) {
    onThumbnailClick(newCanvasOffset);
  }

  // TODO: УДАЛИТЬ замер времени после отладки производительности
  void _toggleCurves() async {
    final tracker = PerformanceTracker();
    tracker.startArrowStyleChange();

    widget.state.useCurves = !widget.state.useCurves;
    if (widget.state.nodesSelected.isNotEmpty) {
      await widget.nodeManager.handleEmptyAreaClick();
    }
    await widget.tileManager.updateTilesAfterNodeChange();

    tracker.endArrowStyleChange();

    // Перерисовываем
    setState(() {});
  }

  void _toggleSnap() {
    setState(() {
      widget.state.snapEnabled = !widget.state.snapEnabled;
    });
  }

  void _togglePerformance() {
    setState(() {
      _showPerformance = !_showPerformance;
      // widget.appEvent?.emitToJs(action: 'relay', targets: ['fbpmn.fbpmn'], data: {'isShowPerformance': _showPerformance});
    });
  }

  void _onAutoLayout() async {
    if (widget.colaLayoutService == null) return;
    if (_isLayoutRunning) return;

    setState(() {
      _isLayoutRunning = true;
    });

    // Подписываемся на обновления от ColaLayoutService
    widget.colaLayoutService!.setOnStateUpdate('ZoomContainer_Cola', () {
      if (mounted) {
        setState(() {
          _isLayoutRunning = widget.colaLayoutService!.isRunning;
        });
      }
    });

    await widget.colaLayoutService!.runAutoLayout();
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
          if (_showPerformance) ...[PerformanceMetrics(panelWidth: containerWidth), const SizedBox(height: 8)],

          // Миниатюра холста (отображается если включена)
          if (_showThumbnail) ...[
            CanvasThumbnail(
              canvasWidth: canvasWidth,
              canvasHeight: canvasHeight,
              canvasOffset: canvasOffset,
              panelWidth: containerWidth,
              delta: delta, // Передаем delta
              viewportSize: viewportSize,
              scale: scale,
              imageTiles: imageTiles,
              onThumbnailClick: _handleThumbnailClick,
            ),
            const SizedBox(height: 8),
          ],

          // Панель управления зумом (ширина равна ширине контейнера)
          ZoomPanel(
            scale: scale,
            showTileBorders: showTileBorders,
            showThumbnail: _showThumbnail,
            showCurves: widget.state.useCurves,
            snapEnabled: widget.state.snapEnabled,
            showPerformance: _showPerformance,
            onAutoLayout: widget.colaLayoutService != null ? _onAutoLayout : null,
            isLayoutRunning: _isLayoutRunning,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            panelWidth: containerWidth,
            onResetZoom: onResetZoom,
            onToggleTileBorders: onToggleTileBorders,
            onToggleThumbnail: _toggleThumbnail,
            onToggleCurves: _toggleCurves,
            onToggleSnap: _toggleSnap,
            onTogglePerformance: _togglePerformance,
          ),
        ],
      ),
    );
  }
}
