import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/table.node.dart';
import '../models/arrow.dart';
import 'arrow_painter.dart';

class ArrowTilePainter {
  final List<Arrow> arrows;
  final List<TableNode> nodes;
  final Map<TableNode, Rect> nodeBoundsCache;

  ArrowTilePainter({
    required this.arrows,
    required this.nodes,
    required this.nodeBoundsCache,
  });

  void drawArrowsInTile({
    required Canvas canvas,
    required Rect tileBounds,
    required Offset baseOffset,
  }) {
    // Рисуем только те стрелки, которые пересекают границы тайла
    for (final arrow in arrows) {
      final arrowPainter = ArrowPainter(
        arrow: arrow,
        nodes: nodes,
        nodeBoundsCache: nodeBoundsCache,
      );
      
      arrowPainter.paintWithOffset(
        canvas: canvas,
        baseOffset: baseOffset,
        visibleBounds: tileBounds,
        allArrows: arrows,
        forTile: true,
      );
    }
  }

  // Метод для определения стрелок, которые пересекают определенный тайл
  static List<Arrow> getArrowsForTile({
    required Rect tileBounds,
    required List<Arrow> allArrows,
    required List<TableNode> allNodes,
    required Map<TableNode, Rect> nodeBoundsCache,
  }) {
    final arrowsInTile = <Arrow>[];
    
    for (final arrow in allArrows) {
      if (_arrowIntersectsTile(
        arrow: arrow,
        tileBounds: tileBounds,
        allNodes: allNodes,
        nodeBoundsCache: nodeBoundsCache,
      )) {
        arrowsInTile.add(arrow);
      }
    }
    
    return arrowsInTile;
  }

  // Проверяет, пересекает ли стрелка указанный тайл
  static bool _arrowIntersectsTile({
    required Arrow arrow,
    required Rect tileBounds,
    required List<TableNode> allNodes,
    required Map<TableNode, Rect> nodeBoundsCache,
  }) {
    // Находим узлы-источник и цель
    TableNode? sourceNode;
    TableNode? targetNode;
    
    void findNodes(List<TableNode> nodes) {
      for (final node in nodes) {
        if (node.id == arrow.source) {
          sourceNode = _getEffectiveNode(node, nodes);
        } else if (node.id == arrow.target) {
          targetNode = _getEffectiveNode(node, nodes);
        }
        
        if (sourceNode != null && targetNode != null) {
          break;
        }
        
        if (node.children != null) {
          findNodes(node.children!);
        }
      }
    }
    
    findNodes(allNodes);
    
    if (sourceNode == null || targetNode == null) {
      return false; // Не можем определить, пересекает ли стрелка тайл без обоих узлов
    }
    
    // Получаем абсолютные позиции узлов
    final sourceAbsolutePos = sourceNode!.aPosition ?? sourceNode!.position;
    final targetAbsolutePos = targetNode!.aPosition ?? targetNode!.position;
    
    // Создаем Rect для узлов
    final sourceRect = nodeBoundsCache[sourceNode!] ?? 
        Rect.fromLTWH(
          sourceAbsolutePos.dx, 
          sourceAbsolutePos.dy, 
          sourceNode!.size.width, 
          sourceNode!.size.height,
        );
    final targetRect = nodeBoundsCache[targetNode!] ?? 
        Rect.fromLTWH(
          targetAbsolutePos.dx, 
          targetAbsolutePos.dy, 
          targetNode!.size.width, 
          targetNode!.size.height,
        );
    
    // Для более точной проверки, определяем ортогональный путь стрелки
    // и проверяем пересечение каждого сегмента пути с тайлом
    
    // Определяем приблизительную область стрелки (между узлами)
    final arrowBounds = sourceRect.expandToInclude(targetRect).inflate(100); // Увеличиваем область для охвата пути
    
    // Сначала проверяем, пересекает ли общая область тайл
    if (!arrowBounds.overlaps(tileBounds)) {
      return false;
    }
    
    // Более точная проверка: определяем, пересекает ли путь стрелки тайл
    // Для этого используем гипотетический путь от центра одного узла к центру другого
    final sourceCenter = sourceRect.center;
    final targetCenter = targetRect.center;
    
    // Проверяем, пересекает ли линия между узлами тайл
    return _lineIntersectsRect(sourceCenter, targetCenter, tileBounds);
  }

  // Проверяет, пересекает ли линия заданный прямоугольник
  static bool _lineIntersectsRect(Offset start, Offset end, Rect rect) {
    // Проверяем пересечение отрезка с каждой стороной прямоугольника
    final left = rect.left;
    final right = rect.right;
    final top = rect.top;
    final bottom = rect.bottom;
    
    // Проверяем пересечение с левой стороной
    if (_lineIntersectsLine(start, end, Offset(left, top), Offset(left, bottom))) return true;
    // Проверяем пересечение с правой стороной
    if (_lineIntersectsLine(start, end, Offset(right, top), Offset(right, bottom))) return true;
    // Проверяем пересечение с верхней стороной
    if (_lineIntersectsLine(start, end, Offset(left, top), Offset(right, top))) return true;
    // Проверяем пересечение с нижней стороной
    if (_lineIntersectsLine(start, end, Offset(left, bottom), Offset(right, bottom))) return true;
    
    // Также проверяем, находится ли хотя бы одна точка внутри прямоугольника
    if (_isPointInRect(start, rect) || _isPointInRect(end, rect)) return true;
    
    return false;
  }

  // Проверяет, пересекаются ли две линии
  static bool _lineIntersectsLine(Offset p1, Offset p2, Offset p3, Offset p4) {
    // Формула для определения пересечения двух отрезков
    final denom = (p4.dy - p3.dy) * (p2.dx - p1.dx) - (p4.dx - p3.dx) * (p2.dy - p1.dy);
    
    if (denom == 0) {
      // Линии параллельны
      return false;
    }
    
    final ua = ((p4.dx - p3.dx) * (p1.dy - p3.dy) - (p4.dy - p3.dy) * (p1.dx - p3.dx)) / denom;
    final ub = ((p2.dx - p1.dx) * (p1.dy - p3.dy) - (p2.dy - p1.dy) * (p1.dx - p3.dx)) / denom;
    
    return ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1;
  }

  // Проверяет, находится ли точка внутри прямоугольника
  static bool _isPointInRect(Offset point, Rect rect) {
    return point.dx >= rect.left && point.dx <= rect.right &&
           point.dy >= rect.top && point.dy <= rect.bottom;
  }

  // Получить эффективный узел для стрелки, учитывая свернутые swimlane
  static TableNode? _getEffectiveNode(TableNode node, List<TableNode> allNodes) {
    // Если узел является дочерним для свернутого swimlane, вернуть родительский swimlane
    if (node.parent != null) {
      // Найти родителя узла
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
        return parent; // Вернуть свернутый swimlane вместо дочернего узла
      }
    }

    return node;
  }
}