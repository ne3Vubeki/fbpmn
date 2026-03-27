import 'package:fbpmn/src/models/image_tile.dart';
import 'package:flutter/foundation.dart';
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
  final Set<String> updatedImageTileIds;

  TileImagePainter({
    required this.scale,
    required this.offset,
    required this.canvasSize,
    required this.state,
    required this.imageTiles,
    required this.nodesIdOnTopLayer,
    required this.isTileEvent,
    required this.updatedImageTileIds,
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

    for (final entry in imageTiles.entries) {
      final tile = state.imageTiles[entry.key];
      if (tile != null && tile.bounds.overlaps(visibleRect)) {
        try {
          final intersection = tile.bounds.intersect(visibleRect);
          if (intersection.isEmpty) continue;

          const double minVisibleSize = 0.1;
          if (intersection.width > minVisibleSize && intersection.height > minVisibleSize) {
            _drawTile(canvas, tile, intersection);
          }
        } catch (e) {
          // Тихая обработка ошибок при рисовании
        }
      }
    }
  }

  void _drawTile(Canvas canvas, ImageTile tile, Rect intersection) {
    canvas.save();
    canvas.saveLayer(intersection, Paint());
    canvas.clipRect(intersection);
    canvas.translate(tile.bounds.left, tile.bounds.top);
    canvas.drawPicture(tile.picture);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TileImagePainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.canvasSize != canvasSize ||
        setEquals(oldDelegate.updatedImageTileIds, updatedImageTileIds) ||
        oldDelegate.isTileEvent != isTileEvent;
  }
}
