import 'dart:ui';

import 'package:get/get.dart';

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
    // Находим узлы источника и цели
    final sourceNode = _findNodeById(arrow.source);
    final targetNode = _findNodeById(arrow.target);
    
    if (sourceNode == null || targetNode == null) {
      return 'top'; // запасной вариант
    }
    
    // Получаем абсолютные позиции узлов
    final sourceAbsolutePos = sourceNode.aPosition ?? sourceNode.position;
    final targetAbsolutePos = targetNode.aPosition ?? targetNode.position;
    
    // Создаем прямоугольники для узлов
    final sourceRect = Rect.fromPoints(
      sourceAbsolutePos,
      Offset(
        sourceAbsolutePos.dx + sourceNode.size.width,
        sourceAbsolutePos.dy + sourceNode.size.height,
      ),
    );
    
    final targetRect = Rect.fromPoints(
      targetAbsolutePos,
      Offset(
        targetAbsolutePos.dx + targetNode.size.width,
        targetAbsolutePos.dy + targetNode.size.height,
      ),
    );
    
    // Вычисляем точки соединения
    final connectionPoints = _calculateConnectionPoints(sourceRect, targetRect, sourceNode, targetNode);
    
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
  ({Offset? end, Offset? start}) _calculateConnectionPoints(Rect sourceRect, Rect targetRect, TableNode sourceNode, TableNode targetNode) {
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

    // Вычисляем расстояния между центрами
    final dx = targetCenter.dx - sourceCenter.dx;
    final dy = targetCenter.dy - sourceCenter.dy;

    // Определяем сторону источника (откуда начинается соединение)
    // Специальные случаи для улучшения визуального представления стрелок
    
    // Случай 1: Источник слева и выше цели, с достаточным расстоянием
    if (dx < 0 && dy < 0 && dx.abs() > 20 && sourceCenter.dy < targetTop - 20) {
      // Центр узла источника находится слева и выше верха узла цели на >20
      startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);  // Изменено: +6 для отступа наружу
      endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);      // Изменено: -6 для отступа наружу
    } 
    // Случай 2: Источник слева и ниже цели, с большим горизонтальным расстоянием
    else if (dx < 0 && dy > 0 && dx.abs() > 40 && sourceCenter.dy > targetTop + 20) {
      // Центр узла источника находится слева (>40 расстояния) и ниже верха+20 узла цели
      startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);  // Изменено: +6 для отступа наружу
      endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);     // Изменено: -6 для отступа наружу
    } 
    // Случай 3: Источник слева и ниже цели, с небольшим горизонтальным расстоянием
    else if (dx < 0 && dy > 0 && dx.abs() <= 40 && sourceCenter.dy > targetTop + 20) {
      // Центр узла источника находится слева (<=40 расстояния) и ниже верха+20 узла цели
      startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);    // Изменено: -6 для отступа наружу
      endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);      // Изменено: -6 для отступа наружу
    } 
    // Случай 4: Источник слева и значительно ниже цели
    else if (dx < 0 && dy > 0 && sourceCenter.dy > targetBottom + 20) {
      // Центр узла источника находится слева и ниже низа узла цели на >20
      startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);  // Изменено: +6 для отступа наружу
      endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);   // Изменено: +6 для отступа наружу
    } 
    // Случай 5: Источник слева и чуть ниже цели, с большим горизонтальным расстоянием
    else if (dx < 0 && dy > 0 && dx.abs() > 40 && sourceCenter.dy > targetBottom - 20) {
      // Центр узла источника находится слева (>40 расстояния) и ниже <20 от низа узла цели
      startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);  // Изменено: +6 для отступа наружу
      endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);     // Изменено: -6 для отступа наружу
    } 
    // Случай 6: Источник слева и чуть ниже цели, с небольшим горизонтальным расстоянием
    else if (dx < 0 && dy > 0 && dx.abs() <= 40 && sourceCenter.dy > targetBottom - 20) {
      // Центр узла источника находится слева (<=40 расстояния) и ниже <20 от низа узла цели
      startConnectionPoint = Offset(sourceCenter.dx, sourceBottom + 6); // Изменено: +6 для отступа наружу
      endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);   // Изменено: +6 для отступа наружу
    } 
    // Стандартные случаи
    else {
      // Для остальных случаев используем алгоритм, подобный оригинальному
      // Определяем основное направление соединения
      if (dx.abs() >= dy.abs()) {
        // Преобладает горизонтальное направление
        if (dx > 0) {
          // Вправо
          startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);  // Изменено: +6 для отступа наружу
          endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);     // Изменено: -6 для отступа наружу
        } else {
          // Влево
          startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);   // Изменено: -6 для отступа наружу
          endConnectionPoint = Offset(targetRight + 6, targetCenter.dy);    // Изменено: +6 для отступа наружу
        }
      } else {
        // Преобладает вертикальное направление
        if (dy > 0) {
          // Вниз
          startConnectionPoint = Offset(sourceCenter.dx, sourceBottom + 6); // Изменено: +6 для отступа наружу
          endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);      // Изменено: -6 для отступа наружу
        } else {
          // Вверх
          startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);    // Изменено: -6 для отступа наружу
          endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);   // Изменено: +6 для отступа наружу
        }
      }
    }

    return (start: startConnectionPoint, end: endConnectionPoint);
  }

  /// Определить, к какой стороне узла принадлежит точка
  String _getSideFromPoint(Offset point, Rect rect) {
    // Compare distances to different sides and select the nearest one
    double leftDist = (point.dx - rect.left).abs();
    double rightDist = (point.dx - rect.right).abs();
    double topDist = (point.dy - rect.top).abs();
    double bottomDist = (point.dy - rect.bottom).abs();
    
    // Find minimum distance
    double minDist = leftDist;
    String closestSide = 'left';
    
    if (rightDist < minDist) { minDist = rightDist; closestSide = 'right'; }
    if (topDist < minDist) { minDist = topDist; closestSide = 'top'; }
    if (bottomDist < minDist) { minDist = bottomDist; closestSide = 'bottom'; }
    
    return closestSide;
  }

  /// Распределить точки соединения вдоль стороны с шагом 10
  /// Этот метод равномерно распределяет несколько соединений на одной стороне узла
  /// для избежания наложения стрелок
  Offset distributeConnectionPoint(Offset originalPoint, Rect rect, String side, String nodeId, Arrow arrow) {
    // Считаем количество соединений, прикрепленных к этой стороне узла
    int connectionsCount = getConnectionsCountOnSide(nodeId, side);
    
    // Если только одно соединение на этой стороне, используем центральную точку
    if (connectionsCount <= 1) {
      return originalPoint;
    }
    
    // Находим индекс текущего соединения среди всех соединений, прикрепленных к этой стороне
    int index = getConnectionIndex(arrow, nodeId, side);
    
    // Вычисляем смещение для равномерного распределения
    double offset = 0.0;
    switch (side) {
      case 'top':
      case 'bottom':
        // Для горизонтальных сторон (верх/низ) смещение по оси X
        double sideLength = rect.width;
        // Центральная точка стороны
        double centerPoint = rect.center.dx;
        
        // Если нечетное количество соединений, центр остается посередине, остальные распределяются по сторонам
        if (connectionsCount % 2 == 1) {
          // Нечетное количество соединений
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
          // Четное количество соединений
          int halfCount = connectionsCount ~/ 2;
          if (index < halfCount) {
            // Левые точки
            offset = -(halfCount - index - 0.5) * 10.0;
          } else {
            // Правые точки
            offset = (index - halfCount + 0.5) * 10.0;
          }
        }
        
        // Убеждаемся, что точка не выходит за пределы стороны
        double clampedOffset = offset.clamp(
          -sideLength / 2 + 6, // Минимальное смещение от края (учитывая отступ 6)
          sideLength / 2 - 6   // Максимальное смещение от края (учитывая отступ 6)
        );
        
        return Offset(centerPoint + clampedOffset, originalPoint.dy);
        
      case 'left':
      case 'right':
        // Для вертикальных сторон (лево/право) смещение по оси Y
        double sideLength = rect.height;
        // Центральная точка стороны
        double centerPoint = rect.center.dy;
        
        // Если нечетное количество соединений, центр остается посередине, остальные распределяются по сторонам
        if (connectionsCount % 2 == 1) {
          // Нечетное количество соединений
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
          // Четное количество соединений
          int halfCount = connectionsCount ~/ 2;
          if (index < halfCount) {
            // Верхние точки
            offset = -(halfCount - index - 0.5) * 10.0;
          } else {
            // Нижние точки
            offset = (index - halfCount + 0.5) * 10.0;
          }
        }
        
        // Убеждаемся, что точка не выходит за пределы стороны
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