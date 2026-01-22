import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../models/table.node.dart';
import '../models/arrow.dart';
import 'manager.dart';

/// Сервис для управления и расчета соединений стрелок
class ArrowManager extends Manager {
  final List<Arrow> arrows;
  final List<TableNode> nodes;

  ArrowManager({
    required this.arrows,
    required this.nodes,
  });

  /// Расчет точек соединения для определения стороны
  ({Offset? end, Offset? start, String? sides})
  calculateConnectionPointsForSideCalculation(
    Arrow arrow,
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

    // Вычисляем расстояния между центрами узлов
    final dx = targetCenter.dx - sourceCenter.dx;
    final dy = targetCenter.dy - sourceCenter.dy;

    final isLeft40 = sourceRight <= targetLeft - 40;
    final isTop40 = sourceBottom <= targetTop - 40;
    final isRight40 = sourceLeft >= targetRight + 40;
    final isBottom40 = sourceTop >= targetBottom + 40;

    final isLeftCenter40 = sourceCenter.dx <= targetLeft - 40;
    final isTopCenter40 = sourceCenter.dy <= targetTop - 40;
    final isRightCenter40 = sourceCenter.dx >= targetRight + 40;
    final isBottomCenter40 = sourceCenter.dy >= targetBottom + 40;

    if (isLeft40 || isTop40 || isRight40 || isBottom40) {
      if (isLeft40 && isTop40) {
        return _getSidePosition('right:top', sourceRect, targetRect);
      } else if (isRight40 && isTop40) {
        return _getSidePosition('left:top', sourceRect, targetRect);
      } else if (isLeft40 && isBottom40) {
        return _getSidePosition('right:bottom', sourceRect, targetRect);
      } else if (isRight40 && isBottom40) {
        return _getSidePosition('left:bottom', sourceRect, targetRect);
      } else if (isLeft40) {
        return _getSidePosition('right:left', sourceRect, targetRect);
      } else if (isTop40) {
        return _getSidePosition('bottom:top', sourceRect, targetRect);
      } else if (isRight40) {
        return _getSidePosition('left:right', sourceRect, targetRect);
      } else if (isBottom40) {
        return _getSidePosition('top:bottom', sourceRect, targetRect);
      }
    } else if (isLeftCenter40 ||
        isTopCenter40 ||
        isRightCenter40 ||
        isBottomCenter40) {
      if (isLeftCenter40 && isTopCenter40) {
        return _getSidePosition('right:top', sourceRect, targetRect);
      } else if (isRightCenter40 && isTopCenter40) {
        return _getSidePosition('left:top', sourceRect, targetRect);
      } else if (isLeftCenter40 && isBottomCenter40) {
        return _getSidePosition('right:bottom', sourceRect, targetRect);
      } else if (isRightCenter40 && isBottomCenter40) {
        return _getSidePosition('left:bottom', sourceRect, targetRect);
      } else if ((isLeftCenter40 || isRightCenter40) && dy > 0) {
        return _getSidePosition('top:top', sourceRect, targetRect);
      } else if ((isLeftCenter40 || isRightCenter40) && dy <= 0) {
        return _getSidePosition('bottom:bottom', sourceRect, targetRect);
      } else if ((isTopCenter40 || isBottomCenter40) && dx > 0) {
        return _getSidePosition('left:left', sourceRect, targetRect);
      } else if ((isTopCenter40 || isBottomCenter40) && dx <= 0) {
        return _getSidePosition('right:right', sourceRect, targetRect);
      }
    } else {
      if ((dx > 0 || dx <= 0) && dy > 0) {
        return _getSidePosition('top:top', sourceRect, targetRect);
      } else if ((dx > 0 || dx <= 0) && dy <= 0) {
        return _getSidePosition('bottom:bottom', sourceRect, targetRect);
      }
    }

    return _getSidePosition('top:top', sourceRect, targetRect);
  }

  ({Offset? start, Offset? end, String? sides}) _getSidePosition(
    String sides,
    Rect sourceRect,
    Rect targetRect,
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

    switch (sides) {
      case 'right:top':
        startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
        break;
      case 'right:bottom':
        startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);
        break;
      case 'right:left':
        startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);
        break;
      case 'right:right':
        startConnectionPoint = Offset(sourceRight + 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetRight + 6, targetCenter.dy);
        break;
      case 'left:top':
        startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
        break;
      case 'left:bottom':
        startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);
        break;
      case 'left:right':
        startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetRight + 6, targetCenter.dy);
        break;
      case 'left:left':
        startConnectionPoint = Offset(sourceLeft - 6, sourceCenter.dy);
        endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);
        break;
      case 'top:bottom':
        startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);
        endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);
        break;
      case 'top:right':
        startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);
        endConnectionPoint = Offset(targetRight + 6, targetCenter.dy);
        break;
      case 'top:left':
        startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);
        endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);
        break;
      case 'top:top':
        startConnectionPoint = Offset(sourceCenter.dx, sourceTop - 6);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
        break;
      case 'bottom:top':
        startConnectionPoint = Offset(sourceCenter.dx, sourceBottom + 6);
        endConnectionPoint = Offset(targetCenter.dx, targetTop - 6);
        break;
      case 'bottom:right':
        startConnectionPoint = Offset(sourceCenter.dx, sourceBottom + 6);
        endConnectionPoint = Offset(targetRight + 6, targetCenter.dy);
        break;
      case 'bottom:left':
        startConnectionPoint = Offset(sourceCenter.dx, sourceBottom + 6);
        endConnectionPoint = Offset(targetLeft - 6, targetCenter.dy);
        break;
      case 'bottom:bottom':
        startConnectionPoint = Offset(sourceCenter.dx, sourceBottom + 6);
        endConnectionPoint = Offset(targetCenter.dx, targetBottom + 6);
        break;
    }
    return (start: startConnectionPoint, end: endConnectionPoint, sides: sides);
  }

  /// Получить полный путь стрелки для отрисовки в тайлах
  ({Path path, List<Offset> coordinates}) getArrowPathForTiles(
    Arrow arrow,
    Offset baseOffset,
  ) {
    // Находим эффективные узлы
    final effectiveSourceNode = _getEffectiveNode(arrow.source);
    final effectiveTargetNode = _getEffectiveNode(arrow.target);

    if (effectiveSourceNode == null || effectiveTargetNode == null) {
      return (path: Path(), coordinates: []);
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
      arrow,
      sourceRect,
      targetRect,
      effectiveSourceNode,
      effectiveTargetNode,
    );

    if (connectionPoints.start == null || connectionPoints.end == null) {
      return (path: Path(), coordinates: []);
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

  /// Создание простого ортогонального пути
  ({Path path, List<Offset> coordinates}) _createSimpleOrthogonalPath(
    Offset start,
    Offset end,
    Rect sourceRect,
    Rect targetRect,
    String sides,
  ) {
    final path = Path();
    List<Offset> coordinates = [];
    coordinates.add(Offset(start.dx, start.dy));

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dx2 = dx.abs() / 2;
    final dy2 = dy.abs() / 2;

    switch (sides) {
      case 'left:right':
        if (dy2 != 0) {
          coordinates.add(Offset(start.dx - dx2, start.dy));
          coordinates.add(Offset(start.dx - dx2, end.dy));
          coordinates.add(Offset(end.dx, end.dy));
        } else {
          coordinates.add(Offset(end.dx, end.dy));
        }
        break;
      case 'right:left':
        if (dy2 != 0) {
          coordinates.add(Offset(start.dx + dx2, start.dy));
          coordinates.add(Offset(start.dx + dx2, end.dy));
          coordinates.add(Offset(end.dx, end.dy));
        } else {
          coordinates.add(Offset(end.dx, end.dy));
        }
        break;
      case 'top:bottom':
        if (dx2 != 0) {
          coordinates.add(Offset(start.dx, start.dy - dy2));
          coordinates.add(Offset(end.dx, start.dy - dy2));
          coordinates.add(Offset(end.dx, end.dy));
        } else {
          coordinates.add(Offset(end.dx, end.dy));
        }
        break;
      case 'bottom:top':
        if (dx2 != 0) {
          coordinates.add(Offset(start.dx, start.dy + dy2));
          coordinates.add(Offset(end.dx, start.dy + dy2));
          coordinates.add(Offset(end.dx, end.dy));
        } else {
          coordinates.add(Offset(end.dx, end.dy));
        }
        break;
      case 'left:top':
      case 'right:top':
      case 'left:bottom':
      case 'right:bottom':
        coordinates.add(Offset(end.dx, start.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:left':
      case 'top:right':
      case 'bottom:left':
      case 'bottom:right':
        coordinates.add(Offset(start.dx, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'left:left':
        final dxMin = dx > 0 ? 0 : dx;
        coordinates.add(Offset(start.dx - 40 + dxMin, start.dy));
        coordinates.add(Offset(start.dx - 40 + dxMin, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:right':
        final dxMin = dx > 0 ? dx : 0;
        coordinates.add(Offset(start.dx + 40 + dxMin, start.dy));
        coordinates.add(Offset(start.dx + 40 + dxMin, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:top':
        final dyMin = dy > 0 ? 0 : dy;
        coordinates.add(Offset(start.dx, start.dy - 40 + dyMin));
        coordinates.add(Offset(end.dx, start.dy - 40 + dyMin));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:bottom':
        final dyMin = dy > 0 ? dy : 0;
        coordinates.add(Offset(start.dx, start.dy + 40 + dyMin));
        coordinates.add(Offset(end.dx, start.dy + 40 + dyMin));
        coordinates.add(Offset(end.dx, end.dy));
        break;
    }

    String direct = sides.split(':')[0];
    path.moveTo(coordinates.first.dx, coordinates.first.dy);
    for (int i = 1; i < coordinates.length - 1; i++) {
      final previous = coordinates[i - 1]; // предыдущая точка
      final current = coordinates[i]; // текущая точка
      final next = coordinates[i + 1]; // следующая точка
      // Расчет длин текущего и следующего отрезка
      final dxPrev = previous.dx - current.dx;
      final dyPrev = previous.dy - current.dy;
      final dx = current.dx - next.dx;
      final dy = current.dy - next.dy;
      final offsetCurrent = (dxPrev + dyPrev).abs(); // длина текущего отрезка
      final offsetNext = (dx + dy).abs(); // длина следующего отрезка
      // Находим минимальный отрезок
      final offset = min(offsetNext, offsetCurrent);
      final maxRadius = offset / 2;
      final double radius = maxRadius > 1 ? 10.0.clamp(1.0, maxRadius) : 0;
      double x1 = current.dx;
      double y1 = current.dy;
      bool clockwise = true;
      Offset endArcPoint;

      if (radius == 0) {
        // Добавляем путь до дуги
        path.lineTo(x1, y1);
        continue;
      }

      switch (direct) {
        case 'left':
          x1 = current.dx + radius;
          clockwise = dy > 0;
          break;
        case 'right':
          x1 = current.dx - radius;
          clockwise = dy < 0;
          break;
        case 'top':
          y1 = current.dy + radius;
          clockwise = dx < 0;
          break;
        case 'bottom':
          y1 = current.dy - radius;
          clockwise = dx > 0;
          break;
        default:
          break;
      }

      if (dx > 0) {
        direct = "left";
        endArcPoint = Offset(current.dx - radius, current.dy);
      } else if (dx < 0) {
        direct = "right";
        endArcPoint = Offset(current.dx + radius, current.dy);
      } else if (dy > 0) {
        direct = "top";
        endArcPoint = Offset(current.dx, current.dy - radius);
      } else {
        direct = "bottom";
        endArcPoint = Offset(current.dx, current.dy + radius);
      }

      // Добавляем путь до дуги
      path.lineTo(x1, y1);

      // Добавляем дугу поворота 90 градусов
      path.arcToPoint(
        endArcPoint,
        radius: Radius.circular(radius),
        largeArc: false,
        clockwise: clockwise,
      );
    }
    path.lineTo(coordinates.last.dx, coordinates.last.dy);

    return (path: path, coordinates: coordinates);
  }

  /// Найти эффективный узел
  TableNode? _getEffectiveNode(String nodeId) {
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

    final node = findNodeRecursive(nodes);
    if (node == null) return null;

    // Проверка на свернутые swimlane
    if (node.parent != null) {
      final parent = _getEffectiveNode(node.parent!);
      if (parent != null &&
          parent.qType == 'swimlane' &&
          (parent.isCollapsed ?? false)) {
        return parent;
      }
    }

    return node;
  }
}
