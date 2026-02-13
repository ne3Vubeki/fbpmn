import 'package:flutter/material.dart';
import '../models/table.node.dart';
import '../painters/node_painter.dart';

class NodeRenderer {
  /// Рисует только корневые узлы, их дети рисуются рекурсивно
  void drawRootNodesToTile({
    required Canvas canvas,
    required List<TableNode?> nodes,
    required Rect tileBounds,
    required Offset delta,
    Set<String>? highlightedNodeIds,
  }) {

    for (final node in nodes) {
      _drawNodeToTile(canvas, node!, tileBounds, delta, highlightedNodeIds);
    }
  }

  /// Рисует отдельный узел на тайле
  void _drawNodeToTile(
    Canvas canvas,
    TableNode node,
    Rect tileBounds,
    Offset delta,
    Set<String>? highlightedNodeIds,
  ) {
      final isHighlighted = highlightedNodeIds?.contains(node.id) ?? false;
      final painter = NodePainter(node: node, isHighlighted: isHighlighted);

      painter.paintWithOffset(
        canvas: canvas,
        baseOffset: delta,
        visibleBounds: tileBounds,
        forTile: true,
        highlightedNodeIds: highlightedNodeIds,
      );
    }

  }

