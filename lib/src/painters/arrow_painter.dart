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

      _drawPaths(canvas, arrow, scale, paths, arrow.coordinates!, linePaint, fillPaint, strokePaint, Colors.black, isTiles: true);
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

      // Обновляем координаты для отрисовки powers
      // arrow.coordinates = pathResult.coordinates;

      print('ArrowPainter: arrow.coordinates: ${arrow.coordinates}');

      _drawPaths(canvas, arrow, scale, paths, pathResult.coordinates, linePaint, fillPaint, strokePaint, Colors.blue);
    }
  }

  _drawPaths(
    Canvas canvas,
    Arrow arrow,
    double scale,
    ArrowPaths paths,
    List<Offset> coordinates,
    Paint linePaint,
    Paint fillPaint,
    Paint strokePaint,
    Color color, {
    bool isTiles = false,
  }) {
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

    // 4. Рисуем значения powers
    _drawPowers(canvas, arrow, coordinates, scale, color, isTiles: isTiles);
  }

  void _drawPowers(Canvas canvas, Arrow arrow, List<Offset> coordinates, double scale, Color color, {bool isTiles = false}) {
    final powers = arrow.powers;
    if (powers == null || powers.isEmpty) return;

    if (coordinates.length < 2) return;

    final sides = arrow.sides;
    final sidesParts = sides?.split(':') ?? ['', ''];
    final sourceSide = sidesParts.isNotEmpty ? sidesParts[0] : '';
    final targetSide = sidesParts.length > 1 ? sidesParts[1] : '';

    final double padding = 1.0 * scale;
    final double fontSize = 10.0 * scale;

    for (final power in powers) {
      if (power.value.isEmpty) continue;

      final textStyle = TextStyle(color: color, fontSize: fontSize);

      final textSpan = TextSpan(text: power.value, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();

      Offset position;
      String currentSide;

      if (power.side == '-1') {
        // Начало связи (source)
        position = isTiles ? coordinates.first * scale : coordinates.first;
        currentSide = sourceSide;
      } else {
        // Конец связи (target)
        position = isTiles ? coordinates.last * scale : coordinates.last;
        currentSide = targetSide;
      }

      // Вычисляем позицию текста в зависимости от стороны
      Offset textPosition;

      switch (currentSide) {
        case 'left':
          // Связь выходит/входит слева - текст слева от точки
          textPosition = Offset(position.dx + padding, position.dy - textPainter.height / 2);
          break;
        case 'right':
          // Связь выходит/входит справа - текст справа от точки
          textPosition = Offset(position.dx - padding - textPainter.width, position.dy - textPainter.height / 2);
          break;
        case 'top':
          // Связь выходит/входит сверху - текст над точкой
          textPosition = Offset(position.dx - textPainter.width / 2, position.dy - padding);
          break;
        case 'bottom':
          // Связь выходит/входит снизу - текст под точкой
          textPosition = Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height);
          break;
        default:
          // Fallback: центрируем по вертикали
          textPosition = Offset(position.dx, position.dy - textPainter.height / 2);
      }

      textPainter.paint(canvas, textPosition);
    }
  }
}
