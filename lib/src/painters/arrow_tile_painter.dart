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

    // Создаем временный координатор для проверки пересечений
    final coordinator = ArrowTileCoordinator(
      arrows: allArrows,
      nodes: allNodes,
      nodeBoundsCache: nodeBoundsCache,
    );

    for (final arrow in allArrows) {
      // Используем координатор для проверки пересечения
      if (coordinator.doesArrowIntersectTile(arrow, tileBounds, baseOffset)) {
        // Дополнительно проверим, связаны ли узлы стрелки с невидимыми swimlane
        bool isNodeHiddenInCollapsedSwimlane(TableNode node) {
          if (node.parent == null) {
            return false; // У корневого узла нет родителя
          }

          // Найти родительский узел
          TableNode? findParent(List<TableNode> nodes) {
            TableNode? searchRecursive(List<TableNode> nodeList) {
              for (final n in nodeList) {
                if (n.id == node.parent) {
                  return n;
                }

                if (n.children != null) {
                  final result = searchRecursive(n.children!);
                  if (result != null) {
                    return result;
                  }
                }
              }
              return null;
            }
            return searchRecursive(allNodes);
          }

          final parent = findParent(allNodes);
          if (parent != null && 
              parent.qType == 'swimlane' && 
              (parent.isCollapsed ?? false)) {
            return true; // Узел находится внутри свернутого swimlane
          }

          return false;
        }

        // Найдем узлы стрелки
        TableNode? findNodeById(String id) {
          TableNode? findRecursive(List<TableNode> nodeList) {
            for (final node in nodeList) {
              if (node.id == id) {
                return node;
              }
              if (node.children != null) {
                final found = findRecursive(node.children!);
                if (found != null) return found;
              }
            }
            return null;
          }
          return findRecursive(allNodes);
        }

        final sourceNode = findNodeById(arrow.source);
        final targetNode = findNodeById(arrow.target);

        // Проверяем, являются ли узлы скрытыми в свернутых swimlane
        if (sourceNode != null && isNodeHiddenInCollapsedSwimlane(sourceNode) ||
            targetNode != null && isNodeHiddenInCollapsedSwimlane(targetNode)) {
          continue; // Пропускаем стрелку, если один из узлов скрыт
        }

        arrowsInTile.add(arrow);
      }
    }

    return arrowsInTile;
  }
}