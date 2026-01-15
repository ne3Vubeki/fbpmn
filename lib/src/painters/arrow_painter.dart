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
    final connectionPoints = arrowManager.calculateConnectionPointsForSideCalculation(
      sourceRect,
      targetRect,
      sourceNode,
      targetNode,
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

  // Создание пути связи по новым правилам
  Path _createSimplePath(
    Offset start,
    Offset end,
    Rect sourceRect,
    Rect targetRect,
  ) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Определяем стороны, к которым принадлежат точки начала и конца
    String startSide = _getSideFromPoint(start, sourceRect);
    String endSide = _getSideFromPoint(end, targetRect);

    // Определяем тип соединения в зависимости от сторон
    bool isParallelSides = _areParallelSides(startSide, endSide);
    
    if (isParallelSides) {
      // Параллельные стороны (правая-левая или левая-правая): может быть 0 или 2 изгиба
      if (_shouldDrawDirectLine(start, end, startSide, endSide)) {
        // Прямая линия
        path.lineTo(end.dx, end.dy);
      } else {
        // Два изгиба
        _addTwoBendPath(path, start, end, startSide, endSide);
      }
    } else {
      // Перпендикулярные стороны: только один изгиб
      _addOneBendPath(path, start, end, startSide, endSide);
    }

    return path;
  }

  // Определение стороны, к которой принадлежит точка
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

  // Проверка, являются ли стороны параллельными (правая-левая или левая-правая, верхняя-нижняя или нижняя-верхняя)
  bool _areParallelSides(String side1, String side2) {
    return (side1 == 'left' && side2 == 'right') ||
           (side1 == 'right' && side2 == 'left') ||
           (side1 == 'top' && side2 == 'bottom') ||
           (side1 == 'bottom' && side2 == 'top');
  }

  // Проверка необходимости прямой линии
  bool _shouldDrawDirectLine(Offset start, Offset end, String startSide, String endSide) {
    // Рисуем прямую линию, если стороны противоположные и точки находятся примерно на одной оси
    if ((startSide == 'left' && endSide == 'right') || (startSide == 'right' && endSide == 'left')) {
      return (start.dy - end.dy).abs() < 5; // Маленькая разница по Y
    } else if ((startSide == 'top' && endSide == 'bottom') || (startSide == 'bottom' && endSide == 'top')) {
      return (start.dx - end.dx).abs() < 5; // Маленькая разница по X
    }
    return false;
  }

  // Добавление пути с двумя изгибами
  void _addTwoBendPath(Path path, Offset start, Offset end, String startSide, String endSide) {
    // Для параллельных сторон с двумя изгибами первый и третий отрезки должны быть одинаковой длины
    
    // Определяем среднюю точку между началом и концом
    double midX = (start.dx + end.dx) / 2;
    double midY = (start.dy + end.dy) / 2;

    Offset middlePoint1, middlePoint2;

    if ((startSide == 'left' || startSide == 'right') && (endSide == 'left' || endSide == 'right')) {
      // Горизонтальное соединение (левая-левая, левая-правая, правая-левая, правая-правая)
      // Используем среднюю Y координату
      middlePoint1 = Offset(start.dx, midY);
      middlePoint2 = Offset(end.dx, midY);
    } else {
      // Вертикальное соединение (остальные случаи параллельных сторон)
      // Используем среднюю X координату
      middlePoint1 = Offset(midX, start.dy);
      middlePoint2 = Offset(midX, end.dy);
    }

    // Добавляем точки пути
    path.lineTo(middlePoint1.dx, middlePoint1.dy);
    path.lineTo(middlePoint2.dx, middlePoint2.dy);
    path.lineTo(end.dx, end.dy);
  }

  // Добавление пути с одним изгибом
  void _addOneBendPath(Path path, Offset start, Offset end, String startSide, String endSide) {
    Offset bendPoint;

    // При соединении между перпендикулярными сторонами делаем один изгиб
    // Определяем, какая координата должна совпадать у начальной точки и точки изгиба,
    // а какая - у конечной точки и точки изгиба
    if ((startSide == 'top' || startSide == 'bottom') && (endSide == 'left' || endSide == 'right')) {
      // Вертикальная сторона к горизонтальной: изгиб по X координате конца
      bendPoint = Offset(end.dx, start.dy);
    } else if ((startSide == 'left' || startSide == 'right') && (endSide == 'top' || endSide == 'bottom')) {
      // Горизонтальная сторона к вертикальной: изгиб по Y координате конца
      bendPoint = Offset(start.dx, end.dy);
    } else {
      // По умолчанию используем координаты центра
      double midX = (start.dx + end.dx) / 2;
      double midY = (start.dy + end.dy) / 2;
      
      // Выбираем, какая ось будет изгибаться
      if ((startSide == 'top' || startSide == 'bottom')) {
        bendPoint = Offset(midX, start.dy);
      } else {
        bendPoint = Offset(start.dx, midY);
      }
    }

    path.lineTo(bendPoint.dx, bendPoint.dy);
    path.lineTo(end.dx, end.dy);
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