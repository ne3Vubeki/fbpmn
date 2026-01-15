import 'dart:ui';

import '../models/table.node.dart';
import '../models/arrow.dart';

/// Сервис для управления и расчета соединений стрелок
class ArrowManager {
  final List<Arrow> arrows;
  final List<TableNode> nodes;
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
        if (getSideForConnection(arrow, true) == side) {
          index++;
        }
      } else if (arrow.target == nodeId) {
        // Проверяем, какая сторона используется для цели
        if (getSideForConnection(arrow, false) == side) {
          index++;
        }
      }
    }
    
    return index;
  }

  /// Получить количество стрелок, подключенных к определенному узлу с определенной стороны
  int getConnectionsCountOnSide(String nodeId, String side) {
    return getArrowsOnSide(nodeId, side).length;
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
    final sourceAbsolutePos = effectiveSourceNode.aPosition ?? effectiveSourceNode.position;
    final targetAbsolutePos = effectiveTargetNode.aPosition ?? effectiveTargetNode.position;
    
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
    final connectionPoints = calculateConnectionPoints(sourceRect, targetRect, effectiveSourceNode, effectiveTargetNode, arrow);
    
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

  /// Вычислить точки соединения между двумя узлами
  /// Алгоритм определяет оптимальные точки входа/выхода для стрелок
  /// с учетом взаимного расположения узлов
  /// Расчет точек соединения для стрелки
  ({Offset? end, Offset? start}) calculateConnectionPoints(Rect sourceRect, Rect targetRect, TableNode sourceNode, TableNode targetNode, Arrow arrow) {
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
    startConnectionPoint = _distributeConnectionPoint(startConnectionPoint, sourceRect, startSide, arrow.source, arrow);
    endConnectionPoint = _distributeConnectionPoint(endConnectionPoint, targetRect, endSide, arrow.target, arrow);

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
  Offset _distributeConnectionPoint(Offset originalPoint, Rect rect, String side, String nodeId, Arrow arrow) {
    // Подсчитываем количество связей, подключенных к данной стороне узла
    int connectionsCount = getConnectionsCountOnSide(nodeId, side);
    
    // Если только одна связь на этой стороне, используем центральную точку
    if (connectionsCount <= 1) {
      return originalPoint;
    }
    
    // Находим индекс текущей связи среди всех связей, подключенных к этой стороне
    int index = getConnectionIndex(arrow, nodeId, side);
    
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
}