import 'package:flutter/material.dart';
import '../models/arrow.dart';
import '../services/arrow_manager.dart';

class ArrowTilePainter {
  final List<Arrow?> arrows;
  late final ArrowManager arrowManager;

  ArrowTilePainter({required this.arrows, required this.arrowManager});

  void drawArrowsInTile({
    required Canvas canvas,
    required Rect tileBounds,
    required Offset baseOffset,
  }) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Рисуем только те стрелки, путь которых пересекает этот тайл
    for (final arrow in arrows) {
      // Получаем полный путь стрелки
      final path = arrowManager.getArrowPathForTiles(arrow!, baseOffset).path;

      // Рисуем путь (автоматически обрежется по границам тайла)
      canvas.drawPath(path, paint);
    }
  }
}
