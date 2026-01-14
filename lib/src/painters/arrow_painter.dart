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
    final connectionPoints = _calculateConnectionPoints(
      sourceRect,
      targetRect,
      sourceNode,
      targetNode,
      arrowManager,
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
  
  /// Расчет точек соединения для стрелки
  ({Offset? end, Offset? start}) _calculateConnectionPoints(Rect sourceRect, Rect targetRect, TableNode sourceNode, TableNode targetNode, ArrowManager arrowManager) {
    // Определяем центральные точки узлов
    final sourceCenter = sourceRect.center;
    final targetCenter = targetRect.center;

    // Определяем стороны узлов
    final sourceTop = sourceRect.top;
    final sourceBottom = sourceRect.bottom;
    final sourceLeft = sourceRect.left;
    final sourceRight = sourceRect.right;
    
    final targetTop = targetRect.top;
    final targetBottom = targetRect.bottom;
    final targetLeft = targetRect.left;
    final targetRight = targetRect.right;

    Offset? startConnectionPoint;
    Offset? endConnectionPoint;

    // Вычисляем расстояния между центрами узлов
    final dx = targetCenter.dx - sourceCenter.dx;
    final dy = targetCenter.dy - sourceCenter.dy;

    // Определяем исходную сторону (откуда выходит связь)
    if (sourceCenter.dy < targetTop - 20) {
      // середина высоты узла источника находится слева и выше
      if (sourceRight < targetCenter.dx - 20) {
        startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
      } else 
      // середина высоты узла источника находится справа и выше
      if (sourceLeft > targetCenter.dx + 20) {
        startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
      } else {
        startConnectionPoint = Offset(sourceCenter.dx, sourceBottom + 6);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
      }
    } else 
    if (sourceCenter.dy > targetTop - 20 && sourceCenter.dy < targetBottom + 20) {
      // середина высоты узла источника находится слева (расстояние между узлами более 40 по x) и внутри отступов 20 от верха и низа
      if (sourceRight < targetLeft - 40) {
        startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);
      } else
      // середина высоты узла источника находится справа (расстояние между узлами более 40 по x) и внутри отступов 20 от верха и низа
      if (sourceLeft > targetRight + 40) {
        startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetRight + 6, targetCenter.dy);
      } else {
        startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
      }
    } else 
    if (sourceCenter.dy > targetBottom + 20) {
      // середина высоты узла источника находится слева и ниже
      if (sourceRight < targetCenter.dx - 20) {
        startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6); 
      } else
      // середина высоты узла источника находится справа и ниже
      if (sourceLeft > targetCenter.dx + 20) {
        startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);
      } else {
        startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);
        endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);
      }
    } else {
      // Для других случаев используем алгоритм по аналогии
      // Определяем основное направление связи
      if (dx.abs() >= dy.abs()) {
        // Горизонтальное направление преобладает
        if (dx > 0) {
          // Справа
          startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
          endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);
        } else {
          // Слева
          startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
          endConnectionPoint = Offset(targetRight + 6, targetCenter.dy);  
        }
      } else {
        // Вертикальное направление преобладает
        if (dy > 0) {
          // Вниз
          startConnectionPoint = Offset(sourceCenter.dx, sourceBottom + 6);
          endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
        } else {
          // Вверх
          startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);
          endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6); 
        }
      }
    }

    // Учитываем количество связей для распределения с шагом 10
    final startSide = _getSideFromPoint(startConnectionPoint, sourceRect);
    final endSide = _getSideFromPoint(endConnectionPoint, targetRect);

    // Распределяем точки по стороне с шагом 10
    startConnectionPoint = _distributeConnectionPoint(startConnectionPoint, sourceRect, startSide, arrow.source, arrowManager);
    endConnectionPoint = _distributeConnectionPoint(endConnectionPoint, targetRect, endSide, arrow.target, arrowManager);

    return (start: startConnectionPoint, end: endConnectionPoint);
  }

  /// Определяет сторону узла, к которой принадлежит точка
  String _getSideFromPoint(Offset point, Rect rect) {
    // Сравниваем расстояния до разных сторон и выбираем ближайшую
    double leftDist = (point.dx - rect.left).abs();
    double rightDist = (point.dx - rect.right).abs();
    double topDist = (point.dy - rect.top).abs();
    double bottomDist = (point.dy - rect.bottom).abs();
    
    // Находим минимальное расстояние
    double minDist = leftDist;
    String closestSide = 'left';
    
    if (rightDist < minDist) { minDist = rightDist; closestSide = 'right'; }
    if (topDist < minDist) { minDist = topDist; closestSide = 'top'; }
    if (bottomDist < minDist) { minDist = bottomDist; closestSide = 'bottom'; }
    
    return closestSide;
  }

  /// Распределяет точки соединения по стороне с шагом 10
  Offset _distributeConnectionPoint(Offset originalPoint, Rect rect, String side, String nodeId, ArrowManager arrowManager) {
    // Подсчитываем количество связей, подключенных к данной стороне узла
    int connectionsCount = arrowManager.getConnectionsCountOnSide(nodeId, side);
    
    // Если только одна связь на этой стороне, используем центральную точку
    if (connectionsCount <= 1) {
      return originalPoint;
    }
    
    // Находим индекс текущей связи среди всех связей, подключенных к этой стороне
    int index = arrowManager.getConnectionIndex(arrow, nodeId, side);
    
    // Рассчитываем смещение для равномерного распределения
    double offset = 0.0;
    switch (side) {
      case 'top':
      case 'bottom':
        // Для горизонтальных сторон (top/bottom) смещение по оси X
        double sideLength = rect.width;
        // Центральная точка стороны
        double centerPoint = rect.center.dx;
        
        // Если нечетное количество связей, центральная остается в центре, остальные распределяются по бокам
        if (connectionsCount % 2 == 1) {
          // Нечетное количество связей
          int halfCount = connectionsCount ~/ 2;
          if (index < halfCount) {
            // Левые точки
            offset = -(halfCount - index) * 10.0;
          } else if (index == halfCount) {
            // Центральная точка
            offset = 0.0;
          } else {
            // Правые точки
            offset = (index - halfCount) * 10.0;
          }
        } else {
          // Четное количество связей
          int halfCount = connectionsCount ~/ 2;
          if (index < halfCount) {
            // Левые точки
            offset = -(halfCount - index - 0.5) * 10.0;
          } else {
            // Правые точки
            offset = (index - halfCount + 0.5) * 10.0;
          }
        }
        
        // Убедимся, что точка не выходит за пределы стороны узла
        double clampedOffset = offset.clamp(
          -sideLength / 2 + 6, // Минимальное смещение от края (учитывая отступ 6)
          sideLength / 2 - 6   // Максимальное смещение от края (учитывая отступ 6)
        );
        
        return Offset(centerPoint + clampedOffset, originalPoint.dy);
        
      case 'left':
      case 'right':
        // Для вертикальных сторон (left/right) смещение по оси Y
        double sideLength = rect.height;
        // Центральная точка стороны
        double centerPoint = rect.center.dy;
        
        // Если нечетное количество связей, центральная остается в центре, остальные распределяются по бокам
        if (connectionsCount % 2 == 1) {
          // Нечетное количество связей
          int halfCount = connectionsCount ~/ 2;
          if (index < halfCount) {
            // Верхние точки
            offset = -(halfCount - index) * 10.0;
          } else if (index == halfCount) {
            // Центральная точка
            offset = 0.0;
          } else {
            // Нижние точки
            offset = (index - halfCount) * 10.0;
          }
        } else {
          // Четное количество связей
          int halfCount = connectionsCount ~/ 2;
          if (index < halfCount) {
            // Верхние точки
            offset = -(halfCount - index - 0.5) * 10.0;
          } else {
            // Нижние точки
            offset = (index - halfCount + 0.5) * 10.0;
          }
        }
        
        // Убедимся, что точка не выходит за пределы стороны узла
        double clampedOffset = offset.clamp(
          -sideLength / 2 + 6, // Минимальное смещение от края (учитывая отступ 6)
          sideLength / 2 - 6   // Максимальное смещение от края (учитывая отступ 6)
        );
        
        return Offset(originalPoint.dx, centerPoint + clampedOffset);
        
      default:
        return originalPoint;
    }
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