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
      ..color = arrowManager.onlyConnectors ? Colors.black.withValues(alpha: 0.1) : Colors.black
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

      _drawPaths(
        canvas,
        arrow,
        scale,
        paths,
        arrow.coordinates!,
        linePaint,
        fillPaint,
        strokePaint,
        Colors.black,
        isTiles: true,
      );
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

    // Рисуем стрелки
    for (final arrow in arrows) {
      if (arrow == null || arrow.source == arrow.target) continue;

      // Получаем полный путь стрелки
      final pathResult = arrowManager.getArrowPathWithSelectedNodes(arrow, arrowsRect);
      final paths = pathResult.paths;

      _drawPaths(canvas, arrow, scale, paths, pathResult.coordinates, linePaint, fillPaint, strokePaint, Colors.blue);
    }
  }

  void paintHover(Canvas canvas, double scale, Rect arrowsRect) {
    final pathWidth = (!arrowManager.onlyConnectors ? EditorConfig.arrowSelectedPathWidth : 2) * scale;
    final lineWidth = (!arrowManager.onlyConnectors ? EditorConfig.arrowSelectedWidth : 2) * scale;

    final linePaint = Paint()
      ..color = !arrowManager.onlyConnectors ? Colors.yellowAccent.withValues(alpha: 0.5) : Colors.black
      ..strokeWidth = pathWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = !arrowManager.onlyConnectors ? Colors.yellowAccent.withValues(alpha: 0.5) : Colors.black
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final arrow in arrows) {
      if (arrow == null || arrow.source == arrow.target) continue;

      final hoverArrow = arrow.copyWith();
      final pathResult = arrowManager.getArrowPathWithSelectedNodes(hoverArrow, arrowsRect);
      final paths = pathResult.paths;

      _drawPaths(
        canvas,
        hoverArrow,
        scale,
        paths,
        pathResult.coordinates,
        linePaint,
        fillPaint,
        strokePaint,
        !arrowManager.onlyConnectors ? Colors.yellowAccent.withValues(alpha: 0.5) : Colors.black,
      );
    }
  }

  void paintCreated(Canvas canvas, double scale) {
    final arrow = arrowManager.state.arrowCreated;
    if (arrow == null) return;

    final pathWidth = EditorConfig.arrowSelectedPathWidth * scale;
    final lineWidth = EditorConfig.arrowSelectedWidth * scale;

    final linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = pathWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final pathResult = arrowManager.getCreatedArrowPath();
    if (pathResult.coordinates.length < 2) {
      return;
    }

    _drawPaths(
      canvas,
      arrow,
      scale,
      pathResult.paths,
      pathResult.coordinates,
      linePaint,
      fillPaint,
      strokePaint,
      Colors.red,
      fillArrowHeadsWithColor: true,
      drawEndArrow: false,
    );

    _drawEndpointCircles(canvas, pathResult.coordinates, scale, Colors.red, drawTarget: arrow.target.isNotEmpty);
  }

  /// Упрощённая отрисовка стрелок (только линии без начальных/конечных объектов)
  void paintSimplified(Canvas canvas, double scale, Rect arrowsRect) {
    final pathWidth = 2.0 * scale;

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = pathWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

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
    bool fillArrowHeadsWithColor = false,
    bool drawEndArrow = true,
  }) {
    arrowManager.onlyConnectors
        ? _drawPowerConnectorLines(
            canvas,
            arrow,
            coordinates,
            scale,
            Paint()
              ..color = Colors.black
              ..strokeWidth = EditorConfig.arrowTileWidth / scale
              ..style = PaintingStyle.stroke
              ..isAntiAlias = true,
            isTiles: isTiles,
            hasStartFigure: paths.startArrow != null,
          )
        : null;

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
    if (drawEndArrow && paths.endArrow != null) {
      fillPaint.color = fillArrowHeadsWithColor ? color : Colors.white;
      canvas.drawPath(paths.endArrow!, fillPaint);
      canvas.drawPath(paths.endArrow!, strokePaint);
    }

    // 4. Рисуем значения powers
    _drawPowers(canvas, arrow, coordinates, scale, color, isTiles: isTiles);
  }

  void _drawPowerConnectorLines(
    Canvas canvas,
    Arrow arrow,
    List<Offset> coordinates,
    double scale,
    Paint linePaint, {
    bool isTiles = false,
    bool hasStartFigure = false,
  }) {
    if (coordinates.length < 2) {
      return;
    }

    final connectorPaint = Paint()
      ..color = linePaint.color
      ..strokeWidth = linePaint.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = linePaint.strokeCap
      ..strokeJoin = linePaint.strokeJoin
      ..blendMode = linePaint.blendMode
      ..filterQuality = linePaint.filterQuality
      ..imageFilter = linePaint.imageFilter
      ..invertColors = linePaint.invertColors
      ..isAntiAlias = linePaint.isAntiAlias
      ..maskFilter = linePaint.maskFilter
      ..shader = linePaint.shader;

    final powers = arrow.powers;
    final hasSourcePower = powers?.any((power) => power.value.isNotEmpty && power.side == '-1') ?? false;
    final hasTargetPower = powers?.any((power) => power.value.isNotEmpty && power.side != '-1') ?? false;

    if (!hasStartFigure && !hasSourcePower) {
      final sourceGeometry = _getDefaultSourcePowerGeometry(
        arrow,
        coordinates,
        scale,
        linePaint.color,
        isTiles: isTiles,
      );
      if (sourceGeometry != null) {
        final lineEnd = _getCircleEdgePoint(
          sourceGeometry.circleCenter,
          sourceGeometry.circleRadius,
          sourceGeometry.side,
        );
        canvas.drawLine(sourceGeometry.position, lineEnd, connectorPaint);
      }
    }

    if (!hasTargetPower) {
      final targetGeometry = _getDefaultTargetPowerGeometry(
        arrow,
        coordinates,
        scale,
        linePaint.color,
        isTiles: isTiles,
      );
      if (targetGeometry != null) {
        final lineEnd = _getCircleEdgePoint(
          targetGeometry.circleCenter,
          targetGeometry.circleRadius,
          targetGeometry.side,
        );
        canvas.drawLine(targetGeometry.position, lineEnd, connectorPaint);
      }
    }

    if (powers == null || powers.isEmpty) {
      return;
    }

    for (final power in powers) {
      if (power.value.isEmpty) continue;

      final geometry = _getPowerGeometry(
        arrow,
        power.value,
        power.side,
        coordinates,
        scale,
        linePaint.color,
        isTiles: isTiles,
      );

      if (geometry == null) continue;

      final lineEnd = _getCircleEdgePoint(geometry.circleCenter, geometry.circleRadius, geometry.side);

      canvas.drawLine(geometry.position, lineEnd, connectorPaint);
    }
  }

  void _drawPowers(
    Canvas canvas,
    Arrow arrow,
    List<Offset> coordinates,
    double scale,
    Color color, {
    bool isTiles = false,
  }) {
    final powers = arrow.powers;
    if (powers == null || powers.isEmpty) return;

    if (coordinates.length < 2) return;

    for (final power in powers) {
      if (power.value.isEmpty) continue;

      final geometry = _getPowerGeometry(arrow, power.value, power.side, coordinates, scale, color, isTiles: isTiles);
      if (geometry == null) continue;

      final textPainter = geometry.textPainter;
      final circleRadius = geometry.circleRadius;
      final circleCenter = geometry.circleCenter;

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
      final textPosition = Offset(circleCenter.dx - textPainter.width / 2, circleCenter.dy - textPainter.height / 2);

      textPainter.paint(canvas, textPosition);
      textPainter.dispose();
    }
  }

  ({TextPainter textPainter, Offset position, String side, double circleRadius, Offset circleCenter})?
  _getPowerGeometry(
    Arrow arrow,
    String powerValue,
    String powerSide,
    List<Offset> coordinates,
    double scale,
    Color color, {
    bool isTiles = false,
  }) {
    if (coordinates.length < 2 || powerValue.isEmpty) {
      return null;
    }

    final sides = arrow.sides;
    final sidesParts = sides?.split(':') ?? ['', ''];
    final sourceSide = sidesParts.isNotEmpty ? sidesParts[0] : '';
    final targetSide = sidesParts.length > 1 ? sidesParts[1] : '';

    final double padding = 14.0 * scale;
    final double fontSize = 8.0 * scale;
    final double circlePadding = 1.0 * scale;

    final textStyle = TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w500);
    final textSpan = TextSpan(text: powerValue, style: textStyle);
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();

    late final Offset position;
    late final String currentSide;

    if (powerSide == '-1') {
      position = isTiles ? coordinates.first * scale : coordinates.first;
      currentSide = sourceSide;
    } else {
      position = isTiles ? coordinates.last * scale : coordinates.last;
      currentSide = targetSide;
    }

    final circleRadius =
        (textPainter.width > textPainter.height ? textPainter.width / 2 : textPainter.height / 2) + circlePadding;

    late final Offset circleCenter;
    switch (currentSide) {
      case 'left':
        circleCenter = Offset(position.dx - padding - circleRadius, position.dy);
        break;
      case 'right':
        circleCenter = Offset(position.dx + padding + circleRadius, position.dy);
        break;
      case 'top':
        circleCenter = Offset(position.dx, position.dy - padding - circleRadius);
        break;
      case 'bottom':
        circleCenter = Offset(position.dx, position.dy + padding + circleRadius);
        break;
      default:
        circleCenter = Offset(position.dx + padding + circleRadius, position.dy);
    }

    return (
      textPainter: textPainter,
      position: position,
      side: currentSide,
      circleRadius: circleRadius,
      circleCenter: circleCenter,
    );
  }

  ({TextPainter textPainter, Offset position, String side, double circleRadius, Offset circleCenter})?
  _getDefaultTargetPowerGeometry(
    Arrow arrow,
    List<Offset> coordinates,
    double scale,
    Color color, {
    bool isTiles = false,
  }) {
    return _getPowerGeometry(arrow, 'M', '1', coordinates, scale, color, isTiles: isTiles);
  }

  ({TextPainter textPainter, Offset position, String side, double circleRadius, Offset circleCenter})?
  _getDefaultSourcePowerGeometry(
    Arrow arrow,
    List<Offset> coordinates,
    double scale,
    Color color, {
    bool isTiles = false,
  }) {
    return _getPowerGeometry(arrow, 'M', '-1', coordinates, scale, color, isTiles: isTiles);
  }

  Offset _getCircleEdgePoint(Offset circleCenter, double circleRadius, String side) {
    switch (side) {
      case 'left':
        return Offset(circleCenter.dx - circleRadius, circleCenter.dy);
      case 'right':
        return Offset(circleCenter.dx + circleRadius, circleCenter.dy);
      case 'top':
        return Offset(circleCenter.dx, circleCenter.dy - circleRadius);
      case 'bottom':
        return Offset(circleCenter.dx, circleCenter.dy + circleRadius);
      default:
        return Offset(circleCenter.dx + circleRadius, circleCenter.dy);
    }
  }

  void _drawEndpointCircles(
    Canvas canvas,
    List<Offset> coordinates,
    double scale,
    Color color, {
    bool drawTarget = true,
  }) {
    if (coordinates.isEmpty) {
      return;
    }

    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(coordinates.first, 5 * scale, circlePaint);

    if (drawTarget && coordinates.length > 1) {
      canvas.drawCircle(coordinates.last, 5 * scale, circlePaint);
    }
  }
}
