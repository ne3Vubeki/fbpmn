import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/input_handler.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/widgets/state_widget.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../painters/arrows_custom_painter.dart';

class ArrowsSelected extends StatefulWidget {
  final EditorState state;
  final ArrowManager arrowManager;
  final InputHandler inputHandler;
  final ScrollHandler scrollHandler;

  const ArrowsSelected({
    super.key,
    required this.state,
    required this.arrowManager,
    required this.inputHandler,
    required this.scrollHandler,
  });

  @override
  State<ArrowsSelected> createState() => _ArrowsSelected();
}

class _ArrowsSelected extends State<ArrowsSelected>
    with StateWidget<ArrowsSelected> {
  @override
  void initState() {
    super.initState();
    widget.arrowManager.setOnStateUpdate('ArrowsSelected', () {
      timeoutSetState();
    });
    // widget.inputHandler.setOnStateUpdate('ArrowsSelected', () {
    //   timeoutSetState();
    // });
    widget.scrollHandler.setOnStateUpdate('ArrowsSelected', () {
      timeoutSetState();
    });
  }

  @override
  void didUpdateWidget(covariant ArrowsSelected oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.arrows.isEmpty) return Container();

    final nodes = widget.state.nodesSelected.toList();
    final arrows = widget.state.arrowsSelected.toList();
    double areaNodes = 0;

    for(final node in nodes){
      areaNodes += node!.size.width * node.size.height;
    }

    // Если нет стрелок, возвращаем пустой контейнер
    if (arrows.isEmpty) return Container();

    // Рассчитываем размер прямоугольника, который вмещает все стрелки
    final boundingRect = widget.arrowManager.calculateBoundingRect(arrows);

    // Проверяем, что прямоугольник имеет ненулевой размер
    if (boundingRect.width <= 0 || boundingRect.height <= 0) {
      return Container();
    }

    final screenPositionRect = Offset(
      boundingRect.left * widget.state.scale + widget.state.offset.dx,
      boundingRect.top * widget.state.scale + widget.state.offset.dy,
    );

    // Размер узла (масштабированный)
    final arrowsSize = Size(
      boundingRect.size.width * widget.state.scale,
      boundingRect.size.height * widget.state.scale,
    );

    return widget.state.arrowsSelected.isNotEmpty
        ? Positioned(
            left: screenPositionRect.dx,
            top: screenPositionRect.dy,
            child: RepaintBoundary(
              child: CustomPaint(
                size: arrowsSize,
                painter: ArrowsCustomPainter(
                  arrows: arrows,
                  scale: widget.state.scale,
                  nodeOffset: widget.state.selectedNodeOffset,
                  arrowsSize: arrowsSize,
                  arrowsRect: boundingRect,
                  areaNodes: areaNodes,
                  arrowManager: widget.arrowManager,
                ),
              ),
            ),
          )
        : Container();
  }
}
