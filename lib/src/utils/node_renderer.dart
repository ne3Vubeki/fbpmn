import 'package:flutter/material.dart';
import '../models/table.node.dart';
import '../painters/node_painter.dart';

class NodeRenderer {
  /// Рисует только корневые узлы, их дети рисуются рекурсивно
  void drawRootNodesToTile({
    required Canvas canvas,
    required List<TableNode?> rootNodes, // Только корневые узлы
    required Rect tileBounds,
    required Offset delta,
    required Map<TableNode, Rect> cache,
  }) {
    // ВАЖНО: Сначала рисуем все НЕ-swimlane узлы и детей swimlane
    // Затем рисуем swimlane узлы (чтобы они были сверху)

    final List<TableNode> nonSwimlaneNodes = [];
    final List<TableNode> swimlaneNodes = [];

    // Разделяем узлы на swimlane и не-swimlane
    for (final node in rootNodes) {
      if (node!.qType == 'swimlane') {
        swimlaneNodes.add(node);
      } else {
        nonSwimlaneNodes.add(node);
      }
    }

    // 1. Сначала рисуем все не-swimlane узлы
    for (final node in nonSwimlaneNodes) {
      _drawNodeToTile(canvas, node, tileBounds, delta, cache);
    }

    // 2. Затем рисуем swimlane узлы (они будут сверху)
    for (final node in swimlaneNodes) {
      _drawNodeToTile(canvas, node, tileBounds, delta, cache);
    }
  }

  /// Рисует отдельный узел на тайле
  void _drawNodeToTile(
    Canvas canvas,
    TableNode node,
    Rect tileBounds,
    Offset delta,
    Map<TableNode, Rect> cache,
  ) {
      // Пропускаем свернутые swimlane, которые не видны в тайле
      if (node.qType == 'swimlane' && (node.isCollapsed ?? false)) {
        final nodeWorldPosition = node.aPosition ?? (delta + node.position);
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

