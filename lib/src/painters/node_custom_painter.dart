import 'package:flutter/material.dart';
import '../models/table.node.dart';
import 'node_painter.dart' as node_painter_lib;

/// Адаптер для использования NodePainter как CustomPainter (простая версия)
class NodeCustomPainter extends CustomPainter {
  final TableNode node;
  final bool isSelected;
  final Size targetSize;

  NodeCustomPainter({
    required this.node,
    required this.isSelected,
    required this.targetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Масштаб для перевода из размеров узла в размеры виджета
    final scaleX = targetSize.width / node.size.width;
    final scaleY = targetSize.height / node.size.height;
    final isSwimlane = node.qType == 'swimlane';

    void parentNodePaint() {
      final painter = node_painter_lib.NodePainter(node: node);
      final rect = Rect.fromLTWH(0, 0, node.size.width, node.size.height);
      painter.paint(canvas, rect, forTile: false);
    }

    // Сохраняем состояние canvas
    canvas.save();

    // Применяем масштаб ко всему (узлу и детям)
    canvas.scale(scaleX, scaleY);

    // Рисуем основной узел
    if (!isSwimlane) {
      parentNodePaint();
    }

    // Рисуем детей, если они есть и не collapsed
    if (node.children != null &&
        node.children!.isNotEmpty &&
        (node.isCollapsed == null || !node.isCollapsed!)) {
      for (final child in node.children!) {
        // Сохраняем состояние для каждого ребенка
        canvas.save();

        // Перемещаемся к позиции ребенка (в координатах родителя)
        canvas.translate(child.position.dx, child.position.dy);

        // Рисуем ребенка
        final childPainter = node_painter_lib.NodePainter(node: child);
        final childRect = Rect.fromLTWH(
          0,
          0,
          child.size.width,
          child.size.height,
        );
        childPainter.paint(canvas, childRect, forTile: false);

        canvas.restore();
      }
    }

    if (isSwimlane) {
      parentNodePaint();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NodeCustomPainter oldDelegate) {
    return oldDelegate.node != node ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.targetSize != targetSize;
  }
}
