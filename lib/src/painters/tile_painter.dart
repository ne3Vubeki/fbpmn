import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:fbpmn/src/models/image_tile.dart';
import 'package:flutter/material.dart';

class TilePainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final List<ImageTile> visibleTiles;

  TilePainter({
    required this.scale,
    required this.offset,
    required this.visibleTiles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (visibleTiles.isEmpty) return;

    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(offset.dx / scale, offset.dy / scale);

    final double visibleLeft   = -offset.dx / scale;
    final double visibleTop    = -offset.dy / scale;
    final double visibleRight  = (size.width  - offset.dx) / scale;
    final double visibleBottom = (size.height - offset.dy) / scale;

    _drawVisibleTiles(canvas, visibleLeft, visibleTop, visibleRight, visibleBottom);

    canvas.restore();
  }

  void _drawVisibleTiles(
    Canvas canvas,
    double visibleLeft,
    double visibleTop,
    double visibleRight,
    double visibleBottom,
  ) {
    final visibleRect = Rect.fromLTRB(visibleLeft, visibleTop, visibleRight, visibleBottom);

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..blendMode = BlendMode.srcOver;

    for (final tile in visibleTiles) {
      // Пропускаем освобождённые тайлы
      if (tile.isDisposed) continue;
      if (!tile.bounds.overlaps(visibleRect)) continue;
      try {
        // Проверяем, что изображение ещё валидно (не освобождено)
        final imageWidth = tile.image.width;
        final imageHeight = tile.image.height;
        if (imageWidth <= 0 || imageHeight <= 0) continue;

        final intersection = tile.bounds.intersect(visibleRect);
        if (intersection.isEmpty) continue;

        final srcLeft   = (intersection.left   - tile.bounds.left) * tile.scale;
        final srcTop    = (intersection.top    - tile.bounds.top)  * tile.scale;
        final srcRight  = (intersection.right  - tile.bounds.left) * tile.scale;
        final srcBottom = (intersection.bottom - tile.bounds.top)  * tile.scale;

        const double epsilon = 0.5;
        if (srcLeft   < -epsilon ||
            srcTop    < -epsilon ||
            srcRight  > imageWidth  + epsilon ||
            srcBottom > imageHeight + epsilon) {
          continue;
        }

        final srcRect = Rect.fromLTRB(
          math.max(0.0, srcLeft),
          math.max(0.0, srcTop),
          math.min(imageWidth.toDouble(),  srcRight),
          math.min(imageHeight.toDouble(), srcBottom),
        );

        const double minVisibleSize = 0.1;
        if (srcRect.width > minVisibleSize && srcRect.height > minVisibleSize) {
          _drawTileWithQuality(canvas, tile.image, srcRect, intersection, paint);
        }
      } catch (_) {
        // Игнорируем ошибки доступа к освобождённым изображениям
      }
    }
  }

  void _drawTileWithQuality(Canvas canvas, ui.Image image, Rect srcRect, Rect dstRect, Paint paint) {
    if (scale < 0.5) {
      canvas.drawImageRect(
        image, srcRect, dstRect,
        Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true
          ..blendMode = BlendMode.srcOver,
      );
    } else {
      canvas.drawImageRect(image, srcRect, dstRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant TilePainter oldDelegate) {
    return oldDelegate.scale != scale ||
           oldDelegate.offset != offset ||
           oldDelegate.visibleTiles != visibleTiles;
  }
}
