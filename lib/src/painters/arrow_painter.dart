import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/table.node.dart';
import '../models/arrow.dart';

/// Универсальный класс для отрисовки Arrow
class ArrowPainter {
  final Arrow arrow;
  final List<TableNode> nodes;
  final Map<TableNode, Rect> nodeBoundsCache;

  ArrowPainter({
    required this.arrow,
    required this.nodes,
    required this.nodeBoundsCache,
  });

  /// Отрисовка стрелки с учетом базового отступа
  void paintWithOffset({
    required Canvas canvas,
    required Offset baseOffset,
    required Rect visibleBounds,
    bool forTile = false,
  }) {
    // Находим узлы-источник и цель
    final sourceNode = _findNodeById(arrow.source);
    final targetNode = _findNodeById(arrow.target);

    if (sourceNode == null || targetNode == null) {
      return; // Не можем нарисовать стрелку без обоих узлов
    }

    // Получаем абсолютные позиции узлов
    final sourceAbsolutePos = sourceNode.aPosition ?? (sourceNode.position + baseOffset);
    final targetAbsolutePos = targetNode.aPosition ?? (targetNode.position + baseOffset);

    // Создаем Rect для узлов в мировых координатах
    final sourceRect = Rect.fromPoints(
      sourceAbsolutePos,
      Offset(
        sourceAbsolutePos.dx + sourceNode.size.width,
        sourceAbsolutePos.dy + sourceNode.size.height,
      ),
    );

    final targetRect = Rect.fromPoints(
      targetAbsolutePos,
      Offset(
        targetAbsolutePos.dx + targetNode.size.width,
        targetAbsolutePos.dy + targetNode.size.height,
      ),
    );

    // Проверяем видимость стрелки (если хотя бы один узел видим, то рисуем стрелку)
    final isSourceVisible = sourceRect.overlaps(visibleBounds.inflate(100.0));
    final isTargetVisible = targetRect.overlaps(visibleBounds.inflate(100.0));

    if (!isSourceVisible && !isTargetVisible) {
      return; // Ни один из узлов не видим, не рисуем стрелку
    }

    // Рисуем стрелку
    _drawArrow(
      canvas: canvas,
      sourceRect: sourceRect,
      targetRect: targetRect,
      sourceNode: sourceNode,
      targetNode: targetNode,
      forTile: forTile,
    );
  }

  /// Поиск узла по ID
  TableNode? _findNodeById(String id) {
    return nodes.firstWhereOrNull((node) => node.id == id);
  }

  /// Рисование стрелки
  void _drawArrow({
    required Canvas canvas,
    required Rect sourceRect,
    required Rect targetRect,
    required TableNode sourceNode,
    required TableNode targetNode,
    required bool forTile,
  }) {
    // Находим точки соединения стрелки
    final connectionPoints = _calculateConnectionPoints(sourceRect, targetRect, sourceNode, targetNode);
    
    if (connectionPoints.start == null || connectionPoints.end == null) {
      return; // Не удалось найти подходящие точки соединения
    }

    final startPoint = connectionPoints.start!;
    final endPoint = connectionPoints.end!;

    // Рисуем линию стрелки
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Определяем точки пути для ортогональной стрелки (только горизонтальные/вертикальные линии)
    final path = _createOrthogonalPath(startPoint, endPoint);

    canvas.drawPath(path, paint);
  }

  /// Расчет точек соединения для стрелки
  ({Offset? end, Offset? start}) _calculateConnectionPoints(Rect sourceRect, Rect targetRect, TableNode sourceNode, TableNode targetNode) {
    // Определяем, являются ли объекты атрибутами (узлы с маленькими размерами)
    final isSourceAttribute = sourceNode.size.width <= 40 || sourceNode.size.height <= 20;
    final isTargetAttribute = targetNode.size.width <= 40 || targetNode.size.height <= 20;

    // Находим центральные точки сторон для обоих узлов
    Offset? startConnectionPoint;
    Offset? endConnectionPoint;

    if (isSourceAttribute) {
      // Для атрибутов используем только левую или правую сторону
      if ((sourceRect.center.dx < targetRect.center.dx)) {
        // Источник слева от цели - используем правую сторону
        startConnectionPoint = Offset(sourceRect.right, sourceRect.center.dy);
      } else {
        // Источник справа от цели - используем левую сторону
        startConnectionPoint = Offset(sourceRect.left, sourceRect.center.dy);
      }
    } else {
      // Для обычных узлов используем все четыре стороны, с отступом 6
      startConnectionPoint = _getClosestSideCenter(sourceRect, targetRect, offset: 6);
    }

    if (isTargetAttribute) {
      // Для атрибутов используем только левую или правую сторону
      if ((targetRect.center.dx < sourceRect.center.dx)) {
        // Цель слева от источника - используем правую сторону
        endConnectionPoint = Offset(targetRect.right, targetRect.center.dy);
      } else {
        // Цель справа от источника - используем левую сторону
        endConnectionPoint = Offset(targetRect.left, targetRect.center.dy);
      }
    } else {
      // Для обычных узлов используем все четыре стороны, с отступом 6
      endConnectionPoint = _getClosestSideCenter(targetRect, sourceRect, offset: 6);
    }

    return (start: startConnectionPoint, end: endConnectionPoint);
  }

  /// Находит центр ближайшей стороны одного прямоугольника к другому
  Offset _getClosestSideCenter(Rect rect, Rect otherRect, {double offset = 0}) {
    final centerPoints = {
      'top': Offset(rect.center.dx, rect.top - offset),
      'bottom': Offset(rect.center.dx, rect.bottom + offset),
      'left': Offset(rect.left - offset, rect.center.dy),
      'right': Offset(rect.right + offset, rect.center.dy),
    };

    // Определяем, какие стороны могут быть использованы в зависимости от положения otherRect
    List<String> possibleSides = ['top', 'bottom', 'left', 'right'];
    
    // Определяем, какая сторона ближе к otherRect
    Offset? closestPoint;
    double minDistance = double.infinity;

    for (final side in possibleSides) {
      final point = centerPoints[side]!;
      final distance = (point - otherRect.center).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    }

    return closestPoint ?? Offset(rect.center.dx, rect.top + offset); // fallback to top center
  }

  /// Создание ортогонального пути (только горизонтальные/вертикальные линии)
  Path _createOrthogonalPath(Offset start, Offset end) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Вычисляем промежуточные точки для ортогонального соединения
    // Используем L-образный путь с возможностью Z-образного, если нужно
    
    // Определяем разницу координат
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Для простоты используем L-образный путь: горизонталь -> вертикаль или вертикаль -> горизонталь
    // Выберем, что использовать, исходя из направления
    if (dx.abs() > dy.abs()) {
      // Горизонтальное расстояние больше, сначала рисуем горизонтальную линию
      path.lineTo(end.dx, start.dy);
      path.lineTo(end.dx, end.dy);
    } else {
      // Вертикальное расстояние больше, сначала рисуем вертикальную линию
      path.lineTo(start.dx, end.dy);
      path.lineTo(end.dx, end.dy);
    }

    return path;
  }
}