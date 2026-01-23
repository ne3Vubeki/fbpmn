import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../models/image_tile.dart';
import '../models/table.node.dart';
import '../models/arrow.dart';
import 'manager.dart';
import 'tile_manager.dart'; 

/// Сервис для управления и расчета соединений стрелок
class ArrowManager extends Manager {
  final List<Arrow> arrows;
  final List<TableNode> nodes;
  TileManager? tileManager; // Добавим tileManager для доступа к тайлам

  ArrowManager({
    required this.arrows,
    required this.nodes,
    this.tileManager,
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

  /// Получить точки соединения с проверкой на пересечения с другими узлами
  ({Offset? start, Offset? end, String? sides}) getConnectionPointsWithCollisionAvoidance(
    Arrow arrow,
    Rect sourceRect,
    Rect targetRect,
    TableNode sourceNode,
    TableNode targetNode,
    Offset baseOffset,
  ) {
    // Получаем базовые точки соединения
    final basePoints = calculateConnectionPointsForSideCalculation(
      arrow,
      sourceRect,
      targetRect,
      sourceNode,
      targetNode,
    );

    // Получаем список узлов для проверки пересечений
    final nodesToCheck = _getNodesForCollisionCheck(
      sourceRect,
      targetRect,
      baseOffset,
    );

    // Удаляем исходный и целевой узлы из списка проверки
    nodesToCheck.removeWhere((node) => 
      node.id == sourceNode.id || node.id == targetNode.id);

    // Если нет узлов для проверки, возвращаем базовые точки
    if (nodesToCheck.isEmpty) {
      return basePoints;
    }

    // Пытаемся найти оптимальные точки соединения без пересечений
    final optimizedPoints = _findOptimalConnectionPoints(
      basePoints,
      sourceRect,
      targetRect,
      sourceNode,
      targetNode,
      nodesToCheck,
      baseOffset,
    );

    return optimizedPoints ?? basePoints;
  }

  /// Получить список узлов для проверки коллизий
  List<TableNode> _getNodesForCollisionCheck(
    Rect sourceRect,
    Rect targetRect,
    Offset baseOffset,
  ) {
    final List<TableNode> nodesToCheck = [];

    // Рассчитываем область для поиска узлов
    final searchArea = _calculateSearchArea(sourceRect, targetRect);

    // Получаем тайлы, которые пересекаются с областью поиска
    final tiles = _getTilesInArea(searchArea);
    
    // Собираем уникальные узлы из всех найденных тайлов
    final Set<String> uniqueNodeIds = {};
    
    for (final tile in tiles) {
      for (final nodeId in tile.nodes) {
        if (nodeId != null && !uniqueNodeIds.contains(nodeId)) {
          final node = _getEffectiveNode(nodeId);
          if (node != null) {
            nodesToCheck.add(node);
            uniqueNodeIds.add(nodeId);
          }
        }
      }
    }

    return nodesToCheck;
  }

  /// Рассчитать область поиска узлов на основе крайних координат
  Rect _calculateSearchArea(Rect sourceRect, Rect targetRect) {
    final minLeft = min(sourceRect.left, targetRect.left);
    final minTop = min(sourceRect.top, targetRect.top);
    final maxRight = max(sourceRect.right, targetRect.right);
    final maxBottom = max(sourceRect.bottom, targetRect.bottom);

    // Добавляем отступ для безопасной зоны
    const padding = 100.0;
    
    return Rect.fromLTRB(
      minLeft - padding,
      minTop - padding,
      maxRight + padding,
      maxBottom + padding,
    );
  }

  /// Получить тайлы, пересекающиеся с областью
  List<ImageTile> _getTilesInArea(Rect area) {
    if (tileManager == null || tileManager!.state.imageTiles.isEmpty) {
      return [];
    }

    return tileManager!.state.imageTiles.where((tile) {
      return tile.bounds.overlaps(area);
    }).toList();
  }

  /// Найти оптимальные точки соединения без пересечений
  ({Offset? start, Offset? end, String? sides})? _findOptimalConnectionPoints(
    ({Offset? start, Offset? end, String? sides}) basePoints,
    Rect sourceRect,
    Rect targetRect,
    TableNode sourceNode,
    TableNode targetNode,
    List<TableNode> nodesToCheck,
    Offset baseOffset,
  ) {
    if (basePoints.start == null || basePoints.end == null) {
      return null;
    }

    final String sides = basePoints.sides ?? 'top:top';
    final List<String> sideVariants = _getSideVariants(sides);

    // Пробуем разные варианты сторон соединения
    for (final variant in sideVariants) {
      final variantPoints = _getSidePosition(variant, sourceRect, targetRect);
      
      if (variantPoints.start == null || variantPoints.end == null) {
        continue;
      }

      // Проверяем пересечение пути с узлами
      final pathCoordinates = _calculatePathCoordinates(
        variantPoints.start!,
        variantPoints.end!,
        variant,
      );

      // Проверяем, что путь не пересекает собственные узлы
      if (!_doesPathIntersectOwnNodes(pathCoordinates, sourceRect, targetRect) &&
          !_doesPathIntersectOtherNodes(pathCoordinates, nodesToCheck, baseOffset)) {
        return variantPoints;
      }
    }

    // Если не нашли вариант без пересечений, проверяем базовый путь
    final basePathCoordinates = _calculatePathCoordinates(
      basePoints.start!,
      basePoints.end!,
      sides,
    );

    // Проверяем, что базовый путь не пересекает собственные узлы
    if (!_doesPathIntersectOwnNodes(basePathCoordinates, sourceRect, targetRect) &&
        !_doesPathIntersectOtherNodes(basePathCoordinates, nodesToCheck, baseOffset)) {
      return basePoints;
    }

    return null; // Не нашли подходящего варианта
  }

  /// Проверить, пересекает ли путь собственные узлы (источник и цель)
  bool _doesPathIntersectOwnNodes(
    List<Offset> pathCoordinates,
    Rect sourceRect,
    Rect targetRect,
  ) {
    // Исключаем первую и последнюю точки (точки соединения)
    for (int i = 1; i < pathCoordinates.length - 1; i++) {
      final start = pathCoordinates[i];
      final end = pathCoordinates[i + 1];
      
      // Проверяем, проходит ли отрезок через sourceRect или targetRect
      if (_doesLineIntersectRect(start, end, sourceRect) ||
          _doesLineIntersectRect(start, end, targetRect)) {
        return true;
      }
    }
    
    return false;
  }

  /// Проверить, пересекает ли путь другие узлы
  bool _doesPathIntersectOtherNodes(
    List<Offset> pathCoordinates,
    List<TableNode> nodesToCheck,
    Offset baseOffset,
  ) {
    for (int i = 0; i < pathCoordinates.length - 1; i++) {
      final start = pathCoordinates[i];
      final end = pathCoordinates[i + 1];
      
      for (final node in nodesToCheck) {
        final nodePos = node.aPosition ?? (baseOffset + node.position);
        final nodeRect = Rect.fromPoints(
          nodePos,
          Offset(
            nodePos.dx + node.size.width,
            nodePos.dy + node.size.height,
          ),
        );

        // Проверяем пересечение линии с прямоугольником узла
        if (_doesLineIntersectRect(start, end, nodeRect)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Получить варианты сторон для тестирования
  List<String> _getSideVariants(String baseSides) {
    final parts = baseSides.split(':');
    if (parts.length != 2) return [baseSides];

    final sourceSide = parts[0];
    final targetSide = parts[1];
    
    final List<String> sourceSides = ['top', 'bottom', 'left', 'right'];
    final List<String> targetSides = ['top', 'bottom', 'left', 'right'];

    final List<String> variants = [baseSides];

    // Генерируем альтернативные варианты, начиная с наиболее вероятных
    final priorityVariants = <String>[];
    
    // Варианты с той же стороной источника
    for (final tgtSide in targetSides) {
      if (tgtSide != targetSide) {
        priorityVariants.add('$sourceSide:$tgtSide');
      }
    }
    
    // Варианты с той же стороной цели
    for (final srcSide in sourceSides) {
      if (srcSide != sourceSide) {
        priorityVariants.add('$srcSide:$targetSide');
      }
    }
    
    // Остальные варианты
    for (final srcSide in sourceSides) {
      for (final tgtSide in targetSides) {
        if (srcSide != sourceSide && tgtSide != targetSide) {
          final variant = '$srcSide:$tgtSide';
          if (!priorityVariants.contains(variant)) {
            priorityVariants.add(variant);
          }
        }
      }
    }

    return [...variants, ...priorityVariants];
  }

  /// Рассчитать координаты пути (без создания Path)
  List<Offset> _calculatePathCoordinates(
    Offset start,
    Offset end,
    String sides,
  ) {
    final coordinates = <Offset>[start];
    
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dx2 = dx.abs() / 2;
    final dy2 = dy.abs() / 2;

    switch (sides) {
      case 'left:right':
        if (dy2 != 0) {
          coordinates.add(Offset(start.dx - dx2, start.dy));
          coordinates.add(Offset(start.dx - dx2, end.dy));
        }
        break;
      case 'right:left':
        if (dy2 != 0) {
          coordinates.add(Offset(start.dx + dx2, start.dy));
          coordinates.add(Offset(start.dx + dx2, end.dy));
        }
        break;
      case 'top:bottom':
        if (dx2 != 0) {
          coordinates.add(Offset(start.dx, start.dy - dy2));
          coordinates.add(Offset(end.dx, start.dy - dy2));
        }
        break;
      case 'bottom:top':
        if (dx2 != 0) {
          coordinates.add(Offset(start.dx, start.dy + dy2));
          coordinates.add(Offset(end.dx, start.dy + dy2));
        }
        break;
      case 'left:top':
      case 'right:top':
      case 'left:bottom':
      case 'right:bottom':
        coordinates.add(Offset(end.dx, start.dy));
        break;
      case 'top:left':
      case 'top:right':
      case 'bottom:left':
      case 'bottom:right':
        coordinates.add(Offset(start.dx, end.dy));
        break;
      case 'left:left':
        final dxMin = dx > 0 ? 0 : dx;
        coordinates.add(Offset(start.dx - 40 + dxMin, start.dy));
        coordinates.add(Offset(start.dx - 40 + dxMin, end.dy));
        break;
      case 'right:right':
        final dxMin = dx > 0 ? dx : 0;
        coordinates.add(Offset(start.dx + 40 + dxMin, start.dy));
        coordinates.add(Offset(start.dx + 40 + dxMin, end.dy));
        break;
      case 'top:top':
        final dyMin = dy > 0 ? 0 : dy;
        coordinates.add(Offset(start.dx, start.dy - 40 + dyMin));
        coordinates.add(Offset(end.dx, start.dy - 40 + dyMin));
        break;
      case 'bottom:bottom':
        final dyMin = dy > 0 ? dy : 0;
        coordinates.add(Offset(start.dx, start.dy + 40 + dyMin));
        coordinates.add(Offset(end.dx, start.dy + 40 + dyMin));
        break;
    }

    coordinates.add(end);
    return coordinates;
  }

  /// Проверить пересечение линии с прямоугольником
  bool _doesLineIntersectRect(Offset lineStart, Offset lineEnd, Rect rect) {
    // Проверяем, находятся ли конечные точки внутри прямоугольника
    // Исключаем точки, которые находятся на границе прямоугольника (точки соединения)
    final borderTolerance = 1.0;
    final rectWithTolerance = Rect.fromLTRB(
      rect.left - borderTolerance,
      rect.top - borderTolerance,
      rect.right + borderTolerance,
      rect.bottom + borderTolerance,
    );
    
    final rectWithoutTolerance = Rect.fromLTRB(
      rect.left + borderTolerance,
      rect.top + borderTolerance,
      rect.right - borderTolerance,
      rect.bottom - borderTolerance,
    );
    
    // Если конечная точка находится внутри прямоугольника (но не на границе)
    if (rectWithoutTolerance.contains(lineStart) || rectWithoutTolerance.contains(lineEnd)) {
      return true;
    }

    // Проверяем пересечение с каждой стороной прямоугольника
    final List<Offset> rectPoints = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];

    for (int i = 0; i < 4; i++) {
      final sideStart = rectPoints[i];
      final sideEnd = rectPoints[(i + 1) % 4];
      
      if (_doLinesIntersect(lineStart, lineEnd, sideStart, sideEnd)) {
        return true;
      }
    }

    return false;
  }

  /// Проверить пересечение двух отрезков
  bool _doLinesIntersect(Offset p1, Offset p2, Offset q1, Offset q2) {
    final orient1 = _orientation(p1, p2, q1);
    final orient2 = _orientation(p1, p2, q2);
    final orient3 = _orientation(q1, q2, p1);
    final orient4 = _orientation(q1, q2, p2);

    return (orient1 != orient2 && orient3 != orient4) ||
           (orient1 == 0 && _onSegment(p1, q1, p2)) ||
           (orient2 == 0 && _onSegment(p1, q2, p2)) ||
           (orient3 == 0 && _onSegment(q1, p1, q2)) ||
           (orient4 == 0 && _onSegment(q1, p2, q2));
  }

  /// Вычислить ориентацию трех точек
  int _orientation(Offset p, Offset q, Offset r) {
    final val = (q.dy - p.dy) * (r.dx - q.dx) - (q.dx - p.dx) * (r.dy - q.dy);
    
    if (val == 0) return 0; // коллинеарны
    return (val > 0) ? 1 : 2; // по часовой или против
  }

  /// Проверить, лежит ли точка q на отрезке pr
  bool _onSegment(Offset p, Offset q, Offset r) {
    return q.dx <= max(p.dx, r.dx) &&
           q.dx >= min(p.dx, r.dx) &&
           q.dy <= max(p.dy, r.dy) &&
           q.dy >= min(p.dy, r.dy);
  }

  ({Offset? end, Offset? start, String? sides}) _getSidePosition(
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

  /// Получить полный путь стрелки для отрисовки в тайлах (обновленная версия)
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

    // Вычисляем точки соединения с проверкой на пересечения
    final connectionPoints = getConnectionPointsWithCollisionAvoidance(
      arrow,
      sourceRect,
      targetRect,
      effectiveSourceNode,
      effectiveTargetNode,
      baseOffset,
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
