import 'package:flutter/material.dart';
import '../models/table.node.dart';
import '../models/arrow.dart';
import '../services/arrow_tile_coordinator.dart';

class ArrowTilePainter {
  final List<Arrow> arrows;
  final List<TableNode> nodes;
  final Map<TableNode, Rect> nodeBoundsCache;
  late final ArrowTileCoordinator coordinator;

  ArrowTilePainter({
    required this.arrows,
    required this.nodes,
    required this.nodeBoundsCache,
  }) {
    coordinator = ArrowTileCoordinator(
      arrows: arrows,
      nodes: nodes,
      nodeBoundsCache: nodeBoundsCache,
    );
  }

  void drawArrowsInTile({
    required Canvas canvas,
    required Rect tileBounds,
    required Offset baseOffset,
  }) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Рисуем только те стрелки, путь которых пересекает этот тайл
    for (final arrow in arrows) {
      // Проверяем, пересекает ли стрелка этот тайл
      if (coordinator.doesArrowIntersectTile(arrow, tileBounds, baseOffset)) {
        // Получаем полный путь стрелки
        final path = coordinator.getArrowPathForTiles(arrow, baseOffset);
        
        // Рисуем путь (автоматически обрежется по границам тайла)
        canvas.drawPath(path, paint);
      }
    }
  }

  // Статический метод для получения стрелок для тайла
  static List<Arrow> getArrowsForTile({
    required Rect tileBounds,
    required List<Arrow> allArrows,
    required List<TableNode> allNodes,
    required Map<TableNode, Rect> nodeBoundsCache,
  }) {
    final arrowsInTile = <Arrow>[];
    final coordinator = ArrowTileCoordinator(
      arrows: allArrows,
      nodes: allNodes,
      nodeBoundsCache: nodeBoundsCache,
    );

    for (final arrow in allArrows) {
      // Используем координатор для проверки пересечения
      if (coordinator.doesArrowIntersectTile(arrow, tileBounds, Offset.zero)) {
        arrowsInTile.add(arrow);
      }
    }

    return arrowsInTile;
  }
}