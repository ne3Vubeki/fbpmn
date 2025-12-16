import 'dart:math';
import 'package:flutter/material.dart';

import '../controllers/node.controller.dart';

class HierarchicalGridPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final Size canvasSize;
  final List<Node> nodes;
  final int forceRepaintId;
  final String? selectedNodeId;
  final bool isDragging;
  final Offset? nodePosition; // Добавлена новая переменная для позиции перемещаемого узла

  const HierarchicalGridPainter({
    required this.scale,
    required this.offset,
    required this.canvasSize,
    required this.nodes,
    required this.forceRepaintId,
    required this.selectedNodeId,
    required this.isDragging,
    this.nodePosition, // Добавлен новый параметр
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..color = Colors.white,
    );

    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(offset.dx / scale, offset.dy / scale);

    final double visibleLeft = -offset.dx / scale;
    final double visibleTop = -offset.dy / scale;
    final double visibleRight = (size.width - offset.dx) / scale;
    final double visibleBottom = (size.height - offset.dy) / scale;

    _drawHierarchicalGrid(canvas, visibleLeft, visibleTop, visibleRight, visibleBottom);
    _drawNodes(canvas);

    canvas.restore();
  }

  void _drawNodes(Canvas canvas) {
    for (final node in nodes) {
      final nodeRect = Rect.fromCenter(
        center: node.position,
        width: node.size.width,
        height: node.size.height,
      );

      final paint = Paint()
        ..color = node.isSelected ? Colors.blue.shade200 : Colors.grey.shade300
        ..style = PaintingStyle.fill;

      canvas.drawRect(nodeRect, paint);

      final borderPaint = Paint()
        ..color = node.isSelected ? Colors.blue.shade600 : Colors.grey.shade600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(nodeRect, borderPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: node.text.value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          node.position.dx - textPainter.width / 2,
          node.position.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawHierarchicalGrid(
    Canvas canvas,
    double visibleLeft,
    double visibleTop,
    double visibleRight,
    double visibleBottom,
  ) {
    const double baseParentSize = 100.0;
    final double extendedLeft = visibleLeft - baseParentSize * 4;
    final double extendedTop = visibleTop - baseParentSize * 4;
    final double extendedRight = visibleRight + baseParentSize * 4;
    final double extendedBottom = visibleBottom + baseParentSize * 4;

    for (int level = -2; level <= 5; level++) {
      double levelParentSize = baseParentSize * pow(4, level);
      _drawGridLevel(
        canvas,
        extendedLeft,
        extendedTop,
        extendedRight,
        extendedBottom,
        levelParentSize,
        level,
      );
    }
  }

  void _drawGridLevel(
    Canvas canvas,
    double left,
    double top,
    double right,
    double bottom,
    double parentSize,
    int level,
  ) {
    double alpha = _calculateAlphaForLevel(level);
    if (alpha < 0.01) return;

    final Paint parentGridPaint = Paint()
      ..color = Color(0xFFE0E0E0).withOpacity(alpha)
      ..strokeWidth = 1.0 / scale;

    final double childSize = parentSize / 4;

    _drawGridLines(canvas, left, top, right, bottom, parentSize, parentGridPaint);

    if (childSize > 2) {
      final double childAlpha = alpha * 0.8;
      if (childAlpha > 0.01) {
        final Paint childGridPaint = Paint()
          ..color = Color(0xFFF0F0F0).withOpacity(childAlpha)
          ..strokeWidth = 0.5 / scale;

        _drawGridLines(canvas, left, top, right, bottom, childSize, childGridPaint);
      }
    }
  }

  void _drawGridLines(
    Canvas canvas,
    double left,
    double top,
    double right,
    double bottom,
    double cellSize,
    Paint paint,
  ) {
    double startX = (left / cellSize).floor() * cellSize;
    double endX = (right / cellSize).ceil() * cellSize;

    for (double x = startX; x <= endX; x += cellSize) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }

    double startY = (top / cellSize).floor() * cellSize;
    double endY = (bottom / cellSize).ceil() * cellSize;

    for (double y = startY; y <= endY; y += cellSize) {
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  double _calculateAlphaForLevel(int level) {
    double idealScale = 1.0 / pow(4, level);
    double logDifference = (log(scale) - log(idealScale)).abs();
    double maxLogDifference = 2.0;
    double alpha = (1.0 - (logDifference / maxLogDifference)).clamp(0.0, 1.0) * 0.8;
    return alpha;
  }

  @override
  bool shouldRepaint(covariant HierarchicalGridPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.canvasSize != canvasSize ||
        oldDelegate.forceRepaintId != forceRepaintId ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.nodePosition != nodePosition || // Добавлена проверка nodePosition
        !_listEquals(oldDelegate.nodes, nodes);
  }

  bool _listEquals(List<Node> a, List<Node> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final nodeA = a[i];
      final nodeB = b[i];
      if (nodeA.id != nodeB.id ||
          nodeA.position != nodeB.position ||
          nodeA.isSelected != nodeB.isSelected ||
          nodeA.text.value != nodeB.text.value) {
        return false;
      }
    }
    return true;
  }
}