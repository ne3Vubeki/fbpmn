import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:flutter/material.dart';
import '../models/arrow.dart';
import '../models/table.node.dart';
import 'arrow_painter.dart';
import 'node_painter.dart';

/// Адаптер для использования NodePainter как CustomPainter (простая версия)
class NodeCustomPainter extends CustomPainter {
  final TableNode node;
  final List<Arrow?> arrows;
  final bool isSelected;
  final Size targetSize;
  final ArrowManager arrowManager;

  NodeCustomPainter({
    required this.node,
    required this.arrows,
    required this.isSelected,
    required this.targetSize,
    required this.arrowManager,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Масштаб для перевода из размеров узла в размеры виджета
    final scaleX = targetSize.width / node.size.width;
    final scaleY = targetSize.height / node.size.height;
    final isSwimlane = node.qType == 'swimlane';
    final arrowTilePainter = ArrowPainter(
      arrows: arrows,
      arrowManager: arrowManager,
    );

    void parentNodePaint() {
      final painter = NodePainter(node: node);
      final rect = Rect.fromLTWH(0, 0, node.size.width, node.size.height);
      painter.paint(canvas, rect, forTile: false);
    }

    // Сохраняем состояние canvas
    canvas.save();

    print('Рисуем узел!!!!!');

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

        // Для дочерних узлов swimlane используем абсолютные позиции
        // относительно родительского swimlane узла
        final relativePosition = child.aPosition != null
            ? Offset(
                (child.aPosition!.dx - (node.aPosition?.dx ?? 0)),
                (child.aPosition!.dy - (node.aPosition?.dy ?? 0)),
              )
            : child.position;

        // Перемещаемся к позиции ребенка (в координатах родителя)
        canvas.translate(relativePosition.dx, relativePosition.dy);

        // Рисуем ребенка
        final childPainter = NodePainter(node: child);
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

    if (arrows.isNotEmpty) {
      arrowTilePainter.drawArrowsSelectedNodes(
        canvas: canvas,
      );
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
