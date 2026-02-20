import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../painters/grid_painter.dart';
import '../painters/tile_image_painter.dart';
import '../services/input_handler.dart';
import '../services/node_manager.dart';
import '../services/scroll_handler.dart';
import 'state_widget.dart';

class HierarchicalGrid extends StatefulWidget {
  final EditorState state;
  final InputHandler inputHandler;
  final NodeManager nodeManager;
  final TileManager tileManager;
  final ArrowManager arrowManager;
  final ScrollHandler scrollHandler;

  const HierarchicalGrid({
    super.key,
    required this.state,
    required this.inputHandler,
    required this.nodeManager,
    required this.tileManager,
    required this.arrowManager,
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
    widget.nodeManager.setOnStateUpdate('HierarchicalGrid', () {
      timeoutSetState();
    });
    widget.tileManager.setOnStateUpdate('HierarchicalGrid', () {
      timeoutSetState();
    });
    widget.arrowManager.setOnStateUpdate('HierarchicalGrid', () {
      timeoutSetState();
    });
    widget.scrollHandler.setOnStateUpdate('HierarchicalGrid', () {
      timeoutSetState();
    });
  }

  @override
  void dispose() {
    widget.nodeManager.removeOnStateUpdate('HierarchicalGrid');
    widget.tileManager.removeOnStateUpdate('HierarchicalGrid');
    widget.arrowManager.removeOnStateUpdate('HierarchicalGrid');
    widget.scrollHandler.removeOnStateUpdate('HierarchicalGrid');
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HierarchicalGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.scrollHandler.scaledCanvasSize;
    return RepaintBoundary(
      child: CustomPaint(
        size: size,
        painter: TileImagePainter(
          scale: widget.state.scale,
          offset: widget.state.offset,
          canvasSize: size,
          state: widget.state,
          tileManager: widget.tileManager,
          nodeManager: widget.nodeManager,
          arrowManager: widget.arrowManager,
        ),
        foregroundPainter: GridPainter(
          scale: widget.state.scale,
          offset: widget.state.offset,
          nodeManager: widget.nodeManager,
        ),
      ),
    );
  }
}
