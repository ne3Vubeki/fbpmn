import 'package:fbpmn/src/services/input_handler.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../painters/tile_border_painter.dart';
import '../services/scroll_handler.dart';
import 'state_widget.dart';

class TileBorder extends StatefulWidget {
  final EditorState state;
  final TileManager tileManager;
  final ScrollHandler scrollHandler;
  final InputHandler inputHandler;

  const TileBorder({
    super.key,
    required this.state,
    required this.tileManager,
    required this.inputHandler,
    required this.scrollHandler,
  });

  @override
  State<TileBorder> createState() => _TileBorderState();
}

class _TileBorderState extends State<TileBorder> with StateWidget<TileBorder> {

  @override
  void initState() {
    super.initState();
    widget.tileManager.setOnStateUpdate('TileBorder', () {
      timeoutSetState();
    });
    widget.scrollHandler.setOnStateUpdate('TileBorder', () {
      timeoutSetState();
    });
    // widget.inputHandler.setOnStateUpdate('TileBorder', () {
    //   timeoutSetState();
    // });
  }

  @override
  void didUpdateWidget(covariant TileBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return widget.state.showTileBorders
        ? RepaintBoundary(
            child: CustomPaint(
              size: widget.scrollHandler.scaledCanvasSize,
              painter: TileBorderPainter(
                state: widget.state,
                isNodeDragging: widget.state.isNodeDragging,
              ),
            ),
          )
        : Container();
  }
}
