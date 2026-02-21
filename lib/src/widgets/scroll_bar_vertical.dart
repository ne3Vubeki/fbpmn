import 'package:fbpmn/src/services/input_handler.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../services/scroll_handler.dart';
import 'state_widget.dart';

class ScrollBarVertical extends StatefulWidget {
  final EditorState state;
  final ScrollHandler scrollHandler;
  final InputHandler inputHandler;

  const ScrollBarVertical({
    super.key,
    required this.state,
    required this.inputHandler,
    required this.scrollHandler,
  });

  @override
  State<ScrollBarVertical> createState() => _TileBorderState();
}

class _TileBorderState extends State<ScrollBarVertical> with StateWidget<ScrollBarVertical> {
  Size _scaledCanvasSize = Size.zero;
  bool _needsHorizontalScrollbar = false;
  bool _needsVerticalScrollbar = false;

  @override
  void initState() {
    super.initState();
    widget.scrollHandler.setOnStateUpdate('ScrollBarVertical', () {
      timeoutSetState(callback: updateCanvasSize);
    });
    widget.inputHandler.setOnStateUpdate('ScrollBarVertical', () {
      timeoutSetState(callback: updateCanvasSize);
    });
  }

  updateCanvasSize() {
    _scaledCanvasSize = widget.scrollHandler.scaledCanvasSize;
    _needsHorizontalScrollbar = widget.scrollHandler.needsHorizontalScrollbar;
    _needsVerticalScrollbar = widget.scrollHandler.needsVerticalScrollbar;
  }

  @override
  void didUpdateWidget(covariant ScrollBarVertical oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return _needsVerticalScrollbar
        ? Positioned(
            top: 0,
            bottom: _needsHorizontalScrollbar ? 10 : 0,
            right: 0,
            width: 10,
            child: Listener(
              onPointerDown:
                  widget.scrollHandler.handleVerticalScrollbarDragStart,
              onPointerMove:
                  widget.scrollHandler.handleVerticalScrollbarDragUpdate,
              onPointerUp: widget.scrollHandler.handleVerticalScrollbarDragEnd,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Scrollbar(
                  controller: widget.scrollHandler.verticalScrollController,
                  thumbVisibility: true,
                  trackVisibility: false,
                  thickness: 10,
                  child: SingleChildScrollView(
                    controller: widget.scrollHandler.verticalScrollController,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: 10,
                      height: _scaledCanvasSize.height,
                    ),
                  ),
                ),
              ),
            ),
          )
        : Container();
  }
}
