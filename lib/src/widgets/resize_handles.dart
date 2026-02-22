import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../editor_state.dart';
import '../services/node_manager.dart';
import '../utils/editor_config.dart';
import 'state_widget.dart';
import '../utils/canvas_icons.dart';

/// Виджет для отображения маркеров изменения размера узла
class ResizeHandles extends StatefulWidget {
  final EditorState state;
  final NodeManager nodeManager;

  const ResizeHandles({super.key, required this.state, required this.nodeManager});

  @override
  State<ResizeHandles> createState() => _ResizeHandlesState();
}

class _ResizeHandlesState extends State<ResizeHandles> with StateWidget<ResizeHandles> {
  Map<String, bool> isHovered = {};

  @override
  void initState() {
    super.initState();
    widget.nodeManager.setOnStateUpdate('ResizeHandles', () {
      timeoutSetState();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Проверяем, есть ли выделенный узел
    if (widget.state.nodesSelected.isEmpty || widget.state.nodesSelected.length > 1) return Container();

    final node = widget.state.nodesSelected.first!;
    final scale = widget.state.scale;
    final hasAttributes = node.attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isGroup = node.qType == 'group';

    final offset = NodeManager.resizeHandleOffset * scale;
    final lengthArrow = NodeManager.arrowHandleWidth * scale;
    final width = NodeManager.resizeHandleBorderWidth * scale;

    // Размер узла (масштабированный)
    final nodeSize = Size(node.size.width * scale, node.size.height * scale);
    final resizeBoxContainerSize = Size(nodeSize.width + offset * 2, nodeSize.height + offset * 2);

    // рамка (масштабированный)
    final frame = widget.nodeManager.frameTotalOffset;

    final containerLeft = widget.state.selectedNodeOffset.dx + frame - offset - width / 4;
    final containerTop = widget.state.selectedNodeOffset.dy + frame - offset - width / 4;
    final buttonSize = 26.0 * scale;

    final showHandles =
        node.qType != 'swimlane' || (node.qType == 'swimlane' && node.isCollapsed != null && node.isCollapsed!);

    if (!showHandles) return Container();

    // Позиция кнопки относительно контейнера
    final buttonTop = containerTop - buttonSize / 2;
    final buttonRight = containerLeft + resizeBoxContainerSize.width - buttonSize / 2;
    final buttonBottom = containerTop + resizeBoxContainerSize.height - buttonSize / 2;

    return Stack(
      children: [
        Positioned(
          left: containerLeft,
          top: containerTop,
          child: Container(
            width: resizeBoxContainerSize.width,
            height: resizeBoxContainerSize.height,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: isGroup || isEnum || !hasAttributes ? BorderRadius.zero : BorderRadius.circular(8 * scale),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: offset,
                  top: offset,
                  child: IgnorePointer(
                    child: Container(
                      width: nodeSize.width,
                      height: nodeSize.height,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: isGroup || isEnum || !hasAttributes
                            ? BorderRadius.zero
                            : BorderRadius.circular(8 * scale),
                      ),
                    ),
                  ),
                ),
                // Подсветка строки атрибута и кружки для всех узлов, включая вложенные в группу
                _buildAllAttributesHighlights(node, nodeSize, offset, scale, lengthArrow, width),

                // Боковые маркеры
                _buildSideHandle(
                  't',
                  resizeBoxContainerSize.width / 2 - lengthArrow / 2 + width / 4,
                  0,
                  lengthArrow,
                  width,
                ),
                _buildSideHandle(
                  'r',
                  resizeBoxContainerSize.width - lengthArrow,
                  resizeBoxContainerSize.height / 2 - lengthArrow / 2 + width / 4,
                  lengthArrow,
                  width,
                ),
                _buildSideHandle(
                  'b',
                  resizeBoxContainerSize.width / 2 - lengthArrow / 2 + width / 4,
                  resizeBoxContainerSize.height - lengthArrow,
                  lengthArrow,
                  width,
                ),
                _buildSideHandle(
                  'l',
                  0,
                  resizeBoxContainerSize.height / 2 - lengthArrow / 2 + width / 4,
                  lengthArrow,
                  width,
                ),
              ],
            ),
          ),
        ),
        _buildRemoveButton(buttonRight, buttonTop, buttonSize),
        _buildResizeButton(buttonRight, buttonBottom, buttonSize),
      ],
    );
  }

  /// Создаёт круглую кнопку для удаления узла
  Widget _buildRemoveButton(double left, double top, double size) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            // TODO: Добавить логику удаления узла
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Center(
              child: CustomPaint(
                size: Size(size * 0.5, size * 0.5),
                painter: _IconPainter(painter: CanvasIcons.paintDelete, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Создаёт круглую кнопку для изменения размера
  Widget _buildResizeButton(double left, double top, double size) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            widget.nodeManager.startResize(event.position);
          },
          onPointerMove: (event) {
            if (widget.nodeManager.isResizing) {
              widget.nodeManager.updateResize(event.position);
            }
          },
          onPointerUp: (event) {
            widget.nodeManager.endResize();
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Center(
              child: CustomPaint(
                size: Size(size * 0.5, size * 0.5),
                painter: _IconPainter(painter: CanvasIcons.paintResize, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Создаёт боковой маркер с увеличенной анимацией при ховере (3x)
  Widget _buildSideHandle(String handle, double left, double top, double length, double width) {
    final isHoveredHandle = isHovered[handle] ?? false;

    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.opaque,
        onEnter: (_) {
          setState(() {
            isHovered[handle] = true;
          });
        },
        onExit: (_) {
          setState(() {
            isHovered[handle] = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: length,
          height: length,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
          child: AnimatedScale(
            scale: isHoveredHandle ? 3.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Container(
              width: length,
              height: length,
              decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              child: isHoveredHandle
                  ? Center(
                      child: CustomPaint(
                        size: Size(length * 0.6, length * 0.6),
                        painter: _DirectionArrowPainter(direction: handle, color: Colors.white),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  /// Создаёт подсветку атрибутов для всех узлов, включая вложенные в группу
  Widget _buildAllAttributesHighlights(
    dynamic node,
    Size nodeSize,
    double offset,
    double scale,
    double length,
    double width,
  ) {
    // Собираем все узлы для отображения атрибутов (текущий узел и вложенные, если это группа)
    final List<dynamic> nodesToProcess = [];
    final isGroup = node.qType == 'group';

    if (isGroup && node.children != null) {
      // Явно приводим children к списку и фильтруем
      final children = List<dynamic>.from(node.children);
      for (var child in children) {
        if (child.attributes != null && child.attributes.isNotEmpty) {
          nodesToProcess.add(child);
        }
      }
    }

    // Добавляем текущий узел, если у него есть атрибуты
    if (node.attributes != null && node.attributes.isNotEmpty) {
      nodesToProcess.add(node);
    }

    if (nodesToProcess.isEmpty) return Container();

    final headerHeight = EditorConfig.headerHeight;
    final circleRadius = length / 2;

    return Positioned(
      top: offset,
      left: 0,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        onHover: (event) {
          final localPos = event.localPosition;

          // Проверяем все узлы
          for (final currentNode in nodesToProcess) {
            // Для вложенных узлов учитываем их реальный размер и позицию
            final nodeOffset = currentNode == node ? 0.0 : (currentNode.position.dy * scale);
            final currentNodeWidth = currentNode.size.width * scale;
            final currentNodeHeight = currentNode.size.height * scale;

            // Проверяем, есть ли атрибуты у текущего узла
            if (currentNode.attributes == null || currentNode.attributes.isEmpty) continue;

            for (int rowIndex = 0; rowIndex < currentNode.attributes.length; rowIndex++) {
              final attribute = currentNode.attributes[rowIndex];
              if (attribute.qType != 'attribute') continue;

              final rowHeight = (currentNode.size.height - headerHeight) / currentNode.attributes.length;
              final minRowHeight = EditorConfig.minRowHeight;
              final actualRowHeight = math.max(rowHeight, minRowHeight);
              final rowTop = (headerHeight + actualRowHeight * rowIndex) * scale + nodeOffset;
              final rowHeightScaled = actualRowHeight * scale;

              // Проверяем, находится ли курсор в области строки вложенного узла
              if (localPos.dy >= rowTop && localPos.dy <= rowTop + rowHeightScaled) {
                // Проверяем по ширине вложенного узла (с учетом offset для кружков)
                if (localPos.dx >= 0 && localPos.dx <= offset * 2 + currentNodeWidth) {
                  // Обновляем состояние hover для строки
                  if (widget.state.hoveredAttributeRowIndex != rowIndex ||
                      widget.state.hoveredAttributeNodeId != currentNode.id) {
                    widget.nodeManager.state.hoveredAttributeRowIndex = rowIndex;
                    widget.nodeManager.state.hoveredAttributeNodeId = currentNode.id;
                    widget.nodeManager.onStateUpdate();
                  }

                  // Проверяем hover для кружков с учетом размеров вложенного узла
                  final leftCircleCenterX = offset;
                  final rightCircleCenterX = offset + currentNodeWidth;
                  final circleCenterY = rowTop + rowHeightScaled / 2;

                  final distToLeft = math.sqrt(
                    math.pow(localPos.dx - leftCircleCenterX, 2) + math.pow(localPos.dy - circleCenterY, 2),
                  );
                  final distToRight = math.sqrt(
                    math.pow(localPos.dx - rightCircleCenterX, 2) + math.pow(localPos.dy - circleCenterY, 2),
                  );

                  final hoveredLeft = distToLeft <= circleRadius * 3;
                  final hoveredRight = distToRight <= circleRadius * 3;

                  final leftKey = 'attr_left_${currentNode.id}_$rowIndex';
                  final rightKey = 'attr_right_${currentNode.id}_$rowIndex';

                  bool needsUpdate = false;

                  // Сбрасываем старые состояния
                  final keysToRemove = [];
                  for (final key in isHovered.keys) {
                    if (key.startsWith('attr_left_') || key.startsWith('attr_right_')) {
                      if (key != leftKey && key != rightKey) {
                        keysToRemove.add(key);
                      }
                    }
                  }
                  for (final key in keysToRemove) {
                    isHovered.remove(key);
                    needsUpdate = true;
                  }

                  if (isHovered[leftKey] != hoveredLeft) {
                    isHovered[leftKey] = hoveredLeft;
                    needsUpdate = true;
                  }
                  if (isHovered[rightKey] != hoveredRight) {
                    isHovered[rightKey] = hoveredRight;
                    needsUpdate = true;
                  }

                  if (needsUpdate) {
                    setState(() {});
                  }
                  return;
                }
              }
            }
          }

          // Сбрасываем если не нашли
          _resetHoverState();
        },
        onExit: (_) {
          _resetHoverState();
        },
        child: Container(
          width: offset * 2 + nodeSize.width,
          height: nodeSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: _buildAllAttributesHighlightChildren(
              nodesToProcess,
              node,
              nodeSize,
              offset,
              headerHeight,
              scale,
              length,
            ),
          ),
        ),
      ),
    );
  }

  /// Сбрасывает состояние hover
  void _resetHoverState() {
    widget.nodeManager.state.hoveredAttributeRowIndex = null;
    widget.nodeManager.state.hoveredAttributeNodeId = null;
    widget.nodeManager.onStateUpdate();

    bool needsUpdate = false;
    final keysToRemove = [];
    for (final key in isHovered.keys) {
      if (key.startsWith('attr_left_') || key.startsWith('attr_right_')) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      isHovered.remove(key);
      needsUpdate = true;
    }

    if (needsUpdate) {
      setState(() {});
    }
  }

  /// Создаёт дочерние виджеты для подсветки атрибутов всех узлов
  List<Widget> _buildAllAttributesHighlightChildren(
    List<dynamic> nodesToProcess,
    dynamic mainNode,
    Size mainNodeSize,
    double offset,
    double headerHeight,
    double scale,
    double length,
  ) {
    final List<Widget> children = [];

    for (final node in nodesToProcess) {
      // Проверяем наличие атрибутов
      if (node.attributes == null || node.attributes.isEmpty) continue;

      // Для каждого узла используем его собственные размеры
      final nodeOffset = node == mainNode ? 0.0 : (node.position.dy * scale);
      final currentNodeWidth = node.size.width * scale;

      for (int rowIndex = 0; rowIndex < node.attributes.length; rowIndex++) {
        final attribute = node.attributes[rowIndex];
        if (attribute.qType != 'attribute') continue;

        final rowHeight = (node.size.height - headerHeight) / node.attributes.length;
        final minRowHeight = EditorConfig.minRowHeight;
        final actualRowHeight = math.max(rowHeight, minRowHeight);
        final rowTop = (headerHeight + actualRowHeight * rowIndex) * scale + nodeOffset;
        final rowHeightScaled = actualRowHeight * scale;

        final isHoveredRow =
            widget.state.hoveredAttributeNodeId == node.id && widget.state.hoveredAttributeRowIndex == rowIndex;
        final isHoveredLeft = isHovered['attr_left_${node.id}_$rowIndex'] ?? false;
        final isHoveredRight = isHovered['attr_right_${node.id}_$rowIndex'] ?? false;

        if (isHoveredRow) {
          // Центральная подсветка для вложенного узла с его размерами
          children.add(
            Positioned(
              left: offset,
              top: rowTop,
              child: Container(
                width: currentNodeWidth, // Используем ширину вложенного узла
                height: rowHeightScaled,
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2)),
              ),
            ),
          );

          // Левый кружок с анимацией 3x - позиционируется относительно вложенного узла
          children.add(
            Positioned(
              left: offset - length / 2,
              top: rowTop + rowHeightScaled / 2 - length / 2,
              child: AnimatedScale(
                scale: isHoveredLeft ? 3.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: MouseRegion(
                  onEnter: (_) {
                    setState(() {
                      isHovered['attr_left_${node.id}_$rowIndex'] = true;
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      isHovered['attr_left_${node.id}_$rowIndex'] = false;
                    });
                  },
                  child: Container(
                    width: length,
                    height: length,
                    decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: isHoveredLeft
                        ? Center(
                            child: CustomPaint(
                              size: Size(length * 0.6, length * 0.6),
                              painter: _DirectionArrowPainter(direction: 'l', color: Colors.white),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          );

          // Правый кружок с анимацией 3x - позиционируется относительно вложенного узла
          children.add(
            Positioned(
              left: offset + currentNodeWidth - length / 2, // Используем ширину вложенного узла
              top: rowTop + rowHeightScaled / 2 - length / 2,
              child: AnimatedScale(
                scale: isHoveredRight ? 3.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: MouseRegion(
                  onEnter: (_) {
                    setState(() {
                      isHovered['attr_right_${node.id}_$rowIndex'] = true;
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      isHovered['attr_right_${node.id}_$rowIndex'] = false;
                    });
                  },
                  child: Container(
                    width: length,
                    height: length,
                    decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: isHoveredRight
                        ? Center(
                            child: CustomPaint(
                              size: Size(length * 0.6, length * 0.6),
                              painter: _DirectionArrowPainter(direction: 'r', color: Colors.white),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return children;
  }
}

/// CustomPainter для отрисовки canvas иконки
class _IconPainter extends CustomPainter {
  final void Function(Canvas, Size, Color) painter;
  final Color color;

  _IconPainter({required this.painter, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    painter(canvas, size, color);
  }

  @override
  bool shouldRepaint(covariant _IconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// CustomPainter для отрисовки стрелки направления
class _DirectionArrowPainter extends CustomPainter {
  final String direction;
  final Color color;

  _DirectionArrowPainter({required this.direction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    CanvasIcons.paintDirectionArrow(canvas, size, color, direction);
  }

  @override
  bool shouldRepaint(covariant _DirectionArrowPainter oldDelegate) {
    return oldDelegate.direction != direction || oldDelegate.color != color;
  }
}
