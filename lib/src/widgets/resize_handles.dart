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
                        // border: Border.all(color: Colors.blue, width: 5),
                        borderRadius: isGroup || isEnum || !hasAttributes
                            ? BorderRadius.zero
                            : BorderRadius.circular(8 * scale),
                      ),
                    ),
                  ),
                ),
                // Подсветка строки атрибута и кружки
                _buildAttributeHighlight(node, nodeSize, offset, scale, lengthArrow, width),

                // Боковые маркеры
                // Top (центр по горизонтали, на расстоянии offset от верха)
                _buildSideHandle(
                  't',
                  resizeBoxContainerSize.width / 2 - lengthArrow / 2 + width / 4,
                  0,
                  lengthArrow,
                  width,
                ),
                // Right (на расстоянии offset от правого края, центр по вертикали)
                _buildSideHandle(
                  'r',
                  resizeBoxContainerSize.width - lengthArrow,
                  resizeBoxContainerSize.height / 2 - lengthArrow / 2 + width / 4,
                  lengthArrow,
                  width,
                ),
                // Bottom (центр по горизонтали, на расстоянии offset от низа)
                _buildSideHandle(
                  'b',
                  resizeBoxContainerSize.width / 2 - lengthArrow / 2 + width / 4,
                  resizeBoxContainerSize.height - lengthArrow,
                  lengthArrow,
                  width,
                ),
                // Left (на расстоянии offset от левого края, центр по вертикали)
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
        // Круглая кнопка с иконкой в правом нижнем углу - внутри расширенного контейнера
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
            // widget.nodeManager.deleteSelectedNode();
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

  /// Создаёт боковой маркер (одна линия)
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
            scale: isHoveredHandle ? 2 : 1.0,
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

  /// Создаёт подсветку строки атрибута с кружками на границах
  Widget _buildAttributeHighlight(
    dynamic node,
    Size nodeSize,
    double offset,
    double scale,
    double length,
    double width,
  ) {
    // Проверяем, есть ли атрибуты
    if (node.attributes.isEmpty) {
      return Container();
    }

    final headerHeight = EditorConfig.headerHeight;
    final circleRadius = length; // Радиус кружка (увеличенный будет length * 2)

    // Вычисляем общую область для всех атрибутов
    final totalHeight = node.size.height * scale;
    final totalWidth = nodeSize.width + offset * 2; // Включаем область для кружков

    return Positioned(
      top: offset,
      left: 0,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        onHover: (event) {
          final localPos = event.localPosition;

          // Определяем, над какой строкой атрибута находится курсор
          int? hoveredRow;
          bool hoveredLeft = false;
          bool hoveredRight = false;

          for (int rowIndex = 0; rowIndex < node.attributes.length; rowIndex++) {
            final attribute = node.attributes[rowIndex];
            if (attribute.qType != 'attribute') continue;

            final rowHeight = (node.size.height - headerHeight) / node.attributes.length;
            final minRowHeight = EditorConfig.minRowHeight;
            final actualRowHeight = math.max(rowHeight, minRowHeight);
            final rowTop = (headerHeight + actualRowHeight * rowIndex) * scale;
            final rowHeightScaled = actualRowHeight * scale;

            // Проверяем, находится ли курсор в области строки (включая кружки)
            if (localPos.dy >= rowTop && localPos.dy <= rowTop + rowHeightScaled) {
              // Курсор в области строки
              if (localPos.dx >= 0 && localPos.dx <= totalWidth) {
                hoveredRow = rowIndex;

                // Проверяем, находится ли курсор над левым кружком
                final leftCircleCenterX = length * 2; // Центр левого кружка
                final leftCircleCenterY = rowTop + rowHeightScaled / 2;
                final distToLeft = math.sqrt(
                  math.pow(localPos.dx - leftCircleCenterX, 2) + math.pow(localPos.dy - leftCircleCenterY, 2),
                );
                if (distToLeft <= circleRadius * 2) {
                  hoveredLeft = true;
                }

                // Проверяем, находится ли курсор над правым кружком
                final rightCircleCenterX = length * 2 + nodeSize.width; // Центр правого кружка
                final rightCircleCenterY = rowTop + rowHeightScaled / 2;
                final distToRight = math.sqrt(
                  math.pow(localPos.dx - rightCircleCenterX, 2) + math.pow(localPos.dy - rightCircleCenterY, 2),
                );
                if (distToRight <= circleRadius * 2) {
                  hoveredRight = true;
                }

                break;
              }
            }
          }

          // Обновляем состояние hover для строки
          if (hoveredRow != widget.state.hoveredAttributeRowIndex || widget.state.hoveredAttributeNodeId != node.id) {
            widget.nodeManager.state.hoveredAttributeRowIndex = hoveredRow;
            widget.nodeManager.state.hoveredAttributeNodeId = hoveredRow != null ? node.id : null;
            widget.nodeManager.onStateUpdate();
          }

          // Обновляем состояние hover для кружков
          final currentHoveredRow = hoveredRow ?? -1;
          final leftKey = 'attr_left_$currentHoveredRow';
          final rightKey = 'attr_right_$currentHoveredRow';

          bool needsUpdate = false;

          // Сбрасываем все hover состояния кружков
          for (final key in isHovered.keys.toList()) {
            if (key.startsWith('attr_left_') || key.startsWith('attr_right_')) {
              if (key != leftKey && key != rightKey) {
                if (isHovered[key] == true) {
                  isHovered[key] = false;
                  needsUpdate = true;
                }
              }
            }
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
        },
        onExit: (_) {
          // Сбрасываем все hover состояния при выходе из области
          widget.nodeManager.state.hoveredAttributeRowIndex = null;
          widget.nodeManager.state.hoveredAttributeNodeId = null;
          widget.nodeManager.onStateUpdate();

          bool needsUpdate = false;
          for (final key in isHovered.keys.toList()) {
            if (key.startsWith('attr_left_') || key.startsWith('attr_right_')) {
              if (isHovered[key] == true) {
                isHovered[key] = false;
                needsUpdate = true;
              }
            }
          }
          if (needsUpdate) {
            setState(() {});
          }
        },
        child: Container(
          width: totalWidth,
          height: totalHeight,
          // color: Colors.red.withOpacity(0.2),
          child: Stack(
            clipBehavior: Clip.none,
            children: _buildAttributeHighlightChildren(node, nodeSize, length, offset, headerHeight, scale),
          ),
        ),
      ),
    );
  }

  /// Создаёт дочерние виджеты для подсветки атрибутов
  List<Widget> _buildAttributeHighlightChildren(
    dynamic node,
    Size nodeSize,
    double length,
    double offset,
    double headerHeight,
    double scale,
  ) {
    final List<Widget> children = [];

    for (int rowIndex = 0; rowIndex < node.attributes.length; rowIndex++) {
      final attribute = node.attributes[rowIndex];
      if (attribute.qType != 'attribute') continue;

      final rowHeight = (node.size.height - headerHeight) / node.attributes.length;
      final minRowHeight = EditorConfig.minRowHeight;
      final actualRowHeight = math.max(rowHeight, minRowHeight);
      final rowTop = (headerHeight + actualRowHeight * rowIndex) * scale;
      final rowHeightScaled = actualRowHeight * scale;

      final isHoveredRow =
          widget.state.hoveredAttributeNodeId == node.id && widget.state.hoveredAttributeRowIndex == rowIndex;
      final isHoveredLeft = isHovered['attr_left_$rowIndex'] ?? false;
      final isHoveredRight = isHovered['attr_right_$rowIndex'] ?? false;

      if (isHoveredRow) {
        // Центральная подсветка
        children.add(
          Positioned(
            left: offset,
            top: rowTop,
            child: Container(
              width: nodeSize.width,
              height: rowHeightScaled,
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2)),
            ),
          ),
        );

        // Левый кружок
        children.add(
          Positioned(
            left: offset - length / 2,
            top: rowTop + rowHeightScaled / 2 - length / 2,
            child: AnimatedScale(
              scale: isHoveredLeft ? 2 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
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
        );

        // Правый кружок
        children.add(
          Positioned(
            left: offset + nodeSize.width - length / 2,
            top: rowTop + rowHeightScaled / 2 - length / 2,
            child: AnimatedScale(
              scale: isHoveredRight ? 2 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
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
        );
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
