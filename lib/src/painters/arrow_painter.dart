import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:math' as math;

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
      return; // Ни один из узлов не видим, не рисуем стрелку
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
    // Находим точки соединения стрелки
    final connectionPoints = _calculateConnectionPoints(sourceRect, targetRect, sourceNode, targetNode, arrowManager);
    
    if (connectionPoints.start == null || connectionPoints.end == null) {
      return; // Не удалось найти подходящие точки соединения
    }

    final startPoint = connectionPoints.start!;
    final endPoint = connectionPoints.end!;

    // Создаем путь с отводами от узлов (перпендикулярные отрезки длиной 20)
    Path? path = _createOrthogonalPathWithPerpendiculars(startPoint, endPoint, sourceRect, targetRect);

    // Проверяем, не пересекает ли путь другие узлы
    bool hasIntersection = _orthogonalPathIntersectsOtherNodes(path, [sourceNode.id, targetNode.id]);
    
    Path? finalPath;
    if (hasIntersection) {
      // Пытаемся найти обходной путь
      finalPath = _createBypassPath(startPoint, endPoint, [sourceNode.id, targetNode.id]);
      
      // Если обходной путь также пересекает узлы, рисуем красную стрелку через узел
      if (finalPath != null && _orthogonalPathIntersectsOtherNodes(finalPath, [sourceNode.id, targetNode.id])) {
        // Рисуем красную стрелку через узел
        finalPath = _createOrthogonalPathWithPerpendiculars(startPoint, endPoint, sourceRect, targetRect);
        final paint = Paint()
          ..color = Colors.red
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        
        canvas.drawPath(finalPath, paint);
        return;
      }
    } else {
      finalPath = path;
    }

    // Если обходной путь не удалось найти, рисуем красную стрелку через узел
    if (finalPath == null) {
      finalPath = _createOrthogonalPathWithPerpendiculars(startPoint, endPoint, sourceRect, targetRect);
      final paint = Paint()
        ..color = Colors.red
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      canvas.drawPath(finalPath, paint);
      return;
    }

    // Рисуем обычную линию стрелки
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;


    canvas.drawPath(finalPath, paint);
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

  /// Проверяет, пересекает ли ортогональный путь другие узлы
  bool _orthogonalPathIntersectsOtherNodes(Path path, List<String> excludeIds) {
    // Преобразуем путь в список сегментов (пар точек)
    final segments = _getPathSegments(path);
    
    // Проверяем каждый сегмент на пересечение с другими узлами
    for (final segment in segments) {
      if (_segmentIntersectsOtherNodes(segment['start']!, segment['end']!, excludeIds)) {
        return true;
      }
    }
    
    return false;
  }

  /// Извлекает сегменты из пути
  List<Map<String, Offset?>> _getPathSegments(Path path) {
    final segments = <Map<String, Offset?>>[];
    
    // Используем более точный способ извлечения точек из Path
    final pathMetrics = path.computeMetrics();
    
    for (final metric in pathMetrics) {
      // Получаем все точки пути с высокой плотностью для точного определения пересечений
      final pathPoints = _getPathPoints(metric);
      
      // Создаем сегменты из соседних точек
      for (int i = 0; i < pathPoints.length - 1; i++) {
        final start = pathPoints[i];
        final end = pathPoints[i + 1];
        
        segments.add({
          'start': start,
          'end': end,
        });
      }
    }
    
    return segments;
  }
  
  /// Вспомогательный метод для получения точек из PathMetric
  List<Offset> _getPathPoints(PathMetric metric) {
    final points = <Offset>[];
    final length = metric.length;
    const step = 10.0; // Шаг между точками
    
    for (double distance = 0; distance <= length; distance += step) {
      try {
        final position = metric.getTangentForOffset(distance)?.position;
        if (position != null) {
          points.add(position);
        }
      } catch (e) {
        // Пропускаем ошибки при получении точки
      }
    }
    
    return points;
  }

  /// Проверяет, пересекает ли сегмент другие узлы
  bool _segmentIntersectsOtherNodes(Offset start, Offset end, List<String> excludeIds) {
    // Простая проверка: проверяем пересечение с границами других узлов
    
    bool checkIntersections(List<TableNode> nodeList) {
      for (final node in nodeList) {
        if (excludeIds.contains(node.id)) continue; // Пропускаем исключенные узлы

        // Получаем границы узла
        final nodeRect = nodeBoundsCache[node] ??
            Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);

        // Проверяем пересечение сегмента от start до end с прямоугольником узла
        if (_lineIntersectsRect(start, end, nodeRect)) {
          return true;
        }

        // Проверяем пересечения с детьми узла
        if (node.children != null) {
          if (checkIntersections(node.children!)) {
            return true;
          }
        }
      }
      return false;
    }

    return checkIntersections(nodes);
  }

  /// Создание обходного пути при наличии пересечений
  Path? _createBypassPath(Offset start, Offset end, List<String> excludeIds) {
    // Ищем возможные обходные пути, обходя узлы по кратчайшему пути
    // Проверяем обход сверху, снизу, слева и справа от препятствий
    
    // Сначала найдем все узлы, которые пересекаются с прямым путем
    final intersectingNodes = _findIntersectingNodes(start, end, excludeIds);
    
    if (intersectingNodes.isEmpty) {
      // Если нет пересекающихся узлов, используем стандартный путь с перпендикулярами
      return _createOrthogonalPathWithPerpendiculars(start, end, 
          Rect.fromCenter(center: start, width: 1, height: 1), 
          Rect.fromCenter(center: end, width: 1, height: 1));
    }
    
    // Попробуем несколько вариантов обхода:
    // 1. Обход через среднюю точку с отклонением вверх/вниз
    // 2. Обход через среднюю точку с отклонением влево/вправо
    // 3. Обход по внешней стороне препятствия
    
    // Путь с перпендикулярами
    Offset startDir = _getExitDirection(start, Rect.fromCenter(center: start, width: 1, height: 1));
    Offset endDir = _getEntryDirection(end, Rect.fromCenter(center: end, width: 1, height: 1));
    
    final perpStart = Offset(start.dx + startDir.dx * 20, start.dy + startDir.dy * 20);
    final perpEnd = Offset(end.dx - endDir.dx * 20, end.dy - endDir.dy * 20);
    
    final pathsToTry = <Path>[];
    
    // Вариант 1: горизонтальный путь с вертикальным отклонением
    Path horizontalPath = Path();
    horizontalPath.moveTo(start.dx, start.dy);
    
    // Найдем среднюю X координату
    final midX = (perpStart.dx + perpEnd.dx) / 2;
    
    horizontalPath.lineTo(perpStart.dx, perpStart.dy);
    horizontalPath.lineTo(midX, perpStart.dy);
    horizontalPath.lineTo(midX, perpEnd.dy);
    horizontalPath.lineTo(perpEnd.dx, perpEnd.dy);
    horizontalPath.lineTo(end.dx, end.dy);
    
    pathsToTry.add(horizontalPath);
    
    // Вариант 2: вертикальный путь с горизонтальным отклонением
    Path verticalPath = Path();
    verticalPath.moveTo(start.dx, start.dy);
    
    // Найдем среднюю Y координату
    final midY = (perpStart.dy + perpEnd.dy) / 2;
    
    verticalPath.lineTo(perpStart.dx, perpStart.dy);
    verticalPath.lineTo(perpStart.dx, midY);
    verticalPath.lineTo(perpEnd.dx, midY);
    verticalPath.lineTo(perpEnd.dx, perpEnd.dy);
    verticalPath.lineTo(end.dx, end.dy);
    
    pathsToTry.add(verticalPath);
    
    // Проверим стандартные пути на наличие пересечений
    for (final path in pathsToTry) {
      if (!_orthogonalPathIntersectsOtherNodes(path, excludeIds)) {
        return path; // Нашли путь без пересечений
      }
    }
    
    // Если стандартные пути не работают, пробуем пути с отклонениями
    final bypassPaths = <Path>[];
    
    // Найдем границы пересекающихся узлов для определения отклонений
    double topBoundary = double.infinity;
    double bottomBoundary = double.negativeInfinity;
    double leftBoundary = double.infinity;
    double rightBoundary = double.negativeInfinity;
    
    for (final node in intersectingNodes) {
      final nodeRect = nodeBoundsCache[node] ?? 
          Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);
      
      topBoundary = math.min(topBoundary, nodeRect.top);
      bottomBoundary = math.max(bottomBoundary, nodeRect.bottom);
      leftBoundary = math.min(leftBoundary, nodeRect.left);
      rightBoundary = math.max(rightBoundary, nodeRect.right);
    }
    
    // Вариант 3: отклонение над препятствиями
    Path abovePath = Path();
    abovePath.moveTo(start.dx, start.dy);
    abovePath.lineTo(perpStart.dx, perpStart.dy);
    
    // Выберем Y координату выше всех препятствий
    final aboveY = topBoundary - 40; // Отступ в 40 пикселей над препятствиями
    
    // Путь: начальная точка -> перпендикуляр -> над препятствиями -> перпендикуляр к цели -> конечная точка
    abovePath.lineTo(perpStart.dx, aboveY);  // Вертикаль вверх от перпендикуляра начала
    abovePath.lineTo(perpEnd.dx, aboveY);    // Горизонталь к перпендикуляру конца
    abovePath.lineTo(perpEnd.dx, perpEnd.dy);  // Вертикаль к перпендикуляру конца
    abovePath.lineTo(end.dx, end.dy);  // Завершение
    
    bypassPaths.add(abovePath);
    
    // Вариант 4: отклонение под препятствиями
    Path belowPath = Path();
    belowPath.moveTo(start.dx, start.dy);
    belowPath.lineTo(perpStart.dx, perpStart.dy);
    
    // Выберем Y координату ниже всех препятствий
    final belowY = bottomBoundary + 40; // Отступ в 40 пикселей под препятствиями
    
    belowPath.lineTo(perpStart.dx, belowY);  // Вертикаль вниз от перпендикуляра начала
    belowPath.lineTo(perpEnd.dx, belowY);    // Горизонталь к перпендикуляру конца
    belowPath.lineTo(perpEnd.dx, perpEnd.dy);  // Вертикаль к перпендикуляру конца
    belowPath.lineTo(end.dx, end.dy);  // Завершение
    
    bypassPaths.add(belowPath);
    
    // Вариант 5: отклонение слева от препятствий
    Path leftPath = Path();
    leftPath.moveTo(start.dx, start.dy);
    leftPath.lineTo(perpStart.dx, perpStart.dy);
    
    // Выберем X координату левее всех препятствий
    final leftX = leftBoundary - 40; // Отступ в 40 пикселей слева от препятствий
    
    leftPath.lineTo(leftX, perpStart.dy);  // Горизонталь влево от перпендикуляра начала
    leftPath.lineTo(leftX, perpEnd.dy);    // Горизонталь к перпендикуляру конца
    leftPath.lineTo(perpEnd.dx, perpEnd.dy);  // Вертикаль к перпендикуляру конца
    leftPath.lineTo(end.dx, end.dy);  // Завершение
    
    bypassPaths.add(leftPath);
    
    // Вариант 6: отклонение справа от препятствий
    Path rightPath = Path();
    rightPath.moveTo(start.dx, start.dy);
    rightPath.lineTo(perpStart.dx, perpStart.dy);
    
    // Выберем X координату правее всех препятствий
    final rightX = rightBoundary + 40; // Отступ в 40 пикселей справа от препятствий
    
    rightPath.lineTo(rightX, perpStart.dy);  // Горизонталь вправо от перпендикуляра начала
    rightPath.lineTo(rightX, perpEnd.dy);    // Горизонталь к перпендикуляру конца
    rightPath.lineTo(perpEnd.dx, perpEnd.dy);  // Вертикаль к перпендикуляру конца
    rightPath.lineTo(end.dx, end.dy);  // Завершение
    
    bypassPaths.add(rightPath);
    
    // Проверим обходные пути на наличие пересечений
    for (final path in bypassPaths) {
      if (!_orthogonalPathIntersectsOtherNodes(path, excludeIds)) {
        return path; // Нашли обходной путь без пересечений
      }
    }
    
    // Если ни один из путей не подходит, возвращаем null
    return null;
  }

  /// Находит узлы, которые пересекаются с прямым путем между двумя точками
  List<TableNode> _findIntersectingNodes(Offset start, Offset end, List<String> excludeIds) {
    final intersectingNodes = <TableNode>[];

    void checkNodeIntersections(List<TableNode> nodeList) {
      for (final node in nodeList) {
        if (excludeIds.contains(node.id)) continue; // Пропускаем исключенные узлы

        // Получаем границы узла
        final nodeRect = nodeBoundsCache[node] ??
            Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);

        // Проверяем пересечение прямой линии от start до end с прямоугольником узла
        if (_lineIntersectsRect(start, end, nodeRect)) {
          intersectingNodes.add(node);
        }

        // Проверяем пересечения с детьми узла
        if (node.children != null) {
          checkNodeIntersections(node.children!);
        }
      }
    }

    checkNodeIntersections(nodes);

    return intersectingNodes;
  }

  /// Создание ортогонального пути с перпендикулярными отводами от узлов и максимум одним поворотом
  Path _createOrthogonalPathWithPerpendiculars(Offset start, Offset end, Rect sourceRect, Rect targetRect) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Определяем направление выхода из начальной точки (от стороны узла)
    // Это зависит от того, с какой стороны выходит соединение
    Offset directionVector = _getExitDirection(start, sourceRect);
    
    // Создаем первый перпендикулярный отрезок длиной 20 от начальной точки (вместо 20)
    final perpStart = Offset(
      start.dx + directionVector.dx * 20,
      start.dy + directionVector.dy * 20
    );
    
    // Определяем направление входа в конечную точку (к стороне узла)
    Offset targetDirectionVector = _getEntryDirection(end, targetRect);
    
    // Создаем последний перпендикулярный отрезок длиной 20 до конечной точки (вместо 20)
    final perpEnd = Offset(
      end.dx - targetDirectionVector.dx * 20,
      end.dy - targetDirectionVector.dy * 20
    );
    
    // Рисуем путь: старт -> перпендиклярный отрезок -> основная часть -> перпендикуляр к цели -> конец
    path.lineTo(perpStart.dx, perpStart.dy);
    
    // Создаем ортогональный путь с максимум одним поворотом
    // Выбираем направление поворота так, чтобы минимизировать количество изгибов
    
    // Если точки уже на одной линии (по X или Y), соединяем напрямую
    if (perpStart.dx == perpEnd.dx || perpStart.dy == perpEnd.dy) {
      // Если перпендикулярные точки уже на одной линии, соединяем напрямую
      path.lineTo(perpEnd.dx, perpEnd.dy);
    } else {
      // Для минимизации изгибов, создаем только один поворот
      // Определяем, сначала двигаться по горизонтали или по вертикали
      
      // Вычисляем разницу между координатами
      double deltaX = perpEnd.dx - perpStart.dx;
      double deltaY = perpEnd.dy - perpStart.dy;
      
      // Выбираем направление, где расстояние больше, для первого отрезка
      if (deltaX.abs() > deltaY.abs()) {
        // Сначала движемся по горизонтали (по оси X), потом по вертикали
        path.lineTo(perpEnd.dx, perpStart.dy); // Горизонтальный отрезок
        path.lineTo(perpEnd.dx, perpEnd.dy);   // Вертикальный отрезок
      } else {
        // Сначала движемся по вертикали (по оси Y), потом по горизонтали
        path.lineTo(perpStart.dx, perpEnd.dy); // Вертикальный отрезок
        path.lineTo(perpEnd.dx, perpEnd.dy);   // Горизонтальный отрезок
      }
    }
    
    // Завершаем путь до конечной точки
    path.lineTo(end.dx, end.dy);

    return path;
  }
  
  /// Определяет направление выхода из стороны узла
  Offset _getExitDirection(Offset point, Rect rect) {
    // Определяем, с какой стороны узла находится точка (с учетом, что точки теперь снаружи)
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
    
    // Возвращаем направление, противоположное стороне (т.к. точка снаружи)
    switch(closestSide) {
      case 'left':
        return const Offset(-1, 0); // выход влево от левой стороны
      case 'right':
        return const Offset(1, 0);  // выход вправо от правой стороны
      case 'top':
        return const Offset(0, -1); // выход вверх от верхней стороны
      case 'bottom':
        return const Offset(0, 1);  // выход вниз от нижней стороны
      default:
        return const Offset(1, 0);  // fallback
    }
  }
  
  /// Определяет направление входа в сторону узла
  Offset _getEntryDirection(Offset point, Rect rect) {
    // Определяем, с какой стороны узла находится точка (с учетом, что точки теперь снаружи)
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
    
    // Возвращаем направление, которое указывает на узел (т.к. точка снаружи, а стрелка идет внутрь)
    switch(closestSide) {
      case 'left':
        return const Offset(1, 0);  // вход справа на левую сторону
      case 'right':
        return const Offset(-1, 0); // вход слева на правую сторону
      case 'top':
        return const Offset(0, 1);  // вход снизу на верхнюю сторону
      case 'bottom':
        return const Offset(0, -1); // вход сверху на нижнюю сторону
      default:
        return const Offset(-1, 0); // fallback
    }
  }
  
}