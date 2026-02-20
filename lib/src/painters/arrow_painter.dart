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
    final pathWidth = EditorConfig.arrowSelectedPathWidth * scale;
    final lineWidth = EditorConfig.arrowSelectedWidth * scale;

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = pathWidth
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

      _drawPaths(canvas, arrow, scale, paths, pathResult.coordinates, linePaint, fillPaint, strokePaint, Colors.blue);
    }
  }

  /// Упрощённая отрисовка стрелок (только линии без начальных/конечных объектов)
  void paintSimplified(Canvas canvas, double scale, Rect arrowsRect) {
    final pathWidth = 2.0 * scale;

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = pathWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Удаляем все коннекты из выбранных узлов для повторного расчета
    for (var node in arrowManager.state.nodesSelected) {
      node?.connections?.removeAll();
    }

    // Рисуем только линии стрелок
    for (final arrow in arrows) {
      if (arrow == null || arrow.source == arrow.target) continue;

      // Получаем полный путь стрелки
      final pathResult = arrowManager.getArrowPathWithSelectedNodes(arrow, arrowsRect);
      final paths = pathResult.paths;

      // Рисуем только линию без начальных/конечных объектов
      canvas.drawPath(paths.path, linePaint);
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

    final double padding = 14.0 * scale;
    final double fontSize = 8.0 * scale;
    final double circlePadding = 1.0 * scale;

    for (final power in powers) {
      if (power.value.isEmpty) continue;

      final textStyle = TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w500);

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

      // Вычисляем размер кружка (радиус = половина максимального размера текста + отступ)
      final circleRadius = (textPainter.width > textPainter.height 
          ? textPainter.width / 2 
          : textPainter.height / 2) + circlePadding;

      // Вычисляем позицию центра кружка в зависимости от стороны
      Offset circleCenter;

      switch (currentSide) {
        case 'left':
          // Связь выходит/входит слева - кружок слева от точки
          circleCenter = Offset(position.dx - padding - circleRadius, position.dy);
          break;
        case 'right':
          // Связь выходит/входит справа - кружок справа от точки
          circleCenter = Offset(position.dx + padding + circleRadius, position.dy);
          break;
        case 'top':
          // Связь выходит/входит сверху - кружок над точкой
          circleCenter = Offset(position.dx, position.dy - padding - circleRadius);
          break;
        case 'bottom':
          // Связь выходит/входит снизу - кружок под точкой
          circleCenter = Offset(position.dx, position.dy + padding + circleRadius);
          break;
        default:
          // Fallback: центрируем по вертикали
          circleCenter = Offset(position.dx + padding + circleRadius, position.dy);
      }

      // Рисуем белый кружок с границей
      final circleFillPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      final circleStrokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale;

      canvas.drawCircle(circleCenter, circleRadius, circleFillPaint);
      canvas.drawCircle(circleCenter, circleRadius, circleStrokePaint);

      // Позиция текста - центрируем в кружке
      final textPosition = Offset(
        circleCenter.dx - textPainter.width / 2,
        circleCenter.dy - textPainter.height / 2,
      );

      textPainter.paint(canvas, textPosition);
      textPainter.dispose();
    }
  }
}
