import 'package:fbpmn/src/utils/canvas_icons.dart';
import 'package:flutter/widgets.dart';

/// CustomPainter для отрисовки стрелки направления
class DirectionArrowPainter extends CustomPainter {
  final String direction;
  final Color color;

  DirectionArrowPainter({required this.direction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    CanvasIcons.paintDirectionArrow(canvas, size, color, direction);
  }

  @override
  bool shouldRepaint(covariant DirectionArrowPainter oldDelegate) {
    return oldDelegate.direction != direction || oldDelegate.color != color;
  }
}
