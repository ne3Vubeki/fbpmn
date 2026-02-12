import 'package:flutter/material.dart';

/// Класс для отрисовки иконок с помощью Canvas
class CanvasIcons {
  /// Иконка миниатюры (picture_in_picture)
  static void paintThumbnail(Canvas canvas, Size size, Color color, {bool filled = false}) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Внешний прямоугольник
    final outerRect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawRect(outerRect, paint);

    // Внутренний прямоугольник (миниатюра)
    if (filled) {
      final innerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final innerRect = Rect.fromLTWH(
        size.width * 0.5,
        size.height * 0.5,
        size.width * 0.4,
        size.height * 0.4,
      );
      canvas.drawRect(innerRect, innerPaint);
    } else {
      final innerRect = Rect.fromLTWH(
        size.width * 0.5,
        size.height * 0.5,
        size.width * 0.4,
        size.height * 0.4,
      );
      canvas.drawRect(innerRect, paint);
    }
  }

  /// Иконка сетки включена (grid_on)
  static void paintGridOn(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cellWidth = size.width / 3;
    final cellHeight = size.height / 3;

    // Вертикальные линии
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(cellWidth * i, 2),
        Offset(cellWidth * i, size.height - 2),
        paint,
      );
    }

    // Горизонтальные линии
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(2, cellHeight * i),
        Offset(size.width - 2, cellHeight * i),
        paint,
      );
    }

    // Рамка
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawRect(rect, paint);
  }

  /// Иконка сетки выключена (grid_off)
  static void paintGridOff(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cellWidth = size.width / 3;
    final cellHeight = size.height / 3;

    // Вертикальные линии (пунктирные)
    for (int i = 1; i < 3; i++) {
      _drawDashedLine(
        canvas,
        Offset(cellWidth * i, 2),
        Offset(cellWidth * i, size.height - 2),
        paint,
        dashWidth: 2,
        dashSpace: 2,
      );
    }

    // Горизонтальные линии (пунктирные)
    for (int i = 1; i < 3; i++) {
      _drawDashedLine(
        canvas,
        Offset(2, cellHeight * i),
        Offset(size.width - 2, cellHeight * i),
        paint,
        dashWidth: 2,
        dashSpace: 2,
      );
    }

    // Рамка (пунктирная)
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    _drawDashedRect(canvas, rect, paint);
  }

  /// Иконка кривых (timeline)
  static void paintCurves(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(2, size.height - 2);
    
    // Кривая линия
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.5,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.5,
      size.width - 2,
      2,
    );

    canvas.drawPath(path, paint);

    // Точки на кривой
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(2, size.height - 2), 2, pointPaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 2, pointPaint);
    canvas.drawCircle(Offset(size.width - 2, 2), 2, pointPaint);
  }

  /// Иконка ортогональных линий (show_chart)
  static void paintOrthogonal(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(2, size.height - 2);
    path.lineTo(size.width * 0.3, size.height - 2);
    path.lineTo(size.width * 0.3, size.height * 0.5);
    path.lineTo(size.width * 0.7, size.height * 0.5);
    path.lineTo(size.width * 0.7, 2);
    path.lineTo(size.width - 2, 2);

    canvas.drawPath(path, paint);

    // Точки на линии
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(2, size.height - 2), 2, pointPaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.5), 2, pointPaint);
    canvas.drawCircle(Offset(size.width * 0.7, 2), 2, pointPaint);
    canvas.drawCircle(Offset(size.width - 2, 2), 2, pointPaint);
  }

  /// Иконка фокусировки (zoom_out_map)
  static void paintZoomOutMap(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final arrowSize = size.width * 0.25;

    // Стрелки в углах
    // Верхний левый
    canvas.drawLine(Offset(2, 2), Offset(2 + arrowSize, 2), paint);
    canvas.drawLine(Offset(2, 2), Offset(2, 2 + arrowSize), paint);

    // Верхний правый
    canvas.drawLine(Offset(size.width - 2, 2), Offset(size.width - 2 - arrowSize, 2), paint);
    canvas.drawLine(Offset(size.width - 2, 2), Offset(size.width - 2, 2 + arrowSize), paint);

    // Нижний левый
    canvas.drawLine(Offset(2, size.height - 2), Offset(2 + arrowSize, size.height - 2), paint);
    canvas.drawLine(Offset(2, size.height - 2), Offset(2, size.height - 2 - arrowSize), paint);

    // Нижний правый
    canvas.drawLine(Offset(size.width - 2, size.height - 2), Offset(size.width - 2 - arrowSize, size.height - 2), paint);
    canvas.drawLine(Offset(size.width - 2, size.height - 2), Offset(size.width - 2, size.height - 2 - arrowSize), paint);
  }

  /// Иконка границ включена (border_outer)
  static void paintBorderOuter(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawRect(rect, paint);

    // Внутренний крест
    final thinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(size.width / 2, 4),
      Offset(size.width / 2, size.height - 4),
      thinPaint,
    );
    canvas.drawLine(
      Offset(4, size.height / 2),
      Offset(size.width - 4, size.height / 2),
      thinPaint,
    );
  }

  /// Иконка границ выключена (border_clear)
  static void paintBorderClear(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    _drawDashedRect(canvas, rect, paint);

    // Внутренний крест (пунктирный)
    _drawDashedLine(
      canvas,
      Offset(size.width / 2, 4),
      Offset(size.width / 2, size.height - 4),
      paint,
      dashWidth: 2,
      dashSpace: 2,
    );
    _drawDashedLine(
      canvas,
      Offset(4, size.height / 2),
      Offset(size.width - 4, size.height / 2),
      paint,
      dashWidth: 2,
      dashSpace: 2,
    );
  }

  /// Иконка закрытого замка (lock)
  static void paintLock(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Размеры замка
    final lockWidth = size.width * 0.5;
    final lockHeight = size.height * 0.4;
    final lockLeft = (size.width - lockWidth) / 2;
    final lockTop = size.height * 0.45;

    // Дужка замка (полукруг сверху)
    final shackleWidth = lockWidth * 0.6;
    final shackleHeight = size.height * 0.3;
    final shackleLeft = lockLeft + (lockWidth - shackleWidth) / 2;
    final shackleTop = lockTop - shackleHeight;

    final shackleRect = Rect.fromLTWH(
      shackleLeft,
      shackleTop,
      shackleWidth,
      shackleHeight * 2,
    );

    canvas.drawArc(
      shackleRect,
      3.14159, // π (180 градусов)
      3.14159, // π (180 градусов)
      false,
      paint,
    );

    // Вертикальные линии дужки
    canvas.drawLine(
      Offset(shackleLeft, shackleTop + shackleHeight),
      Offset(shackleLeft, lockTop),
      paint,
    );
    canvas.drawLine(
      Offset(shackleLeft + shackleWidth, shackleTop + shackleHeight),
      Offset(shackleLeft + shackleWidth, lockTop),
      paint,
    );

    // Тело замка (прямоугольник со скругленными углами)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(lockLeft, lockTop, lockWidth, lockHeight),
      Radius.circular(2),
    );
    canvas.drawRRect(bodyRect, paint);
    canvas.drawRRect(bodyRect, fillPaint);

    // Замочная скважина
    final keyholeRadius = lockWidth * 0.12;
    final keyholeCenterX = lockLeft + lockWidth / 2;
    final keyholeCenterY = lockTop + lockHeight * 0.35;

    // Круглая часть замочной скважины
    final keyholePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(keyholeCenterX, keyholeCenterY),
      keyholeRadius,
      keyholePaint,
    );

    // Прямоугольная часть замочной скважины (внизу)
    final keyholeSlotWidth = keyholeRadius * 0.6;
    final keyholeSlotHeight = lockHeight * 0.35;
    final keyholeSlotRect = Rect.fromLTWH(
      keyholeCenterX - keyholeSlotWidth / 2,
      keyholeCenterY,
      keyholeSlotWidth,
      keyholeSlotHeight,
    );
    canvas.drawRect(keyholeSlotRect, keyholePaint);
  }

  /// Иконка предупреждения (красный треугольник с буквой i)
  static void paintWarningTriangle(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Вычисляем точки треугольника
    final triangleHeight = size.height * 0.85;
    final triangleWidth = size.width * 0.85;
    
    final topPoint = Offset(center.dx, center.dy - triangleHeight / 2);
    final bottomLeft = Offset(center.dx - triangleWidth / 2, center.dy + triangleHeight / 2);
    final bottomRight = Offset(center.dx + triangleWidth / 2, center.dy + triangleHeight / 2);
    
    // Создаем путь треугольника с закругленными углами
    final path = Path();
    final cornerRadius = size.width * 0.1;
    
    // Начинаем от верхней точки (с небольшим смещением для закругления)
    path.moveTo(topPoint.dx, topPoint.dy + cornerRadius);
    
    // Линия к нижнему левому углу
    path.lineTo(bottomLeft.dx + cornerRadius * 0.866, bottomLeft.dy - cornerRadius * 0.5);
    
    // Закругление в нижнем левом углу
    path.arcToPoint(
      Offset(bottomLeft.dx + cornerRadius, bottomLeft.dy),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );
    
    // Нижняя линия
    path.lineTo(bottomRight.dx - cornerRadius, bottomRight.dy);
    
    // Закругление в нижнем правом углу
    path.arcToPoint(
      Offset(bottomRight.dx - cornerRadius * 0.866, bottomRight.dy - cornerRadius * 0.5),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );
    
    // Линия к верхней точке
    path.lineTo(topPoint.dx, topPoint.dy + cornerRadius);
    
    path.close();
    
    // Рисуем красный треугольник
    final trianglePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    
    canvas.drawPath(path, trianglePaint);
    
    // Рисуем белую букву "i"
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: size.height * 0.5,
      fontWeight: FontWeight.bold,
      fontFamily: 'Arial',
    );
    
    final textSpan = TextSpan(
      text: 'i',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout();
    
    // Позиционируем букву "i" в центре треугольника
    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 4,
    );
    
    textPainter.paint(canvas, textOffset);
  }

  /// Иконка перемещения (open_with)
  static void paintOpenWith(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;

    final center = Offset(size.width / 2, size.height / 2);
    final lineLength = size.width * 0.3;
    final arrowSize = size.width * 0.12;

    // Рисуем 4 стрелки от центра в разные стороны
    // Стрелка вверх
    final topEnd = Offset(center.dx, center.dy - lineLength);
    canvas.drawLine(center, topEnd, paint);
    final topPath = Path()
      ..moveTo(topEnd.dx - arrowSize, topEnd.dy + arrowSize)
      ..lineTo(topEnd.dx, topEnd.dy)
      ..lineTo(topEnd.dx + arrowSize, topEnd.dy + arrowSize);
    canvas.drawPath(topPath, paint);

    // Стрелка вниз
    final bottomEnd = Offset(center.dx, center.dy + lineLength);
    canvas.drawLine(center, bottomEnd, paint);
    final bottomPath = Path()
      ..moveTo(bottomEnd.dx - arrowSize, bottomEnd.dy - arrowSize)
      ..lineTo(bottomEnd.dx, bottomEnd.dy)
      ..lineTo(bottomEnd.dx + arrowSize, bottomEnd.dy - arrowSize);
    canvas.drawPath(bottomPath, paint);

    // Стрелка влево
    final leftEnd = Offset(center.dx - lineLength, center.dy);
    canvas.drawLine(center, leftEnd, paint);
    final leftPath = Path()
      ..moveTo(leftEnd.dx + arrowSize, leftEnd.dy - arrowSize)
      ..lineTo(leftEnd.dx, leftEnd.dy)
      ..lineTo(leftEnd.dx + arrowSize, leftEnd.dy + arrowSize);
    canvas.drawPath(leftPath, paint);

    // Стрелка вправо
    final rightEnd = Offset(center.dx + lineLength, center.dy);
    canvas.drawLine(center, rightEnd, paint);
    final rightPath = Path()
      ..moveTo(rightEnd.dx - arrowSize, rightEnd.dy - arrowSize)
      ..lineTo(rightEnd.dx, rightEnd.dy)
      ..lineTo(rightEnd.dx - arrowSize, rightEnd.dy + arrowSize);
    canvas.drawPath(rightPath, paint);

    // Центральный круг
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.0, circlePaint);
  }

  /// Вспомогательный метод для рисования пунктирной линии
  static void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 3,
    double dashSpace = 3,
  }) {
    final distance = (end - start).distance;
    final normalizedVector = Offset(
      (end.dx - start.dx) / distance,
      (end.dy - start.dy) / distance,
    );

    double currentDistance = 0;
    bool isDash = true;

    while (currentDistance < distance) {
      final segmentLength = isDash ? dashWidth : dashSpace;
      final nextDistance = (currentDistance + segmentLength).clamp(0.0, distance);

      if (isDash) {
        final startPoint = Offset(
          start.dx + normalizedVector.dx * currentDistance,
          start.dy + normalizedVector.dy * currentDistance,
        );
        final endPoint = Offset(
          start.dx + normalizedVector.dx * nextDistance,
          start.dy + normalizedVector.dy * nextDistance,
        );
        canvas.drawLine(startPoint, endPoint, paint);
      }

      currentDistance = nextDistance;
      isDash = !isDash;
    }
  }

  /// Вспомогательный метод для рисования пунктирного прямоугольника
  static void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  /// Иконка автораскладки (auto_layout / scatter_plot)
  static void paintAutoLayout(Canvas canvas, Size size, Color color, {bool active = false}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Рисуем 4 узла в виде прямоугольников
    final nodeSize = size.width * 0.2;
    final nodes = [
      Offset(size.width * 0.2, size.height * 0.25),
      Offset(size.width * 0.65, size.height * 0.15),
      Offset(size.width * 0.15, size.height * 0.65),
      Offset(size.width * 0.6, size.height * 0.6),
    ];

    // Рисуем связи между узлами
    canvas.drawLine(
      Offset(nodes[0].dx + nodeSize / 2, nodes[0].dy + nodeSize / 2),
      Offset(nodes[1].dx + nodeSize / 2, nodes[1].dy + nodeSize / 2),
      paint,
    );
    canvas.drawLine(
      Offset(nodes[0].dx + nodeSize / 2, nodes[0].dy + nodeSize / 2),
      Offset(nodes[2].dx + nodeSize / 2, nodes[2].dy + nodeSize / 2),
      paint,
    );
    canvas.drawLine(
      Offset(nodes[1].dx + nodeSize / 2, nodes[1].dy + nodeSize / 2),
      Offset(nodes[3].dx + nodeSize / 2, nodes[3].dy + nodeSize / 2),
      paint,
    );
    canvas.drawLine(
      Offset(nodes[2].dx + nodeSize / 2, nodes[2].dy + nodeSize / 2),
      Offset(nodes[3].dx + nodeSize / 2, nodes[3].dy + nodeSize / 2),
      paint,
    );

    // Рисуем узлы поверх связей
    for (final node in nodes) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(node.dx, node.dy, nodeSize, nodeSize),
        Radius.circular(2),
      );
      if (active) {
        canvas.drawRRect(rect, fillPaint);
      } else {
        canvas.drawRRect(rect, paint);
      }
    }
  }

  /// Иконка метрик производительности (speedometer)
  static void paintPerformance(Canvas canvas, Size size, Color color, {bool filled = false}) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height * 0.55);
    final radius = size.width * 0.4;

    // Полукруг (спидометр)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159, // π
      3.14159, // π
      false,
      paint,
    );

    // Стрелка спидометра
    final needlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Угол стрелки (примерно 45 градусов от вертикали)
    final needleAngle = filled ? -0.5 : -1.0; // Разные позиции для filled/unfilled
    final needleLength = radius * 0.7;
    final needleEnd = Offset(
      center.dx + needleLength * (needleAngle > 0 ? 0.7 : -0.3),
      center.dy - needleLength * 0.7,
    );

    canvas.drawLine(center, needleEnd, needlePaint);

    // Центральная точка
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2, dotPaint);

  }
}

/// Виджет для отображения canvas-иконки
class CanvasIcon extends StatelessWidget {
  final void Function(Canvas, Size, Color) painter;
  final double size;
  final Color color;

  const CanvasIcon({
    super.key,
    required this.painter,
    this.size = 18,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CanvasIconPainter(painter: painter, color: color),
    );
  }
}

/// CustomPainter для отрисовки иконки
class _CanvasIconPainter extends CustomPainter {
  final void Function(Canvas, Size, Color) painter;
  final Color color;

  _CanvasIconPainter({required this.painter, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    painter(canvas, size, color);
  }

  @override
  bool shouldRepaint(covariant _CanvasIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
