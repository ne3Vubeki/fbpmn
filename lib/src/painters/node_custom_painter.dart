import 'package:flutter/material.dart';
import '../models/table.node.dart';
import '../services/node_manager.dart';
import 'node_painter.dart';

/// Адаптер для использования NodePainter как CustomPainter
/// Поддерживает два режима:
/// 1. Единичное выделение — один узел (node), масштаб из размеров узла в targetSize
/// 2. Множественное выделение — список узлов (nodes) с worldBounds,
///    узлы рисуются в мировых координатах внутри bounding box
class NodeCustomPainter extends CustomPainter {
  final TableNode? node;
  final List<TableNode>? nodes;
  final NodeManager? nodeManager;
  final Size targetSize;
  final Rect? worldBounds;
  /// Упрощённый режим отрисовки (только цветные прямоугольники) для Cola анимации
  final bool simplifiedMode;

  NodeCustomPainter({
    this.node,
    this.nodes,
    this.nodeManager,
    required this.targetSize,
    this.worldBounds,
    this.simplifiedMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (simplifiedMode) {
      // Упрощённый режим: рисуем только цветные прямоугольники
      if (nodes != null && nodes!.isNotEmpty && worldBounds != null) {
        _paintMultiSelectSimplified(canvas, size);
      } else if (node != null) {
        _paintSingleNodeSimplified(canvas, size);
      }
    } else {
      if (nodes != null && nodes!.isNotEmpty && worldBounds != null) {
        _paintMultiSelect(canvas, size);
      } else if (node != null) {
        _paintSingleNode(canvas, size);
      }
    }
  }

  /// Упрощённая отрисовка одного узла (только цветной прямоугольник)
  void _paintSingleNodeSimplified(Canvas canvas, Size size) {
    final n = node!;
    final scaleX = targetSize.width / n.size.width;
    final scaleY = targetSize.height / n.size.height;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    _paintNodeSimplified(canvas, n, Offset.zero);

    canvas.restore();
  }

  /// Упрощённая отрисовка множественного выделения
  void _paintMultiSelectSimplified(Canvas canvas, Size size) {
    final bounds = worldBounds!;
    final scaleX = targetSize.width / bounds.width;
    final scaleY = targetSize.height / bounds.height;

    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.translate(-bounds.left, -bounds.top);

    for (final n in nodes!) {
      final nodeWorldPos = n.aPosition ?? Offset.zero;

      canvas.save();
      canvas.translate(nodeWorldPos.dx, nodeWorldPos.dy);

      _paintNodeSimplified(canvas, n, nodeWorldPos);

      canvas.restore();
    }

    canvas.restore();
  }

  /// Рисует упрощённый узел (цветной прямоугольник с границей)
  void _paintNodeSimplified(Canvas canvas, TableNode n, Offset nodeWorldPos) {
    final rect = Rect.fromLTWH(0, 0, n.size.width, n.size.height);
    final isSwimlane = n.qType == 'swimlane';
    final isGroup = n.qType == 'group';
    final isEnum = n.qType == 'enum';
    final hasAttributes = n.attributes.isNotEmpty;

    // Определяем цвет фона на основе типа узла
    Color fillColor;
    if (isSwimlane) {
      fillColor = Colors.blue.withValues(alpha: 0.3);
    } else if (isGroup) {
      fillColor = Colors.blue.withValues(alpha: 0.3);
    } else if (isEnum) {
      fillColor = Colors.blue.withValues(alpha: 0.3);
    } else {
      fillColor = Colors.blue.withValues(alpha: 0.3);
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Рисуем прямоугольник
    if (isSwimlane || isGroup || isEnum || !hasAttributes) {
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    } else {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, borderPaint);
    }

    // Рисуем детей (упрощённо)
    if (n.children != null &&
        n.children!.isNotEmpty &&
        (n.isCollapsed == null || !n.isCollapsed!)) {
      for (final child in n.children!) {
        canvas.save();

        final relativePosition = child.aPosition != null
            ? Offset(
                (child.aPosition!.dx - (n.aPosition?.dx ?? nodeWorldPos.dx)),
                (child.aPosition!.dy - (n.aPosition?.dy ?? nodeWorldPos.dy)),
              )
            : child.position;

        canvas.translate(relativePosition.dx, relativePosition.dy);

        _paintNodeSimplified(canvas, child, child.aPosition ?? Offset.zero);

        canvas.restore();
      }
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
