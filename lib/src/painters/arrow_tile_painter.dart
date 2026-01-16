import 'package:flutter/material.dart';
import '../models/table.node.dart';
import '../models/arrow.dart';
import '../services/arrow_manager.dart';

class ArrowTilePainter {
  final List<Arrow> arrows;
  final List<TableNode> nodes;
  final Map<TableNode, Rect> nodeBoundsCache;
  late final ArrowManager arrowManager;

  ArrowTilePainter({
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

  void drawArrowsInTile({
    required Canvas canvas,
    required Rect tileBounds,
    required Offset baseOffset,
  }) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Рисуем все стрелки, которые пересекают этот тайл
    for (final arrow in arrows) {
      // Проверяем, пересекает ли стрелка этот тайл
      if (_doesArrowIntersectTile(arrow, tileBounds, baseOffset)) {
        // Получаем полный путь стрелки
        final path = _getArrowPathForTile(arrow, baseOffset);
        
        // Рисуем путь (автоматически обрежется по границам тайла)
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Получить путь стрелки для отрисовки в тайле
  Path _getArrowPathForTile(Arrow arrow, Offset baseOffset) {
    // Находим эффективные узлы
    final effectiveSourceNode = _getEffectiveNode(arrow.source);
    final effectiveTargetNode = _getEffectiveNode(arrow.target);

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
    final connectionPoints = arrowManager
        .calculateConnectionPointsForSideCalculation(
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

  /// Проверяет, пересекает ли стрелка определенный тайл
  bool _doesArrowIntersectTile(Arrow arrow, Rect tileBounds, Offset baseOffset) {
    // Находим эффективные узлы
    final effectiveSourceNode = _getEffectiveNode(arrow.source);
    final effectiveTargetNode = _getEffectiveNode(arrow.target);

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
    final connectionPoints = arrowManager
        .calculateConnectionPointsForSideCalculation(
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

  // Статический метод для получения стрелок для тайла
  static List<Arrow> getArrowsForTile({
    required Rect tileBounds,
    required List<Arrow> allArrows,
    required List<TableNode> allNodes,
    required Map<TableNode, Rect> nodeBoundsCache,
    Offset baseOffset = Offset.zero,
  }) {
    final arrowsInTile = <Arrow>[];
    final arrowManager = ArrowManager(
      arrows: allArrows,
      nodes: allNodes,
      nodeBoundsCache: nodeBoundsCache,
    );

    for (final arrow in allArrows) {
      // Используем менеджер для проверки пересечения
      if (arrowManager._doesArrowIntersectTile(arrow, tileBounds, baseOffset)) {
        arrowsInTile.add(arrow);
      }
    }

    return arrowsInTile;
  }
}