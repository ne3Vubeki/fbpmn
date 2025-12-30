import 'package:flutter/material.dart';
import '../models/table.node.dart';
import '../painters/node_painter.dart';

class NodeRenderer {
  /// Рисует только корневые узлы, их дети рисуются рекурсивно
  void drawRootNodesToTile({
    required Canvas canvas,
    required List<TableNode> rootNodes, // Только корневые узлы
    required Rect tileBounds,
    required Offset delta,
    required Map<TableNode, Rect> cache,
  }) {
    for (final node in rootNodes) {
      // Пропускаем свернутые swimlane, которые не видны в тайле
      if (node.qType == 'swimlane' && (node.isCollapsed ?? false)) {
        final nodeWorldPosition = delta + node.position;
        final nodeRect = Rect.fromLTWH(
          nodeWorldPosition.dx,
          nodeWorldPosition.dy,
          node.size.width,
          node.size.height,
        );

        // Проверяем, пересекается ли узел с тайлом
        if (!nodeRect.overlaps(tileBounds)) {
          continue;
        }
      }

      final painter = NodePainter(node: node);

      painter.paintWithOffset(
        canvas: canvas,
        baseOffset: delta,
        visibleBounds: tileBounds,
        forTile: true,
        nodeBoundsCache: cache,
      );
    }
  }

  /// Старый метод для обратной совместимости
  void drawNodeToTile({
    required Canvas canvas,
    required TableNode node,
    required Rect tileBounds,
    required Offset delta,
    required Map<TableNode, Rect> cache,
  }) {
    // Пропускаем свернутые swimlane, которые не видны в тайле
    if (node.qType == 'swimlane' && (node.isCollapsed ?? false)) {
      final nodeWorldPosition = delta + node.position;
      final nodeRect = Rect.fromLTWH(
        nodeWorldPosition.dx,
        nodeWorldPosition.dy,
        node.size.width,
        node.size.height,
      );

      // Проверяем, пересекается ли узел с тайлом
      if (!nodeRect.overlaps(tileBounds)) {
        return;
      }
    }

    final painter = NodePainter(node: node);

    painter.paintWithOffset(
      canvas: canvas,
      baseOffset: delta,
      visibleBounds: tileBounds,
      forTile: true,
      nodeBoundsCache: cache,
    );
  }
}
