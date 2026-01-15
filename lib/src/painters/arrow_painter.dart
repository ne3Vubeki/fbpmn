import 'package:flutter/material.dart';

import '../models/table.node.dart';
import '../models/arrow.dart';
import '../services/arrow_manager.dart';

/// Универсальный класс для отрисовки Arrow
class ArrowPainter {
  final Arrow arrow;
  final List<TableNode> nodes;
  final Map<TableNode, Rect> nodeBoundsCache;
  final Map<String, TableNode> _nodeMap;

  ArrowPainter({
    required this.arrow,
    required this.nodes,
    required this.nodeBoundsCache,
  }) : _nodeMap = _buildNodeMap(nodes);

  /// Build a map of all nodes including nested ones
  static Map<String, TableNode> _buildNodeMap(List<TableNode> nodes) {
    Map<String, TableNode> nodeMap = {};
    
    void addNodeRecursively(TableNode node) {
      nodeMap[node.id] = node;
      
      // Add all children recursively
      if (node.children != null) {
        for (final child in node.children!) {
          addNodeRecursively(child);
        }
      }
    }
    
    for (final node in nodes) {
      addNodeRecursively(node);
    }
    
    return nodeMap;
  }

  /// Get the effective node for arrow drawing considering swimlane collapsed state
  TableNode? _getEffectiveNode(String nodeId) {
    final node = _nodeMap[nodeId];
    if (node == null) return null;

    // If the node is a child of a collapsed swimlane, return the parent swimlane instead
    if (node.parent != null) {
      final parent = _nodeMap[node.parent!];
      if (parent != null && 
          parent.qType == 'swimlane' && 
          (parent.isCollapsed ?? false)) {
        return parent; // Return the collapsed swimlane instead of the child
      }
    }

    return node;
  }

  /// Отрисовка стрелки с учетом базового отступа
  void paintWithOffset({
    required Canvas canvas,
    required Offset baseOffset,
    required Rect visibleBounds,
    required List<Arrow> allArrows,
    bool forTile = false,
  }) {
    // Находим эффективные узлы-источник и цель (учитываем свернутые swimlane)
    final effectiveSourceNode = _getEffectiveNode(arrow.source);
    final effectiveTargetNode = _getEffectiveNode(arrow.target);

    if (effectiveSourceNode == null || effectiveTargetNode == null) {
      return; // Не можем нарисовать стрелку без обоих узлов
    }

    // Проверяем, не являются ли узлы скрытыми из-за свернутого родителя
    if (_isNodeHiddenByCollapsedParent(effectiveSourceNode) || _isNodeHiddenByCollapsedParent(effectiveTargetNode)) {
      return; // Не рисуем стрелку, если один из узлов скрыт из-за свернутого родителя
    }

    // Получаем абсолютные позиции узлов
    final sourceAbsolutePos = effectiveSourceNode.aPosition ?? (effectiveSourceNode.position + baseOffset);
    final targetAbsolutePos = effectiveTargetNode.aPosition ?? (effectiveTargetNode.position + baseOffset);

    // Создаем Rect для узлов в мировых координатах
    final sourceRect = Rect.fromPoints(
      sourceAbsolutePos,
      Offset(
        sourceAbsolutePos.dx + effectiveSourceNode.size.width,
        sourceAbsolutePos.dy + effectiveSourceNode.size.height,
      ),
    );

    final targetRect = Rect.fromPoints(
      targetAbsolutePos,
      Offset(
        targetAbsolutePos.dx + effectiveTargetNode.size.width,
        targetAbsolutePos.dy + effectiveTargetNode.size.height,
      ),
    );

    // Проверяем видимость стрелки (если хотя бы один узел видим, то рисуем стрелку)
    final isSourceVisible = sourceRect.overlaps(visibleBounds.inflate(100.0));
    final isTargetVisible = targetRect.overlaps(visibleBounds.inflate(100.0));

    if (!isSourceVisible && !isTargetVisible) {
      // Для тайлового рендеринга дополнительно проверяем, пересекает ли путь стрелки тайл
      if (forTile) {
        // Проверяем, пересекает ли путь между узлами тайл
        final sourceCenter = sourceRect.center;
        final targetCenter = targetRect.center;
        if (!_lineIntersectsRect(sourceCenter, targetCenter, visibleBounds)) {
          return; // Ни один из узлов не видим и путь не пересекает тайл
        }
      } else {
        return; // Ни один из узлов не видим, не рисуем стрелку
      }
    }

    // Создаем ArrowManager для расчетов
    final arrowManager = ArrowManager(
      arrows: allArrows,
      nodes: nodes,
      nodeBoundsCache: nodeBoundsCache,
    );

    // Рисуем стрелку
    _drawArrow(
      canvas: canvas,
      sourceRect: sourceRect,
      targetRect: targetRect,
      sourceNode: effectiveSourceNode,
      targetNode: effectiveTargetNode,
      forTile: forTile,
      arrowManager: arrowManager,
    );
  }

  /// Проверяет, является ли узел скрытым из-за свернутого родителя
  bool _isNodeHiddenByCollapsedParent(TableNode node) {
    String? currentParentId = node.parent;
    
    // Проверяем всю цепочку родителей
    while (currentParentId != null) {
      TableNode? parentNode = _nodeMap[currentParentId];
      if (parentNode != null && parentNode.isCollapsed == true) {
        return true;
      }
      // Переходим к следующему родителю
      currentParentId = parentNode?.parent;
    }
    
    return false;
  }

  /// Рисование стрелки
 void _drawArrow({
    required Canvas canvas,
    required Rect sourceRect,
    required Rect targetRect,
    required TableNode sourceNode,
    required TableNode targetNode,
    required bool forTile,
    required ArrowManager arrowManager,
  }) {
    final connectionPoints = arrowManager.calculateConnectionPoints(
      sourceRect,
      targetRect,
      sourceNode,
      targetNode,
      arrow,
    );
    
    if (connectionPoints.start == null || connectionPoints.end == null) {
      return;
    }

    final startPoint = connectionPoints.start!;
    final endPoint = connectionPoints.end!;

    // Создаем простой путь без проверок пересечений
    final path = _createSimplePath(startPoint, endPoint, sourceRect, targetRect);

    // Всегда черный цвет
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, paint);
  }

  // Упрощенный путь
  Path _createSimplePath(
    Offset start,
    Offset end,
    Rect sourceRect,
    Rect targetRect,
  ) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Простой путь с одним поворотом
    if (dx.abs() > dy.abs()) {
      path.lineTo(end.dx, start.dy);
      path.lineTo(end.dx, end.dy);
    } else {
      path.lineTo(start.dx, end.dy);
      path.lineTo(end.dx, end.dy);
    }

    return path;
  }
  
  /// Проверяет, пересекает ли линия заданный прямоугольник
  bool _lineIntersectsRect(Offset start, Offset end, Rect rect) {
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

  /// Проверяет, пересекаются ли две линии
  bool _lineIntersectsLine(Offset p1, Offset p2, Offset p3, Offset p4) {
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

  /// Проверяет, находится ли точка внутри прямоугольника
  bool _isPointInRect(Offset point, Rect rect) {
    return point.dx >= rect.left && point.dx <= rect.right &&
           point.dy >= rect.top && point.dy <= rect.bottom;
  }
  
}