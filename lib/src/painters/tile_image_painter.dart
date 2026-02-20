import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../services/arrow_manager.dart';
import '../services/node_manager.dart';
import '../services/tile_manager.dart';

class TileImagePainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final Size canvasSize;
  final EditorState state;
  final TileManager tileManager;
  final NodeManager nodeManager;
  final ArrowManager arrowManager;

  TileImagePainter({
    required this.scale,
    required this.offset,
    required this.canvasSize,
    required this.state,
    required this.tileManager,
    required this.nodeManager,
    required this.arrowManager,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Рисуем белый фон холста
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..color = Colors.white,
    );

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
    if (state.imageTiles.isEmpty) return;

    final visibleRect = Rect.fromLTRB(visibleLeft, visibleTop, visibleRight, visibleBottom);

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..blendMode = BlendMode.srcOver;

    for (final tile in state.imageTiles) {
      if (tile.bounds.overlaps(visibleRect)) {
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
        oldDelegate.state.imageTiles.length != state.imageTiles.length;
  }
}
