import 'package:fbpmn/src/services/input_handler.dart';
import 'package:fbpmn/src/services/manager.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/services/performance_tracker.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:fbpmn/src/services/cola_layout_service.dart';
import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/utils/editor_config.dart';
import 'package:flutter/material.dart';

class ZoomManager extends Manager {
  final EditorState state;
  final InputHandler inputHandler;
  final ScrollHandler scrollHandler;
  final TileManager tileManager;
  final NodeManager nodeManager;
  final ColaLayoutService? colaLayoutService;

  bool _isLayoutRunning = false;

  ZoomManager({
    required this.state,
    required this.inputHandler,
    required this.scrollHandler,
    required this.tileManager,
    required this.nodeManager,
    this.colaLayoutService,
  });

  bool get isLayoutRunning => _isLayoutRunning;

  Future<void> resetZoom() async {
    if (state.nodesSelected.isNotEmpty) {
      await nodeManager.handleEmptyAreaClick();
    }

    // Для пустой схемы всегда возвращаем 100% масштаб
    if (state.nodes.isEmpty) {
      state.scale = 1.0;
      scrollHandler.centerCanvas();
      return;
    }

    scrollHandler.autoFitAndCenterNodes();
  }

  void zoomInStep() {
    _zoomByPercentStep(10);
  }

  void zoomOutStep() {
    _zoomByPercentStep(-10);
  }

  void handleThumbnailClick(Offset newCanvasOffset) {
    state.offset = _constrainOffset(newCanvasOffset);
    scrollHandler.updateScrollControllers();
    onStateUpdate();
  }

  Future<void> handleThumbnailInteractionStart() async {
    if (state.nodesSelected.isNotEmpty || state.arrowsSelected.isNotEmpty) {
      await nodeManager.handleEmptyAreaClick();
    }
  }

  void toggleTileBorders() {
    inputHandler.toggleTileBorders();
    onStateUpdate();
  }

  void onTileBorders() {
    inputHandler.onTileBorders();
    onStateUpdate();
  }

  void offTileBorders() {
    inputHandler.offTileBorders();
    onStateUpdate();
  }

  void toggleThumbnail() {
    state.showThumbnail = !state.showThumbnail;
    onStateUpdate();
  }

  void onThumbnail() {
    state.showThumbnail = true;
    onStateUpdate();
  }

  void offThumbnail() {
    state.showThumbnail = false;
    onStateUpdate();
  }

  Future<void> toggleCurves([bool? useCurves]) async {
    final tracker = PerformanceTracker();
    tracker.startArrowStyleChange();

    state.useCurves = useCurves ?? !state.useCurves;
    if (state.nodesSelected.isNotEmpty) {
      await nodeManager.handleEmptyAreaClick();
    }
    await tileManager.updateTilesAfterNodeChange(isUpdate: false);

    tracker.endArrowStyleChange();

    onStateUpdate();
  }

  void onCurves() {
    toggleCurves(true);
  }

  void offCurves() {
    toggleCurves(false);
  }

  void toggleSnap() {
    setSnapEnabled(!state.snapEnabled);
  }

  void setSnapEnabled(bool enabled, {bool forceNotify = false}) {
    if (!forceNotify && state.snapEnabled == enabled) {
      return;
    }

    state.snapEnabled = enabled;
    if (!enabled && state.snapLines.isNotEmpty) {
      state.snapLines = [];
    }

    onStateUpdate('snap');
  }

  void onSnap() {
    setSnapEnabled(true);
  }

  void offSnap() {
    setSnapEnabled(false);
  }

  void togglePerformance() {
    state.showPerformance = !state.showPerformance;
    onStateUpdate();
  }

  void onPerformance() {
    state.showPerformance = true;
    onStateUpdate();
  }

  void offPerformance() {
    state.showPerformance = false;
    onStateUpdate();
  }

  Future<void> runAutoLayout() async {
    if (colaLayoutService == null) return;
    if (_isLayoutRunning) return;

    _isLayoutRunning = true;
    onStateUpdate();

    colaLayoutService!.setOnStateUpdate('ZoomManager_Cola', ([data]) {
      _isLayoutRunning = colaLayoutService!.isRunning;
      onStateUpdate();
    });

    await colaLayoutService!.runAutoLayout();
  }

  void _zoomByPercentStep(int percentStep) {
    final double oldScale = state.scale;
    final double oldPercent = oldScale * 100;
    final double targetPercent = (oldPercent + percentStep).clamp(
      EditorConfig.minScale * 100,
      EditorConfig.maxScale * 100,
    );
    final double newScale = targetPercent / 100;

    if (newScale == oldScale) {
      return;
    }

    final Offset viewportCenter = Offset(
      state.viewportSize.width / 2,
      state.viewportSize.height / 2,
    );
    final Offset centerInCanvas = viewportCenter - state.offset;
    final double zoomFactor = newScale / oldScale;
    final Offset newOffset = viewportCenter - centerInCanvas * zoomFactor;

    state.scale = newScale;
    state.offset = _constrainOffset(newOffset);

    if (oldScale != newScale) {
      nodeManager.onScaleChanged();
    }

    scrollHandler.updateScrollControllers();
    scrollHandler.onStateUpdate();
    onStateUpdate();
  }

  Offset _constrainOffset(Offset newOffset) {
    return scrollHandler.constrainOffset(newOffset);
  }
}
