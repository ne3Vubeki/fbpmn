import 'package:fbpmn/src/services/input_handler.dart';
import 'package:fbpmn/src/services/manager.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/services/performance_tracker.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:fbpmn/src/services/cola_layout_service.dart';
import 'package:fbpmn/src/editor_state.dart';
import 'package:flutter/material.dart';

class ZoomManager extends Manager {
  final EditorState state;
  final InputHandler inputHandler;
  final ScrollHandler scrollHandler;
  final TileManager tileManager;
  final NodeManager nodeManager;
  final ColaLayoutService? colaLayoutService;

  bool _showThumbnail = true;
  bool _isLayoutRunning = false;

  ZoomManager({
    required this.state,
    required this.inputHandler,
    required this.scrollHandler,
    required this.tileManager,
    required this.nodeManager,
    this.colaLayoutService,
  });

  bool get showThumbnail => _showThumbnail;
  bool get isLayoutRunning => _isLayoutRunning;

  Future<void> resetZoom() async {
    if (state.nodesSelected.isNotEmpty) {
      await nodeManager.handleEmptyAreaClick();
    }
    scrollHandler.autoFitAndCenterNodes();
  }

  void handleThumbnailClick(Offset newCanvasOffset) {
    state.offset = _constrainOffset(newCanvasOffset);
    scrollHandler.updateScrollControllers();
    onStateUpdate();
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
    _showThumbnail = !_showThumbnail;
    onStateUpdate();
  }

  Future<void> toggleCurves([bool? useCurves]) async {
    final tracker = PerformanceTracker();
    tracker.startArrowStyleChange();

    state.useCurves = useCurves ?? !state.useCurves;
    if (state.nodesSelected.isNotEmpty) {
      await nodeManager.handleEmptyAreaClick();
    }
    await tileManager.updateTilesAfterNodeChange();

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
    state.snapEnabled = !state.snapEnabled;
    onStateUpdate();
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

    colaLayoutService!.setOnStateUpdate('ZoomManager_Cola', () {
      _isLayoutRunning = colaLayoutService!.isRunning;
      onStateUpdate();
    });

    await colaLayoutService!.runAutoLayout();
  }

  Offset _constrainOffset(Offset newOffset) {
    final viewportWidth = state.viewportSize.width;
    final viewportHeight = state.viewportSize.height;
    final canvasWidth = scrollHandler.dynamicCanvasWidth;
    final canvasHeight = scrollHandler.dynamicCanvasHeight;

    final maxOffsetX = 0.0;
    final minOffsetX = viewportWidth - canvasWidth * state.scale;
    final maxOffsetY = 0.0;
    final minOffsetY = viewportHeight - canvasHeight * state.scale;

    return Offset(newOffset.dx.clamp(minOffsetX, maxOffsetX), newOffset.dy.clamp(minOffsetY, maxOffsetY));
  }
}
