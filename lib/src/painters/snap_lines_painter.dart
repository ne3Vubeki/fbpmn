import 'package:flutter/material.dart';

import '../models/snap_line.dart';

class SnapLinesPainter extends CustomPainter {
  final List<SnapLine> snapLines;
  final Size viewportSize;

  SnapLinesPainter({
    required this.snapLines,
    required this.viewportSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Создаем прерывистый эффект
    const dashWidth = 5.0;
    const dashSpace = 3.0;

    for (final snapLine in snapLines) {
      if (snapLine.type == SnapLineType.vertical) {
        // Вертикальная линия (от верха до низа viewport)
        _drawDashedLine(
          canvas,
          Offset(snapLine.position, 0),
          Offset(snapLine.position, viewportSize.height),
          paint,
          dashWidth,
          dashSpace,
        );
      } else {
        // Горизонтальная линия (от левого до правого края viewport)
        _drawDashedLine(
          canvas,
          Offset(0, snapLine.position),
          Offset(viewportSize.width, snapLine.position),
          paint,
          dashWidth,
          dashSpace,
        );
      }
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = (dx * dx + dy * dy);
    if (distance == 0) return;
    
    final length = distance > 0 ? (dx.abs() > dy.abs() ? dx.abs() : dy.abs()) : 0.0;
    final unitX = dx / length;
    final unitY = dy / length;

    double currentDistance = 0;
    bool draw = true;

    while (currentDistance < length) {
      final segmentLength = draw ? dashWidth : dashSpace;
      final nextDistance = (currentDistance + segmentLength).clamp(0.0, length);

      if (draw) {
        canvas.drawLine(
          Offset(start.dx + unitX * currentDistance, start.dy + unitY * currentDistance),
          Offset(start.dx + unitX * nextDistance, start.dy + unitY * nextDistance),
          paint,
        );
      }

      currentDistance = nextDistance;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(covariant SnapLinesPainter oldDelegate) {
    return snapLines != oldDelegate.snapLines;
  }
}
