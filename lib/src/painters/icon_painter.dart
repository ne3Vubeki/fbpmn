import 'package:flutter/widgets.dart';

/// CustomPainter для отрисовки canvas иконки
class IconPainter extends CustomPainter {
  final void Function(Canvas, Size, Color) painter;
  final Color color;

  IconPainter({required this.painter, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    painter(canvas, size, color);
  }

  @override
  bool shouldRepaint(covariant IconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
