import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/table.node.dart';
import '../models/arrow.dart';

class ArrowTileCoordinator {
  final List<Arrow> arrows;
  final List<TableNode> nodes;
  final Map<TableNode, Rect> nodeBoundsCache;

  ArrowTileCoordinator({
    required this.arrows,
    required this.nodes,
    required this.nodeBoundsCache,
  });

  /// Получить полный путь стрелки для отрисовки в тайлах
  Path getArrowPathForTiles(
    Arrow arrow,
    Offset baseOffset,
  ) {
    // Находим эффективные узлы
    final effectiveSourceNode = _getEffectiveNode(arrow.source);
    final effectiveTargetNode = _getEffectiveNode(arrow.target);

    if (effectiveSourceNode == null || effectiveTargetNode == null) {
      return Path();
    }

    // Получаем абсолютные позиции
    final sourceAbsolutePos = effectiveSourceNode.aPosition ?? 
        (effectiveSourceNode.position + baseOffset);
    final targetAbsolutePos = effectiveTargetNode.aPosition ?? 
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
    final connectionPoints = _calculateSimpleConnectionPoints(
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

  /// Упрощенный расчет точек соединения (без распределения по сторонам)
  ({Offset? start, Offset? end}) _calculateSimpleConnectionPoints(
    Rect sourceRect,
    Rect targetRect,
    TableNode sourceNode,
    TableNode targetNode,
  ) {
    final sourceCenter = sourceRect.center;
    final targetCenter = targetRect.center;

    final dx = targetCenter.dx - sourceCenter.dx;
    final dy = targetCenter.dy - sourceCenter.dy;

    Offset? startPoint;
    Offset? endPoint;

    // Простая логика определения сторон
    if (dx.abs() >= dy.abs()) {
      // Горизонтальное направление
      if (dx > 0) {
        startPoint = Offset(sourceRect.right, sourceCenter.dy);
        endPoint = Offset(targetRect.left, targetCenter.dy);
      } else {
        startPoint = Offset(sourceRect.left, sourceCenter.dy);
        endPoint = Offset(targetRect.right, targetCenter.dy);
      }
    } else {
      // Вертикальное направление
      if (dy > 0) {
        startPoint = Offset(sourceCenter.dx, sourceRect.bottom);
        endPoint = Offset(targetCenter.dx, targetRect.top);
      } else {
        startPoint = Offset(sourceCenter.dx, sourceRect.top);
        endPoint = Offset(targetCenter.dx, targetRect.bottom);
      }
    }

    // Добавляем небольшой отступ (6 пикселей)
    startPoint = Offset(
      startPoint.dx + (dx > 0 ? 6 : -6), 
      startPoint.dy + (dy > 0 ? 0 : 0)
    );
    endPoint = Offset(
      endPoint.dx + (dx > 0 ? -6 : 6), 
      endPoint.dy + (dy > 0 ? 0 : 0)
    );

    return (start: startPoint, end: endPoint);
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
    
    return path.getBounds().overlaps(tileBounds);
  }
}