import 'package:fbpmn/src/painters/grid_painter.dart';
import 'package:fbpmn/src/painters/tile_painter.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:fbpmn/src/services/viewport_tile_controller.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/image_tile.dart';
import '../services/input_handler.dart';
import '../services/node_manager.dart';
import '../services/scroll_handler.dart';
import 'state_widget.dart';

class HierarchicalGrid extends StatefulWidget {
  final EditorState state;
  final InputHandler inputHandler;
  final NodeManager nodeManager;
  final TileManager tileManager;
  final ScrollHandler scrollHandler;

  const HierarchicalGrid({
    super.key,
    required this.state,
    required this.inputHandler,
    required this.nodeManager,
    required this.tileManager,
    required this.scrollHandler,
  });

  @override
  State<HierarchicalGrid> createState() => _HierarchicalGridState();
}

class _HierarchicalGridState extends State<HierarchicalGrid>
    with StateWidget<HierarchicalGrid> {

  late final ViewportTileController _viewportController;

  /// Список видимых тайлов, передаваемый в TilePainter.
  List<ImageTile> _visibleTiles = [];

  @override
  void initState() {
    super.initState();

    _viewportController = ViewportTileController(
      state: widget.state,
      tileManager: widget.tileManager,
    );

    widget.nodeManager.setOnStateUpdate('HierarchicalGrid ', () {
      // Обновляем _visibleTiles в том же setState что и NodeSelected —
      // тайлы и верхний слой обновляются в одном кадре без моргания
      timeoutSetState(() {
        _visibleTiles = _viewportController.visibleTiles;
      });
    });

    widget.tileManager.setOnStateUpdate('HierarchicalGrid', () {
      // Только синхронизируем данные без setState.
      // Если узел на верхнем слое — nodeManager.onStateUpdate() сработает сразу после
      // и обновит _visibleTiles в том же кадре.
      // Если узел не на верхнем слое — обновляем немедленно.
      _viewportController.syncTileIndex();
      _computeVisibleTiles();
      if (!widget.state.isNodeOnTopLayer) {
        timeoutSetState(() {
          _visibleTiles = _viewportController.visibleTiles;
        });
      }
    });

    widget.scrollHandler.setOnStateUpdate('HierarchicalGrid', () {
      _computeVisibleTiles();
      timeoutSetState(() {
        _visibleTiles = _viewportController.visibleTiles;
      });
    });

    _viewportController.setOnStateUpdate('HierarchicalGrid_vpc', () {
      timeoutSetState(() {
        _visibleTiles = _viewportController.visibleTiles;
      });
    });
  }

  @override
  void dispose() {
    _viewportController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HierarchicalGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  /// Пересчитывает видимую область и уведомляет ViewportTileController.
  /// Не вызывает setState напрямую — только обновляет внутреннее состояние контроллера.
  void _computeVisibleTiles() {
    final scale  = widget.state.scale;
    final offset = widget.state.offset;
    final size   = widget.state.viewportSize;

    if (size == Size.zero) return;

    final visibleLeft   = -offset.dx / scale;
    final visibleTop    = -offset.dy / scale;
    final visibleRight  = (size.width  - offset.dx) / scale;
    final visibleBottom = (size.height - offset.dy) / scale;

    _viewportController.onViewportChanged(
      visibleLeft:   visibleLeft,
      visibleTop:    visibleTop,
      visibleRight:  visibleRight,
      visibleBottom: visibleBottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvasSize = widget.scrollHandler.scaledCanvasSize;
    final scale      = widget.state.scale;
    final offset     = widget.state.offset;

    return Stack(
      children: [
        // Слой 1: сетка — перерисовывается только при scale/offset
        RepaintBoundary(
          child: CustomPaint(
            size: canvasSize,
            painter: GridPainter(
              scale:       scale,
              offset:      offset,
              canvasSize:  canvasSize,
              nodeManager: widget.nodeManager,
            ),
          ),
        ),

        // Слой 2: тайлы — перерисовывается только при изменении visibleTiles
        RepaintBoundary(
          child: CustomPaint(
            size: canvasSize,
            painter: TilePainter(
              scale:        scale,
              offset:       offset,
              visibleTiles: _visibleTiles,
            ),
          ),
        ),
      ],
    );
  }
}
