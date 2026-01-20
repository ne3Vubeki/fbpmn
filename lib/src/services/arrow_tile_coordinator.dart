import 'dart:ui';
import '../models/table.node.dart';
import '../models/arrow.dart';
import 'arrow_manager.dart';

class ArrowTileCoordinator {
  final List<Arrow> arrows;
  final List<TableNode> nodes;
  final Map<TableNode, Rect> nodeBoundsCache;
  late ArrowManager arrowManager;

  ArrowTileCoordinator({
    required this.arrows,
    required this.nodes,
    required this.nodeBoundsCache,
  }) {
    arrowManager = ArrowManager(
      arrows: arrows,
      nodes: nodes,
      nodeBoundsCache: nodeBoundsCache,
    );
  }

  /// Получить полный путь стрелки для отрисовки в тайлах
  ({Path path, List<Offset> coordinates}) getArrowPathForTiles(Arrow arrow, Offset baseOffset) {
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
    final connectionPoints = arrowManager
        .calculateConnectionPointsForSideCalculation(
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
    void lineToCoordinates(dx, dy) {
      path.lineTo(dx, dy);
      coordinates.add(Offset(dx, dy));
    }

    path.moveTo(start.dx, start.dy);
    coordinates.add(Offset(start.dx, start.dy));

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dx2 = dx.abs() / 2;
    final dy2 = dy.abs() / 2;

    switch (sides) {
      case 'left:right':
        if (dy2 != 0) {
          lineToCoordinates(start.dx - dx2, start.dy);
          lineToCoordinates(start.dx - dx2, end.dy);
          lineToCoordinates(end.dx, end.dy);
        } else {
          lineToCoordinates(end.dx, end.dy);
        }
        break;
      case 'right:left':
        if (dy2 != 0) {
          lineToCoordinates(start.dx + dx2, start.dy);
          lineToCoordinates(start.dx + dx2, end.dy);
          lineToCoordinates(end.dx, end.dy);
        } else {
          lineToCoordinates(end.dx, end.dy);
        }
        break;
      case 'top:bottom':
        if (dx2 != 0) {
          lineToCoordinates(start.dx, start.dy - dy2);
          lineToCoordinates(end.dx, start.dy - dy2);
          lineToCoordinates(end.dx, end.dy);
        } else {
          lineToCoordinates(end.dx, end.dy);
        }
        break;
      case 'bottom:top':
        if (dx2 != 0) {
          lineToCoordinates(start.dx, start.dy + dy2);
          lineToCoordinates(end.dx, start.dy + dy2);
          lineToCoordinates(end.dx, end.dy);
        } else {
          lineToCoordinates(end.dx, end.dy);
        }
        break;
      case 'left:top':
      case 'right:top':
      case 'left:bottom':
      case 'right:bottom':
        lineToCoordinates(end.dx, start.dy);
        lineToCoordinates(end.dx, end.dy);
        break;
      case 'top:left':
      case 'top:right':
      case 'bottom:left':
      case 'bottom:right':
        lineToCoordinates(start.dx, end.dy);
        lineToCoordinates(end.dx, end.dy);
        break;
    }

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
