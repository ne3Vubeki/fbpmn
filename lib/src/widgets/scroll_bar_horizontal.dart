import 'package:fbpmn/src/services/input_handler.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../services/scroll_handler.dart';
import 'state_widget.dart';

class ScrollBarHorizontal extends StatefulWidget {
  final EditorState state;
  final ScrollHandler scrollHandler;
  final InputHandler inputHandler;

  const ScrollBarHorizontal({
    super.key,
    required this.state,
    required this.inputHandler,
    required this.scrollHandler,
  });

  @override
  State<ScrollBarHorizontal> createState() => _TileBorderState();
}

class _TileBorderState extends State<ScrollBarHorizontal> with StateWidget<ScrollBarHorizontal> {
  Size _scaledCanvasSize = Size.zero;
  bool _needsHorizontalScrollbar = false;
  bool _needsVerticalScrollbar = false;

  @override
  void initState() {
    super.initState();
    widget.scrollHandler.setOnStateUpdate('ScrollBarHorizontal', () {
      timeoutSetState(updateCanvasSize);
    });
    widget.inputHandler.setOnStateUpdate('ScrollBarHorizontal', () {
      timeoutSetState(updateCanvasSize);
    });
  }

  updateCanvasSize() {
    _scaledCanvasSize = widget.scrollHandler.scaledCanvasSize;
    _needsHorizontalScrollbar = widget.scrollHandler.needsHorizontalScrollbar;
    _needsVerticalScrollbar = widget.scrollHandler.needsVerticalScrollbar;
  }

  @override
  void didUpdateWidget(covariant ScrollBarHorizontal oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return _needsHorizontalScrollbar
        ? Positioned(
            left: 0,
            right: _needsVerticalScrollbar ? 10 : 0,
            bottom: 0,
            height: 10,
            child: Listener(
              onPointerDown:
                  widget.scrollHandler.handleHorizontalScrollbarDragStart,
              onPointerMove:
                  widget.scrollHandler.handleHorizontalScrollbarDragUpdate,
              onPointerUp:
                  widget.scrollHandler.handleHorizontalScrollbarDragEnd,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Scrollbar(
                  controller: widget.scrollHandler.horizontalScrollController,
                  thumbVisibility: true,
                  trackVisibility: false,
                  thickness: 10,
                  child: SingleChildScrollView(
                    controller: widget.scrollHandler.horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(width: _scaledCanvasSize.width, height: 10),
                  ),
                ),
              ),
            ),
          )
        : Container();
  }
}
