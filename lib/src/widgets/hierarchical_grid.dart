import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../painters/hierarchical_grid_painter.dart';
import '../services/input_handler.dart';
import '../services/node_manager.dart';
import '../services/scroll_handler.dart';

class HierarchicalGrid extends StatefulWidget {
  final EditorState state;
  final Size size;
  final InputHandler inputHandler;
  final NodeManager nodeManager;
  final TileManager tileManager;
  final ScrollHandler scrollHandler;

  const HierarchicalGrid({
    super.key,
    required this.state,
    required this.size,
    required this.inputHandler,
    required this.nodeManager,
    required this.tileManager,
    required this.scrollHandler,
  });

  @override
  State<HierarchicalGrid> createState() => _HierarchicalGridState();
}

class _HierarchicalGridState extends State<HierarchicalGrid> {
  // Используем константы из NodeManager
  double get framePadding => NodeManager.framePadding;
  double get frameBorderWidth => NodeManager.frameBorderWidth;
  double get frameTotalOffset => NodeManager.frameTotalOffset;

  @override
  void initState() {
    super.initState();
    widget.inputHandler.setOnStateUpdate('HierarchicalGrid', () {
      if (this.mounted) {
        setState(() {});
      }
    });
    widget.nodeManager.setOnStateUpdate('HierarchicalGrid', () {
      if (this.mounted) {
        setState(() {});
      }
    });
    widget.tileManager.setOnStateUpdate('HierarchicalGrid', () {
      if (this.mounted) {
        setState(() {});
      }
    });
    widget.scrollHandler.setOnStateUpdate('HierarchicalGrid', () {
      if (this.mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant HierarchicalGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return // Отображение холста и тайлов
    RepaintBoundary(
      child: CustomPaint(
        size: widget.size,
        painter: HierarchicalGridPainter(
          scale: widget.state.scale,
          offset: widget.state.offset,
          canvasSize: widget.size,
          state: widget.state,
          isNodeDragging: widget.state.isNodeDragging,
        ),
      ),
    );
  }
}
