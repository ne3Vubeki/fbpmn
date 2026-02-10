import 'package:flutter/material.dart';
import '../models/table.node.dart';
import 'node_painter.dart';

/// Адаптер для использования NodePainter как CustomPainter
/// Поддерживает два режима:
/// 1. Единичное выделение — один узел (node), масштаб из размеров узла в targetSize
/// 2. Множественное выделение — список узлов (nodes) с worldBounds,
///    узлы рисуются в мировых координатах внутри bounding box
class NodeCustomPainter extends CustomPainter {
  final TableNode? node;
  final List<TableNode>? nodes;
  final Size targetSize;
  final Rect? worldBounds;

  NodeCustomPainter({
    this.node,
    this.nodes,
    required this.targetSize,
    this.worldBounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes != null && nodes!.isNotEmpty && worldBounds != null) {
      _paintMultiSelect(canvas, size);
    } else if (node != null) {
      _paintSingleNode(canvas, size);
    }
  }

  /// Режим 1: Единичное выделение — один узел
  void _paintSingleNode(Canvas canvas, Size size) {
    final n = node!;
    // Масштаб для перевода из размеров узла в размеры виджета
    final scaleX = targetSize.width / n.size.width;
    final scaleY = targetSize.height / n.size.height;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    _paintNodeWithChildren(canvas, n, Offset.zero);

    canvas.restore();
  }

  /// Режим 2: Множественное выделение — список узлов в мировых координатах
  void _paintMultiSelect(Canvas canvas, Size size) {
    final bounds = worldBounds!;
    // Масштаб из мировых координат в экранные размеры виджета
    final scaleX = targetSize.width / bounds.width;
    final scaleY = targetSize.height / bounds.height;

    canvas.save();
    canvas.scale(scaleX, scaleY);
    // Смещаем canvas так, чтобы worldBounds.topLeft стал (0, 0)
    canvas.translate(-bounds.left, -bounds.top);

    for (final n in nodes!) {
      final nodeWorldPos = n.aPosition ?? Offset.zero;

      canvas.save();
      canvas.translate(nodeWorldPos.dx, nodeWorldPos.dy);

      _paintNodeWithChildren(canvas, n, nodeWorldPos);

      canvas.restore();
    }

    canvas.restore();
  }

  /// Рисует узел и его детей (общая логика для обоих режимов)
  void _paintNodeWithChildren(Canvas canvas, TableNode n, Offset nodeWorldPos) {
    final isSwimlane = n.qType == 'swimlane';

    void parentNodePaint() {
      final painter = NodePainter(node: n);
      final rect = Rect.fromLTWH(0, 0, n.size.width, n.size.height);
      painter.paint(canvas, rect, forTile: false);
    }

    // Рисуем основной узел (для не-swimlane — сначала узел, потом дети)
    if (!isSwimlane) {
      parentNodePaint();
    }

    // Рисуем детей, если они есть и не collapsed
    if (n.children != null &&
        n.children!.isNotEmpty &&
        (n.isCollapsed == null || !n.isCollapsed!)) {
      for (final child in n.children!) {
        canvas.save();

        // Для дочерних узлов swimlane используем абсолютные позиции
        // относительно родительского узла
        final relativePosition = child.aPosition != null
            ? Offset(
                (child.aPosition!.dx - (n.aPosition?.dx ?? nodeWorldPos.dx)),
                (child.aPosition!.dy - (n.aPosition?.dy ?? nodeWorldPos.dy)),
              )
            : child.position;

        canvas.translate(relativePosition.dx, relativePosition.dy);

        final childPainter = NodePainter(node: child);
        final childRect = Rect.fromLTWH(0, 0, child.size.width, child.size.height);
        childPainter.paint(canvas, childRect, forTile: false);

        canvas.restore();
      }
    }

    // Для swimlane — рисуем родителя после детей
    if (isSwimlane) {
      parentNodePaint();
    }
  }

  @override
  bool shouldRepaint(covariant NodeCustomPainter oldDelegate) {
    return oldDelegate.node != node ||
        oldDelegate.nodes != nodes ||
        oldDelegate.targetSize != targetSize ||
        oldDelegate.worldBounds != worldBounds;
  }
}
