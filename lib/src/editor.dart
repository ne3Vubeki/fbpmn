import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/node.dart';
import 'models/table.node.dart';
import 'widgets/hierarchical_grid_painter.dart';

class StableGridCanvas extends StatefulWidget {
  final Map diagram;
  const StableGridCanvas({super.key, required this.diagram});

  @override
  State<StableGridCanvas> createState() => _StableGridCanvasState();
}

class _StableGridCanvasState extends State<StableGridCanvas> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _isShiftPressed = false;

  // Добавляем флаг для отслеживания только навигации (скроллинг/масштабирование)
  bool _isNavigationOnly = false;

  final FocusNode _focusNode = FocusNode();

  final double _canvasSizeMultiplier = 3.0;

  Offset _mousePosition = Offset.zero;

  Offset _panStartOffset = Offset.zero;
  Offset _panStartMousePosition = Offset.zero;
  bool _isPanning = false;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  bool _updatingFromScroll = false;

  Size _viewportSize = Size.zero;
  bool _isInitialized = false;

  // Для перемещения скроллбаров
  bool _isHorizontalScrollbarDragging = false;
  bool _isVerticalScrollbarDragging = false;
  Offset _horizontalScrollbarDragStart = Offset.zero;
  Offset _verticalScrollbarDragStart = Offset.zero;
  double _horizontalScrollbarStartOffset = 0.0;
  double _verticalScrollbarStartOffset = 0.0;

  // Для работы с узлами
  final List<TableNode> _nodes = [];
  Offset _delta = Offset.zero;
  Node? _selectedNode;
  bool _isNodeDragging = false;
  Offset _nodeDragStart = Offset.zero;
  Offset _nodeStartPosition = Offset.zero;

  @override
  void initState() {
    super.initState();

    final objects = widget.diagram['objects'];
    final metadata = widget.diagram['metadata'];
    final double dx = (metadata['dx'] as num).toDouble();
    final double dy = (metadata['dy'] as num).toDouble();

    _delta = Offset(dx, dy);

    for (final object in objects) {
      _nodes.add(TableNode.fromJson(object));
    }

    _horizontalScrollController.addListener(_onHorizontalScroll);
    _verticalScrollController.addListener(_onVerticalScroll);
  }

  // void _addNodeAt(Offset position) {
  //   setState(() {
  //     final newNode = TableNode(
  //       id: DateTime.now().millisecondsSinceEpoch.toString(),
  //       position: position,
  //       text: 'Node ${_nodes.length + 1}',
  //     );
  //     _nodes.add(newNode);
  //   });
  // }

  void _deleteSelectedNode() {
    if (_selectedNode != null) {
      setState(() {
        _nodes.removeWhere((node) => node.id == _selectedNode!.id);
        _selectedNode = null;
      });
    }
  }

  void _selectNodeAtPosition(Offset position) {
    final worldPos = (position - _offset) / _scale;

    setState(() {
      // Снимаем выделение со всех узлов
      for (final node in _nodes) {
        node.isSelected = false;
      }
      _selectedNode = null;

      // Ищем узел под курсором (в обратном порядке для приоритета верхних узлов)
      for (int i = _nodes.length - 1; i >= 0; i--) {
        final node = _nodes[i];
        final deltaPosition = node.position + _delta;
        final nodeRect = Rect.fromPoints(
          deltaPosition,
          Offset(
            deltaPosition.dx + node.size.width,
            deltaPosition.dy + node.size.height,
          ),
        );

        if (nodeRect.contains(worldPos)) {
          node.isSelected = true;
          _selectedNode = node;
          break;
        }
      }
    });
  }

  void _startNodeDrag(Offset position) {
    if (_selectedNode != null) {
      setState(() {
        _isNodeDragging = true;
        _nodeDragStart = position;
        _nodeStartPosition = _selectedNode!.position;
      });
    }
  }

  void _updateNodeDrag(Offset position) {
    if (_isNodeDragging && _selectedNode != null) {
      setState(() {
        final delta = (position - _nodeDragStart) / _scale;
        _selectedNode!.position = _nodeStartPosition + delta;
      });
    }
  }

  void _endNodeDrag() {
    setState(() {
      _isNodeDragging = false;
    });
  }

  void _centerCanvas() {
    setState(() {
      _offset = Offset(
        (_viewportSize.width - _viewportSize.width * _canvasSizeMultiplier) / 2,
        (_viewportSize.height - _viewportSize.height * _canvasSizeMultiplier) /
            2,
      );

      _updateScrollControllers();
      _isInitialized = true;
    });
  }

  void _resetZoom() {
    setState(() {
      _isNavigationOnly = true;
      _scale = 1.0;
      _centerCanvas();
    });
  }

  void _updateScrollControllers() {
    if (_updatingFromScroll) return;

    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double horizontalMaxScroll = max(0, canvasSize.width - _viewportSize.width);
    double verticalMaxScroll = max(0, canvasSize.height - _viewportSize.height);

    num horizontalPosition = -_offset.dx.clamp(-horizontalMaxScroll, 0);
    num verticalPosition = -_offset.dy.clamp(-verticalMaxScroll, 0);

    _horizontalScrollController.jumpTo(
      horizontalPosition.clamp(0, horizontalMaxScroll).toDouble(),
    );
    _verticalScrollController.jumpTo(
      verticalPosition.clamp(0, verticalMaxScroll).toDouble(),
    );
  }

  void _onHorizontalScroll() {
    if (_updatingFromScroll) return;

    _updatingFromScroll = true;

    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double horizontalMaxScroll = max(0, canvasSize.width - _viewportSize.width);
    num newOffsetX = -_horizontalScrollController.offset.clamp(
      0,
      horizontalMaxScroll,
    );

    setState(() {
      _offset = Offset(newOffsetX.toDouble(), _offset.dy);
    });

    _updatingFromScroll = false;
  }

  void _onVerticalScroll() {
    if (_updatingFromScroll) return;

    _updatingFromScroll = true;

    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double verticalMaxScroll = max(0, canvasSize.height - _viewportSize.height);
    num newOffsetY = -_verticalScrollController.offset.clamp(
      0,
      verticalMaxScroll,
    );

    setState(() {
      _offset = Offset(_offset.dx, newOffsetY.toDouble());
    });

    _updatingFromScroll = false;
  }

  void _handleZoom(double delta, Offset localPosition) {
    setState(() {
      double oldScale = _scale;

      double newScale = _scale * (1 + delta * 0.001);

      // Ограничения зума
      if (newScale < 0.35) {
        newScale = 0.35;
      } else if (newScale > 5.0) {
        newScale = 5.0;
      }

      // Корректировка смещения для фокуса на курсоре
      double zoomFactor = newScale / oldScale;
      Offset mouseInCanvas = (localPosition - _offset);
      Offset newOffset = localPosition - mouseInCanvas * zoomFactor;

      _scale = newScale;
      _offset = _constrainOffset(newOffset);

      _updateScrollControllers();
    });
  }

  Offset _constrainOffset(Offset offset) {
    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double constrainedX = offset.dx;
    double constrainedY = offset.dy;

    double maxXOffset = _viewportSize.width - canvasSize.width;
    double maxYOffset = _viewportSize.height - canvasSize.height;

    if (constrainedX > 0) {
      constrainedX = 0;
    }
    if (constrainedX < maxXOffset) {
      constrainedX = maxXOffset;
    }

    if (constrainedY > 0) {
      constrainedY = 0;
    }
    if (constrainedY < maxYOffset) {
      constrainedY = maxYOffset;
    }

    return Offset(constrainedX, constrainedY);
  }

  void _handleHorizontalScrollbarDragStart(PointerDownEvent details) {
    setState(() {
      _isHorizontalScrollbarDragging = true;
      _horizontalScrollbarDragStart = details.localPosition;
      _horizontalScrollbarStartOffset = _horizontalScrollController.offset;
    });
  }

  void _handleHorizontalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!_isHorizontalScrollbarDragging) return;

    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double horizontalMaxScroll = max(0, canvasSize.width - _viewportSize.width);
    if (horizontalMaxScroll == 0) return;

    // Вычисляем соотношение размеров для правильной скорости перемещения
    double viewportToCanvasRatio = canvasSize.width / _viewportSize.width;

    // Применяем соотношение к перемещению мыши для синхронизации скоростей
    double delta =
        (details.localPosition.dx - _horizontalScrollbarDragStart.dx) *
        viewportToCanvasRatio;

    double newScrollOffset = (_horizontalScrollbarStartOffset + delta).clamp(
      0,
      horizontalMaxScroll,
    );

    _updatingFromScroll = true;
    _horizontalScrollController.jumpTo(newScrollOffset);
    _updatingFromScroll = false;

    double newOffsetX = -newScrollOffset;
    setState(() {
      _offset = Offset(newOffsetX, _offset.dy);
    });
  }

  void _handleHorizontalScrollbarDragEnd(PointerUpEvent details) {
    setState(() {
      _isHorizontalScrollbarDragging = false;
    });
  }

  void _handleVerticalScrollbarDragStart(PointerDownEvent details) {
    setState(() {
      _isVerticalScrollbarDragging = true;
      _verticalScrollbarDragStart = details.localPosition;
      _verticalScrollbarStartOffset = _verticalScrollController.offset;
    });
  }

  void _handleVerticalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!_isVerticalScrollbarDragging) return;

    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double verticalMaxScroll = max(0, canvasSize.height - _viewportSize.height);
    if (verticalMaxScroll == 0) return;

    // Вычисляем соотношение размеров для правильной скорости перемещения
    double viewportToCanvasRatio = canvasSize.height / _viewportSize.height;

    // Применяем соотношение к перемещению мыши для синхронизации скоростей
    double delta =
        (details.localPosition.dy - _verticalScrollbarDragStart.dy) *
        viewportToCanvasRatio;

    double newScrollOffset = (_verticalScrollbarStartOffset + delta).clamp(
      0,
      verticalMaxScroll,
    );

    _updatingFromScroll = true;
    _verticalScrollController.jumpTo(newScrollOffset);
    _updatingFromScroll = false;

    double newOffsetY = -newScrollOffset;
    setState(() {
      _offset = Offset(_offset.dx, newOffsetY);
    });
  }

  void _handleVerticalScrollbarDragEnd(PointerUpEvent details) {
    setState(() {
      _isVerticalScrollbarDragging = false;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (!_isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _centerCanvas();
          });
        }

        final Size baseCanvasSize = Size(
          _viewportSize.width * _canvasSizeMultiplier,
          _viewportSize.height * _canvasSizeMultiplier,
        );

        final Size scaledCanvasSize = Size(
          baseCanvasSize.width * _scale,
          baseCanvasSize.height * _scale,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateScrollControllers();
        });

        return Row(
          children: [
            // Контент с холстом
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 10,
                    bottom: 10,
                    child: KeyboardListener(
                      focusNode: _focusNode,
                      autofocus: true,
                      onKeyEvent: (KeyEvent event) {
                        if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                            event.logicalKey == LogicalKeyboardKey.shiftRight) {
                          setState(() {
                            _isShiftPressed =
                                event is KeyDownEvent ||
                                event is KeyRepeatEvent;
                          });
                        }
                        // Обработка удаления узла
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.delete) {
                          _deleteSelectedNode();
                        }
                      },
                      child: MouseRegion(
                        cursor: _isShiftPressed && _isPanning
                            ? SystemMouseCursors.grabbing
                            : _isShiftPressed
                            ? SystemMouseCursors.grab
                            : SystemMouseCursors.basic,
                        onHover: (PointerHoverEvent event) {
                          _mousePosition = event.localPosition;
                        },
                        child: Listener(
                          onPointerSignal: (pointerSignal) {
                            if (pointerSignal is PointerScrollEvent &&
                                _isShiftPressed) {
                              _handleZoom(
                                pointerSignal.scrollDelta.dy,
                                _mousePosition,
                              );
                            }
                          },
                          onPointerMove: (PointerMoveEvent event) {
                            _mousePosition = event.localPosition;

                            if (_isPanning && _isShiftPressed) {
                              setState(() {
                                Offset delta =
                                    event.localPosition -
                                    _panStartMousePosition;
                                Offset newOffset = _panStartOffset + delta;

                                _offset = _constrainOffset(newOffset);

                                _updateScrollControllers();
                              });
                            } else if (_isNodeDragging) {
                              _updateNodeDrag(event.localPosition);
                            }
                          },
                          onPointerDown: (PointerDownEvent event) {
                            if (_isShiftPressed) {
                              setState(() {
                                _isPanning = true;
                                _panStartOffset = _offset;
                                _panStartMousePosition = event.localPosition;
                              });
                            } else {
                              _selectNodeAtPosition(event.localPosition);
                              _startNodeDrag(event.localPosition);
                            }
                            _focusNode.requestFocus();
                          },
                          onPointerUp: (PointerUpEvent event) {
                            setState(() {
                              _isPanning = false;
                            });
                            _endNodeDrag();
                          },
                          onPointerCancel: (PointerCancelEvent event) {
                            setState(() {
                              _isPanning = false;
                            });
                            _endNodeDrag();
                          },
                          child: ClipRect(
                            child: CustomPaint(
                              size: scaledCanvasSize,
                              painter: HierarchicalGridPainter(
                                scale: _scale,
                                offset: _offset,
                                canvasSize: scaledCanvasSize,
                                nodes: _nodes,
                                delta: _delta,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Горизонтальный скроллбар с возможностью перетаскивания
                  Positioned(
                    left: 0,
                    right: 10,
                    bottom: 0,
                    height: 10,
                    child: Listener(
                      onPointerDown: _handleHorizontalScrollbarDragStart,
                      onPointerMove: _handleHorizontalScrollbarDragUpdate,
                      onPointerUp: _handleHorizontalScrollbarDragEnd,
                      child: Scrollbar(
                        controller: _horizontalScrollController,
                        thumbVisibility: true,
                        trackVisibility: false,
                        thickness: 10,
                        child: SingleChildScrollView(
                          controller: _horizontalScrollController,
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

                  // Вертикальный скроллбар с возможностью перетаскивания
                  Positioned(
                    top: 0,
                    bottom: 10,
                    right: 0,
                    width: 10,
                    child: Listener(
                      onPointerDown: _handleVerticalScrollbarDragStart,
                      onPointerMove: _handleVerticalScrollbarDragUpdate,
                      onPointerUp: _handleVerticalScrollbarDragEnd,
                      child: Scrollbar(
                        controller: _verticalScrollController,
                        thumbVisibility: true,
                        trackVisibility: false,
                        thickness: 10,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          physics: const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: 10,
                            height: scaledCanvasSize.height,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Панель зума
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(_scale * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.zoom_out_map, size: 18),
                            onPressed: _resetZoom,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            tooltip: 'Reset to 100%',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Кнопка добавления узла
                  Positioned(
                    right: 20,
                    bottom: 70,
                    child: FloatingActionButton(
                      onPressed: () {
                        // _addNodeAt((_mousePosition - _offset) / _scale);
                      },
                      mini: true,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
