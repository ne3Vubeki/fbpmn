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
    Offset baseOffset = Offset.zero,
  }) {
    final arrowsInTile = <Arrow>[];
    final coordinator = ArrowTileCoordinator(
      arrows: allArrows,
      nodes: allNodes,
      nodeBoundsCache: nodeBoundsCache,
    );

    for (final arrow in allArrows) {
      // Проверяем, связаны ли стрелки с узлами в скрытых swimlane
      final effectiveSourceNode = _getEffectiveNodeById(arrow.source, allNodes);
      final effectiveTargetNode = _getEffectiveNodeById(arrow.target, allNodes);

      // Пропускаем стрелки, связанные с узлами в скрытых swimlane
      if ((effectiveSourceNode != null &&
              _isNodeHiddenInCollapsedSwimlane(effectiveSourceNode, allNodes)) ||
          (effectiveTargetNode != null &&
              _isNodeHiddenInCollapsedSwimlane(effectiveTargetNode, allNodes))) {
        continue;
      }

      // Используем координатор для проверки пересечения
      if (coordinator.doesArrowIntersectTile(arrow, tileBounds, baseOffset)) {
        arrowsInTile.add(arrow);
      }
    }

    return arrowsInTile;
  }

  // Получить эффективный узел по ID
  static TableNode? _getEffectiveNodeById(String id, List<TableNode> allNodes) {
    TableNode? findNodeRecursive(List<TableNode> nodeList) {
      for (final node in nodeList) {
        if (node.id == id) {
          return node;
        }
        if (node.children != null) {
          final found = findNodeRecursive(node.children!);
          if (found != null) return found;
        }
      }
      return null;
    }

    return findNodeRecursive(allNodes);
  }

  // Проверка, является ли узел скрытым в свернутом swimlane
  static bool _isNodeHiddenInCollapsedSwimlane(
    TableNode? node,
    List<TableNode> allNodes,
  ) {
    if (node == null || node.parent == null) {
      return false;
    }

    // Найти родительский узел
    TableNode? findParent(List<TableNode> nodes) {
      for (final n in nodes) {
        if (n.id == node.parent) {
          return n;
        }

        if (n.children != null) {
          final result = findParent(n.children!);
          if (result != null) {
            return result;
          }
        }
      }
      return null;
    }

    final parent = findParent(allNodes);
    if (parent != null &&
        parent.qType == 'swimlane' &&
        (parent.isCollapsed ?? false)) {
      return true;
    }

    return false;
  }
}