import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:fbpmn/src/widgets/state_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor_state.dart';
import '../models/app.model.dart';
import '../services/input_handler.dart';
import '../services/node_manager.dart';
import '../services/scroll_handler.dart';
import 'arrow_created.dart';
import 'arrow_hover.dart';
import 'arrows_selected.dart';
import 'cursor_layer.dart';
import 'hierarchical_grid.dart';
import 'node_hover.dart';
import 'node_selected.dart';
import 'node_config.dart';
import 'scroll_bar_horizontal.dart';
import 'scroll_bar_vertical.dart';
import 'snap_lines_overlay.dart';
import 'tile_border.dart';

class CanvasArea extends StatefulWidget {
  final EditorState state;
  final InputHandler inputHandler;
  final NodeManager nodeManager;
  final ArrowManager arrowManager;
  final TileManager tileManager;
  final ScrollHandler scrollHandler;
  final EventApp? appEvent;

  const CanvasArea({
    super.key,
    required this.state,
    required this.inputHandler,
    required this.nodeManager,
    required this.arrowManager,
    required this.tileManager,
    required this.scrollHandler,
    required this.appEvent,
  });

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> with StateWidget<CanvasArea> {

  // GlobalKey для получения реального размера
  final GlobalKey _containerKey = GlobalKey();
  Size _actualSize = Size.zero;
  
  // Для отслеживания resize handles
  String? _currentResizeHandle;

  @override
  void initState() {
    super.initState();
    // Отложенное обновление после построения
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateActualSize();
    });
    widget.inputHandler.setOnStateUpdate('CanvasArea', () {
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

    return Container(
      key: _containerKey,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: 0,
            child: KeyboardListener(
              focusNode: widget.inputHandler.focusNode,
              autofocus: true,
              onKeyEvent: widget.inputHandler.handleKeyEvent,
              child: CursorLayer(
                state: widget.state,
                nodeManager: widget.nodeManager,
                currentResizeHandle: _currentResizeHandle,
                child: MouseRegion(
                  onHover: (PointerHoverEvent event) {
                    if (widget.state.arrowCreated != null) {
                      widget.arrowManager.updateCreatedArrowTargetSnap(event.localPosition);
                    } else {
                      widget.state.mousePosition = event.localPosition;
                    }
                    widget.nodeManager.onHover(event.localPosition);
                    widget.arrowManager.onHover(event.localPosition, widget.tileManager);
                  },
                  onExit: (_) {
                    widget.nodeManager.clearHoveredNode();
                    widget.arrowManager.clearHoveredArrow();
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
                    if (widget.state.arrowCreated != null) {
                      widget.arrowManager.updateCreatedArrowTargetSnap(event.localPosition);
                    } else {
                      widget.state.mousePosition = event.localPosition;
                    }
                    if (widget.state.isPanning && widget.state.isShiftPressed) {
                      widget.inputHandler.handlePanUpdate(
                        event.localPosition,
                        event.delta,
                      );
                    } else if (widget.nodeManager.isResizing) {
                    } else if (widget.state.isNodeDragging) {
                      widget.nodeManager.updateNodeDrag(event.localPosition);
                    }
                  },
                  onPointerDown: (PointerDownEvent event) {
                      widget.inputHandler.handlePanStart(event.localPosition);
                  },
                  onPointerUp: (PointerUpEvent event) {
                    if (widget.nodeManager.isResizing) {
                      _currentResizeHandle = null;
                    } else {
                      widget.inputHandler.handlePanEnd();
                    }
                  },
                  onPointerCancel: (PointerCancelEvent event) {
                    if (widget.nodeManager.isResizing) {
                      _currentResizeHandle = null;
                    } else {
                      widget.inputHandler.handlePanCancel();
                    }
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
                          arrowManager: widget.arrowManager,
                          scrollHandler: widget.scrollHandler,
                        ),

                        // Отображение рамок тайлов
                        TileBorder(
                          state: widget.state,
                          inputHandler: widget.inputHandler,
                          tileManager: widget.tileManager,
                          scrollHandler: widget.scrollHandler,
                        ),

                        NodeHover(
                          state: widget.state,
                          nodeManager: widget.nodeManager,
                        ),

                        ArrowHover(
                          state: widget.state,
                          arrowManager: widget.arrowManager,
                        ),

                        // Отображение выделенного узла на верхнем слое
                        NodeSelected(
                          state: widget.state,
                          nodeManager: widget.nodeManager,
                          arrowManager: widget.arrowManager,
                          inputHandler: widget.inputHandler,
                        ),
                        
                        // Отображение выделенных связей на верхнем слое
                        ArrowsSelected(
                          state: widget.state,
                          arrowManager: widget.arrowManager,
                          inputHandler: widget.inputHandler,
                          scrollHandler: widget.scrollHandler,
                        ),

                        // Маркеры изменения размера узла
                        NodeConfig(
                          state: widget.state,
                          nodeManager: widget.nodeManager,
                        ),
                        
                        // Отображение создаваемой связи
                        ArrowCreated(
                          state: widget.state,
                          arrowManager: widget.arrowManager,
                        ),

                        // Отображение snap-линий при перетаскивании узла
                        SnapLinesOverlay(
                          state: widget.state,
                          nodeManager: widget.nodeManager,
                        ),
                      ],
                    ),
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
