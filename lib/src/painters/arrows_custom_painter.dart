import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:flutter/material.dart';
import '../models/arrow.dart';
import 'arrow_painter.dart';

/// Адаптер для использования NodePainter как CustomPainter (простая версия)
class ArrowsCustomPainter extends CustomPainter {
  final List<Arrow?> arrows;
  final double scale;
  final Size arrowsSize;
  final Rect arrowsRect;
  final ArrowManager arrowManager;

  ArrowsCustomPainter({
    required this.arrows,
    required this.scale,
    required this.arrowsSize,
    required this.arrowsRect,
    required this.arrowManager,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = arrowsSize.width / size.width;
    final scaleY = arrowsSize.height / size.height;

    // Сохраняем состояние canvas
    canvas.save();

    print('Рисуем связи!!!!!');

    // Применяем масштаб ко всему (узлу и детям)
    canvas.scale(scaleX, scaleY);

    // Рисуем основной узел
    final painter = ArrowsPainter(arrows: arrows, arrowManager: arrowManager);
    painter.paint(canvas, scale, arrowsRect);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArrowsCustomPainter oldDelegate) {
    return oldDelegate.arrows.length != arrows.length ||
        oldDelegate.arrowsSize != arrowsSize ||
        oldDelegate.scale != scale;
  }
}
