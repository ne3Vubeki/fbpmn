import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/image_tile.dart';
import '../models/table.node.dart';
import 'editor_config.dart';

class BoundsCalculator {
  // УБИРАЕМ общие границы - теперь метод просто собирает узлы для тайла
  List<TableNode> getNodesForTile({
    required Rect bounds,
    required List<TableNode> allNodes,
    required Offset delta,
    required TableNode? excludedNode,
  }) {
    final List<TableNode> nodesInTile = [];

    void collectNodes(
      TableNode node,
      Offset parentOffset,
      bool isParentCollapsedSwimlane,
    ) {
      // Пропускаем исключенный узел
      if (excludedNode != null && node.id == excludedNode.id) {
        return;
      }

      // Если родительский swimlane свернут, пропускаем детей
      if (isParentCollapsedSwimlane && node.qType != 'swimlane') {
        return;
      }

      final shiftedPosition = node.position + parentOffset;
      final nodeRect = calculateNodeRect(node: node, position: shiftedPosition);

      // Проверяем пересечение с тайлом
      if (nodeRect.overlaps(bounds)) {
        nodesInTile.add(node);
      }

      // Проверяем, является ли текущий узел свернутым swimlane
      final isCurrentCollapsedSwimlane =
          node.qType == 'swimlane' && (node.isCollapsed ?? false);

      // Рекурсивно проверяем детей, если узел не свернут
      if (!isCurrentCollapsedSwimlane &&
          node.children != null &&
          node.children!.isNotEmpty) {
        for (final child in node.children!) {
          collectNodes(child, shiftedPosition, isCurrentCollapsedSwimlane);
        }
      }
    }

    for (final node in allNodes) {
      collectNodes(node, delta, false);
    }

    return nodesInTile;
  }

  Rect calculateNodeRect({required TableNode node, required Offset position}) {
    final actualWidth = node.size.width;
    final minHeight = _calculateMinHeight(node);
    final actualHeight = math.max(node.size.height, minHeight);

    return Rect.fromLTWH(position.dx, position.dy, actualWidth, actualHeight);
  }

  Set<int> getTileIndicesForNode({
    required TableNode node,
    required Offset nodePosition,
    required List<ImageTile> imageTiles,
  }) {
    final Set<int> indices = {};
    final nodeRect = calculateNodeRect(node: node, position: nodePosition);

    for (int i = 0; i < imageTiles.length; i++) {
      final tile = imageTiles[i];
      if (nodeRect.overlaps(tile.bounds)) {
        indices.add(i);
      }
    }

    return indices;
  }

  double _calculateMinHeight(TableNode node) {
    return EditorConfig.headerHeight +
        (node.attributes.length * EditorConfig.minRowHeight);
  }

  /// Получает только корневые узлы для тайла
  List<TableNode> getRootNodesForTile({
    required Rect bounds,
    required List<TableNode> allNodes,
    required Offset delta,
    required TableNode? excludedNode,
  }) {
    final List<TableNode> rootNodes = [];

    void checkNode(TableNode node, Offset parentOffset, bool isRoot) {
      // Пропускаем исключенный узел
      if (excludedNode != null && node.id == excludedNode.id) {
        return;
      }

      final shiftedPosition = node.position + parentOffset;
      final nodeRect = calculateNodeRect(node: node, position: shiftedPosition);

      if (nodeRect.overlaps(bounds)) {
        if (isRoot) {
          rootNodes.add(node);
        }
      }

      if (node.children != null && node.children!.isNotEmpty) {
        for (final child in node.children!) {
          checkNode(child, shiftedPosition, false);
        }
      }
    }

    for (final node in allNodes) {
      checkNode(node, delta, true);
    }

    return rootNodes;
  }
}
