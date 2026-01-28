import 'package:flutter/material.dart';
import '../models/arrow.dart';
import '../services/arrow_manager.dart';

class ArrowsPainter {
  final List<Arrow?> arrows;
  final ArrowManager arrowManager;

  ArrowsPainter({
    required this.arrows,
    required this.arrowManager,
  });

  void drawArrowsInTile({required Canvas canvas, required Offset baseOffset}) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Рисуем только те стрелки, путь которых пересекает этот тайл
    for (final arrow in arrows) {
      // Получаем полный путь стрелки
      final path = arrowManager.getArrowPathInTile(arrow!, baseOffset).path;

      // Рисуем путь (автоматически обрежется по границам тайла)
      canvas.drawPath(path, paint);
    }
  }

  void paint(Canvas canvas, double scale, Rect arrowsRect) {
    // Рассчитываем толщину линии
    final lineWidth = 3.0 * scale;

    final arrowPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Рисуем стрелки
    for (final arrow in arrows) {
      if (arrow == null) continue;

      // Получаем полный путь стрелки
      final pathResult = arrowManager.getArrowPathWithSelectedNodes(arrow, arrowsRect);
      final path = pathResult.path;

      // Рисуем путь стрелки
      canvas.drawPath(path, arrowPaint);
    }
  }
}
