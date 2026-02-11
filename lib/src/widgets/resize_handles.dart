import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../editor_state.dart';
import '../painters/resize_painter.dart';
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
    final length = NodeManager.resizeHandleLength * scale;
    final width = NodeManager.resizeHandleWidth * scale;
    final frame = widget.nodeManager.frameTotalOffset;

    // Размер узла (масштабированный)
    final nodeSize = Size(node.size.width * scale, node.size.height * scale);
    final resizeBoxContainerSize = Size(
      nodeSize.width + offset * 2,
      nodeSize.height + offset * 2,
    );

    return node.qType != 'swimlane' || (node.qType == 'swimlane' && node.isCollapsed != null && node.isCollapsed!)
        ? Positioned(
            left: widget.state.selectedNodeOffset.dx + frame - offset,
            top: widget.state.selectedNodeOffset.dy + frame - offset,
            child: Container(
              width: resizeBoxContainerSize.width,
              height: resizeBoxContainerSize.height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.withValues(alpha: .5), width: .5),
                color: Colors.blue.withValues(alpha: .03),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Подсветка строки атрибута и кружки
                  _buildAttributeHighlight(node, nodeSize),
                  
                  // Угловые маркеры
                  // Top-Left (угол в точке -offset, -offset, линии идут вправо и вниз)
                  _buildCornerHandle('tl', 0, 0, 0, length, width),
                  // Top-Right (угол в точке nodeSize.width + offset, -offset, линии идут влево и вниз)
                  _buildCornerHandle('tr', resizeBoxContainerSize.width - length - width / 4, 0, 90, length, width),
                  // Bottom-Left (угол в точке -offset, nodeSize.height + offset, линии идут вправо и вверх)
                  _buildCornerHandle('bl', 0, resizeBoxContainerSize.height - length - width / 2, 270, length, width),
                  // Bottom-Right (угол в точке nodeSize.width + offset, nodeSize.height + offset, линии идут влево и вверх)
                  _buildCornerHandle(
                    'br',
                    resizeBoxContainerSize.width - length - width / 4,
                    resizeBoxContainerSize.height - length - width / 4,
                    180,
                    length,
                    width,
                  ),

                  // Боковые маркеры
                  // Top (центр по горизонтали, на расстоянии offset от верха)
                  _buildSideHandle(
                    't',
                    resizeBoxContainerSize.width / 2 - length / 2,
                    0 - width / 2,
                    true,
                    length,
                    width,
                  ),
                  // Right (на расстоянии offset от правого края, центр по вертикали)
                  _buildSideHandle(
                    'r',
                    resizeBoxContainerSize.width - length - width / 4,
                    resizeBoxContainerSize.height / 2 - length / 2,
                    false,
                    length,
                    width,
                  ),
                  // Bottom (центр по горизонтали, на расстоянии offset от низа)
                  _buildSideHandle(
                    'b',
                    resizeBoxContainerSize.width / 2 - length / 2,
                    resizeBoxContainerSize.height - length - width / 4,
                    true,
                    length,
                    width,
                  ),
                  // Left (на расстоянии offset от левого края, центр по вертикали)
                  _buildSideHandle(
                    'l',
                    0 - width / 2,
                    resizeBoxContainerSize.height / 2 - length / 2,
                    false,
                    length,
                    width,
                  ),
                ],
              ),
            ),
          )
        : Container();
  }

  /// Создаёт угловой маркер (две линии под углом 90 градусов)
  Widget _buildCornerHandle(String handle, double left, double top, double rotation, double length, double width) {
    final isHovered = widget.nodeManager.hoveredResizeHandle == handle;
    final cursor = widget.nodeManager.getResizeCursor(handle);

    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor: cursor,
        child: Container(
          width: length,
          height: length,
          color: isHovered ? Colors.red.withValues(alpha: .1) : Colors.transparent,
          child: Transform.rotate(
            angle: rotation * 3.14159 / 180,
            child: CustomPaint(
              size: Size(length, length),
              painter: ResizePainter(width: width, isHovered: isHovered),
            ),
          ),
        ),
      ),
    );
  }

  /// Создаёт боковой маркер (одна линия)
  Widget _buildSideHandle(String handle, double left, double top, bool isHorizontal, double length, double width) {
    final isHovered = widget.nodeManager.hoveredResizeHandle == handle;
    final cursor = widget.nodeManager.getResizeCursor(handle);

    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor: cursor,
        child: Container(
          padding: EdgeInsets.only(
            left: handle == 'r' ? length - width / 2 : 0,
            right: handle == 'l' ? length - width / 2 : 0,
            top: handle == 'b' ? length - width / 2 : 0,
            bottom: handle == 't' ? length - width / 2 : 0,
          ),
          width: length + width / 2,
          height: length + width / 2,
          alignment: Alignment.center,
          color: isHovered ? Colors.red.withValues(alpha: .1) : const Color.fromRGBO(0, 0, 0, 0),
          child: Container(
            width: isHorizontal ? length : width,
            height: isHorizontal ? width : length,
            decoration: BoxDecoration(
              color: isHovered ? Colors.red : Colors.blue,
              borderRadius: BorderRadius.circular(1),
            ),
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
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
        ),
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
