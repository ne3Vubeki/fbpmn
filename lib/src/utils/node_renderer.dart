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
  }) {

    for (final node in nodes) {
      _drawNodeToTile(canvas, node!, tileBounds, delta);
    }
  }

  /// Рисует отдельный узел на тайле
  void _drawNodeToTile(
    Canvas canvas,
    TableNode node,
    Rect tileBounds,
    Offset delta,
  ) {
      final painter = NodePainter(node: node);

      painter.paintWithOffset(
        canvas: canvas,
        baseOffset: delta,
        visibleBounds: tileBounds,
        forTile: true,
      );
    }

  }

