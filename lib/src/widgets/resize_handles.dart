import 'package:flutter/material.dart';
import '../editor_state.dart';
import '../services/node_manager.dart';
import 'state_widget.dart';

/// Виджет для отображения маркеров изменения размера узла
class ResizeHandles extends StatefulWidget {
  final EditorState state;
  final NodeManager nodeManager;
  final String? hoveredHandle;

  const ResizeHandles({
    super.key,
    required this.state,
    required this.nodeManager,
    this.hoveredHandle,
  });

  @override
  State<ResizeHandles> createState() => _ResizeHandlesState();
}

class _ResizeHandlesState extends State<ResizeHandles> with StateWidget<ResizeHandles> {
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
    if (widget.state.nodesSelected.isEmpty) return Container();

    final node = widget.state.nodesSelected.first!;
    final scale = widget.state.scale;

    final offset = NodeManager.resizeHandleOffset * scale;
    final length = NodeManager.resizeHandleLength * scale;
    final width = NodeManager.resizeHandleWidth * scale;

    // Размер узла (масштабированный)
    final nodeSize = Size(node.size.width * scale, node.size.height * scale);
    final resizeBoxContainerSize = Size(
      nodeSize.width + offset * 2 + width * 4,
      nodeSize.height + offset * 2 + width * 4,
    );

    return Positioned(
      left: widget.state.selectedNodeOffset.dx - offset,
      top: widget.state.selectedNodeOffset.dy - offset,
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
            _buildSideHandle('t', resizeBoxContainerSize.width / 2 - length / 2, 0 - width / 2, true, length, width),
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
            _buildSideHandle('l', 0 - width / 2, resizeBoxContainerSize.height / 2 - length / 2, false, length, width),
          ],
        ),
      ),
    );
  }

  /// Создаёт угловой маркер (две линии под углом 90 градусов)
  Widget _buildCornerHandle(String handle, double left, double top, double rotation, double length, double width) {
    final isHovered = widget.hoveredHandle == handle;

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: length,
        height: length,
        color: isHovered ? Colors.red.withValues(alpha: .1) : Colors.transparent,
        child: Transform.rotate(
          angle: rotation * 3.14159 / 180,
          child: CustomPaint(
            size: Size(length, length),
            painter: _CornerHandlePainter(width: width, isHovered: isHovered),
          ),
        ),
      ),
    );
  }

  /// Создаёт боковой маркер (одна линия)
  Widget _buildSideHandle(String handle, double left, double top, bool isHorizontal, double length, double width) {
    final isHovered = widget.hoveredHandle == handle;

    return Positioned(
      left: left,
      top: top,
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
    );
  }

}

/// Painter для углового маркера (две линии под углом 90 градусов)
class _CornerHandlePainter extends CustomPainter {
  final double width;
  final bool isHovered;

  _CornerHandlePainter({required this.width, this.isHovered = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isHovered ? Colors.red : Colors.blue
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    // Горизонтальная линия
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), paint);

    // Вертикальная линия
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
