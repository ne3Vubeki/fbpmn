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

  /// Расчет точек соединения для определения стороны (без вызова методов подсчета)
  ({Offset? end, Offset? start, String? sides})
  calculateConnectionPointsForSideCalculation(
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
    print(sides);

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
}
