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

    // Определяем точки пути для ортогональной стрелки (только горизонтальные/вертикальные линии)
    final path = _createOrthogonalPath(startPoint, endPoint);

    // Проверяем, не пересекает ли путь другие узлы
    if (_orthogonalPathIntersectsOtherNodes(path, [sourceNode.id, targetNode.id])) {
      return; // Путь пересекает другие узлы, не рисуем стрелку
    }

    // Рисуем линию стрелки
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Добавляем логирование
    debugPrint('Рисование связи ${arrow.id}: начало (${startPoint.dx}, ${startPoint.dy}), конец (${endPoint.dx}, ${endPoint.dy})');

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

  

  /// Проверяет, пересекает ли линия заданный прямоугольник
  bool _lineIntersectsRect(Offset start, Offset end, Rect rect) {
    // Проверяем пересечение отрезка с каждой стороной прямоугольника
    final left = rect.left;
    final right = rect.right;
    final top = rect.top;
    final bottom = rect.bottom;
    
    // Проверяем пересечение с левой стороной
    if (_lineIntersectsLine(start, end, Offset(left, top), Offset(left, bottom))) return true;
    // Проверяем пересечение с правой стороной
    if (_lineIntersectsLine(start, end, Offset(right, top), Offset(right, bottom))) return true;
    // Проверяем пересечение с верхней стороной
    if (_lineIntersectsLine(start, end, Offset(left, top), Offset(right, top))) return true;
    // Проверяем пересечение с нижней стороной
    if (_lineIntersectsLine(start, end, Offset(left, bottom), Offset(right, bottom))) return true;
    
    // Также проверяем, находится ли хотя бы одна точка внутри прямоугольника
    if (_isPointInRect(start, rect) || _isPointInRect(end, rect)) return true;
    
    return false;
  }

  /// Проверяет, пересекаются ли две линии
  bool _lineIntersectsLine(Offset p1, Offset p2, Offset p3, Offset p4) {
    // Формула для определения пересечения двух отрезков
    final denom = (p4.dy - p3.dy) * (p2.dx - p1.dx) - (p4.dx - p3.dx) * (p2.dy - p1.dy);
    
    if (denom == 0) {
      // Линии параллельны
      return false;
    }
    
    final ua = ((p4.dx - p3.dx) * (p1.dy - p3.dy) - (p4.dy - p3.dy) * (p1.dx - p3.dx)) / denom;
    final ub = ((p2.dx - p1.dx) * (p1.dy - p3.dy) - (p2.dy - p1.dy) * (p1.dx - p3.dx)) / denom;
    
    return ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1;
  }

  /// Проверяет, находится ли точка внутри прямоугольника
  bool _isPointInRect(Offset point, Rect rect) {
    return point.dx >= rect.left && point.dx <= rect.right &&
           point.dy >= rect.top && point.dy <= rect.bottom;
  }

  /// Проверяет, пересекает ли ортогональный путь другие узлы
  bool _orthogonalPathIntersectsOtherNodes(Path path, List<String> excludeIds) {
    // Преобразуем путь в список сегментов (пар точек)
    final segments = _getPathSegments(path);
    
    // Проверяем каждый сегмент на пересечение с другими узлами
    for (final segment in segments) {
      if (_segmentIntersectsOtherNodes(segment['start']!, segment['end']!, excludeIds)) {
        return true;
      }
    }
    
    return false;
  }

  /// Извлекает сегменты из пути
  List<Map<String, Offset?>> _getPathSegments(Path path) {
    final segments = <Map<String, Offset?>>[];
    var prevX = 0.0;
    var prevY = 0.0;
    var startX = 0.0;
    var startY = 0.0;
    var firstMove = true;
    
    // Для получения точек из Path мы будем использовать вычисление пути с высокой точностью
    // и анализировать изменения в координатах
    final pathMetrics = path.computeMetrics();
    
    for (final metric in pathMetrics) {
      final pathPoints = _getPathPoints(metric);
      
      for (int i = 0; i < pathPoints.length - 1; i++) {
        final start = pathPoints[i];
        final end = pathPoints[i + 1];
        
        segments.add({
          'start': start,
          'end': end,
        });
      }
    }
    
    return segments;
  }
  
  /// Вспомогательный метод для получения точек из PathMetric
  List<Offset> _getPathPoints(PathMetric metric) {
    final points = <Offset>[];
    final length = metric.length;
    const step = 10.0; // Шаг между точками
    
    for (double distance = 0; distance <= length; distance += step) {
      try {
        final position = metric.getTangentForOffset(distance)?.position;
        if (position != null) {
          points.add(position);
        }
      } catch (e) {
        // Пропускаем ошибки при получении точки
      }
    }
    
    return points;
  }

  /// Проверяет, пересекает ли сегмент другие узлы
  bool _segmentIntersectsOtherNodes(Offset start, Offset end, List<String> excludeIds) {
    // Простая проверка: проверяем пересечение с границами других узлов
    for (final node in nodes) {
      if (excludeIds.contains(node.id)) continue; // Пропускаем исключенные узлы
      
      // Получаем границы узла
      final nodeRect = nodeBoundsCache[node] ?? 
          Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);
          
      // Проверяем пересечение сегмента от start до end с прямоугольником узла
      if (_lineIntersectsRect(start, end, nodeRect)) {
        return true;
      }
    }
    return false;
  }

  /// Создание ортогонального пути (только горизонтальные/вертикальные линии)
  Path _createOrthogonalPath(Offset start, Offset end) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Вычисляем промежуточные точки для ортогонального соединения
    // Учитываем требование минимум 20 пикселей для начального и конечного отрезков
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Определяем направление для начального отрезка
    if (dx.abs() > 20 && dy.abs() > 20) {
      // Если оба направления больше 20 пикселей, создаем Z-образный путь
      // Сначала делаем отступ от начальной точки, затем от конечной
      final startOffsetX = start.dx + (dx > 0 ? 20 : -20);
      final startOffsetY = start.dy + (dy > 0 ? 20 : -20);
      final endOffsetX = end.dx - (dx > 0 ? 20 : -20);
      final endOffsetY = end.dy - (dy > 0 ? 20 : -20);
      
      // Проверяем, чтобы начальный и конечный отрезки не пересекались
      if ((dx > 0 && startOffsetX < endOffsetX) || (dx <= 0 && startOffsetX > endOffsetX)) {
        // Рисуем путь: начальная точка -> начальный отступ -> конечный отступ -> конечная точка
        path.lineTo(startOffsetX, start.dy);  // Первый отрезок от начала
        path.lineTo(startOffsetX, end.dy);    // Вертикаль к конечной точке
        path.lineTo(end.dx, end.dy);          // Завершаем до конечной точки
      } else if ((dy > 0 && startOffsetY < endOffsetY) || (dy <= 0 && startOffsetY > endOffsetY)) {
        // Альтернативный путь если X-координаты пересеклись
        path.lineTo(start.dx, startOffsetY);  // Первый отрезок от начала
        path.lineTo(end.dx, startOffsetY);    // Горизонталь к конечной точке
        path.lineTo(end.dx, end.dy);          // Завершаем до конечной точки
      } else {
        // Если оба направления пересекаются, используем среднюю точку
        final midX = start.dx + dx / 2;
        final midY = start.dy + dy / 2;
        
        path.lineTo(midX, start.dy);  // Горизонтальный отрезок от начала
        path.lineTo(midX, end.dy);    // Вертикальный отрезок к концу
        path.lineTo(end.dx, end.dy);  // Горизонтальный отрезок до конечной точки
      }
    } else if (dx.abs() <= 20 && dy.abs() > 20) {
      // Горизонтальное расстояние мало, сначала вертикальный отрезок
      final startOffsetY = start.dy + (dy > 0 ? 20 : -20);
      final endOffsetY = end.dy - (dy > 0 ? 20 : -20);
      
      if ((dy > 0 && startOffsetY < endOffsetY) || (dy <= 0 && startOffsetY > endOffsetY)) {
        // Начинаем с вертикального отрезка, затем горизонтальный, затем завершаем вертикаль
        path.lineTo(start.dx, startOffsetY);  // Начальный вертикальный отрезок
        path.lineTo(end.dx, startOffsetY);    // Переход к конечной точке по горизонтали
        path.lineTo(end.dx, end.dy);          // Завершение вертикального отрезка
      } else {
        // Если отрезки пересекаются, просто используем прямую линию
        path.lineTo(start.dx, (start.dy + end.dy) / 2); // К средней точке по Y
        path.lineTo(end.dx, (start.dy + end.dy) / 2);   // К средней точке по X
        path.lineTo(end.dx, end.dy);                    // Завершаем
      }
    } else if (dx.abs() > 20 && dy.abs() <= 20) {
      // Вертикальное расстояние мало, сначала горизонтальный отрезок
      final startOffsetX = start.dx + (dx > 0 ? 20 : -20);
      final endOffsetX = end.dx - (dx > 0 ? 20 : -20);
      
      if ((dx > 0 && startOffsetX < endOffsetX) || (dx <= 0 && startOffsetX > endOffsetX)) {
        // Начинаем с горизонтального отрезка, затем вертикальный, затем завершаем горизонталь
        path.lineTo(startOffsetX, start.dy);  // Начальный горизонтальный отрезок
        path.lineTo(startOffsetX, end.dy);    // Переход к конечной точке по вертикали
        path.lineTo(end.dx, end.dy);          // Завершение горизонтального отрезка
      } else {
        // Если отрезки пересекаются, просто используем прямую линию
        path.lineTo((start.dx + end.dx) / 2, start.dy); // К средней точке по X
        path.lineTo((start.dx + end.dx) / 2, end.dy);   // К средней точке по Y
        path.lineTo(end.dx, end.dy);                    // Завершаем
      }
    } else {
      // Оба расстояния малы, создаем путь с отступами в любом случае
      // Определяем, какой отрезок рисовать первым
      if (dx.abs() >= dy.abs()) {
        // Горизонтальный отрезок первым
        final startOffsetX = start.dx + (dx > 0 ? 20 : -20);
        final endOffsetX = end.dx - (dx > 0 ? 20 : -20);
        
        if ((dx > 0 && startOffsetX < endOffsetX) || (dx <= 0 && startOffsetX > endOffsetX)) {
          path.lineTo(startOffsetX, start.dy);             // Начальный горизонтальный отрезок
          path.lineTo(startOffsetX, (start.dy + end.dy) / 2); // Вертикаль к средней точке
          path.lineTo(endOffsetX, (start.dy + end.dy) / 2);   // Горизонталь к конечной точке
          path.lineTo(endOffsetX, end.dy);                 // Вертикаль к конечной точке
          path.lineTo(end.dx, end.dy);                     // Завершаем
        } else {
          // Если горизонтальные отрезки пересекаются, используем вертикальный путь
          path.lineTo(start.dx, start.dy + (dy > 0 ? 20 : -20)); // Начальный вертикальный отрезок
          path.lineTo((start.dx + end.dx) / 2, start.dy + (dy > 0 ? 20 : -20)); // Горизонталь к средней точке
          path.lineTo((start.dx + end.dx) / 2, end.dy + (dy > 0 ? -20 : 20));   // Вертикаль к конечной точке
          path.lineTo(end.dx, end.dy + (dy > 0 ? -20 : 20));                   // Горизонталь к конечной точке
          path.lineTo(end.dx, end.dy);                                         // Завершаем
        }
      } else {
        // Вертикальный отрезок первым
        final startOffsetY = start.dy + (dy > 0 ? 20 : -20);
        final endOffsetY = end.dy - (dy > 0 ? 20 : -20);
        
        if ((dy > 0 && startOffsetY < endOffsetY) || (dy <= 0 && startOffsetY > endOffsetY)) {
          path.lineTo(start.dx, startOffsetY);             // Начальный вертикальный отрезок
          path.lineTo((start.dx + end.dx) / 2, startOffsetY); // Горизонталь к средней точке
          path.lineTo((start.dx + end.dx) / 2, endOffsetY);   // Вертикаль к конечной точке
          path.lineTo(end.dx, endOffsetY);                 // Горизонталь к конечной точке
          path.lineTo(end.dx, end.dy);                     // Завершаем
        } else {
          // Если вертикальные отрезки пересекаются, используем горизонтальный путь
          path.lineTo(start.dx + (dx > 0 ? 20 : -20), start.dy); // Начальный горизонтальный отрезок
          path.lineTo(start.dx + (dx > 0 ? 20 : -20), (start.dy + end.dy) / 2); // Вертикаль к средней точке
          path.lineTo(end.dx + (dx > 0 ? -20 : 20), (start.dy + end.dy) / 2);   // Горизонталь к конечной точке
          path.lineTo(end.dx + (dx > 0 ? -20 : 20), end.dy);                   // Вертикаль к конечной точке
          path.lineTo(end.dx, end.dy);                                         // Завершаем
        }
      }
    }

    return path;
  }
}