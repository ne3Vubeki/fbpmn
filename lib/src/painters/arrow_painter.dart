import 'package:fbpmn/src/utils/editor_config.dart';
import 'package:flutter/material.dart';
import '../models/arrow.dart';
import '../services/arrow_manager.dart';

class ArrowsPainter {
  final List<Arrow?> arrows;
  final ArrowManager arrowManager;

  ArrowsPainter({required this.arrows, required this.arrowManager});

  void drawArrowsInTile({required Canvas canvas, required Offset baseOffset}) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = EditorConfig.arrowTileWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Рисуем только те стрелки, путь которых пересекает этот тайл
    for (final arrow in arrows) {
      // Получаем полный путь стрелки
      final path = arrow?.path ?? Path();

      // Рисуем путь (автоматически обрежется по границам тайла)
      canvas.drawPath(path, paint);
    }
  }

  void paint(Canvas canvas, double scale, Rect arrowsRect) {
    // Рассчитываем толщину линии
    final lineWidth = EditorConfig.arrowSelectedWidth * scale;

    final arrowPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Удаляем все коннекты из выбранных узлов для повторного расчета
    for (var node in arrowManager.state.nodesSelected) {
      node?.connections?.removeAll();
    }

    // Рисуем стрелки
    for (final arrow in arrows) {
      if (arrow == null || arrow.source == arrow.target) continue;

      // Получаем полный путь стрелки
      final pathResult = arrowManager.getArrowPathWithSelectedNodes(arrow, arrowsRect);
      final path = pathResult.path;

      // Рисуем путь стрелки
      canvas.drawPath(path, arrowPaint);
    }
  }
}
