import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:fbpmn/src/widgets/state_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor_state.dart';
import '../services/input_handler.dart';
import '../services/node_manager.dart';
import '../services/scroll_handler.dart';
import 'hierarchical_grid.dart';
import 'node_selected.dart';
import 'scroll_bar_horizontal.dart';
import 'scroll_bar_vertical.dart';
import 'tile_border.dart';

class CanvasArea extends StatefulWidget {
  final EditorState state;
  final InputHandler inputHandler;
  final NodeManager nodeManager;
  final ArrowManager arrowManager;
  final TileManager tileManager;
  final ScrollHandler scrollHandler;

  const CanvasArea({
    super.key,
    required this.state,
    required this.inputHandler,
    required this.nodeManager,
    required this.arrowManager,
    required this.tileManager,
    required this.scrollHandler,
  });

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> with StateWidget<CanvasArea> {
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
    widget.inputHandler.setOnStateUpdate('CanvasArea', () {
      print('Event inputHandler ------');
      timeoutSetState();
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
    print('Рисую холст!!!!!');

    return Container(
      key: _containerKey,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0, //needsVerticalScrollbar ? 10 : 0,
            bottom: 0, //needsHorizontalScrollbar ? 10 : 0,
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
                        // Отображение холста и тайлов
                        HierarchicalGrid(
                          state: widget.state,
                          inputHandler: widget.inputHandler,
                          nodeManager: widget.nodeManager,
                          tileManager: widget.tileManager,
                          scrollHandler: widget.scrollHandler,
                        ),

                        // Отображение рамок тайлов
                        TileBorder(
                          state: widget.state,
                          inputHandler: widget.inputHandler,
                          tileManager: widget.tileManager,
                          scrollHandler: widget.scrollHandler,
                        ),

                        // Отображение выделенного узла на верхнем слое
                        NodeSelected(
                          state: widget.state,
                          nodeManager: widget.nodeManager,
                          arrowManager: widget.arrowManager,
                          inputHandler: widget.inputHandler,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          ScrollBarHorizontal(
            state: widget.state,
            scrollHandler: widget.scrollHandler,
            inputHandler: widget.inputHandler,
          ),
          ScrollBarVertical(
            state: widget.state,
            scrollHandler: widget.scrollHandler,
            inputHandler: widget.inputHandler,
          ),
        ],
      ),
    );
  }
}
