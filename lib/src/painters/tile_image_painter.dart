import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:fbpmn/src/models/image_tile.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';

class TileImagePainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final Size canvasSize;
  final EditorState state;
  final Map<String, ImageTile> imageTiles;
  final String nodesIdOnTopLayer;
  final bool isTileEvent;

  TileImagePainter({
    required this.scale,
    required this.offset,
    required this.canvasSize,
    required this.state,
    required this.imageTiles,
    required this.nodesIdOnTopLayer,
    required this.isTileEvent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Рисуем белый фон холста
    canvas.drawRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height), Paint()..color = Colors.transparent);

    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(offset.dx / scale, offset.dy / scale);

    final double visibleLeft = -offset.dx / scale;
    final double visibleTop = -offset.dy / scale;
    final double visibleRight = (size.width - offset.dx) / scale;
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
    if (imageTiles.isEmpty) return;

    final visibleRect = Rect.fromLTRB(visibleLeft, visibleTop, visibleRight, visibleBottom);

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..blendMode = BlendMode.srcOver;

    for (final entry in imageTiles.entries) {
      final tile = state.imageTiles[entry.key];
      if (tile != null && tile.bounds.overlaps(visibleRect)) {
        try {
          final intersection = tile.bounds.intersect(visibleRect);
          if (intersection.isEmpty) continue;

          final srcLeft = (intersection.left - tile.bounds.left) * tile.scale;
          final srcTop = (intersection.top - tile.bounds.top) * tile.scale;
          final srcRight = (intersection.right - tile.bounds.left) * tile.scale;
          final srcBottom = (intersection.bottom - tile.bounds.top) * tile.scale;

          const double epsilon = 0.5;
          if (srcLeft < -epsilon ||
              srcTop < -epsilon ||
              srcRight > tile.image.width + epsilon ||
              srcBottom > tile.image.height + epsilon) {
            continue;
          }

          final srcRect = Rect.fromLTRB(
            math.max(0.0, srcLeft),
            math.max(0.0, srcTop),
            math.min(tile.image.width.toDouble(), srcRight),
            math.min(tile.image.height.toDouble(), srcBottom),
          );

          const double minVisibleSize = 0.1;
          if (srcRect.width > minVisibleSize && srcRect.height > minVisibleSize) {
            print('Рисую тайл ${tile.id}');
            _drawTileWithQuality(canvas, tile.image, srcRect, intersection, paint);
          }
        } catch (e) {
          // Тихая обработка ошибок при рисовании
        }
      }
    }
  }

  void _drawTileWithQuality(Canvas canvas, ui.Image image, Rect srcRect, Rect dstRect, Paint paint) {
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

  @override
  bool shouldRepaint(covariant TileImagePainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.canvasSize != canvasSize ||
        oldDelegate.imageTiles.length != imageTiles.length ||
        oldDelegate.nodesIdOnTopLayer != nodesIdOnTopLayer ||
        oldDelegate.isTileEvent != isTileEvent;
  }
}
