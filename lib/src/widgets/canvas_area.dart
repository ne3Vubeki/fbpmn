import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor_state.dart';
import '../services/input_handler.dart';
import '../services/node_manager.dart';
import '../services/scroll_handler.dart';
import '../painters/tile_border_painter.dart';
import '../painters/node_custom_painter.dart';
import '../painters/hierarchical_grid_painter.dart';

class CanvasArea extends StatefulWidget {
  final EditorState state;
  final InputHandler inputHandler;
  final NodeManager nodeManager;
  final ScrollHandler scrollHandler;

  const CanvasArea({
    super.key,
    required this.state,
    required this.inputHandler,
    required this.nodeManager,
    required this.scrollHandler,
  });

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> {
  // Используем константы из NodeManager
  double get framePadding => NodeManager.framePadding;
  double get frameBorderWidth => NodeManager.frameBorderWidth;
  double get frameTotalOffset => NodeManager.frameTotalOffset;

  // GlobalKey для получения реального размера
  final GlobalKey _containerKey = GlobalKey();
  Size _actualSize = Size.zero;

  @override
  void initState() {
    super.initState();
    // Отложенное обновление после построения
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateActualSize();
    });
  }

  void _updateActualSize() {
    if (_containerKey.currentContext != null) {
      final RenderBox renderBox =
          _containerKey.currentContext!.findRenderObject() as RenderBox;
      final newSize = renderBox.size;

      if (_actualSize != newSize) {
        _actualSize = newSize;

        // Обновляем viewportSize в состоянии
        if (widget.state.viewportSize != _actualSize) {
          widget.state.viewportSize = _actualSize;
          widget.scrollHandler.handleViewportResize(_actualSize);
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant CanvasArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем размер после изменения виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateActualSize();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Используем динамический размер холста с учетом масштаба
    // Размер рассчитывается в ScrollHandler на основе расположения узлов
    final Size scaledCanvasSize = Size(
      widget.scrollHandler.dynamicCanvasWidth * widget.state.scale,
      widget.scrollHandler.dynamicCanvasHeight * widget.state.scale,
    );

    final bool needsHorizontalScrollbar =
        scaledCanvasSize.width > widget.state.viewportSize.width;
    final bool needsVerticalScrollbar =
        scaledCanvasSize.height > widget.state.viewportSize.height;

    return Container(
      key: _containerKey,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: needsVerticalScrollbar ? 10 : 0,
            bottom: needsHorizontalScrollbar ? 10 : 0,
            child: KeyboardListener(
              focusNode: widget.inputHandler.focusNode,
              autofocus: true,
              onKeyEvent: widget.inputHandler.handleKeyEvent,
              child: MouseRegion(
                cursor: widget.state.isShiftPressed && widget.state.isPanning
                    ? SystemMouseCursors.grabbing
                    : widget.state.isShiftPressed
                    ? SystemMouseCursors.grab
                    : SystemMouseCursors.basic,
                onHover: (PointerHoverEvent event) {
                  widget.state.mousePosition = event.localPosition;
                },
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent &&
                        widget.state.isShiftPressed) {
                      widget.inputHandler.handleZoom(
                        pointerSignal.scrollDelta.dy,
                        widget.state.mousePosition,
                      );
                    }
                  },
                  onPointerMove: (PointerMoveEvent event) {
                    widget.state.mousePosition = event.localPosition;

                    if (widget.state.isPanning && widget.state.isShiftPressed) {
                      widget.inputHandler.handlePanUpdate(
                        event.localPosition,
                        event.delta,
                      );
                    } else if (widget.state.isNodeDragging) {
                      widget.nodeManager.updateNodeDrag(event.localPosition);
                    }
                  },
                  onPointerDown: (PointerDownEvent event) {
                    widget.inputHandler.handlePanStart(event.localPosition);
                  },
                  onPointerUp: (PointerUpEvent event) {
                    widget.inputHandler.handlePanEnd();
                  },
                  onPointerCancel: (PointerCancelEvent event) {
                    widget.inputHandler.handlePanCancel();
                  },
                  child: ClipRect(
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: scaledCanvasSize,
                          painter: HierarchicalGridPainter(
                            scale: widget.state.scale,
                            offset: widget.state.offset,
                            canvasSize: scaledCanvasSize,
                            nodes: widget.state.nodes,
                            delta: widget.state.delta,
                            state: widget.state,
                            tileScale: 2.0,
                          ),
                        ),

                        if (widget.state.showTileBorders)
                          CustomPaint(
                            size: scaledCanvasSize,
                            painter: TileBorderPainter(
                              scale: widget.state.scale,
                              offset: widget.state.offset,
                              state: widget.state,
                            ),
                          ),

                        // Отображение выделенного узла на верхнем слое
                        if (widget.state.isNodeOnTopLayer &&
                            widget.state.selectedNodeOnTopLayer != null)
                          _buildSelectedNode(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (needsHorizontalScrollbar)
            Positioned(
              left: 0,
              right: needsVerticalScrollbar ? 10 : 0,
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
                      controller:
                          widget.scrollHandler.horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: scaledCanvasSize.width,
                        height: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (needsVerticalScrollbar)
            Positioned(
              top: 0,
              bottom: needsHorizontalScrollbar ? 10 : 0,
              right: 0,
              width: 10,
              child: Listener(
                onPointerDown:
                    widget.scrollHandler.handleVerticalScrollbarDragStart,
                onPointerMove:
                    widget.scrollHandler.handleVerticalScrollbarDragUpdate,
                onPointerUp:
                    widget.scrollHandler.handleVerticalScrollbarDragEnd,
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
                        height: scaledCanvasSize.height,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedNode() {
    if (widget.state.selectedNodeOnTopLayer == null) return Container();

    final node = widget.state.selectedNodeOnTopLayer!;
    final hasAttributes = node.attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isNotGroup = node.groupId != null;

    // Размер узла (масштабированный)
    final nodeSize = Size(
      node.size.width * widget.state.scale,
      node.size.height * widget.state.scale,
    );

    return Positioned(
      left: widget.state.selectedNodeOffset.dx,
      top: widget.state.selectedNodeOffset.dy,
      child: Container(
        padding: widget.state.framePadding,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: frameBorderWidth),
          borderRadius: isNotGroup || isEnum || !hasAttributes
              ? BorderRadius.zero
              : BorderRadius.circular(12),
        ),
        child: CustomPaint(
          size: nodeSize,
          painter: NodeCustomPainter(
            node: node,
            isSelected: true,
            targetSize: nodeSize,
          ),
        ),
      ),
    );
  }
}
