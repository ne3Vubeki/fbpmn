import 'dart:math';
import 'package:flutter/material.dart';

import '../models/vector_data.dart';

class VectorGridPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final Size canvasSize;
  final Offset delta;
  final List<NodeVectorData> vectorCache;
  final String debugInfo;

  VectorGridPainter({
    required this.scale,
    required this.offset,
    required this.canvasSize,
    required this.delta,
    required this.vectorCache,
    this.debugInfo = '',
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Тайминг для отладки
    final stopwatch = Stopwatch()..start();

    // 1. Белый фон холста
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..color = Colors.white,
    );

    // 2. Применяем трансформации
    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(offset.dx / scale, offset.dy / scale);

    // 3. Видимая область
    final double visibleLeft = -offset.dx / scale;
    final double visibleTop = -offset.dy / scale;
    final double visibleRight = (size.width - offset.dx) / scale;
    final double visibleBottom = (size.height - offset.dy) / scale;

    final visibleRect = Rect.fromLTRB(
      visibleLeft,
      visibleTop,
      visibleRight,
      visibleBottom,
    );

    // 4. Сетка (под узлами)
    _drawHierarchicalGrid(
      canvas,
      visibleLeft,
      visibleTop,
      visibleRight,
      visibleBottom,
    );

    // 5. Рисуем только видимые узлы
    int visibleCount = 0;
    for (final vector in vectorCache) {
      if (vector.isVisible(visibleRect)) {
        visibleCount++;
        _drawNodeVector(canvas, vector);
      }
    }

    // 6. Отладочная информация
    if (debugInfo.isNotEmpty) {
      _drawDebugInfo(canvas, stopwatch.elapsedMicroseconds, visibleCount);
    }

    canvas.restore();
  }

  // Векторная отрисовка узла
  void _drawNodeVector(Canvas canvas, NodeVectorData vector) {
    final nodeRect = vector.bounds;
    final isSimplified = vector.shouldDrawSimplified(scale);
    final drawText = vector.shouldDrawText(scale);
    final drawCellDetails = vector.shouldDrawCellDetails(scale);

    // 1. Основной контур узла
    if (vector.isGroup) {
      // Прямоугольник для группы
      canvas.drawRect(nodeRect, Paint()..color = vector.backgroundColor);
      canvas.drawRect(
        nodeRect,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth =
              1.0 /
              scale // Исправлено: толщина линии учитывает масштаб
          ..isAntiAlias = true,
      );
    } else {
      // Закругленный прямоугольник
      final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
      canvas.drawRRect(roundedRect, Paint()..color = vector.backgroundColor);
      canvas.drawRRect(
        roundedRect,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth =
              1.0 /
              scale // Исправлено: толщина линии учитывает масштаб
          ..isAntiAlias = true,
      );
    }

    // 2. Заголовок (если не упрощенный режим)
    if (!isSimplified) {
      if (vector.isGroup) {
        canvas.drawRect(
          vector.headerRect,
          Paint()..color = vector.headerBackgroundColor,
        );
      } else {
        final headerRoundedRect = RRect.fromRectAndCorners(
          vector.headerRect,
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        );
        canvas.drawRRect(
          headerRoundedRect,
          Paint()..color = vector.headerBackgroundColor,
        );
      }

      // Линия под заголовком
      if (!vector.isGroup) {
        canvas.drawLine(
          Offset(nodeRect.left, nodeRect.top + vector.headerHeight),
          Offset(nodeRect.right, nodeRect.top + vector.headerHeight),
          Paint()
            ..color = Colors.black
            ..strokeWidth =
                1.0 /
                scale // Исправлено
            ..isAntiAlias = true,
        );
      }

      // Текст заголовка
      if (drawText) {
        _drawText(
          canvas,
          vector.headerText,
          Offset(
            nodeRect.left + 8, // Исправлено: отступ учитывает масштаб
            nodeRect.top + (vector.headerHeight - 12) / 2,
          ),
          vector.headerTextColor,
          nodeRect.width - 16, // Исправлено: максимальная ширина
          isBold: true,
        );
      }
    }

    // 3. Ячейки (если не упрощенный режим и нужно рисовать детали)
    if (!isSimplified && drawCellDetails) {
      for (int i = 0; i < vector.attributes.length; i++) {
        final attribute = vector.attributes[i];
        final rowTop =
            nodeRect.top + vector.headerHeight + vector.actualRowHeight * i;
        final rowBottom = rowTop + vector.actualRowHeight;

        // Вертикальная линия разделения
        final columnSplit = vector.qType == 'enum' ? 20 : nodeRect.width - 20;

        canvas.drawLine(
          Offset(nodeRect.left + columnSplit, rowTop),
          Offset(nodeRect.left + columnSplit, rowBottom),
          Paint()
            ..color = Colors.black
            ..strokeWidth =
                1.0 /
                scale // Исправлено
            ..isAntiAlias = true,
        );

        // Горизонтальная линия между строками
        if (i < vector.attributes.length - 1) {
          canvas.drawLine(
            Offset(nodeRect.left, rowBottom),
            Offset(nodeRect.right, rowBottom),
            Paint()
              ..color = Colors.black
              ..strokeWidth =
                  1.0 /
                  scale // Исправлено
              ..isAntiAlias = true,
          );
        }

        // Текст в ячейках
        if (drawText) {
          final leftText = vector.qType == 'enum'
              ? attribute['position']
              : attribute['label'];

          if (leftText.isNotEmpty) {
            _drawText(
              canvas,
              leftText,
              Offset(
                nodeRect.left + 8, // Исправлено
                rowTop + (vector.actualRowHeight - 10) / 2,
              ),
              Colors.black,
              columnSplit - 16, // Исправлено
            );
          }

          if (vector.qType == 'enum') {
            final rightText = attribute['label'];
            if (rightText.isNotEmpty) {
              _drawText(
                canvas,
                rightText,
                Offset(
                  nodeRect.left + columnSplit + 8, // Исправлено
                  rowTop + (vector.actualRowHeight - 10) / 2,
                ),
                Colors.black,
                nodeRect.width - columnSplit - 16, // Исправлено
              );
            }
          }
        }
      }
    }

    final children = vector.children ?? [];

    if (children.isNotEmpty) {
      for (int i = 0; i < children.length; i++) {
        final vect = children[i];
        _drawNodeVector(canvas, vect);
      }
    }

    // 4. Выделение (если узел выбран)
    if (vector.isSelected) {
      final selectionPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / scale
        ..isAntiAlias = true;

      if (vector.isGroup) {
        final selectionRect = Rect.fromLTWH(
          nodeRect.left - 2 / scale, // Исправлено
          nodeRect.top - 2 / scale, // Исправлено
          nodeRect.width + 4 / scale, // Исправлено
          nodeRect.height + 4 / scale, // Исправлено
        );
        canvas.drawRect(selectionRect, selectionPaint);
      } else {
        final selectionRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            nodeRect.left - 2 / scale, // Исправлено
            nodeRect.top - 2 / scale, // Исправлено
            nodeRect.width + 4 / scale, // Исправлено
            nodeRect.height + 4 / scale, // Исправлено
          ),
          Radius.circular(8), // Исправлено
        );
        canvas.drawRRect(selectionRRect, selectionPaint);
      }
    }
  }

  // Оптимизированная отрисовка текста
  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
    double maxWidth, {
    bool isBold = false,
  }) {
    // Размер шрифта фиксированный в мировых координатах
    // Это обеспечивает постоянный размер текста относительно содержимого
    final fontSize = isBold ? 12.0 : 10.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      maxLines: 1,
      ellipsis: '...',
    );

    textPainter.layout(maxWidth: maxWidth);
    textPainter.paint(canvas, position);
  }

  // Отладочная информация
  void _drawDebugInfo(
    Canvas canvas,
    int elapsedMicroseconds,
    int visibleCount,
  ) {
    final info =
        '''
$debugInfo
Векторный рендеринг
Узлов: $visibleCount/${vectorCache.length} видно
Время: ${(elapsedMicroseconds / 1000).toStringAsFixed(1)}ms
''';

    final textPainter = TextPainter(
      text: TextSpan(
        text: info,
        style: TextStyle(
          color: Colors.blue,
          fontSize: 10,
          backgroundColor: Colors.white.withOpacity(0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(10, 10));
  }

  // Методы сетки (оптимизированные)
  void _drawHierarchicalGrid(
    Canvas canvas,
    double visibleLeft,
    double visibleTop,
    double visibleRight,
    double visibleBottom,
  ) {
    const double baseParentSize = 100.0;

    // Расширяем область для плавного появления/исчезновения
    final double extendedLeft = visibleLeft - baseParentSize * 2;
    final double extendedTop = visibleTop - baseParentSize * 2;
    final double extendedRight = visibleRight + baseParentSize * 2;
    final double extendedBottom = visibleBottom + baseParentSize * 2;

    // Оптимизация: рисуем только уровни с достаточной прозрачностью
    for (int level = -2; level <= 5; level++) {
      final alpha = _calculateAlphaForLevel(level);
      if (alpha < 0.05) continue; // Пропускаем почти невидимые уровни

      final levelParentSize = baseParentSize * pow(4, level);
      _drawGridLevel(
        canvas,
        extendedLeft,
        extendedTop,
        extendedRight,
        extendedBottom,
        levelParentSize,
        alpha,
      );
    }
  }

  void _drawGridLevel(
    Canvas canvas,
    double left,
    double top,
    double right,
    double bottom,
    double parentSize,
    double alpha,
  ) {
    final Paint parentGridPaint = Paint()
      ..color = Color(0xFFE0E0E0).withOpacity(alpha)
      ..strokeWidth =
          max(0.5, 1.0) // Фиксированная толщина в мировых координатах
      ..isAntiAlias = true;

    _drawGridLines(
      canvas,
      left,
      top,
      right,
      bottom,
      parentSize,
      parentGridPaint,
    );

    // Дочерняя сетка (4x4)
    final double childSize = parentSize / 4;
    final double childAlpha = alpha * 0.6;

    if (childAlpha > 0.05 && childSize > 5) {
      // Минимальный размер для рисования
      final Paint childGridPaint = Paint()
        ..color = Color(0xFFF0F0F0).withOpacity(childAlpha)
        ..strokeWidth =
            max(0.3, 0.5) // Фиксированная толщина
        ..isAntiAlias = true;

      _drawGridLines(
        canvas,
        left,
        top,
        right,
        bottom,
        childSize,
        childGridPaint,
      );
    }
  }

  void _drawGridLines(
    Canvas canvas,
    double left,
    double top,
    double right,
    double bottom,
    double cellSize,
    Paint paint,
  ) {
    // Оптимизация: вычисляем только видимые линии
    final startX = (left / cellSize).floor() * cellSize;
    final endX = (right / cellSize).ceil() * cellSize;
    final startY = (top / cellSize).floor() * cellSize;
    final endY = (bottom / cellSize).ceil() * cellSize;

    // Вертикальные линии
    for (double x = startX; x <= endX; x += cellSize) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }

    // Горизонтальные линии
    for (double y = startY; y <= endY; y += cellSize) {
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  double _calculateAlphaForLevel(int level) {
    final idealScale = 1.0 / pow(4, level);
    final logDifference = (log(scale) - log(idealScale)).abs();
    final maxLogDifference = 2.0;
    final alpha = 1.0 - min(logDifference / maxLogDifference, 1.0);
    return pow(alpha, 3).toDouble();
  }

  @override
  bool shouldRepaint(covariant VectorGridPainter oldDelegate) {
    // Оптимизация: перерисовываем только при значительных изменениях
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.canvasSize != canvasSize ||
        oldDelegate.delta != delta ||
        !_compareVectorCaches(oldDelegate.vectorCache, vectorCache) ||
        oldDelegate.debugInfo != debugInfo;
  }

  @override
  bool shouldRebuildSemantics(covariant VectorGridPainter oldDelegate) {
    return shouldRepaint(oldDelegate);
  }

  // Сравнение векторных кешей
  bool _compareVectorCaches(List<NodeVectorData> a, List<NodeVectorData> b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      final vectorA = a[i];
      final vectorB = b[i];

      if (vectorA.id != vectorB.id ||
          vectorA.bounds != vectorB.bounds ||
          vectorA.backgroundColor != vectorB.backgroundColor ||
          vectorA.headerText != vectorB.headerText ||
          vectorA.isSelected != vectorB.isSelected ||
          vectorA.position != vectorB.position) {
        return false;
      }
    }

    return true;
  }
}
