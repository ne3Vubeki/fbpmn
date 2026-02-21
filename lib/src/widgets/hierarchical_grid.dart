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

class _HierarchicalGridState extends State<HierarchicalGrid> with StateWidget<HierarchicalGrid> {
  bool isTileEvent = false;
  // Timer? _tileEventTimer;
  // Timer? _nodeEventTimer;

  @override
  void initState() {
    super.initState();
    // widget.nodeManager.setOnStateUpdate('HierarchicalGrid', () {
    //   timeoutSetState(
    //     duration: Duration(milliseconds: 200),
    //     callback: () {
    //       print('Event HierarchicalGrid: NodeManager');
    //     },
    //     timer: _nodeEventTimer,
    //   );
    // });
    widget.tileManager.setOnStateUpdate('HierarchicalGrid', () {
      timeoutSetState(
        callback: () {
          isTileEvent = !isTileEvent;
          print('Event HierarchicalGrid: TileManager');
        },
      );
    });
    widget.scrollHandler.setOnStateUpdate('HierarchicalGrid', () {
      timeoutSetState();
      print('Event HierarchicalGrid: ScrollHandler');
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
    return Stack(
      children: [
        // Слой 1: сетка — перерисовывается только при scale/offset
        RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: GridPainter(
              scale: widget.state.scale,
              offset: widget.state.offset,
              nodeManager: widget.nodeManager,
            ),
          ),
        ),

        // Слой 2: тайлы — перерисовывается только при изменении visibleTiles
        RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: TileImagePainter(
              scale: widget.state.scale,
              offset: widget.state.offset,
              canvasSize: size,
              state: widget.state,
              imageTiles: widget.state.imageTiles,
              nodesIdOnTopLayer: widget.state.nodesIdOnTopLayer,
              isTileEvent: isTileEvent,
              updatedImageTileIds: widget.state.updatedImageTileIds,
            ),
          ),
        ),
      ],
    );
  }
}
