import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../editor_state.dart';
import '../services/node_manager.dart';
import '../utils/editor_config.dart';
import 'state_widget.dart';

/// Виджет для отображения маркеров изменения размера узла
class ResizeHandles extends StatefulWidget {
  final EditorState state;
  final NodeManager nodeManager;

  const ResizeHandles({super.key, required this.state, required this.nodeManager});

  @override
  State<ResizeHandles> createState() => _ResizeHandlesState();
}

class _ResizeHandlesState extends State<ResizeHandles> with StateWidget<ResizeHandles> {
  String? _hoveredCircle; // 'left' или 'right'
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

    final offset = NodeManager.resizeHandleOffset * scale;
    final length = NodeManager.resizeHandleLength;
    final width = NodeManager.resizeHandleWidth;
    final frame = widget.nodeManager.frameTotalOffset;

    // Размер узла (масштабированный)
    final nodeSize = Size(node.size.width * scale, node.size.height * scale);
    final resizeBoxContainerSize = Size(nodeSize.width + offset * 2, nodeSize.height + offset * 2);

    return node.qType != 'swimlane' || (node.qType == 'swimlane' && node.isCollapsed != null && node.isCollapsed!)
        ? Positioned(
            left: widget.state.selectedNodeOffset.dx + frame - offset - width / 4,
            top: widget.state.selectedNodeOffset.dy + frame - offset - width / 4,
            child: Container(
              width: resizeBoxContainerSize.width,
              height: resizeBoxContainerSize.height,
              color: Colors.blue.withOpacity(0.1),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: offset - frame / 2,
                    top:offset - frame / 2,
                    child: Container(
                      width: nodeSize.width + frame,
                      height: nodeSize.height + frame,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                    ),
                  ),
                  // Подсветка строки атрибута и кружки
                  _buildAttributeHighlight(node, nodeSize),

                  // Угловые маркеры
                  // Top-Left (угол в точке -offset, -offset, линии идут вправо и вниз)
                  _buildCornerHandle('tl', 0, 0, length, width),
                  // Top-Right (угол в точке nodeSize.width + offset, -offset, линии идут влево и вниз)
                  _buildCornerHandle('tr', resizeBoxContainerSize.width - length - width / 2, 0, length, width),
                  // Bottom-Left (угол в точке -offset, nodeSize.height + offset, линии идут вправо и вверх)
                  _buildCornerHandle('bl', 0, resizeBoxContainerSize.height - length - width / 2, length, width),
                  // Bottom-Right (угол в точке nodeSize.width + offset, nodeSize.height + offset, линии идут влево и вверх)
                  _buildCornerHandle(
                    'br',
                    resizeBoxContainerSize.width - length - width / 2,
                    resizeBoxContainerSize.height - length - width / 2,
                    length,
                    width,
                  ),

                  // Боковые маркеры
                  // Top (центр по горизонтали, на расстоянии offset от верха)
                  _buildSideHandle('t', resizeBoxContainerSize.width / 2 - length / 2, 0, length, width),
                  // Right (на расстоянии offset от правого края, центр по вертикали)
                  _buildSideHandle(
                    'r',
                    resizeBoxContainerSize.width - length,
                    resizeBoxContainerSize.height / 2 - length / 2,
                    length,
                    width,
                  ),
                  // Bottom (центр по горизонтали, на расстоянии offset от низа)
                  _buildSideHandle(
                    'b',
                    resizeBoxContainerSize.width / 2 - length / 2,
                    resizeBoxContainerSize.height - length,
                    length,
                    width,
                  ),
                  // Left (на расстоянии offset от левого края, центр по вертикали)
                  _buildSideHandle('l', 0, resizeBoxContainerSize.height / 2 - length / 2, length, width),
                ],
              ),
            ),
          )
        : Container();
  }

  /// Создаёт угловой маркер (две линии под углом 90 градусов)
  Widget _buildCornerHandle(String handle, double left, double top, double length, double width) {
    return Positioned(
      left: left + (handle == 'tl' || handle == 'bl' ? length / 2 : -length / 2),
      top: top + (handle == 'tl' || handle == 'tr' ? length / 2 : -length / 2),
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.opaque,
        onHover: (event) {
          setState(() {
            widget.nodeManager.getResizeCursor(handle);
            print('handle: $handle');
          });
        },
        onEnter: (event) => setState(() => isHovered[handle] = true),
        onExit: (event) => setState(() => isHovered[handle] = false),
        child: Container(
          width: length,
          height: length,
          decoration: BoxDecoration(
            color: isHovered[handle] ?? false ? Colors.blue : Colors.white,
            border: Border.all(color: Colors.blue, width: width),
          ),
        ),
      ),
    );
  }

  /// Создаёт боковой маркер (одна линия)
  Widget _buildSideHandle(String handle, double left, double top, double length, double width) {
    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.opaque,
        onHover: (event) {
          setState(() {
            widget.nodeManager.getResizeCursor(handle);
          });
        },
        onEnter: (event) => setState(() => isHovered[handle] = true),
        onExit: (event) => setState(() => isHovered[handle] = false),
        child: Container(
          width: length + width / 2,
          height: length + width / 2,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isHovered[handle] ?? false ? Colors.blue : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: width),
          ),
        ),
      ),
    );
  }

  /// Создаёт подсветку строки атрибута с кружками на границах
  Widget _buildAttributeHighlight(dynamic node, Size nodeSize) {
    // Проверяем, нужно ли рисовать подсветку
    if (widget.state.hoveredAttributeNodeId != node.id ||
        widget.state.hoveredAttributeRowIndex == null ||
        node.attributes.isEmpty) {
      return Container();
    }

    final scale = widget.state.scale;
    final headerHeight = EditorConfig.headerHeight;
    final rowHeight = (node.size.height - headerHeight) / node.attributes.length;
    final minRowHeight = EditorConfig.minRowHeight;
    final actualRowHeight = math.max(rowHeight, minRowHeight);

    final rowIndex = widget.state.hoveredAttributeRowIndex!;
    if (rowIndex < 0 || rowIndex >= node.attributes.length) {
      return Container();
    }

    // Вычисляем позицию строки с учётом масштаба
    final offset = NodeManager.resizeHandleOffset * scale;
    final rowTop = (headerHeight + actualRowHeight * rowIndex) * scale + offset;
    final rowHeightScaled = actualRowHeight * scale;

    // Размеры кружков с учётом масштаба
    final circleDiameter = 8.0 * scale;
    final circleRadius = circleDiameter / 2;
    final circleBorderWidth = 1.0 * scale;

    return Positioned(
      left: offset,
      top: rowTop,
      child: Container(
        width: nodeSize.width,
        height: rowHeightScaled,
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Левый кружок
            Positioned(
              left: -circleRadius,
              top: rowHeightScaled / 2 - circleRadius,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoveredCircle = 'left'),
                onExit: (_) => setState(() => _hoveredCircle = null),
                child: Container(
                  width: circleDiameter,
                  height: circleDiameter,
                  decoration: BoxDecoration(
                    color: _hoveredCircle == 'left' ? Colors.blue : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: circleBorderWidth),
                  ),
                ),
              ),
            ),
            // Правый кружок
            Positioned(
              right: -circleRadius,
              top: rowHeightScaled / 2 - circleRadius,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoveredCircle = 'right'),
                onExit: (_) => setState(() => _hoveredCircle = null),
                child: Container(
                  width: circleDiameter,
                  height: circleDiameter,
                  decoration: BoxDecoration(
                    color: _hoveredCircle == 'right' ? Colors.blue : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: circleBorderWidth),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
