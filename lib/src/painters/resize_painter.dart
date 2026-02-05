import 'package:flutter/material.dart';

/// Painter для углового маркера (две линии под углом 90 градусов)
class ResizePainter extends CustomPainter {
  final double width;
  final bool isHovered;

  ResizePainter({required this.width, this.isHovered = false});

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
