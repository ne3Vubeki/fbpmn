import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/image_tile.dart';
import '../models/table.node.dart';
import 'editor_config.dart';

class BoundsCalculator {
  Rect? calculateTotalBounds({
    required List<TableNode> nodes,
    required Offset delta,
    required Map<TableNode, Rect> cache,
  }) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    bool hasNodes = false;

    void calculateBounds(List<TableNode> nodeList, Offset currentOffset) {
      for (final node in nodeList) {
        hasNodes = true;
        final shiftedPosition = node.position + currentOffset;
        final nodeRect = calculateNodeRect(
          node: node,
          position: shiftedPosition,
        );

        cache[node] = nodeRect;

        minX = math.min(minX, nodeRect.left);
        minY = math.min(minY, nodeRect.top);
        maxX = math.max(maxX, nodeRect.right);
        maxY = math.max(maxY, nodeRect.bottom);

        if (node.children != null && node.children!.isNotEmpty) {
          calculateBounds(node.children!, shiftedPosition);
        }
      }
    }

    calculateBounds(nodes, delta);

    if (!hasNodes) {
      return null;
    }

    return Rect.fromLTRB(
      minX - EditorConfig.tilePadding,
      minY - EditorConfig.tilePadding,
      maxX + EditorConfig.tilePadding,
      maxY + EditorConfig.tilePadding,
    );
  }

  Rect calculateNodeRect({required TableNode node, required Offset position}) {
    final actualWidth = node.size.width;
    final minHeight = _calculateMinHeight(node);
    final actualHeight = math.max(node.size.height, minHeight);

    return Rect.fromLTWH(position.dx, position.dy, actualWidth, actualHeight);
  }

  List<TableNode> getNodesForTile({
    required Rect bounds,
    required List<TableNode> allNodes,
    required Offset delta,
    required TableNode? excludedNode,
  }) {
    final List<TableNode> nodesInTile = [];

    void collectNodes(TableNode node, Offset parentOffset) {
      // Пропускаем исключенный узел
      if (excludedNode != null && node.id == excludedNode.id) {
        return;
      }

      final shiftedPosition = node.position + parentOffset;
      final nodeRect = calculateNodeRect(node: node, position: shiftedPosition);

      // Проверяем пересечение с тайлом
      if (nodeRect.overlaps(bounds)) {
        nodesInTile.add(node);
      }

      // Рекурсивно проверяем детей
      if (node.children != null && node.children!.isNotEmpty) {
        for (final child in node.children!) {
          collectNodes(child, shiftedPosition);
        }
      }
    }

    for (final node in allNodes) {
      collectNodes(node, delta);
    }

    return nodesInTile;
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
