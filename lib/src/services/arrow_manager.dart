import 'dart:math';
import 'dart:ui';

import 'package:fbpmn/src/editor_state.dart';
import 'package:flutter/cupertino.dart';

import '../models/table.node.dart';
import '../models/arrow.dart';
import 'manager.dart';

/// Сервис для управления и расчета соединений стрелок
class ArrowManager extends Manager {
  final EditorState state;

  ArrowManager({required this.state});

  selectAllArrows() {
    final arrowsSelected = getArrowsForNodes(
      state.nodesSelected.toList(),
    ).toSet();
    state.arrowsSelected.addAll(arrowsSelected);
    onStateUpdate();
  }

  /// Расчет точек соединения для определения стороны
  /// по расположению узлов относительно друг друга
  ({Offset? end, Offset? start, String? sides}) calculateConnectionPoints(
    Arrow arrow,
    Rect sourceRect,
    Rect targetRect,
    TableNode sourceNode,
    TableNode targetNode,
  ) {
    // Определяем центральные точки узлов
    final sourceCenter = sourceRect.center;
    final targetCenter = targetRect.center;

    // Определяем стороны и размеры узлов
    final sourceTop = sourceRect.top;
    final sourceBottom = sourceRect.bottom;
    final sourceLeft = sourceRect.left;
    final sourceRight = sourceRect.right;

    final targetTop = targetRect.top;
    final targetBottom = targetRect.bottom;
    final targetLeft = targetRect.left;
    final targetRight = targetRect.right;

    // Вычисляем расстояния между центрами узлов
    final cx = targetCenter.dx - sourceCenter.dx;
    final cy = targetCenter.dy - sourceCenter.dy;

    // Истино для Source узла
    final isLeftSide40 = sourceRight <= targetLeft - 40;
    final isTopSide40 = sourceBottom <= targetTop - 40;
    final isRightSide40 = sourceLeft >= targetRight + 40;
    final isBottomSide40 = sourceTop >= targetBottom + 40;

    // Истино для Source узла
    final isLeftCenter40 = sourceCenter.dx <= targetLeft - 40;
    final isTopCenter40 = sourceCenter.dy <= targetTop - 40;
    final isRightCenter40 = sourceCenter.dx >= targetRight + 40;
    final isBottomCenter40 = sourceCenter.dy >= targetBottom + 40;

    // Source находится сторонами за пределами 40px зоны Target
    if (isLeftSide40 || isTopSide40 || isRightSide40 || isBottomSide40) {
      if (isLeftSide40 && isTopSide40) {
        return _getSidePosition('left40|top40', sourceRect, targetRect);
      } else if (isRightSide40 && isTopSide40) {
        return _getSidePosition('right40|top40', sourceRect, targetRect);
      } else if (isLeftSide40 && isBottomSide40) {
        return _getSidePosition('left40|bottom40', sourceRect, targetRect);
      } else if (isRightSide40 && isBottomSide40) {
        return _getSidePosition('right40|bottom40', sourceRect, targetRect);
      } else if (isLeftSide40) {
        return _getSidePosition('left40', sourceRect, targetRect);
      } else if (isTopSide40) {
        return _getSidePosition('top40', sourceRect, targetRect);
      } else if (isRightSide40) {
        return _getSidePosition('right40', sourceRect, targetRect);
      } else if (isBottomSide40) {
        return _getSidePosition('bottom40', sourceRect, targetRect);
      }
    } else
    // Source находится центром за пределами 40px зоны Target
    if (isLeftCenter40 ||
        isTopCenter40 ||
        isRightCenter40 ||
        isBottomCenter40) {
      if (isLeftCenter40 && isTopCenter40) {
        return _getSidePosition('leftC|topC', sourceRect, targetRect);
      } else if (isRightCenter40 && isTopCenter40) {
        return _getSidePosition('rightC|topC', sourceRect, targetRect);
      } else if (isLeftCenter40 && isBottomCenter40) {
        return _getSidePosition('leftC|bottomC', sourceRect, targetRect);
      } else if (isRightCenter40 && isBottomCenter40) {
        return _getSidePosition('rightC|bottomC', sourceRect, targetRect);
      } else if (isLeftCenter40 && cy > 0) {
        return _getSidePosition('leftC|top', sourceRect, targetRect);
      } else if (isRightCenter40 && cy > 0) {
        return _getSidePosition('rightC|top', sourceRect, targetRect);
      } else if (isLeftCenter40 && cy <= 0) {
        return _getSidePosition('leftC|bottom', sourceRect, targetRect);
      } else if (isRightCenter40 && cy <= 0) {
        return _getSidePosition('rightC|bottom', sourceRect, targetRect);
      } else if (isTopCenter40 && cx > 0) {
        return _getSidePosition('left|topC', sourceRect, targetRect);
      } else if (isBottomCenter40 && cx > 0) {
        return _getSidePosition('left|bottomC', sourceRect, targetRect);
      } else if (isTopCenter40 && cx <= 0) {
        return _getSidePosition('right|topC', sourceRect, targetRect);
      } else if (isBottomCenter40 && cx <= 0) {
        return _getSidePosition('right|bottomC', sourceRect, targetRect);
      }
    } else {
      // Source находится центром внутри 40px зоны Target, положение от центра Target
      if (cx > 0 && cy > 0) {
        return _getSidePosition('left|top', sourceRect, targetRect);
      } else if (cx > 0 && cy <= 0) {
        return _getSidePosition('left|bottom', sourceRect, targetRect);
      } else if (cx <= 0 && cy > 0) {
        return _getSidePosition('right|top', sourceRect, targetRect);
      } else if (cx <= 0 && cy <= 0) {
        return _getSidePosition('right|bottom', sourceRect, targetRect);
      }
    }

    return _getSidePosition('error', sourceRect, targetRect);
  }

  /// Расчет координат точек соединения
  ({Offset? start, Offset? end, String? sides}) _getSidePosition(
    String position,
    Rect sourceRect,
    Rect targetRect,
  ) {
    String sides = '';

    // Определяем центральные точки узлов
    final sourceCenter = sourceRect.center;
    final sourceWidth = sourceRect.width;
    final sourceHeight = sourceRect.height;

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

    switch (position) {
      case 'left40':
        sides = 'right:left';
        break;
      case 'right40':
        sides = 'left:right';
        break;
      case 'top40':
        sides = 'bottom:top';
        break;
      case 'bottom40':
        sides = 'top:bottom';
        break;
      case 'left40|top40':
        sides = sourceWidth < sourceHeight ? 'right:top' : 'bottom:left';
        break;
      case 'right40|top40':
        sides = sourceWidth < sourceHeight ? 'left:top' : 'bottom:right';
        break;
      case 'left40|bottom40':
        sides = sourceWidth < sourceHeight ? 'right:bottom' : 'top:left';
        break;
      case 'right40|bottom40':
        sides = sourceWidth < sourceHeight ? 'left:bottom' : 'top:right';
        break;
      case 'leftC|topC':
      case 'leftC|bottomC':
        if (sourceWidth < sourceHeight) {
          if (sourceRight <= targetCenter.dx - 20) {
            sides = position == 'leftC|topC' ? 'right:top' : 'right:bottom';
          } else if (sourceBottom <= targetCenter.dy - 20) {
            sides = position == 'leftC|topC' ? 'bottom:left' : 'top:left';
          } else {
            sides = 'right:right';
          }
        } else {
          if (sourceBottom <= targetCenter.dy - 20) {
            sides = position == 'leftC|topC' ? 'bottom:left' : 'top:left';
          } else if (sourceRight <= targetCenter.dx - 20) {
            sides = position == 'leftC|topC' ? 'right:top' : 'right:bottom';
          } else {
            sides = 'bottom:bottom';
          }
        }
        break;
      case 'rightC|topC':
      case 'rightC|bottomC':
        if (sourceWidth < sourceHeight) {
          if (sourceRight > targetCenter.dx + 20) {
            sides = position == 'rightC|topC' ? 'left:top' : 'left:bottom';
          } else if (sourceBottom <= targetCenter.dy - 20) {
            sides = position == 'rightC|topC' ? 'bottom:right' : 'top:right';
          } else {
            sides = 'left:left';
          }
        } else {
          if (sourceBottom <= targetCenter.dy - 20) {
            sides = position == 'rightC|topC' ? 'bottom:right' : 'top:right';
          } else if (sourceRight > targetCenter.dx - 20) {
            sides = position == 'rightC|topC' ? 'left:top' : 'left:bottom';
          } else {
            sides = 'bottom:bottom';
          }
        }
        break;
      case 'leftC|top':
        sides = sourceBottom <= targetCenter.dy - 20
            ? 'bottom:left'
            : 'bottom:bottom';
        break;
      case 'rightC|top':
        sides = sourceBottom <= targetCenter.dy - 20
            ? 'bottom:right'
            : 'bottom:bottom';
        break;
      case 'leftC|bottom':
        sides = sourceTop > targetCenter.dy + 20 ? 'top:left' : 'top:top';
        break;
      case 'rightC|bottom':
        sides = sourceTop > targetCenter.dy + 20 ? 'top:right' : 'top:top';
        break;
      case 'left|topC':
      case 'left|bottomC':
        sides = 'left:left';
        break;
      case 'right|topC':
      case 'right|bottomC':
        sides = 'right:right';
        break;
      case 'left|top':
        if (sourceTop < targetTop) {
          sides = 'top:right:3';
        } else if (sourceBottom > targetBottom) {
          sides = 'bottom:right:3';
        } else if (sourceLeft < targetLeft) {
          sides = 'left:top:3';
        } else {
          sides = 'left:top:3';
        }
        break;
      case 'right|top':
        if (sourceTop < targetTop) {
          sides = 'top:left:3';
        } else if (sourceBottom > targetBottom) {
          sides = 'bottom:left:3';
        } else if (sourceRight > targetRight) {
          sides = 'right:top:3';
        } else {
          sides = 'right:top:3';
        }
        break;
      case 'left|bottom':
        if (sourceBottom > targetBottom) {
          sides = 'bottom:right:3';
        } else if (sourceTop < targetTop) {
          sides = 'top:right:3';
        } else if (sourceLeft < targetLeft) {
          sides = 'left:bottom:3';
        } else {
          sides = 'left:bottom:3';
        }
        break;
      case 'right|bottom':
        if (sourceBottom > targetBottom) {
          sides = 'bottom:left:3';
        } else if (sourceTop < targetTop) {
          sides = 'top:left:3';
        } else if (sourceRight > targetRight) {
          sides = 'right:bottom:3';
        } else {
          sides = 'right:bottom:3';
        }
        break;
      default:
        sides = 'error';
        break;
    }

    print('Source:Target=$sides, Position Source=$position');

    final sidesNodes = sides.split(':').take(2).join(':');

    switch (sidesNodes) {
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
  ({Path path, List<Offset> coordinates}) getArrowPathInTile(
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
    final baseConnectionPoints = calculateConnectionPoints(
      arrow,
      sourceRect,
      targetRect,
      effectiveSourceNode,
      effectiveTargetNode,
    );

    arrow.aPositionSource = baseConnectionPoints.start!;
    arrow.aPositionTarget = baseConnectionPoints.end!;

    if (baseConnectionPoints.start == null ||
        baseConnectionPoints.end == null) {
      return (path: Path(), coordinates: []);
    }

    // Создаем простой ортогональный путь без проверок пересечений
    final basePath = _createSimpleOrthogonalPath(
      baseConnectionPoints.start!,
      baseConnectionPoints.end!,
      sourceRect,
      targetRect,
      baseConnectionPoints.sides!,
    );

    return basePath;
  }

  /// Получает путь стрелки с учетом выбранных узлов и текущего масштаба
  ({Path path, List<Offset> coordinates}) getArrowPathWithSelectedNodes(
    Arrow arrow,
    Rect arrowsRect,
  ) {
    // Создаем простой ортогональный путь в мировых координатах
    final basePath = getArrowPathInTile(arrow, state.delta);

    // Преобразуем путь и координаты в экранные координаты
    return _convertPathToScreenCoordinates(basePath, arrowsRect);
  }

  /// Преобразует путь из мировых координат в экранные
  ({Path path, List<Offset> coordinates}) _convertPathToScreenCoordinates(
    ({Path path, List<Offset> coordinates}) worldPath,
    Rect arrowsRect,
  ) {
    final screenCoordinates = <Offset>[];

    // Преобразуем каждую координату
    for (final worldCoord in worldPath.coordinates) {
      final screenCoord =
          Offset(
            worldCoord.dx - arrowsRect.left,
            worldCoord.dy - arrowsRect.top,
          ) *
          state.scale;
      screenCoordinates.add(screenCoord);
    }

    final screenPath = _createPath(screenCoordinates, scale: state.scale);

    return (path: screenPath, coordinates: screenCoordinates);
  }

  /// Создание простого ортогонального пути
  ({Path path, List<Offset> coordinates}) _createSimpleOrthogonalPath(
    Offset start,
    Offset end,
    Rect sourceRect,
    Rect targetRect,
    String sides,
  ) {
    List<Offset> coordinates = [];

    // Определяем стороны и размеры узлов
    final sourceTop = sourceRect.top;
    final sourceBottom = sourceRect.bottom;
    final sourceLeft = sourceRect.left;
    final sourceRight = sourceRect.right;

    final targetTop = targetRect.top;
    final targetBottom = targetRect.bottom;
    final targetLeft = targetRect.left;
    final targetRight = targetRect.right;

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
      case 'left:top:3':
        final dyUp = min(sourceTop, targetTop) - 40;
        coordinates.add(Offset(start.dx - 40, start.dy));
        coordinates.add(Offset(start.dx - 40, dyUp));
        coordinates.add(Offset(end.dx, dyUp));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:top:3':
        final dyUp = min(sourceTop, targetTop) - 40;
        coordinates.add(Offset(start.dx + 40, start.dy));
        coordinates.add(Offset(start.dx + 40, dyUp));
        coordinates.add(Offset(end.dx, dyUp));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'left:bottom:3':
        final dyDown = max(sourceBottom, targetBottom) + 40;
        coordinates.add(Offset(start.dx - 40, start.dy));
        coordinates.add(Offset(start.dx - 40, dyDown));
        coordinates.add(Offset(end.dx, dyDown));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:bottom:3':
        final dyDown = max(sourceBottom, targetBottom) + 40;
        coordinates.add(Offset(start.dx + 40, start.dy));
        coordinates.add(Offset(start.dx + 40, dyDown));
        coordinates.add(Offset(end.dx, dyDown));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:left:3':
        final dyLeft = min(sourceLeft, targetLeft) - 40;
        coordinates.add(Offset(start.dx, start.dy - 40));
        coordinates.add(Offset(dyLeft, start.dy - 40));
        coordinates.add(Offset(dyLeft, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:left:3':
        final dyLeft = min(sourceLeft, targetLeft) - 40;
        coordinates.add(Offset(start.dx, start.dy + 40));
        coordinates.add(Offset(dyLeft, start.dy + 40));
        coordinates.add(Offset(dyLeft, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:right:3':
        final dyRight = max(sourceRight, targetRight) + 40;
        coordinates.add(Offset(start.dx, start.dy - 40));
        coordinates.add(Offset(dyRight, start.dy - 40));
        coordinates.add(Offset(dyRight, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:right:3':
        final dyRight = max(sourceRight, targetRight) + 40;
        coordinates.add(Offset(start.dx, start.dy + 40));
        coordinates.add(Offset(dyRight, start.dy + 40));
        coordinates.add(Offset(dyRight, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      default:
        break;
    }

    String direct = sides.split(':')[0];
    final path = _createPath(coordinates, direct: direct);

    return (path: path, coordinates: coordinates);
  }

  Path _createPath(List<Offset> coordinates, {String? direct, double? scale}) {
    final path = Path();
    final baseRadius = 10.0 * (scale ?? 1);
    final dx = coordinates.first.dx - coordinates[1].dx;
    final dy = coordinates.first.dy - coordinates[1].dy;

    if (direct == null) {
      if (dx > 0) {
        direct = 'left';
      } else if (dx < 0) {
        direct = 'right';
      } else if (dy > 0) {
        direct = 'top';
      } else {
        direct = 'bottom';
      }
    }

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
      final double radius = maxRadius > 1
          ? baseRadius.clamp(1.0, maxRadius)
          : 0;
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

    return path;
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

    final node = findNodeRecursive(state.nodes);
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

  /// Находит все связи, связанные с указанными узлами
  /// [nodes] - список узлов, для которых нужно найти связанные стрелки
  /// Возвращает список всех стрелок, где источник или цель находится в списке узлов
  List<Arrow?> getArrowsForNodes(List<TableNode?> nodes) {
    // Создаем Set для хранения уникальных ID узлов
    final Set<String> nodeIds = {};

    // Добавляем ID всех узлов из списка
    for (final node in nodes) {
      nodeIds.add(node!.id);

      // Также добавляем ID всех вложенных узлов, если они есть
      if (node.children != null && node.children!.isNotEmpty) {
        void addChildrenIds(TableNode parentNode) {
          for (final child in parentNode.children!) {
            nodeIds.add(child.id);
            if (child.children != null && child.children!.isNotEmpty) {
              addChildrenIds(child);
            }
          }
        }

        addChildrenIds(node);
      }
    }

    // Создаем Set для хранения уникальных стрелок
    final Set<Arrow?> arrowsSet = {};

    // Проходим по всем стрелкам в state.arrows
    for (final arrow in state.arrows) {
      // Проверяем, связана ли стрелка с любым из узлов в списке
      if (nodeIds.contains(arrow.source) || nodeIds.contains(arrow.target)) {
        arrowsSet.add(arrow);
      }
    }

    // Преобразуем Set в List и возвращаем
    return arrowsSet.toList();
  }

  /// Рассчитывает прямоугольник, который вмещает все стрелки
  Rect calculateBoundingRect(List<Arrow?> arrows) {
    if (arrows.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final arrow in arrows) {
      // Проверяем source позицию
      minX = arrow!.aPositionSource.dx < minX ? arrow.aPositionSource.dx : minX;
      minY = arrow.aPositionSource.dy < minY ? arrow.aPositionSource.dy : minY;
      maxX = arrow.aPositionSource.dx > maxX ? arrow.aPositionSource.dx : maxX;
      maxY = arrow.aPositionSource.dy > maxY ? arrow.aPositionSource.dy : maxY;

      // Проверяем target позицию
      minX = arrow.aPositionTarget.dx < minX ? arrow.aPositionTarget.dx : minX;
      minY = arrow.aPositionTarget.dy < minY ? arrow.aPositionTarget.dy : minY;
      maxX = arrow.aPositionTarget.dx > maxX ? arrow.aPositionTarget.dx : maxX;
      maxY = arrow.aPositionTarget.dy > maxY ? arrow.aPositionTarget.dy : maxY;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
