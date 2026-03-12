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
    // рамка (масштабированный)
    final frame = widget.nodeManager.frameTotalOffset;

    // Размер узла (масштабированный)
    final nodeSize = Size(node.size.width * scale, node.size.height * scale);
    final resizeBoxContainerSize = Size(
      nodeSize.width + offset * 2 + frame * 2,
      nodeSize.height + offset * 2 + frame * 2,
    );

    final containerLeft = widget.state.selectedNodeOffset.dx - offset - width / 4;
    final containerTop = widget.state.selectedNodeOffset.dy - offset - width / 4;
    final buttonSize = 26.0 * scale;

    final showHandles =
        node.qType != 'swimlane' || (node.qType == 'swimlane' && node.isCollapsed != null && node.isCollapsed!);

    if (!showHandles) return Container();

    // Для группы определяем смещение для маркеров (если есть вложенный узел)
    double groupOffsetX = 0;
    double groupOffsetY = 0;

    if (isGroup && node.children != null && node.children!.isNotEmpty) {
      // Берем первый дочерний узел для определения области маркеров
      final firstChild = node.children!.first;
      groupOffsetX = firstChild.position.dx * scale;
      groupOffsetY = firstChild.position.dy * scale;
    }

    // Позиция кнопки относительно контейнера
    final buttonTop = containerTop - buttonSize / 2;
    final buttonLeft = containerLeft - buttonSize / 2;
    final buttonRight = containerLeft + resizeBoxContainerSize.width - buttonSize / 2;
    final buttonBottom = containerTop + resizeBoxContainerSize.height - buttonSize / 2;

    return Stack(
      children: [
        Positioned(
          left: containerLeft,
          top: containerTop,
          child: SizedBox(
            width: resizeBoxContainerSize.width,
            height: resizeBoxContainerSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: frame,
                  top: frame,
                  child: IgnorePointer(
                    child: Container(
                      width: resizeBoxContainerSize.width - frame * 2,
                      height: resizeBoxContainerSize.height - frame * 2,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: isGroup || isEnum || !hasAttributes
                            ? BorderRadius.zero
                            : BorderRadius.circular(12 * scale),
                      ),
                    ),
                  ),
                ),

                // Подсветка строки атрибута и кружки для всех узлов, включая вложенные в группу
                _buildAllAttributesHighlights(node, nodeSize, offset + frame, scale, lengthArrow, width),

                // Боковые маркеры
                _buildSideHandle(
                  't',
                  resizeBoxContainerSize.width / 2 - lengthArrow / 2 + width / 4,
                  frame + groupOffsetY - lengthArrow / 2,
                  lengthArrow,
                  width,
                  cursor: SystemMouseCursors.alias, // Курсор для верхнего маркера
                ),

                _buildSideHandle(
                  'b',
                  resizeBoxContainerSize.width / 2 - lengthArrow / 2 + width / 4,
                  resizeBoxContainerSize.height - frame - lengthArrow / 2 - groupOffsetY,
                  lengthArrow,
                  width,
                  cursor: SystemMouseCursors.alias, // Курсор для нижнего маркера
                ),
                _buildSideHandle(
                  'r',
                  resizeBoxContainerSize.width - frame - lengthArrow / 2 - groupOffsetX,
                  frame +
                      groupOffsetY +
                      offset +
                      (node.heightHeader ?? EditorConfig.minHeaderHeight) * scale / 2 -
                      lengthArrow / 2,
                  lengthArrow,
                  width,
                  cursor: SystemMouseCursors.alias, // Курсор для нижнего маркера
                ),
                _buildSideHandle(
                  'l',
                  frame + groupOffsetX - lengthArrow / 2,
                  frame +
                      groupOffsetY +
                      offset +
                      (node.heightHeader ?? EditorConfig.minHeaderHeight) * scale / 2 -
                      lengthArrow / 2,
                  lengthArrow,
                  width,
                  cursor: SystemMouseCursors.alias, // Курсор для нижнего маркера
                ),
              ],
            ),
          ),
        ),

        _buildActionButton(
          left: buttonLeft,
          top: buttonTop,
          size: buttonSize,
          color: Colors.white,
          colorIcon: Colors.black,
          icon: CanvasIcons.paintBars,
          cursor: SystemMouseCursors.click, // Курсор для кнопки настроек
          tooltip: 'Настроить объект',
          onTap: () {
            // TODO: добавить обработчик для кнопки настроек
          },
        ),
        _buildActionButton(
          left: buttonRight,
          top: buttonTop,
          size: buttonSize,
          color: Colors.red,
          icon: CanvasIcons.paintDelete,
          cursor: SystemMouseCursors.click, // Курсор для кнопки удаления
          tooltip: 'Удалить объект',
          onTap: () {
            // TODO: добавить обработчик для кнопки удаления
          },
        ),
        _buildResizeButton(
          left: buttonRight,
          top: buttonBottom,
          size: buttonSize,
          color: Colors.amber,
          colorIcon: Colors.black,
        ),
      ],
    );
  }

  /// Создаёт круглую кнопку по углам узла
  Widget _buildActionButton({
    required double left,
    required double top,
    required double size,
    required Color color,
    Color colorIcon = Colors.white,
    required void Function(Canvas, Size, Color) icon,
    MouseCursor? cursor,
    String? tooltip,
    Function()? onTap,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: MouseRegion(
        cursor: cursor ?? SystemMouseCursors.click, // Используем переданный курсор или значение по умолчанию
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Tooltip(
              message: tooltip,
              child: Center(
                child: CustomPaint(
                  size: Size(size * 0.5, size * 0.5),
                  painter: _IconPainter(painter: icon, color: colorIcon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Создаёт круглую кнопку для изменения размера
  Widget _buildResizeButton({
    required double left,
    required double top,
    required double size,
    required Color color,
    required Color colorIcon,
  }) {
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
          child: Tooltip(
            message: 'Изменить размер объекта',
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Center(
                child: CustomPaint(
                  size: Size(size * 0.5, size * 0.5),
                  painter: _IconPainter(painter: CanvasIcons.paintResize, color: colorIcon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Создаёт боковой маркер для создания связей узел->
  Widget _buildSideHandle(String handle, double left, double top, double length, double width, {MouseCursor? cursor}) {
    final isHoveredHandle = isHovered[handle] ?? false;
    final hoverAreaSize = length * 3; // Увеличиваем область для ховера в 3 раза

    return Positioned(
      left: left - (hoverAreaSize - length) / 2,
      top: top - (hoverAreaSize - length) / 2,
      width: hoverAreaSize,
      height: hoverAreaSize,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        cursor: cursor ?? SystemMouseCursors.resizeUpDown,
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
        child: Tooltip(
          // Tooltip теперь оборачивает всю область
          message: 'Создать связь объекта',
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: length,
              height: length,
              alignment: Alignment.center,
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

    if (node.qType == 'group' && node.children != null) {
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

    final minHeaderHeight = EditorConfig.minHeaderHeight;
    final attributeRows = _buildAttributeHighlightRows(nodesToProcess, node, offset, minHeaderHeight, scale);
    final circleHoverRadius = length * 1.5;

    return Positioned(
      top: offset,
      left: 0,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        cursor: SystemMouseCursors.basic, // Курсор по умолчанию для области атрибутов
        onHover: (event) {
          final localPos = event.localPosition;

          for (final row in attributeRows) {
            final distToLeft = math.sqrt(
              math.pow(localPos.dx - row.leftCircleCenterX, 2) + math.pow(localPos.dy - row.circleCenterY, 2),
            );
            final distToRight = math.sqrt(
              math.pow(localPos.dx - row.rightCircleCenterX, 2) + math.pow(localPos.dy - row.circleCenterY, 2),
            );
            final inRowArea = localPos.dy >= row.rowTop && localPos.dy <= row.rowBottom;
            final inRowHorizontalArea = localPos.dx >= row.currentNodeLeft && localPos.dx <= row.rowRight;

            if (distToLeft <= circleHoverRadius) {
              _updateHoverState(row.node, row.rowIndex, left: true, right: false);
              return;
            } else if (distToRight <= circleHoverRadius) {
              _updateHoverState(row.node, row.rowIndex, left: false, right: true);
              return;
            } else if (inRowArea && inRowHorizontalArea) {
              _updateHoverState(row.node, row.rowIndex, left: false, right: false);
              return;
            }
          }

          _resetHoverState();
        },
        onExit: (_) {
          _resetHoverState();
        },
        child: SizedBox(
          width: offset * 2 + nodeSize.width,
          height: nodeSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: _buildAllAttributesHighlightChildren(
              attributeRows,
              length,
            ),
          ),
        ),
      ),
    );
  }

  /// Вспомогательный метод для обновления состояния hover
  void _updateHoverState(dynamic currentNode, int rowIndex, {required bool left, required bool right}) {
    // Обновляем состояние hover для строки
    if (widget.state.hoveredAttributeRowIndex != rowIndex || widget.state.hoveredAttributeNodeId != currentNode.id) {
      widget.nodeManager.state.hoveredAttributeRowIndex = rowIndex;
      widget.nodeManager.state.hoveredAttributeNodeId = currentNode.id;
      widget.nodeManager.onStateUpdate();
    }

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

    if (isHovered[leftKey] != left) {
      isHovered[leftKey] = left;
      needsUpdate = true;
    }
    if (isHovered[rightKey] != right) {
      isHovered[rightKey] = right;
      needsUpdate = true;
    }

    if (needsUpdate) {
      setState(() {});
    }
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

  /// Создаёт дочерние виджеты кружки с лева и права атрибута для создания связи атрибут->
  List<Widget> _buildAllAttributesHighlightChildren(
    List<_AttributeHighlightRow> attributeRows,
    double length,
  ) {
    final List<Widget> children = [];
    final hoverAreaSize = length * 3; // Увеличиваем область для ховера в 3 раза

    for (final row in attributeRows) {
      final isHoveredRow =
          widget.state.hoveredAttributeNodeId == row.node.id && widget.state.hoveredAttributeRowIndex == row.rowIndex;
      final attribute = row.node.attributes[row.rowIndex];
      final isLeftConnected = (attribute.connections?.length('left') ?? 0) == 1;
      final isRightConnected = (attribute.connections?.length('right') ?? 0) == 1;
      final isHoveredLeft = isHovered['attr_left_${row.node.id}_${row.rowIndex}'] ?? false;
      final isHoveredRight = isHovered['attr_right_${row.node.id}_${row.rowIndex}'] ?? false;

      if (!isHoveredRow) continue;

      children.add(
        Positioned(
          left: row.currentNodeLeft,
          top: row.rowTop,
          child: Container(
            width: row.currentNodeWidth,
            height: row.rowHeightScaled,
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2)),
          ),
        ),
      );

      if (!isLeftConnected) {
        children.add(
          Positioned(
            left: row.leftCircleCenterX - hoverAreaSize / 2,
            top: row.circleCenterY - hoverAreaSize / 2,
            width: hoverAreaSize,
            height: hoverAreaSize,
            child: MouseRegion(
              cursor: SystemMouseCursors.alias,
              hitTestBehavior: HitTestBehavior.translucent,
              onEnter: (_) {
                setState(() {
                  isHovered['attr_left_${row.node.id}_${row.rowIndex}'] = true;
                });
              },
              onExit: (_) {
                setState(() {
                  isHovered['attr_left_${row.node.id}_${row.rowIndex}'] = false;
                });
              },
              child: Tooltip(
                message: 'Создать связь атрибута',
                child: Center(
                  child: AnimatedScale(
                    scale: isHoveredLeft ? 3.0 : 1.0,
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
              ),
            ),
          ),
        );
      }

      if (!isRightConnected) {
        children.add(
          Positioned(
            left: row.rightCircleCenterX - hoverAreaSize / 2,
            top: row.circleCenterY - hoverAreaSize / 2,
            width: hoverAreaSize,
            height: hoverAreaSize,
            child: MouseRegion(
              cursor: SystemMouseCursors.alias,
              hitTestBehavior: HitTestBehavior.translucent,
              onEnter: (_) {
                setState(() {
                  isHovered['attr_right_${row.node.id}_${row.rowIndex}'] = true;
                });
              },
              onExit: (_) {
                setState(() {
                  isHovered['attr_right_${row.node.id}_${row.rowIndex}'] = false;
                });
              },
              child: Tooltip(
                message: 'Создать связь атрибута',
                child: Center(
                  child: AnimatedScale(
                    scale: isHoveredRight ? 3.0 : 1.0,
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
              ),
            ),
          ),
        );
      }
    }

    return children;
  }

  List<_AttributeHighlightRow> _buildAttributeHighlightRows(
    List<dynamic> nodesToProcess,
    dynamic mainNode,
    double offset,
    double minHeaderHeight,
    double scale,
  ) {
    final rows = <_AttributeHighlightRow>[];

    for (final node in nodesToProcess) {
      if (node.attributes == null || node.attributes.isEmpty) continue;

      final nodeOffsetY = node == mainNode ? 0.0 : node.position.dy * scale;
      final nodeOffsetX = node == mainNode ? 0.0 : node.position.dx * scale;
      final currentNodeWidth = node.size.width * scale;
      final currentNodeLeft = offset + nodeOffsetX;
      final rowHeight = (node.size.height - minHeaderHeight) / node.attributes.length;
      final actualRowHeight = math.max(rowHeight, EditorConfig.minRowHeight);
      final rowHeightScaled = actualRowHeight * scale;

      for (int rowIndex = 0; rowIndex < node.attributes.length; rowIndex++) {
        final attribute = node.attributes[rowIndex];
        if (attribute.qType != 'attribute') continue;

        final rowTop = (minHeaderHeight + actualRowHeight * rowIndex) * scale + nodeOffsetY;
        rows.add(
          _AttributeHighlightRow(
            node: node,
            rowIndex: rowIndex,
            currentNodeLeft: currentNodeLeft,
            currentNodeWidth: currentNodeWidth,
            rowTop: rowTop,
            rowBottom: rowTop + rowHeightScaled,
            rowHeightScaled: rowHeightScaled,
            leftCircleCenterX: currentNodeLeft,
            rightCircleCenterX: currentNodeLeft + currentNodeWidth,
            circleCenterY: rowTop + rowHeightScaled / 2,
          ),
        );
      }
    }

    return rows;
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

class _AttributeHighlightRow {
  final dynamic node;
  final int rowIndex;
  final double currentNodeLeft;
  final double currentNodeWidth;
  final double rowTop;
  final double rowBottom;
  final double rowHeightScaled;
  final double leftCircleCenterX;
  final double rightCircleCenterX;
  final double circleCenterY;

  const _AttributeHighlightRow({
    required this.node,
    required this.rowIndex,
    required this.currentNodeLeft,
    required this.currentNodeWidth,
    required this.rowTop,
    required this.rowBottom,
    required this.rowHeightScaled,
    required this.leftCircleCenterX,
    required this.rightCircleCenterX,
    required this.circleCenterY,
  });

  double get rowRight => currentNodeLeft + currentNodeWidth;
}
