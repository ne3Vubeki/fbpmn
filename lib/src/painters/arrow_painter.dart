import 'package:flutter/material.dart';
import '../models/arrow.dart';
import '../services/arrow_manager.dart';

class ArrowPainter {
  final List<Arrow?> arrows;
  late final ArrowManager arrowManager;

  ArrowPainter({required this.arrows, required this.arrowManager});

  void drawArrowsInTile({
    required Canvas canvas,
    required Offset baseOffset,
  }) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 3
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

  void drawArrowsSelectedNodes({
    required Canvas canvas,
  }) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Рисуем только те стрелки, путь которых пересекает этот тайл
    for (final arrow in arrows) {
      // Получаем полный путь стрелки
      final path = arrowManager.getArrowPathWithSelectedNodes(arrow!).path;

      // Рисуем путь (автоматически обрежется по границам тайла)
      canvas.drawPath(path, paint);
    }
  }
}
