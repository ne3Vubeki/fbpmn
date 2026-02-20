import 'dart:math' as math;
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final Size canvasSize;
  final NodeManager nodeManager;

  GridPainter({
    required this.scale,
    required this.offset,
    required this.canvasSize,
    required this.nodeManager,
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

    final double visibleLeft   = -offset.dx / scale;
    final double visibleTop    = -offset.dy / scale;
    final double visibleRight  = (size.width  - offset.dx) / scale;
    final double visibleBottom = (size.height - offset.dy) / scale;

    _drawHierarchicalGrid(canvas, visibleLeft, visibleTop, visibleRight, visibleBottom);

    canvas.restore();
  }

  void _drawHierarchicalGrid(
    Canvas canvas,
    double visibleLeft,
    double visibleTop,
    double visibleRight,
    double visibleBottom,
  ) {
    const double baseParentSize = 100.0;

    final double extendedLeft   = visibleLeft   - baseParentSize * 4;
    final double extendedTop    = visibleTop    - baseParentSize * 4;
    final double extendedRight  = visibleRight  + baseParentSize * 4;
    final double extendedBottom = visibleBottom + baseParentSize * 4;

    for (int level = -2; level <= 5; level++) {
      final double levelParentSize = baseParentSize * math.pow(4, level).toDouble();
      _drawGridLevel(canvas, extendedLeft, extendedTop, extendedRight, extendedBottom, levelParentSize, level);
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
    final double alpha = nodeManager.calculateGridAlphaForLevel(level);
    if (alpha < 0.01) return;

    final Paint parentGridPaint = Paint()
      ..color = const Color(0xFFE0E0E0).withOpacity(alpha)
      ..strokeWidth = 1.0 / scale;

    final double childSize = parentSize / 4;

    _drawGridLines(canvas, left, top, right, bottom, parentSize, parentGridPaint);

    if (childSize > 2) {
      final double childAlpha = alpha * 0.8;
      if (childAlpha > 0.0005) {
        final Paint childGridPaint = Paint()
          ..color = const Color(0xFFF0F0F0).withOpacity(childAlpha)
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
    double startX = (left  / cellSize).floor() * cellSize;
    double endX   = (right / cellSize).ceil()  * cellSize;
    for (double x = startX; x <= endX; x += cellSize) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }

    double startY = (top    / cellSize).floor() * cellSize;
    double endY   = (bottom / cellSize).ceil()  * cellSize;
    for (double y = startY; y <= endY; y += cellSize) {
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.scale != scale ||
           oldDelegate.offset != offset ||
           oldDelegate.canvasSize != canvasSize;
  }
}
