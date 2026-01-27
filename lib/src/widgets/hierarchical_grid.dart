import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../painters/hierarchical_grid_painter.dart';
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

  @override
  void initState() {
    super.initState();
    widget.inputHandler.setOnStateUpdate('HierarchicalGrid', () {
      timeoutSetState();
    });
    widget.nodeManager.setOnStateUpdate('HierarchicalGrid ', () {
      timeoutSetState();
    });
    widget.tileManager.setOnStateUpdate('HierarchicalGrid', () {
      timeoutSetState();
    });
    widget.scrollHandler.setOnStateUpdate('HierarchicalGrid', () {
      timeoutSetState();
    });
  }

  @override
  void didUpdateWidget(covariant HierarchicalGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: widget.scrollHandler.scaledCanvasSize,
        painter: HierarchicalGridPainter(
          scale: widget.state.scale,
          offset: widget.state.offset,
          canvasSize: widget.scrollHandler.scaledCanvasSize,
          state: widget.state,
          isNodeDragging: widget.state.isNodeDragging,
        ),
      ),
    );
  }
}
