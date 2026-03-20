import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/input_handler.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/utils/utils.dart';
import 'package:fbpmn/src/widgets/config_action_button.dart';
import 'package:fbpmn/src/widgets/state_widget.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/arrow.dart';
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

class _ArrowsSelected extends State<ArrowsSelected> with StateWidget<ArrowsSelected> {
  ({Offset center, bool isHorizontal})? _resolveDeleteButtonPosition(Arrow arrow) {
    final coordinates =
        arrow.coordinates ?? widget.arrowManager.getArrowPathInTile(arrow, widget.state.delta).coordinates;
    if (coordinates.length < 2) {
      return null;
    }

    double bestLength = -1;
    Offset? bestCenter;
    bool bestIsHorizontal = true;

    for (int i = 0; i < coordinates.length - 1; i++) {
      final start = coordinates[i];
      final end = coordinates[i + 1];
      final dx = (end.dx - start.dx).abs();
      final dy = (end.dy - start.dy).abs();
      final isHorizontal = dx >= dy;
      final segmentLength = isHorizontal ? dx : dy;

      if (segmentLength <= 0) {
        continue;
      }

      if (segmentLength > bestLength) {
        bestLength = segmentLength;
        bestCenter = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
        bestIsHorizontal = isHorizontal;
      }
    }

    if (bestCenter == null) {
      return null;
    }

    return (center: bestCenter, isHorizontal: bestIsHorizontal);
  }

  @override
  void initState() {
    super.initState();
    widget.arrowManager.setOnStateUpdate('ArrowsSelected', (path) {
      if (path == null || path == 'ArrowsSelected') timeoutSetState();
    });
    widget.scrollHandler.setOnStateUpdate('ArrowsSelected', (path) {
      if (path == null || path == 'ArrowsSelected') timeoutSetState();
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
    final singleSelectedArrow = arrows.length == 1 ? arrows.firstOrNull : null;
    final hasSelectedNode = nodes.any((node) => node != null);
    final showDeleteButton = !hasSelectedNode && singleSelectedArrow != null;
    double areaNodes = 0;

    for (final node in nodes) {
      areaNodes += node!.size.width * node.size.height;
    }

    // Если нет стрелок, возвращаем пустой контейнер
    if (arrows.isEmpty) return Container();

    // Рассчитываем размер прямоугольника, который вмещает все стрелки
    final boundingRect = Utils.calculateBoundingRect(arrows, widget.state);
    final deleteButtonAnchor = showDeleteButton ? _resolveDeleteButtonPosition(singleSelectedArrow) : null;

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

    final buttonSize = 26.0 * widget.state.scale;
    final markerSize = buttonSize / 2;
    final actionDistance = buttonSize * 1.2;
    final diagonalOffset = actionDistance * 0.70710678118;
    final actionGroupPadding = diagonalOffset + buttonSize;
    final overlayPadding = actionGroupPadding;

    return widget.state.arrowsSelected.isNotEmpty
        ? Positioned(
            left: screenPositionRect.dx - overlayPadding,
            top: screenPositionRect.dy - overlayPadding,
            child: SizedBox(
              width: arrowsSize.width + overlayPadding * 2,
              height: arrowsSize.height + overlayPadding * 2,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: overlayPadding,
                    top: overlayPadding,
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
                          simplifiedMode: widget.state.isAutoLayoutMode,
                        ),
                      ),
                    ),
                  ),
                  if (showDeleteButton && deleteButtonAnchor != null)
                    Positioned(
                      left:
                          overlayPadding +
                          (deleteButtonAnchor.center.dx - boundingRect.left) * widget.state.scale -
                          actionGroupPadding,
                      top:
                          overlayPadding +
                          (deleteButtonAnchor.center.dy - boundingRect.top) * widget.state.scale -
                          actionGroupPadding,
                      width: actionGroupPadding * 2,
                      height: actionGroupPadding * 2,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: actionGroupPadding - markerSize / 2,
                            top: actionGroupPadding - markerSize / 2,
                            width: markerSize,
                            height: markerSize,
                            child: Container(
                              width: markerSize,
                              height: markerSize,
                              decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                            ),
                          ),
                          ConfigActionButton(
                            left: actionGroupPadding - buttonSize / 2 + diagonalOffset,
                            top: actionGroupPadding - buttonSize / 2 - diagonalOffset,
                            size: buttonSize,
                            color: Colors.red,
                            icon: Icons.remove_circle_outline_outlined,
                            cursor: SystemMouseCursors.click,
                            tooltip: 'Удалить связь',
                            onPointerDown: () {
                              widget.state.ignoreNextCanvasPointerDown = true;
                            },
                            onTap: () {
                              widget.arrowManager.confirmDeleteArrow(singleSelectedArrow);
                            },
                          ),
                          ConfigActionButton(
                            left: actionGroupPadding - buttonSize / 2 - diagonalOffset,
                            top: actionGroupPadding - buttonSize / 2 - diagonalOffset,
                            size: buttonSize,
                            color: Colors.white,
                            colorIcon: Colors.black,
                            icon: Icons.settings_outlined,
                            cursor: SystemMouseCursors.click,
                            tooltip: 'Настроить связь',
                            onPointerDown: () {
                              widget.state.ignoreNextCanvasPointerDown = true;
                            },
                            onTap: () {
                              widget.arrowManager.confirmConfigArrow(singleSelectedArrow);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          )
        : Container();
  }
}
