import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/utils/utils.dart';
import 'package:fbpmn/src/widgets/state_widget.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../painters/arrows_custom_painter.dart';

class ArrowHover extends StatefulWidget {
  final EditorState state;
  final ArrowManager arrowManager;
  final ScrollHandler scrollHandler;

  const ArrowHover({super.key, required this.state, required this.arrowManager, required this.scrollHandler});

  @override
  State<ArrowHover> createState() => _ArrowHoverState();
}

class _ArrowHoverState extends State<ArrowHover> with StateWidget<ArrowHover> {
  @override
  void initState() {
    super.initState();
    widget.arrowManager.setOnStateUpdate('ArrowHover', () {
      timeoutSetState();
    });
    widget.scrollHandler.setOnStateUpdate('ArrowHover', () {
      timeoutSetState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final arrow = widget.state.hoveredArrow;
    if (arrow == null) {
      return Container();
    }

    final boundingRect = Utils.calculateBoundingRect([arrow], widget.state);
    if (boundingRect.width <= 0 || boundingRect.height <= 0) {
      return Container();
    }

    final screenPositionRect = Offset(
      boundingRect.left * widget.state.scale + widget.state.offset.dx,
      boundingRect.top * widget.state.scale + widget.state.offset.dy,
    );

    final arrowsSize = Size(
      boundingRect.size.width * widget.state.scale,
      boundingRect.size.height * widget.state.scale,
    );


    if (arrowsSize.width <= 0 || arrowsSize.height <= 0) {
      return Container();
    }

    return Positioned(
      left: screenPositionRect.dx - widget.arrowManager.arrowPathRectOffset * widget.state.scale,
      top: screenPositionRect.dy - widget.arrowManager.arrowPathRectOffset * widget.state.scale,
      child: MouseRegion(
        opaque: true,
        cursor: SystemMouseCursors.click,
        child: Container(
          width: arrowsSize.width,
          height: arrowsSize.height,
          margin: EdgeInsets.all(widget.arrowManager.arrowPathRectOffset * widget.state.scale),
          child: Stack(
            children: [
              IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: arrowsSize,
                    painter: ArrowsCustomPainter(
                      arrows: [arrow],
                      scale: widget.state.scale,
                      arrowsSize: arrowsSize,
                      arrowsRect: boundingRect,
                      nodeOffset: Offset.zero,
                      arrowManager: widget.arrowManager,
                      areaNodes: 0,
                      hoverMode: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
