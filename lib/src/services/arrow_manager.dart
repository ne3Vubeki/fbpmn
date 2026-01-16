import 'dart:ui';

import '../models/table.node.dart';
import '../models/arrow.dart';

/// Сервис для управления и расчета соединений стрелок
class ArrowManager {
  List<Arrow> arrows;
  List<TableNode> nodes;
  final Map<TableNode, Rect> nodeBoundsCache;

  ArrowManager({
    required this.arrows,
    required this.nodes,
    required this.nodeBoundsCache,
  });

  /// Получить все стрелки, подключенные к определенному узлу с определенной стороны
  List<Arrow> getArrowsOnSide(String nodeId, String side) {
    final result = <Arrow>[];

    for (final arrow in arrows) {
      // Проверяем, подключена ли стрелка к этому узлу как источник или цель
      if (arrow.source == nodeId) {
        // Проверяем, какая сторона используется для источника
        if (getSideForConnection(arrow, true) == side) {
          result.add(arrow);
        }
      } else if (arrow.target == nodeId) {
        // Проверяем, какая сторона используется для цели
        if (getSideForConnection(arrow, false) == side) {
          result.add(arrow);
        }
      }
    }

    return result;
  }

  /// Получить индекс конкретной стрелки среди всех стрелок, подключенных к стороне узла
  int getConnectionIndex(Arrow targetArrow, String nodeId, String side) {
    int index = 0;

    for (int i = 0; i < arrows.length; i++) {
      final arrow = arrows[i];

      // Пропускаем, если это сама целевая стрелка
      if (arrow.id == targetArrow.id) {
        break;
      }

      // Проверяем, подключена ли эта стрелка к узлу как источник или цель
      if (arrow.source == nodeId) {
        // Проверяем, какая сторона используется для источника
        if (getSideForConnectionWithoutCounting(arrow, true) == side) {
          index++;
        }
      } else if (arrow.target == nodeId) {
        // Проверяем, какая сторона используется для цели
        if (getSideForConnectionWithoutCounting(arrow, false) == side) {
          index++;
        }
      }
    }

    return index;
  }

  /// Получить количество стрелок, подключенных к определенному узлу с определенной стороны
  int getConnectionsCountOnSide(String nodeId, String side) {
    int count = 0;

    for (final arrow in arrows) {
      // Проверяем, подключена ли стрелка к этому узлу как источник или цель
      if (arrow.source == nodeId) {
        // Проверяем, какая сторона используется для источника
        if (getSideForConnectionWithoutCounting(arrow, true) == side) {
          count++;
        }
      } else if (arrow.target == nodeId) {
        // Проверяем, какая сторона используется для цели
        if (getSideForConnectionWithoutCounting(arrow, false) == side) {
          count++;
        }
      }
    }

    return count;
  }

  /// Определить сторону, к которой стрелка подключена к узлу (для источника или цели)
  String getSideForConnection(Arrow arrow, bool isSource) {
    // Находим эффективные узлы источника и цели (учитываем свернутые swimlane)
    final effectiveSourceNode = _findEffectiveNodeById(arrow.source);
    final effectiveTargetNode = _findEffectiveNodeById(arrow.target);

    if (effectiveSourceNode == null || effectiveTargetNode == null) {
      return 'top'; // запасной вариант
    }

    // Получаем абсолютные позиции узлов
    final sourceAbsolutePos =
        effectiveSourceNode.aPosition ?? effectiveSourceNode.position;
    final targetAbsolutePos =
        effectiveTargetNode.aPosition ?? effectiveTargetNode.position;

    // Создаем прямоугольники для узлов
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

    // Вычисляем точки соединения
    final connectionPoints = calculateConnectionPointsForSideCalculation(
      sourceRect,
      targetRect,
      effectiveSourceNode,
      effectiveTargetNode,
    );

    if (isSource) {
      return _getSideFromPoint(connectionPoints.start!, sourceRect);
    } else {
      return _getSideFromPoint(connectionPoints.end!, targetRect);
    }
  }

  /// Определить сторону, к которой стрелка подключена к узлу (для источника или цели) - без вызова методов подсчета
  String getSideForConnectionWithoutCounting(Arrow arrow, bool isSource) {
    // Находим эффективные узлы источника и цели (учитываем свернутые swimlane)
    final effectiveSourceNode = _findEffectiveNodeById(arrow.source);
    final effectiveTargetNode = _findEffectiveNodeById(arrow.target);

    if (effectiveSourceNode == null || effectiveTargetNode == null) {
      return 'top'; // запасной вариант
    }

    // Получаем абсолютные позиции узлов
    final sourceAbsolutePos =
        effectiveSourceNode.aPosition ?? effectiveSourceNode.position;
    final targetAbsolutePos =
        effectiveTargetNode.aPosition ?? effectiveTargetNode.position;

    // Создаем прямоугольники для узлов
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

    // Вычисляем точки соединения, но без вызова методов подсчета
    final connectionPoints = calculateConnectionPointsForSideCalculation(
      sourceRect,
      targetRect,
      effectiveSourceNode,
      effectiveTargetNode,
    );

    if (isSource) {
      return _getSideFromPoint(connectionPoints.start!, sourceRect);
    } else {
      return _getSideFromPoint(connectionPoints.end!, targetRect);
    }
  }

  /// Найти узел по ID, включая вложенные узлы
  TableNode? _findNodeById(String id) {
    return _findNodeByIdRecursive(nodes, id);
  }

  /// Найти эффективный узел по ID, учитывая свернутые swimlane
  TableNode? _findEffectiveNodeById(String id) {
    final node = _findNodeById(id);
    if (node == null) return null;

    // Если узел является дочерним для свернутого swimlane, вернуть родительский swimlane
    if (node.parent != null) {
      final parent = _findNodeById(node.parent!);
      if (parent != null &&
          parent.qType == 'swimlane' &&
          (parent.isCollapsed ?? false)) {
        return parent; // Вернуть свернутый swimlane вместо дочернего узла
      }
    }

    return node;
  }

  /// Рекурсивный поиск узла по ID
  TableNode? _findNodeByIdRecursive(List<TableNode> nodeList, String id) {
    for (final node in nodeList) {
      if (node.id == id) {
        return node;
      }

      if (node.children != null) {
        final foundChild = _findNodeByIdRecursive(node.children!, id);
        if (foundChild != null) {
          return foundChild;
        }
      }
    }
    return null;
  }

  /// Расчет точек соединения для определения стороны
  ({Offset? end, Offset? start, String? sides}) calculateConnectionPointsForSideCalculation(
    Rect sourceRect,
    Rect targetRect,
    TableNode sourceNode,
    TableNode targetNode,
  ) {
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
    String? sides;

    // Вычисляем расстояния между центрами узлов
    final dx = targetCenter.dx - sourceCenter.dx;
    final dy = targetCenter.dy - sourceCenter.dy;

    // Определяем исходную сторону (откуда выходит связь)
    if (sourceCenter.dy < targetTop - 20) {
      // середина высоты узла источника находится слева и выше
      if (sourceRight < targetCenter.dx - 20) {
        sides = 'right:top';
        startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
      } else
      // середина высоты узла источника находится справа и выше
      if (sourceLeft > targetCenter.dx + 20) {
        sides = 'left:top';
        startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
      } else {
        sides = 'bottom:top';
        startConnectionPoint = Offset(sourceCenter.dx, sourceBottom + 6);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
      }
    } else if (sourceCenter.dy > targetTop - 20 &&
        sourceCenter.dy < targetBottom + 20) {
      // середина высоты узла источника находится слева (расстояние между узлами более 40 по x) и внутри отступов 20 от верха и низа
      if (sourceRight < targetLeft - 40) {
        sides = 'right:left';
        startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);
      } else
      // середина высоты узла источника находится справа (расстояние между узлами более 40 по x) и внутри отступов 20 от верха и низа
      if (sourceLeft > targetRight + 40) {
        sides = 'left:right';
        startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetRight + 6, targetCenter.dy);
      } else {
        sides = 'top:top';
        startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
      }
    } else if (sourceCenter.dy > targetBottom + 20) {
      // середина высоты узла источника находится слева и ниже
      if (sourceRight < targetCenter.dx - 20) {
        sides = 'right:bottom';
        startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);
      } else
      // середина высоты узла источника находится справа и ниже
      if (sourceLeft > targetCenter.dx + 20) {
        sides = 'left:bottom';
        startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);
      } else {
        sides = 'top:bottom';
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
          sides = 'right:left';
          startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
          endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);
        } else {
          // Слева
          sides = 'left:right';
          startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
          endConnectionPoint = Offset(targetRight + 6, targetCenter.dy);
        }
      } else {
        // Вертикальное направление преобладает
        if (dy > 0) {
          // Вниз
          sides = 'bottom:top';
          startConnectionPoint = Offset(sourceCenter.dx, sourceBottom + 6);
          endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
        } else {
          // Вверх
          sides = 'top:bottom';
          startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);
          endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);
        }
      }
    }

    return (start: startConnectionPoint, end: endConnectionPoint, sides: sides);
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

    if (rightDist < minDist) {
      minDist = rightDist;
      closestSide = 'right';
    }
    if (topDist < minDist) {
      minDist = topDist;
      closestSide = 'top';
    }
    if (bottomDist < minDist) {
      minDist = bottomDist;
      closestSide = 'bottom';
    }

    return closestSide;
  }

  /// Получить стрелки, связанные с конкретным узлом
  List<Arrow> getArrowsForNode(String nodeId) {
    return arrows.where((arrow) => 
      arrow.source == nodeId || arrow.target == nodeId
    ).toList();
  }

  /// Получить все стрелки, которые проходят через определенный тайл
  List<Arrow> getArrowsInTile(Rect tileBounds, Offset baseOffset) {
    final arrowsInTile = <Arrow>[];
    
    for (final arrow in arrows) {
      if (doesArrowIntersectTile(arrow, tileBounds, baseOffset)) {
        arrowsInTile.add(arrow);
      }
    }
    
    return arrowsInTile;
  }

  /// Проверяет, пересекает ли стрелка определенный тайл
  bool doesArrowIntersectTile(Arrow arrow, Rect tileBounds, Offset baseOffset) {
    // Находим эффективные узлы
    final effectiveSourceNode = _findEffectiveNodeById(arrow.source);
    final effectiveTargetNode = _findEffectiveNodeById(arrow.target);

    if (effectiveSourceNode == null || effectiveTargetNode == null) {
      return false;
    }

    // Получаем абсолютные позиции
    final sourceAbsolutePos =
        effectiveSourceNode.aPosition ??
        (effectiveSourceNode.position + baseOffset);
    final targetAbsolutePos =
        effectiveTargetNode.aPosition ??
        (effectiveTargetNode.position + baseOffset);

    // Создаем Rect для узлов
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

    // Вычисляем точки соединения
    final connectionPoints = calculateConnectionPointsForSideCalculation(
      sourceRect,
      targetRect,
      effectiveSourceNode,
      effectiveTargetNode,
    );
    
    if (connectionPoints.start == null || connectionPoints.end == null) {
      return false;
    }

    // Создаем простой ортогональный путь
    final path = _createSimpleOrthogonalPath(
      connectionPoints.start!,
      connectionPoints.end!,
      sourceRect,
      targetRect,
      connectionPoints.sides!,
    );
    
    // Проверяем пересечение с тайлом
    return path.getBounds().overlaps(tileBounds);
  }

  /// Создание простого ортогонального пути
  Path _createSimpleOrthogonalPath(
    Offset start,
    Offset end,
    Rect sourceRect,
    Rect targetRect,
    String sides,
  ) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dx2 = dx.abs() / 2;
    final dy2 = dy.abs() / 2;

    switch (sides) {
      case 'left:right':
        path.lineTo(start.dx - dx2, start.dy);
        path.lineTo(start.dx - dx2, end.dy);
        path.lineTo(end.dx, end.dy);
        break;
      case 'right:left':
        path.lineTo(start.dx + dx2, start.dy);
        path.lineTo(start.dx + dx2, end.dy);
        path.lineTo(end.dx, end.dy);
        break;
      case 'top:bottom':
        path.lineTo(start.dx, start.dy - dy2);
        path.lineTo(end.dx, start.dy - dy2);
        path.lineTo(end.dx, end.dy);
        break;
      case 'bottom:top':
        path.lineTo(start.dx, start.dy + dy2);
        path.lineTo(end.dx, start.dy + dy2);
        path.lineTo(end.dx, end.dy);
        break;
      case 'left:top':
      case 'right:top':
      case 'left:bottom':
      case 'right:bottom':
        path.lineTo(end.dx, start.dy);
        path.lineTo(end.dx, end.dy);
        break;
      case 'top:left':
      case 'top:right':
      case 'bottom:left':
      case 'bottom:right':
        path.lineTo(start.dx, end.dy);
        path.lineTo(end.dx, end.dy);
        break;
    }

    return path;
  }

  /// Получить ID узлов, связанных со стрелками
  Set<String> getNodeIdsForArrows(List<Arrow> arrowList) {
    final Set<String> nodeIds = <String>{};
    for (final arrow in arrowList) {
      nodeIds.add(arrow.source);
      nodeIds.add(arrow.target);
    }
    return nodeIds;
  }

  /// Получить ID стрелок, связанных с конкретным узлом
  List<String> getArrowIdsForNode(String nodeId) {
    return arrows.where((arrow) => 
      arrow.source == nodeId || arrow.target == nodeId
    ).map((arrow) => arrow.id).toList();
  }

  /// Получить полный путь стрелки для отрисовки в тайлах
  Path getArrowPathForTiles(Arrow arrow, Offset baseOffset) {
    // Находим эффективные узлы
    final effectiveSourceNode = _getEffectiveNode(arrow.source, nodes);
    final effectiveTargetNode = _getEffectiveNode(arrow.target, nodes);

    if (effectiveSourceNode == null || effectiveTargetNode == null) {
      return Path();
    }

    // Получаем абсолютные позиции
    final sourceAbsolutePos =
        effectiveSourceNode.aPosition ??
        (effectiveSourceNode.position + baseOffset);
    final targetAbsolutePos =
        effectiveTargetNode.aPosition ??
        (effectiveTargetNode.position + baseOffset);

    // Создаем Rect для узлов
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

    // Вычисляем точки соединения
    final connectionPoints = calculateConnectionPointsForSideCalculation(
      sourceRect,
      targetRect,
      effectiveSourceNode,
      effectiveTargetNode,
    );

    if (connectionPoints.start == null || connectionPoints.end == null) {
      return Path();
    }

    // Создаем простой ортогональный путь без проверок пересечений
    return _createSimpleOrthogonalPath(
      connectionPoints.start!,
      connectionPoints.end!,
      sourceRect,
      targetRect,
      connectionPoints.sides!,
    );
  }

  /// Найти эффективный узел
  TableNode? _getEffectiveNode(String nodeId, List<TableNode> allNodes) {
    TableNode? findNodeRecursive(List<TableNode> nodeList) {
      for (final node in nodeList) {
        if (node.id == nodeId) {
          return node;
        }
        if (node.children != null) {
          final found = findNodeRecursive(node.children!);
          if (found != null) return found;
        }
      }
      return null;
    }

    final node = findNodeRecursive(allNodes);
    if (node == null) return null;

    // Проверка на свернутые swimlane
    if (node.parent != null) {
      final parent = _getEffectiveNode(node.parent!, allNodes);
      if (parent != null &&
          parent.qType == 'swimlane' &&
          (parent.isCollapsed ?? false)) {
        return parent;
      }
    }

    return node;
  }

  /// Проверяет, пересекает ли путь тайл
  bool doesArrowPathIntersectTile(Arrow arrow, Rect tileBounds, Offset baseOffset) {
    final path = getArrowPathForTiles(arrow, baseOffset);
    if (path.getBounds().isEmpty) return false;

    // Проверяем, пересекается ли bounding box пути с тайлом
    final pathBounds = path.getBounds();
    if (!pathBounds.overlaps(tileBounds)) {
      return false;
    }

    // Проверяем, пересекаются ли bounding box узлов с тайлом
    final effectiveSourceNode = _getEffectiveNode(arrow.source, nodes);
    final effectiveTargetNode = _getEffectiveNode(arrow.target, nodes);

    if (effectiveSourceNode != null && effectiveTargetNode != null) {
      final sourceAbsolutePos =
          effectiveSourceNode.aPosition ?? (effectiveSourceNode.position + baseOffset);
      final targetAbsolutePos =
          effectiveTargetNode.aPosition ?? (effectiveTargetNode.position + baseOffset);

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

      // Если хотя бы один из узлов пересекается с тайлом, то стрелка должна быть в тайле
      if (sourceRect.overlaps(tileBounds) || targetRect.overlaps(tileBounds)) {
        return true;
      }
    }

    // Проверяем пересечение пути с тайлом более точно с помощью Path.contains()
    // Создаем Path для тайла
    final tilePath = Path()..addRect(tileBounds);
    
    // Используем более точный алгоритм проверки пересечения
    // Разбиваем путь на сегменты и проверяем каждый
    final pathMetrics = path.computeMetrics();
    
    for (final metric in pathMetrics) {
      // Проверяем несколько точек вдоль пути для надежности
      final totalLength = metric.length;
      final stepSize = totalLength > 0 ? totalLength / 50 : 1.0; // 50 точек для проверки
      
      for (double distance = 0; distance <= totalLength; distance += stepSize) {
        try {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            final point = tangent.position;
            if (tileBounds.contains(point)) {
              return true;
            }
          }
        } catch (e) {
          continue;
        }
      }
      
      // Также проверяем точки между начальной и конечной точками сегмента
      try {
        final startTangent = metric.getTangentForOffset(0);
        final endTangent = metric.getTangentForOffset(metric.length);
        
        if (startTangent != null && endTangent != null) {
          final startPoint = startTangent.position;
          final endPoint = endTangent.position;
          
          // Проверяем, пересекает ли сегмент границу тайла
          if (_lineIntersectsRect(startPoint, endPoint, tileBounds)) {
            return true;
          }
        }
      } catch (e) {
        continue;
      }
    }

    // Проверяем пересечение с помощью Path.op() - это самый точный способ
    try {
      final intersection = Path.combine(PathOperation.intersect, path, tilePath);
      return !intersection.getBounds().isEmpty;
    } catch (e) {
      // Если Path.op() не работает, используем резервный метод
      return pathBounds.overlaps(tileBounds);
    }
  }

  /// Проверяет, пересекает ли линия между двумя точками прямоугольник
  bool _lineIntersectsRect(Offset start, Offset end, Rect rect) {
    // Проверяем, находятся ли обе точки по одну сторону от прямоугольника
    if ((start.dx < rect.left && end.dx < rect.left) ||
        (start.dx > rect.right && end.dx > rect.right) ||
        (start.dy < rect.top && end.dy < rect.top) ||
        (start.dy > rect.bottom && end.dy > rect.bottom)) {
      return false;
    }

    // Если одна из точек внутри прямоугольника
    if (rect.contains(start) || rect.contains(end)) {
      return true;
    }

    // Проверяем пересечение с каждой стороной прямоугольника
    final leftEdge = _lineSegmentsIntersect(start, end, Offset(rect.left, rect.top), Offset(rect.left, rect.bottom));
    final rightEdge = _lineSegmentsIntersect(start, end, Offset(rect.right, rect.top), Offset(rect.right, rect.bottom));
    final topEdge = _lineSegmentsIntersect(start, end, Offset(rect.left, rect.top), Offset(rect.right, rect.top));
    final bottomEdge = _lineSegmentsIntersect(start, end, Offset(rect.left, rect.bottom), Offset(rect.right, rect.bottom));

    return leftEdge || rightEdge || topEdge || bottomEdge;
  }

  /// Проверяет пересечение двух отрезков
  bool _lineSegmentsIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    // Формула для определения пересечения отрезков
    final denom = (p4.dy - p3.dy) * (p2.dx - p1.dx) - (p4.dx - p3.dx) * (p2.dy - p1.dy);
    if (denom == 0) {
      // Линии параллельны
      return false;
    }

    final ua = ((p4.dx - p3.dx) * (p1.dy - p3.dy) - (p4.dy - p3.dy) * (p1.dx - p3.dx)) / denom;
    final ub = ((p2.dx - p1.dx) * (p1.dy - p3.dy) - (p2.dy - p1.dy) * (p1.dx - p3.dx)) / denom;

    return ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1;
  }
}
