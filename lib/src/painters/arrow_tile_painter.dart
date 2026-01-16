import 'package:flutter/material.dart';
import '../models/table.node.dart';
import '../models/arrow.dart';
import '../services/arrow_manager.dart';

class ArrowTilePainter {
  final List<Arrow> arrows;
  final List<TableNode> nodes;
  final Map<TableNode, Rect> nodeBoundsCache;
  late final ArrowManager arrowManager;

  ArrowTilePainter({
    required this.arrows,
    required this.nodes,
    required this.nodeBoundsCache,
  }) {
    arrowManager = ArrowManager(
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

    // Рисуем все стрелки, которые пересекают этот тайл
    for (final arrow in arrows) {
      // Проверяем, пересекает ли стрелка этот тайл
      if (arrowManager.doesArrowPathIntersectTile(arrow, tileBounds, baseOffset)) {
        // Получаем полный путь стрелки
        final path = arrowManager.getArrowPathForTiles(arrow, baseOffset);
        
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
    Offset baseOffset = Offset.zero,
  }) {
    final arrowsInTile = <Arrow>[];
    final arrowManager = ArrowManager(
      arrows: allArrows,
      nodes: allNodes,
      nodeBoundsCache: nodeBoundsCache,
    );

    for (final arrow in allArrows) {
      // Используем менеджер для проверки пересечения
      if (arrowManager.doesArrowPathIntersectTile(arrow, tileBounds, baseOffset)) {
        arrowsInTile.add(arrow);
      }
    }

    return arrowsInTile;
  }
}