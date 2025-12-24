import 'package:flutter/material.dart';
import '../models/table.node.dart';
import '../painters/node_painter.dart';

class NodeRenderer {
  void drawNodeToTile({
    required Canvas canvas,
    required TableNode node,
    required Rect tileBounds,
    required Offset delta,
    required Map<TableNode, Rect> cache,
  }) {
    // Используем NodePainter с поддержкой иерархии
    final painter = NodePainter(node: node);
    
    painter.paintWithOffset(
      canvas: canvas,
      baseOffset: delta, // Для корневых узлов передаем delta
      visibleBounds: tileBounds,
      forTile: true,
      nodeBoundsCache: cache,
    );
  }
}