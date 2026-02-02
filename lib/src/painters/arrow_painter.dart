import 'package:fbpmn/src/models/arrow_paths.dart';
import 'package:fbpmn/src/utils/editor_config.dart';
import 'package:flutter/material.dart';
import '../models/arrow.dart';
import '../services/arrow_manager.dart';

class ArrowsPainter {
  final List<Arrow?> arrows;
  final ArrowManager arrowManager;

  ArrowsPainter({required this.arrows, required this.arrowManager});

  void drawArrowsInTile({required Canvas canvas, required Offset baseOffset, required double scale}) {
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = EditorConfig.arrowTileWidth / scale
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Рисуем только те стрелки, путь которых пересекает этот тайл
    for (final arrow in arrows) {
      if (arrow == null) continue;
      // Получаем полный путь стрелки
      final paths = arrow.paths ?? ArrowPaths(path: Path());

      _drawPaths(canvas, arrow, paths, linePaint, fillPaint, strokePaint, Colors.black);
    }
  }

  void paint(Canvas canvas, double scale, Rect arrowsRect) {
    // Рассчитываем толщину линии
    final lineWidth = EditorConfig.arrowSelectedWidth * scale;

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
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
      final paths = pathResult.paths;

      _drawPaths(canvas, arrow, paths, linePaint, fillPaint, strokePaint, Colors.blue);
    }
  }

  _drawPaths(
    Canvas canvas,
    Arrow arrow,
    ArrowPaths paths,
    Paint linePaint,
    Paint fillPaint,
    Paint strokePaint,
    Color color,
  ) {
    // 1. Рисуем линию
    canvas.drawPath(paths.path, linePaint);

    // 2. Рисуем фигуру в начале (ромб)
    if (paths.startArrow != null) {
      if (arrow.sourceArrow == 'diamondThin') {
        // Черный ромб
        fillPaint.color = color;
        canvas.drawPath(paths.startArrow!, fillPaint);
      } else {
        // Белый ромб с черной границей
        fillPaint.color = Colors.white;
        canvas.drawPath(paths.startArrow!, fillPaint);
        canvas.drawPath(paths.startArrow!, strokePaint);
      }
    }

    // 3. Рисуем фигуру в конце (треугольник)
    if (paths.endArrow != null) {
      // Белый треугольник с черной границей
      fillPaint.color = Colors.white;
      canvas.drawPath(paths.endArrow!, fillPaint);
      canvas.drawPath(paths.endArrow!, strokePaint);
    }
  }
}
