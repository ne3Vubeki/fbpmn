import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';

class HierarchicalGridPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final Size canvasSize;
  final EditorState state;
  final NodeManager nodeManager;
  final bool isNodeDragging;

  HierarchicalGridPainter({
    required this.scale,
    required this.offset,
    required this.canvasSize,
    required this.state,
    required this.nodeManager,
    required this.isNodeDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Рисуем белый фон холста
    canvas.drawRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height), Paint()..color = Colors.white);

    // 2. Применяем трансформации (масштабирование и смещение)
    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(offset.dx / scale, offset.dy / scale);

    // 3. Определяем видимую область в мировых координатах
    final double visibleLeft = -offset.dx / scale;
    final double visibleTop = -offset.dy / scale;
    final double visibleRight = (size.width - offset.dx) / scale;
    final double visibleBottom = (size.height - offset.dy) / scale;

    // 4. Рисуем иерархическую сетку ПЕРВОЙ (она будет под узлами)
    _drawHierarchicalGrid(canvas, visibleLeft, visibleTop, visibleRight, visibleBottom);

    // 5. Рисуем видимые тайлы
    _drawVisibleTiles(canvas, visibleLeft, visibleTop, visibleRight, visibleBottom);

    canvas.restore();
  }

  // Рисуем видимые тайлы
  void _drawVisibleTiles(
    Canvas canvas,
    double visibleLeft,
    double visibleTop,
    double visibleRight,
    double visibleBottom,
  ) {
    if (state.imageTiles.isEmpty) return;

    final visibleRect = Rect.fromLTRB(visibleLeft, visibleTop, visibleRight, visibleBottom);

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..blendMode = BlendMode.srcOver;

    // Ищем тайлы, которые пересекаются с видимой областью
    for (final tile in state.imageTiles) {
      if (tile.bounds.overlaps(visibleRect)) {
        try {
          // Находим пересечение тайла с видимой областью
          final intersection = tile.bounds.intersect(visibleRect);
          if (intersection.isEmpty) continue;

          // Вычисляем координаты в изображении тайла с учетом масштаба тайла
          final srcLeft = (intersection.left - tile.bounds.left) * tile.scale;
          final srcTop = (intersection.top - tile.bounds.top) * tile.scale;
          final srcRight = (intersection.right - tile.bounds.left) * tile.scale;
          final srcBottom = (intersection.bottom - tile.bounds.top) * tile.scale;

          // Проверяем границы изображения с небольшим запасом
          final double epsilon = 0.5; // Небольшой запас для предотвращения артефактов
          if (srcLeft < -epsilon ||
              srcTop < -epsilon ||
              srcRight > tile.image.width + epsilon ||
              srcBottom > tile.image.height + epsilon) {
            continue;
          }

          // Ограничиваем координаты с учетом эпсилон
          final srcRect = Rect.fromLTRB(
            math.max(0.0, srcLeft),
            math.max(0.0, srcTop),
            math.min(tile.image.width.toDouble(), srcRight),
            math.min(tile.image.height.toDouble(), srcBottom),
          );

          final dstRect = intersection;

          // Увеличиваем порог для очень тонких линий
          // При малых масштабах линии могут быть очень тонкими, но все равно должны отображаться
          final double minVisibleSize = 0.1; // Минимальный размер для отображения
          if (srcRect.width > minVisibleSize && srcRect.height > minVisibleSize) {
            // Используем улучшенный метод отрисовки с учетом масштаба
            _drawTileWithQuality(canvas, tile.image, srcRect, dstRect, paint);
          }
        } catch (e) {
          // Тихая обработка ошибок при рисовании
        }
      }
    }
  }

  // Улучшенный метод отрисовки тайлов с учетом качества
  void _drawTileWithQuality(Canvas canvas, ui.Image image, Rect srcRect, Rect dstRect, Paint paint) {
    // При очень маленьких масштабах используем более агрессивный антиалиасинг
    if (scale < 0.5) {
      final highQualityPaint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true
        ..blendMode = BlendMode.srcOver;

      canvas.drawImageRect(image, srcRect, dstRect, highQualityPaint);
    } else {
      canvas.drawImageRect(image, srcRect, dstRect, paint);
    }
  }

  // Методы для рисования сетки остаются без изменений
  void _drawHierarchicalGrid(
    Canvas canvas,
    double visibleLeft,
    double visibleTop,
    double visibleRight,
    double visibleBottom,
  ) {
    const double baseParentSize = 100.0;

    final double extendedLeft = visibleLeft - baseParentSize * 4;
    final double extendedTop = visibleTop - baseParentSize * 4;
    final double extendedRight = visibleRight + baseParentSize * 4;
    final double extendedBottom = visibleBottom + baseParentSize * 4;

    for (int level = -2; level <= 5; level++) {
      double levelParentSize = baseParentSize * math.pow(4, level).toDouble();
      _drawGridLevel(canvas, extendedLeft, extendedTop, extendedRight, extendedBottom, levelParentSize, level);
    }
  }

  void _drawGridLevel(
    Canvas canvas,
    double left,
    double top,
    double right,
    double bottom,
    double parentSize,
    int level,
  ) {
    double alpha = nodeManager.calculateGridAlphaForLevel(level);
    if (alpha < 0.01) return;

    final Paint parentGridPaint = Paint()
      ..color = Color(0xFFE0E0E0).withOpacity(alpha)
      ..strokeWidth = 1.0 / scale;

    final double childSize = parentSize / 4;

    _drawGridLines(canvas, left, top, right, bottom, parentSize, parentGridPaint);

    if (childSize > 2) {
      final double childAlpha = alpha * 0.8;

      if (childAlpha > 0.0005) {
        final Paint childGridPaint = Paint()
          ..color = Color(0xFFF0F0F0).withOpacity(childAlpha)
          ..strokeWidth = 0.5 / scale;

        _drawGridLines(canvas, left, top, right, bottom, childSize, childGridPaint);
      }
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
    double startX = (left / cellSize).floor() * cellSize;
    double endX = (right / cellSize).ceil() * cellSize;

    for (double x = startX; x <= endX; x += cellSize) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }

    double startY = (top / cellSize).floor() * cellSize;
    double endY = (bottom / cellSize).ceil() * cellSize;

    for (double y = startY; y <= endY; y += cellSize) {
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant HierarchicalGridPainter oldDelegate) {
    return !oldDelegate.isNodeDragging || !isNodeDragging;
  }
}
