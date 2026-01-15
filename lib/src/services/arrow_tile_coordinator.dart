import 'dart:ui';
import 'package:flutter/material.dart';
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
  Path getArrowPathForTiles(Arrow arrow, Offset baseOffset) {
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

    // Вычисляем точки соединения (упрощенная версия без распределения)
    final connectionPoints = arrowManager.calculateConnectionPointsForSideCalculation(
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
    );
  }

  /// Создание простого ортогонального пути
  Path _createSimpleOrthogonalPath(
    Offset start,
    Offset end,
    Rect sourceRect,
    Rect targetRect,
  ) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Простой путь с одним поворотом
    if (dx.abs() > dy.abs()) {
      // Сначала по горизонтали, потом по вертикали
      path.lineTo(end.dx, start.dy);
      path.lineTo(end.dx, end.dy);
    } else {
      // Сначала по вертикали, потом по горизонтали
      path.lineTo(start.dx, end.dy);
      path.lineTo(end.dx, end.dy);
    }

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

  /// Проверяет, пересекает ли путь тайл
  bool doesArrowIntersectTile(Arrow arrow, Rect tileBounds, Offset baseOffset) {
    final path = getArrowPathForTiles(arrow, baseOffset);
    if (path.getBounds().isEmpty) return false;

    // Более точная проверка пересечения с использованием PathMetrics
    // для лучшего определения пересечений с тайлами
    final pathMetrics = path.computeMetrics();
    
    for (final metric in pathMetrics) {
      final pathLength = metric.length;
      // Проверяем несколько точек вдоль пути
      for (double t = 0; t <= pathLength; t += pathLength / 10) {
        try {
          final point = metric.getTangentForOffset(t)?.position;
          if (point != null && tileBounds.contains(point)) {
            return true;
          }
        } catch (e) {
          // Если не удалось получить точку, продолжаем
          continue;
        }
      }
    }

    // Резервная проверка через bounds
    return path.getBounds().overlaps(tileBounds);
  }
}
