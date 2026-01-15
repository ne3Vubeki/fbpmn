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
    
    // Определяем сторону
    if (isSource) {
      return _determineOptimalSide(sourceRect, targetRect, true);
    } else {
      return _determineOptimalSide(sourceRect, targetRect, false);
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
    
    // Определяем сторону без вызова методов подсчета
    if (isSource) {
      return _determineOptimalSide(sourceRect, targetRect, true);
    } else {
      return _determineOptimalSide(sourceRect, targetRect, false);
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

  /// Расчет точек соединения с учетом распределения для текущей стрелки
  ({Offset? end, Offset? start}) calculateConnectionPointsWithDistribution(Arrow arrow) {
    // Находим эффективные узлы источника и цели (учитываем свернутые swimlane)
    final effectiveSourceNode = _findEffectiveNodeById(arrow.source);
    final effectiveTargetNode = _findEffectiveNodeById(arrow.target);
    
    if (effectiveSourceNode == null || effectiveTargetNode == null) {
      return (start: null, end: null);
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
    
    // Определяем стороны для подключения
    final sourceSide = _determineOptimalSide(sourceRect, targetRect, true);
    final targetSide = _determineOptimalSide(sourceRect, targetRect, false);
    
    // Получаем количество стрелок, уже подключенных к этим сторонам
    final sourceSideConnectionCount = getConnectionsCountOnSide(arrow.source, sourceSide);
    final targetSideConnectionCount = getConnectionsCountOnSide(arrow.target, targetSide);
    
    // Получаем индекс текущей стрелки среди всех стрелок, подключенных к стороне источника
    final sourceConnectionIndex = getConnectionIndex(arrow, arrow.source, sourceSide);
    final targetConnectionIndex = getConnectionIndex(arrow, arrow.target, targetSide);
    
    // Рассчитываем точки подключения с учетом распределения
    final startConnectionPoint = _calculateDistributedPoint(
      sourceRect, 
      sourceSide, 
      sourceConnectionIndex, 
      sourceSideConnectionCount
    );
    
    final endConnectionPoint = _calculateDistributedPoint(
      targetRect, 
      targetSide, 
      targetConnectionIndex, 
      targetSideConnectionCount
    );

    return (start: startConnectionPoint, end: endConnectionPoint);
  }
  
  /// Расчет точек соединения для определения стороны (без вызова методов подсчета)
  ({Offset? end, Offset? start}) calculateConnectionPointsForSideCalculation(Rect sourceRect, Rect targetRect, TableNode sourceNode, TableNode targetNode) {
    // Используем тот же алгоритм определения стороны, что и в основном методе
    final sourceSide = _determineOptimalSide(sourceRect, targetRect, true);
    final targetSide = _determineOptimalSide(sourceRect, targetRect, false);
    
    // Для определения стороны используем центральную точку
    final sourceCenter = sourceRect.center;
    final targetCenter = targetRect.center;
    
    Offset? startConnectionPoint;
    Offset? endConnectionPoint;

    switch (sourceSide) {
      case 'left':
        startConnectionPoint = Offset(sourceRect.left, sourceCenter.dy);
        break;
      case 'right':
        startConnectionPoint = Offset(sourceRect.right, sourceCenter.dy);
        break;
      case 'top':
        startConnectionPoint = Offset(sourceCenter.dx, sourceRect.top);
        break;
      case 'bottom':
        startConnectionPoint = Offset(sourceCenter.dx, sourceRect.bottom);
        break;
      default:
        startConnectionPoint = sourceCenter;
    }

    switch (targetSide) {
      case 'left':
        endConnectionPoint = Offset(targetRect.left, targetCenter.dy);
        break;
      case 'right':
        endConnectionPoint = Offset(targetRect.right, targetCenter.dy);
        break;
      case 'top':
        endConnectionPoint = Offset(targetCenter.dx, targetRect.top);
        break;
      case 'bottom':
        endConnectionPoint = Offset(targetCenter.dx, targetRect.bottom);
        break;
      default:
        endConnectionPoint = targetCenter;
    }

    // ВАЖНО: Этот метод не вызывает распределение точек, чтобы избежать рекурсии
    // Он возвращает базовые точки соединения без вызова методов подсчета
    return (start: startConnectionPoint, end: endConnectionPoint);
  }
  
  /// Определяет оптимальную сторону для подключения стрелки
  String _determineOptimalSide(Rect sourceRect, Rect targetRect, bool isSource) {
    final sourceCenter = sourceRect.center;
    final targetCenter = targetRect.center;

    // Вычисляем расстояния между центрами узлов
    final dx = targetCenter.dx - sourceCenter.dx;
    final dy = targetCenter.dy - sourceCenter.dy;

    // Определяем, какую сторону использовать
    if (isSource) {
      // Для источника определяем сторону в зависимости от положения цели
      if (dx.abs() >= dy.abs()) {
        // Горизонтальное направление преобладает
        if (dx > 0) {
          return 'right';  // Цель справа от источника
        } else {
          return 'left';   // Цель слева от источника
        }
      } else {
        // Вертикальное направление преобладает
        if (dy > 0) {
          return 'bottom'; // Цель снизу от источника
        } else {
          return 'top';    // Цель сверху от источника
        }
      }
    } else {
      // Для цели определяем сторону в зависимости от положения источника
      if (dx.abs() >= dy.abs()) {
        // Горизонтальное направление преобладает
        if (dx > 0) {
          return 'left';   // Источник слева от цели
        } else {
          return 'right';  // Источник справа от цели
        }
      } else {
        // Вертикальное направление преобладает
        if (dy > 0) {
          return 'top';    // Источник сверху от цели
        } else {
          return 'bottom'; // Источник снизу от цели
        }
      }
    }
  }
  
  /// Рассчитывает точку подключения с учетом распределения нескольких стрелок на одной стороне
  Offset? _calculateDistributedPoint(Rect rect, String side, int connectionIndex, int totalConnections) {
    // Вычисляем центральные координаты
    final center = rect.center;
    
    if (totalConnections <= 1) {
      // Если только одна стрелка, используем центр стороны
      switch (side) {
        case 'left':
          return Offset(rect.left, center.dy);
        case 'right':
          return Offset(rect.right, center.dy);
        case 'top':
          return Offset(center.dx, rect.top);
        case 'bottom':
          return Offset(center.dx, rect.bottom);
        default:
          return center;
      }
    }
    
    // Если несколько стрелок, распределяем их равномерно по стороне
    const spacingPadding = 8.0; // Отступ от краев, чтобы стрелки не выходили за границы
    double position = 0.5; // По умолчанию в центре
    
    if (totalConnections > 1) {
      // Распределяем стрелки равномерно по стороне
      position = (connectionIndex + 1) / (totalConnections + 1);
    }
    
    switch (side) {
      case 'left':
      case 'right':
        // Для вертикальных сторон (левая, правая) изменяем Y координату
        final availableLength = rect.height - 2 * spacingPadding;
        final offset = (position * availableLength) + spacingPadding;
        return Offset(
          side == 'left' ? rect.left : rect.right,
          rect.top + offset,
        );
        
      case 'top':
      case 'bottom':
        // Для горизонтальных сторон (верх, низ) изменяем X координату
        final availableLength = rect.width - 2 * spacingPadding;
        final offset = (position * availableLength) + spacingPadding;
        return Offset(
          rect.left + offset,
          side == 'top' ? rect.top : rect.bottom,
        );
        
      default:
        return center;
    }
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

}