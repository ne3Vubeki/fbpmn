import 'dart:math';
import 'dart:ui';

import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/models/arrow_paths.dart';
import 'package:flutter/cupertino.dart';

import '../models/table.node.dart';
import '../models/arrow.dart';
import 'manager.dart';

/// Сервис для управления и расчета соединений стрелок
class ArrowManager extends Manager {
  final EditorState state;

  double get arrowIndent => 12;
  double get sizeLimit => 60;
  double get halfSizeLimit => 30;

  ArrowManager({required this.state});

  selectAllArrows() {
    final arrowsSelected = getArrowsForNodes(state.nodesSelected.toList()).toSet();
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
    final isLeftSide60 = sourceRight <= targetLeft - 60;
    final isTopSide60 = sourceBottom <= targetTop - 60;
    final isRightSide60 = sourceLeft >= targetRight + 60;
    final isBottomSide60 = sourceTop >= targetBottom + 60;

    // Истино для Source узла
    final isLeftCenter60 = sourceCenter.dx <= targetLeft - 60;
    final isTopCenter60 = sourceCenter.dy <= targetTop - 60;
    final isRightCenter60 = sourceCenter.dx >= targetRight + 60;
    final isBottomCenter60 = sourceCenter.dy >= targetBottom + 60;

    // Source находится сторонами за пределами 60px зоны Target
    if (isLeftSide60 || isTopSide60 || isRightSide60 || isBottomSide60) {
      if (isLeftSide60 && isTopSide60) {
        return _getSidePosition('left60|top60', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isRightSide60 && isTopSide60) {
        return _getSidePosition('right60|top60', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isLeftSide60 && isBottomSide60) {
        return _getSidePosition('left60|bottom60', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isRightSide60 && isBottomSide60) {
        return _getSidePosition('right60|bottom60', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isLeftSide60) {
        return _getSidePosition('left60', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isTopSide60) {
        return _getSidePosition('top60', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isRightSide60) {
        return _getSidePosition('right60', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isBottomSide60) {
        return _getSidePosition('bottom60', sourceRect, targetRect, sourceNode, targetNode, arrow);
      }
    } else
    // Source находится центром за пределами 60px зоны Target
    if (isLeftCenter60 || isTopCenter60 || isRightCenter60 || isBottomCenter60) {
      if (isLeftCenter60 && isTopCenter60) {
        return _getSidePosition('leftC|topC', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isRightCenter60 && isTopCenter60) {
        return _getSidePosition('rightC|topC', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isLeftCenter60 && isBottomCenter60) {
        return _getSidePosition('leftC|bottomC', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isRightCenter60 && isBottomCenter60) {
        return _getSidePosition('rightC|bottomC', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isLeftCenter60 && cy > 0) {
        return _getSidePosition('leftC|top', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isRightCenter60 && cy > 0) {
        return _getSidePosition('rightC|top', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isLeftCenter60 && cy <= 0) {
        return _getSidePosition('leftC|bottom', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isRightCenter60 && cy <= 0) {
        return _getSidePosition('rightC|bottom', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isTopCenter60 && cx > 0) {
        return _getSidePosition('left|topC', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isBottomCenter60 && cx > 0) {
        return _getSidePosition('left|bottomC', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isTopCenter60 && cx <= 0) {
        return _getSidePosition('right|topC', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (isBottomCenter60 && cx <= 0) {
        return _getSidePosition('right|bottomC', sourceRect, targetRect, sourceNode, targetNode, arrow);
      }
    } else {
      // Source находится центром внутри 60px зоны Target, положение от центра Target
      if (cx > 0 && cy > 0) {
        return _getSidePosition('left|top', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (cx > 0 && cy <= 0) {
        return _getSidePosition('left|bottom', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (cx <= 0 && cy > 0) {
        return _getSidePosition('right|top', sourceRect, targetRect, sourceNode, targetNode, arrow);
      } else if (cx <= 0 && cy <= 0) {
        return _getSidePosition('right|bottom', sourceRect, targetRect, sourceNode, targetNode, arrow);
      }
    }

    return _getSidePosition('error', sourceRect, targetRect, sourceNode, targetNode, arrow);
  }

  /// Расчет координат точек соединения
  ({Offset? start, Offset? end, String? sides}) _getSidePosition(
    String position,
    Rect sourceRect,
    Rect targetRect,
    TableNode sourceNode,
    TableNode targetNode,
    Arrow arrow,
  ) {
    String sides = '';

    try {
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

      Offset startConnectionPoint = Offset.zero;
      Offset endConnectionPoint = Offset.zero;

      switch (position) {
        case 'left60':
          sides = 'right:left';
          break;
        case 'right60':
          sides = 'left:right';
          break;
        case 'top60':
          sides = 'bottom:top';
          break;
        case 'bottom60':
          sides = 'top:bottom';
          break;
        case 'left60|top60':
          sides = sourceWidth < sourceHeight ? 'right:top' : 'bottom:left';
          break;
        case 'right60|top60':
          sides = sourceWidth < sourceHeight ? 'left:top' : 'bottom:right';
          break;
        case 'left60|bottom60':
          sides = sourceWidth < sourceHeight ? 'right:bottom' : 'top:left';
          break;
        case 'right60|bottom60':
          sides = sourceWidth < sourceHeight ? 'left:bottom' : 'top:right';
          break;
        case 'leftC|topC':
        case 'leftC|bottomC':
          if (sourceWidth < sourceHeight) {
            if (sourceRight <= targetCenter.dx - halfSizeLimit) {
              sides = position == 'leftC|topC' ? 'right:top' : 'right:bottom';
            } else if (sourceBottom <= targetCenter.dy - halfSizeLimit) {
              sides = position == 'leftC|topC' ? 'bottom:left' : 'top:left';
            } else {
              sides = 'right:right';
            }
          } else {
            if (sourceBottom <= targetCenter.dy - halfSizeLimit) {
              sides = position == 'leftC|topC' ? 'bottom:left' : 'top:left';
            } else if (sourceRight <= targetCenter.dx - halfSizeLimit) {
              sides = position == 'leftC|topC' ? 'right:top' : 'right:bottom';
            } else {
              sides = 'bottom:bottom';
            }
          }
          break;
        case 'rightC|topC':
        case 'rightC|bottomC':
          if (sourceWidth < sourceHeight) {
            if (sourceLeft > targetCenter.dx + halfSizeLimit) {
              sides = position == 'rightC|topC' ? 'left:top' : 'left:bottom';
            } else if (sourceBottom <= targetCenter.dy - halfSizeLimit) {
              sides = position == 'rightC|topC' ? 'bottom:right' : 'top:right';
            } else {
              sides = 'left:left';
            }
          } else {
            if (sourceBottom <= targetCenter.dy - halfSizeLimit) {
              sides = position == 'rightC|topC' ? 'bottom:right' : 'top:right';
            } else if (sourceLeft > targetCenter.dx - halfSizeLimit) {
              sides = position == 'rightC|topC' ? 'left:top' : 'left:bottom';
            } else {
              sides = 'bottom:bottom';
            }
          }
          break;
        case 'leftC|top':
          sides = sourceBottom <= targetCenter.dy - halfSizeLimit ? 'bottom:left' : 'bottom:bottom';
          break;
        case 'rightC|top':
          sides = sourceBottom <= targetCenter.dy - halfSizeLimit ? 'bottom:right' : 'bottom:bottom';
          break;
        case 'leftC|bottom':
          sides = sourceTop > targetCenter.dy + halfSizeLimit ? 'top:left' : 'top:top';
          break;
        case 'rightC|bottom':
          sides = sourceTop > targetCenter.dy + halfSizeLimit ? 'top:right' : 'top:top';
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

      final sidesNodesList = sides.split(':').take(2).toList();
      String sidesNodes = sidesNodesList.join(':');

      final startConnections = sourceNode.connections;
      final endConnections = targetNode.connections;

      // final startConnectionsCount = startConnections?.length(sidesNodesList[0]) ?? 0;
      // final endConnectionsCount = endConnections?.length(sidesNodesList[1]) ?? 0;

      // if (endConnectionsCount * Connections.discreteness >= targetRect.height) {
      //   if (sidesNodes == 'bottom:right') {
      //     sidesNodes = 'bottom:top';
      //     sides = '$sidesNodes:4';
      //   } else if(sidesNodes == 'right:bottom') {
      //     sidesNodes = 'top:bottom';
      //     sides = '$sidesNodes:4';
      //   }
      // }

      final startConnection = startConnections?.add(sidesNodesList[0], arrow.id, startConnectionPoint);
      final endConnection = endConnections?.add(sidesNodesList[1], arrow.id, endConnectionPoint);

      final startDeltaPos = startConnections?.getSideDelta(sidesNodesList[0], startConnection!) ?? 0;
      final endDeltaPos = endConnections?.getSideDelta(sidesNodesList[1], endConnection!) ?? 0;

      switch (sidesNodes) {
        case 'right:top':
          startConnectionPoint = Offset(sourceRight + arrowIndent, sourceCenter.dy + startDeltaPos);
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetTop - arrowIndent);
          break;
        case 'right:bottom':
          startConnectionPoint = Offset(sourceRight + arrowIndent, sourceCenter.dy + startDeltaPos);
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetBottom + arrowIndent);
          break;
        case 'right:left':
          startConnectionPoint = Offset(sourceRight + arrowIndent, sourceCenter.dy + startDeltaPos);
          endConnectionPoint = Offset(targetLeft - arrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'right:right':
          startConnectionPoint = Offset(sourceRight + arrowIndent, sourceCenter.dy + startDeltaPos);
          endConnectionPoint = Offset(targetRight + arrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'left:top':
          startConnectionPoint = Offset(sourceLeft - arrowIndent, sourceCenter.dy + startDeltaPos);
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetTop - arrowIndent);
          break;
        case 'left:bottom':
          startConnectionPoint = Offset(sourceLeft - arrowIndent, sourceCenter.dy + startDeltaPos);
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetBottom + arrowIndent);
          break;
        case 'left:right':
          startConnectionPoint = Offset(sourceLeft - arrowIndent, sourceCenter.dy + startDeltaPos);
          endConnectionPoint = Offset(targetRight + arrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'left:left':
          startConnectionPoint = Offset(sourceLeft - arrowIndent, sourceCenter.dy + startDeltaPos);
          endConnectionPoint = Offset(targetLeft - arrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'top:bottom':
          startConnectionPoint = Offset(sourceCenter.dx + startDeltaPos, sourceTop - arrowIndent);
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetBottom + arrowIndent);
          break;
        case 'top:right':
          startConnectionPoint = Offset(sourceCenter.dx + startDeltaPos, sourceTop - arrowIndent);
          endConnectionPoint = Offset(targetRight + arrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'top:left':
          startConnectionPoint = Offset(sourceCenter.dx + startDeltaPos, sourceTop - arrowIndent);
          endConnectionPoint = Offset(targetLeft - arrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'top:top':
          startConnectionPoint = Offset(sourceCenter.dx + startDeltaPos, sourceTop - arrowIndent);
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetTop - arrowIndent);
          break;
        case 'bottom:top':
          startConnectionPoint = Offset(sourceCenter.dx + startDeltaPos, sourceBottom + arrowIndent);
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetTop - arrowIndent);
          break;
        case 'bottom:right':
          startConnectionPoint = Offset(sourceCenter.dx + startDeltaPos, sourceBottom + arrowIndent);
          endConnectionPoint = Offset(targetRight + arrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'bottom:left':
          startConnectionPoint = Offset(sourceCenter.dx + startDeltaPos, sourceBottom + arrowIndent);
          endConnectionPoint = Offset(targetLeft - arrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'bottom:bottom':
          startConnectionPoint = Offset(sourceCenter.dx + startDeltaPos, sourceBottom + arrowIndent);
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetBottom + arrowIndent);
          break;
      }

      startConnection!.pos = startConnectionPoint;
      endConnection!.pos = endConnectionPoint;

      return (start: startConnectionPoint, end: endConnectionPoint, sides: sides);
    } catch (e) {
      print('ERROR [_getSidePosition]: $e');
    }
    return (start: Offset.zero, end: Offset.zero, sides: sides);
  }

  /// Получить полный путь стрелки для отрисовки в тайлах
  ({ArrowPaths paths, List<Offset> coordinates}) getArrowPathInTile(
    Arrow arrow,
    Offset baseOffset, {
    bool isNotCalculate = false,
    bool isTiles = false,
  }) {
    // Для рассчитанных путей не считаем - отдаем сразу
    // if (isNotCalculate && arrow.path != null && arrow.coordinates != null) {
    //   return (path: arrow.path!, coordinates: arrow.coordinates!);
    // }

    // Находим эффективные узлы
    final effectiveSourceNode = _getEffectiveNode(arrow.source);
    final effectiveTargetNode = _getEffectiveNode(arrow.target);

    if (effectiveSourceNode == null || effectiveTargetNode == null) {
      return (paths: ArrowPaths(path: Path()), coordinates: []);
    }

    // Получаем абсолютные позиции
    final sourceAbsolutePos = effectiveSourceNode.aPosition ?? (effectiveSourceNode.position + baseOffset);
    final targetAbsolutePos = effectiveTargetNode.aPosition ?? (effectiveTargetNode.position + baseOffset);

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

    effectiveSourceNode.connections?.remove(arrow.id);
    effectiveTargetNode.connections?.remove(arrow.id);

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

    if (baseConnectionPoints.start == null || baseConnectionPoints.end == null) {
      return (paths: ArrowPaths(path: Path()), coordinates: []);
    }

    // Создаем простой ортогональный путь без проверок пересечений
    final basePath = _createSimpleOrthogonalPath(
      arrow,
      baseConnectionPoints.start!,
      baseConnectionPoints.end!,
      sourceRect,
      targetRect,
      baseConnectionPoints.sides!,
      isTiles,
    );

    arrow.paths = basePath.paths;
    arrow.coordinates = basePath.coordinates;
    arrow.sides = baseConnectionPoints.sides;

    return basePath;
  }

  /// Получает путь стрелки с учетом выбранных узлов и текущего масштаба
  ({ArrowPaths paths, List<Offset> coordinates}) getArrowPathWithSelectedNodes(Arrow arrow, Rect arrowsRect) {
    // Создаем простой ортогональный путь в мировых координатах
    final basePath = getArrowPathInTile(arrow, state.delta);

    // Преобразуем путь и координаты в экранные координаты
    return _convertPathToScreenCoordinates(arrow, basePath, arrowsRect);
  }

  /// Преобразует путь из мировых координат в экранные
  ({ArrowPaths paths, List<Offset> coordinates}) _convertPathToScreenCoordinates(
    Arrow arrow,
    ({ArrowPaths paths, List<Offset> coordinates}) worldPath,
    Rect arrowsRect,
  ) {
    final screenCoordinates = <Offset>[];

    // Преобразуем каждую координату
    for (final worldCoord in worldPath.coordinates) {
      final screenCoord = Offset(worldCoord.dx - arrowsRect.left, worldCoord.dy - arrowsRect.top) * state.scale;
      screenCoordinates.add(screenCoord);
    }

    final paths = _createPath(arrow, screenCoordinates, scale: state.scale, isTiles: false, isCurves: state.useCurves);

    return (paths: paths, coordinates: screenCoordinates);
  }

  /// Создание простого ортогонального пути
  ({ArrowPaths paths, List<Offset> coordinates}) _createSimpleOrthogonalPath(
    Arrow arrow,
    Offset start,
    Offset end,
    Rect sourceRect,
    Rect targetRect,
    String sides,
    bool isTiles,
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
        coordinates.add(Offset(start.dx - 60 + dxMin, start.dy));
        coordinates.add(Offset(start.dx - 60 + dxMin, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:right':
        final dxMin = dx > 0 ? dx : 0;
        coordinates.add(Offset(start.dx + 60 + dxMin, start.dy));
        coordinates.add(Offset(start.dx + 60 + dxMin, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:top':
        final dyMin = dy > 0 ? 0 : dy;
        coordinates.add(Offset(start.dx, start.dy - 60 + dyMin));
        coordinates.add(Offset(end.dx, start.dy - 60 + dyMin));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:bottom':
        final dyMin = dy > 0 ? dy : 0;
        coordinates.add(Offset(start.dx, start.dy + 60 + dyMin));
        coordinates.add(Offset(end.dx, start.dy + 60 + dyMin));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'left:top:3':
        final dyUp = min(sourceTop, targetTop) - 60;
        coordinates.add(Offset(start.dx - 60, start.dy));
        coordinates.add(Offset(start.dx - 60, dyUp));
        coordinates.add(Offset(end.dx, dyUp));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:top:3':
        final dyUp = min(sourceTop, targetTop) - 60;
        coordinates.add(Offset(start.dx + 60, start.dy));
        coordinates.add(Offset(start.dx + 60, dyUp));
        coordinates.add(Offset(end.dx, dyUp));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'left:bottom:3':
        final dyDown = max(sourceBottom, targetBottom) + 60;
        coordinates.add(Offset(start.dx - 60, start.dy));
        coordinates.add(Offset(start.dx - 60, dyDown));
        coordinates.add(Offset(end.dx, dyDown));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:bottom:3':
        final dyDown = max(sourceBottom, targetBottom) + 60;
        coordinates.add(Offset(start.dx + 60, start.dy));
        coordinates.add(Offset(start.dx + 60, dyDown));
        coordinates.add(Offset(end.dx, dyDown));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:left:3':
        final dyLeft = min(sourceLeft, targetLeft) - 60;
        coordinates.add(Offset(start.dx, start.dy - 60));
        coordinates.add(Offset(dyLeft, start.dy - 60));
        coordinates.add(Offset(dyLeft, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:left:3':
        final dyLeft = min(sourceLeft, targetLeft) - 60;
        coordinates.add(Offset(start.dx, start.dy + 60));
        coordinates.add(Offset(dyLeft, start.dy + 60));
        coordinates.add(Offset(dyLeft, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:right:3':
        final dyRight = max(sourceRight, targetRight) + 60;
        coordinates.add(Offset(start.dx, start.dy - 60));
        coordinates.add(Offset(dyRight, start.dy - 60));
        coordinates.add(Offset(dyRight, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:right:3':
        final dyRight = max(sourceRight, targetRight) + 60;
        coordinates.add(Offset(start.dx, start.dy + 60));
        coordinates.add(Offset(dyRight, start.dy + 60));
        coordinates.add(Offset(dyRight, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:top:4':
        final dxRight = max(sourceRight, targetRight) + 60;
        coordinates.add(Offset(start.dx, start.dy + 60));
        coordinates.add(Offset(dxRight, start.dy + 60));
        coordinates.add(Offset(dxRight, targetTop - 60));
        coordinates.add(Offset(end.dx, targetTop - 60));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:bottom:4':
        final dxRight = max(sourceRight, targetRight) + 60;
        coordinates.add(Offset(start.dx, start.dy - 60));
        coordinates.add(Offset(dxRight, start.dy - 60));
        coordinates.add(Offset(dxRight, targetBottom + 60));
        coordinates.add(Offset(end.dx, targetBottom + 60));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      default:
        break;
    }

    String direct = sides.split(':')[0];
    final paths = _createPath(arrow, coordinates, direct: direct, isCurves: state.useCurves, isTiles: isTiles);

    return (paths: paths, coordinates: coordinates);
  }

  ArrowPaths _createPath(
    Arrow arrow,
    List<Offset> coordinates, {
    required bool isTiles,
    String? direct,
    double? scale,
    bool isCurves = false,
  }) {
    final path = Path();
    final baseRadius = 10.0 * (scale ?? 1);

    if (coordinates.isEmpty) return ArrowPaths(path: path);

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

    final len = coordinates.length;

    path.moveTo(coordinates.first.dx, coordinates.first.dy);

    for (int i = 1; i < len - 1; i++) {
      final previous = coordinates[i - 1]; // предыдущая точка
      final current = coordinates[i]; // текущая точка
      final next = coordinates[i + 1]; // следующая точка
      // Расчет длин текущего и следующего отрезка
      final dxPrev = previous.dx - current.dx;
      final dyPrev = previous.dy - current.dy;
      final dx = current.dx - next.dx;
      final dy = current.dy - next.dy;
      double offsetCurrent = (dxPrev + dyPrev).abs(); // длина текущего отрезка
      double offsetNext = (dx + dy).abs(); // длина следующего отрезка
      double radius = 0.0;
      if (!isCurves) {
        // Находим минимальный отрезок
        final offset = min(offsetNext, offsetCurrent);
        final maxRadius = offset / 2;
        radius = maxRadius > 1 ? baseRadius.clamp(1.0, maxRadius) : 0;
      } else {
        offsetCurrent = (len == 4 || len == 5) && (i == 2 || i == 4) ? offsetCurrent / 2 : offsetCurrent;
        offsetNext = (len == 4 || len == 5) && (i == 1 || i == 3) ? offsetNext / 2 : offsetNext;
        final offset = min(offsetNext, offsetCurrent);
        radius = offset;
      }
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
      path.arcToPoint(endArcPoint, radius: Radius.circular(radius), largeArc: false, clockwise: clockwise);
    }

    // Добавляем линию к последней точке
    if (len > 1) {
      path.lineTo(coordinates.last.dx, coordinates.last.dy);
    }

    // Добавляем начальную фигуру для targetArrow
    final startArrow = _addStartArrowHead(arrow, coordinates, direct, isTiles);

    // Добавляем конечную фигуру для sourceArrow
    final endArrow = _addEndArrowHead(arrow, coordinates, direct, isTiles);

    return ArrowPaths(path: path, startArrow: startArrow, endArrow: endArrow);
  }

  /// Добавляет фигуру стрелки в начале пути
  Path? _addStartArrowHead(Arrow arrow, List<Offset> coordinates, String? direct, bool isTiles) {
    if (coordinates.length < 2) return null;

    final startPos = coordinates.first;
    final nextPos = coordinates[1];
    final sizeArrow = 8.0 * (isTiles ? 1 : state.scale);

    // Определяем направление от startPos к nextPos
    final direction = Offset(nextPos.dx - startPos.dx, nextPos.dy - startPos.dy);
    final directionLength = sqrt(direction.dx * direction.dx + direction.dy * direction.dy);

    if (directionLength == 0) return null;

    final normalizedDir = Offset(direction.dx / directionLength, direction.dy / directionLength);
    final rotationAngle = atan2(normalizedDir.dy, normalizedDir.dx);

    // Добавляем фигуру в зависимости от targetArrow
    if (arrow.sourceArrow == 'diamondThin' || arrow.sourceArrow == 'diamond') {
      return _addDiamondToPath(
        startPos + normalizedDir * sizeArrow,
        rotationAngle,
        isFilled: arrow.sourceArrow == 'diamondThin',
        isTiles: isTiles,
        size: sizeArrow,
      );
    }
    return null;
  }

  /// Добавляет фигуру стрелки в конце пути
  Path? _addEndArrowHead(Arrow arrow, List<Offset> coordinates, String? direct, bool isTiles) {
    if (coordinates.length < 2) return null;

    final endPos = coordinates.last;
    final prevPos = coordinates[coordinates.length - 2];
    final sizeArrow = 8.0 * (isTiles ? 1 : state.scale);

    // Определяем направление от prevPos к endPos
    final direction = Offset(endPos.dx - prevPos.dx, endPos.dy - prevPos.dy);
    final directionLength = sqrt(direction.dx * direction.dx + direction.dy * direction.dy);

    if (directionLength == 0) return null;

    final normalizedDir = Offset(direction.dx / directionLength, direction.dy / directionLength);
    final rotationAngle = atan2(normalizedDir.dy, normalizedDir.dx);

    // Добавляем фигуру в зависимости от sourceArrow
    if (arrow.targetArrow == 'block') {
      return _addTriangleToPath(endPos - normalizedDir * sizeArrow, rotationAngle, isTiles: isTiles, size: sizeArrow);
    }
    return null;
  }

  /// Добавляет треугольник к пути
  Path _addTriangleToPath(Offset position, double rotationAngle, {required isTiles, double size = 5.0}) {
    final halfSize = size / 2;
    final triangleHeight = size * sqrt(3) / 2; // Высота равностороннего треугольника
    final path = Path();

    // Вершины треугольника (вершина направлена вперед)
    final vertices = [
      Offset(0, -halfSize), // Левая вершина основания
      Offset(0, halfSize), // Правая вершина основания
      Offset(triangleHeight, 0), // Вершина треугольника
    ];

    // Поворачиваем и перемещаем вершины
    final rotatedVertices = vertices.map((vertex) {
      final xRotated = vertex.dx * cos(rotationAngle) - vertex.dy * sin(rotationAngle);
      final yRotated = vertex.dx * sin(rotationAngle) + vertex.dy * cos(rotationAngle);
      return Offset(position.dx + xRotated, position.dy + yRotated);
    }).toList();

    // Добавляем треугольник к пути
    path.moveTo(rotatedVertices[0].dx, rotatedVertices[0].dy);
    path.lineTo(rotatedVertices[1].dx, rotatedVertices[1].dy);
    path.lineTo(rotatedVertices[2].dx, rotatedVertices[2].dy);
    path.close();
    return path;
  }

  /// Добавляет ромб к пути
  Path _addDiamondToPath(
    Offset position,
    double rotationAngle, {
    required isTiles,
    bool isFilled = true,
    double size = 6.0,
  }) {
    final halfSize = size;
    final path = Path();

    // Вершины ромба (длинная диагональ вдоль направления)
    final outerVertices = [
      Offset(0, -halfSize / 2), // Верх
      Offset(halfSize, 0), // Право
      Offset(0, halfSize / 2), // Низ
      Offset(-halfSize, 0), // Лево
    ];

    // Поворачиваем внешние вершины
    final rotatedOuterVertices = outerVertices.map((vertex) {
      final xRotated = vertex.dx * cos(rotationAngle) - vertex.dy * sin(rotationAngle);
      final yRotated = vertex.dx * sin(rotationAngle) + vertex.dy * cos(rotationAngle);
      return Offset(position.dx + xRotated, position.dy + yRotated);
    }).toList();

    // Добавляем внешний ромб
    path.moveTo(rotatedOuterVertices[0].dx, rotatedOuterVertices[0].dy);
    for (int i = 1; i < rotatedOuterVertices.length; i++) {
      path.lineTo(rotatedOuterVertices[i].dx, rotatedOuterVertices[i].dy);
    }
    path.close();
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
      if (parent != null && parent.qType == 'swimlane' && (parent.isCollapsed ?? false)) {
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
