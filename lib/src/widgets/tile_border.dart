import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../painters/tile_border_painter.dart';
import '../services/node_manager.dart';
import '../services/scroll_handler.dart';

class TileBorder extends StatefulWidget {
  final EditorState state;
  final Size size;
  final TileManager tileManager;
  final ScrollHandler scrollHandler;

  const TileBorder({
    super.key,
    required this.state,
    required this.size,
    required this.tileManager,
    required this.scrollHandler,
  });

  @override
  State<TileBorder> createState() => _TileBorderState();
}

class _TileBorderState extends State<TileBorder> {
  // Используем константы из NodeManager
  double get framePadding => NodeManager.framePadding;
  double get frameBorderWidth => NodeManager.frameBorderWidth;
  double get frameTotalOffset => NodeManager.frameTotalOffset;

  @override
  void initState() {
    super.initState();
    widget.tileManager.setOnStateUpdate('TileBorder', () {
      if (this.mounted) {
        setState(() {});
      }
    });
    widget.scrollHandler.setOnStateUpdate('TileBorder', () {
      if (this.mounted) {
        setState(() {});
      }
    });
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
              size: widget.size,
              painter: TileBorderPainter(
                state: widget.state,
                isNodeDragging: widget.state.isNodeDragging,
              ),
            ),
          )
        : Container();
  }
}
