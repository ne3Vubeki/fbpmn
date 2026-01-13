import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;

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
    Path? path = _createOrthogonalPath(startPoint, endPoint);

    // Проверяем, не пересекает ли путь другие узлы
    if (_orthogonalPathIntersectsOtherNodes(path, [sourceNode.id, targetNode.id])) {
      // Если путь пересекает другие узлы, пытаемся найти обходной путь
      path = _createBypassPath(startPoint, endPoint, [sourceNode.id, targetNode.id]);
      
      // Если обходной путь также пересекает узлы, не рисуем стрелку
      if (path != null && _orthogonalPathIntersectsOtherNodes(path, [sourceNode.id, targetNode.id])) {
        return; // Путь пересекает другие узлы даже после попытки обхода
      }
    }

    // Если обходной путь не удалось найти, не рисуем стрелку
    if (path == null) {
      return;
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
      if (targetRect.center.dx < sourceRect.center.dx) {
        // Цель слева от источника - используем левую сторону
        startConnectionPoint = Offset(sourceRect.left, sourceRect.center.dy);
      } else {
        // Цель справа от источника - используем правую сторону
        startConnectionPoint = Offset(sourceRect.right, sourceRect.center.dy);
      }
    } else {
      // Для обычных узлов используем все четыре стороны, с отступом 6
      startConnectionPoint = _getClosestSideCenter(sourceRect, targetRect, offset: 6);
    }

    if (isTargetAttribute) {
      // Для атрибутов используем только левую или правую сторону
      if (sourceRect.center.dx < targetRect.center.dx) {
        // Источник слева от цели - используем левую сторону
        endConnectionPoint = Offset(targetRect.left, targetRect.center.dy);
      } else {
        // Источник справа от цели - используем правую сторону
        endConnectionPoint = Offset(targetRect.right, targetRect.center.dy);
      }
    } else {
      // Для обычных узлов используем все четыре стороны, с отступом 6
      endConnectionPoint = _getClosestSideCenter(targetRect, sourceRect, offset: 6);
    }

    return (start: startConnectionPoint, end: endConnectionPoint);
  }

  /// Находит центр ближайшей стороны одного прямоугольника к другому
  Offset _getClosestSideCenter(Rect rect, Rect otherRect, {double offset = 0}) {
    // Определяем расстояния до центра otherRect от каждой из сторон rect
    final distances = {
      'top': (Offset(rect.center.dx, rect.top) - otherRect.center).distance,
      'bottom': (Offset(rect.center.dx, rect.bottom) - otherRect.center).distance,
      'left': (Offset(rect.left, rect.center.dy) - otherRect.center).distance,
      'right': (Offset(rect.right, rect.center.dy) - otherRect.center).distance,
    };

    // Находим сторону с минимальным расстоянием
    String closestSide = 'top';
    double minDistance = distances['top']!;
    
    for (final entry in distances.entries) {
      if (entry.value < minDistance) {
        minDistance = entry.value;
        closestSide = entry.key;
      }
    }

    // Возвращаем точку с учетом отступа
    switch (closestSide) {
      case 'top':
        return Offset(rect.center.dx, rect.top - offset);
      case 'bottom':
        return Offset(rect.center.dx, rect.bottom + offset);
      case 'left':
        return Offset(rect.left - offset, rect.center.dy);
      case 'right':
        return Offset(rect.right + offset, rect.center.dy);
      default:
        return Offset(rect.center.dx, rect.top - offset); // fallback to top
    }
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

  /// Создание обходного пути при наличии пересечений
  Path? _createBypassPath(Offset start, Offset end, List<String> excludeIds) {
    // Ищем возможные обходные пути, обходя узлы по кратчайшему пути
    // Проверяем обход сверху, снизу, слева и справа от препятствий
    
    // Сначала найдем все узлы, которые пересекаются с прямым путем
    final intersectingNodes = _findIntersectingNodes(start, end, excludeIds);
    
    if (intersectingNodes.isEmpty) {
      // Если нет пересекающихся узлов, используем стандартный путь
      return _createOrthogonalPath(start, end);
    }
    
    // Попробуем несколько вариантов обхода:
    // 1. Обход через среднюю точку с отклонением вверх/вниз
    // 2. Обход через среднюю точку с отклонением влево/вправо
    // 3. Обход по внешней стороне препятствия
    
    final pathsToTry = <Path>[];
    
    // Вариант 1: горизонтальный путь с вертикальным отклонением
    Path horizontalPath = Path();
    horizontalPath.moveTo(start.dx, start.dy);
    
    // Найдем среднюю X координату
    final midX = (start.dx + end.dx) / 2;
    
    horizontalPath.lineTo(midX, start.dy);
    horizontalPath.lineTo(midX, end.dy);
    horizontalPath.lineTo(end.dx, end.dy);
    
    pathsToTry.add(horizontalPath);
    
    // Вариант 2: вертикальный путь с горизонтальным отклонением
    Path verticalPath = Path();
    verticalPath.moveTo(start.dx, start.dy);
    
    // Найдем среднюю Y координату
    final midY = (start.dy + end.dy) / 2;
    
    verticalPath.lineTo(start.dx, midY);
    verticalPath.lineTo(end.dx, midY);
    verticalPath.lineTo(end.dx, end.dy);
    
    pathsToTry.add(verticalPath);
    
    // Проверим стандартные пути на наличие пересечений
    for (final path in pathsToTry) {
      if (!_orthogonalPathIntersectsOtherNodes(path, excludeIds)) {
        return path; // Нашли путь без пересечений
      }
    }
    
    // Если стандартные пути не работают, пробуем пути с отклонениями
    final bypassPaths = <Path>[];
    
    // Найдем границы пересекающихся узлов для определения отклонений
    double topBoundary = double.infinity;
    double bottomBoundary = double.negativeInfinity;
    double leftBoundary = double.infinity;
    double rightBoundary = double.negativeInfinity;
    
    for (final node in intersectingNodes) {
      final nodeRect = nodeBoundsCache[node] ?? 
          Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);
      
      topBoundary = math.min(topBoundary, nodeRect.top);
      bottomBoundary = math.max(bottomBoundary, nodeRect.bottom);
      leftBoundary = math.min(leftBoundary, nodeRect.left);
      rightBoundary = math.max(rightBoundary, nodeRect.right);
    }
    
    // Вариант 3: отклонение над препятствиями
    Path abovePath = Path();
    abovePath.moveTo(start.dx, start.dy);
    
    // Выберем Y координату выше всех препятствий
    final aboveY = topBoundary - 40; // Отступ в 40 пикселей над препятствиями
    
    // Путь: начальная точка -> средняя точка по X на уровне старта -> выше препятствий -> на уровень конца -> в конечную точку
    abovePath.lineTo(midX, start.dy);  // Горизонтальный отрезок к середине
    abovePath.lineTo(midX, aboveY);    // Вертикаль вверх
    abovePath.lineTo(midX, end.dy);    // Вертикаль вниз до уровня конца
    abovePath.lineTo(end.dx, end.dy);  // Горизонтальный отрезок к концу
    
    bypassPaths.add(abovePath);
    
    // Вариант 4: отклонение под препятствиями
    Path belowPath = Path();
    belowPath.moveTo(start.dx, start.dy);
    
    // Выберем Y координату ниже всех препятствий
    final belowY = bottomBoundary + 40; // Отступ в 40 пикселей под препятствиями
    
    belowPath.lineTo(midX, start.dy);  // Горизонтальный отрезок к середине
    belowPath.lineTo(midX, belowY);    // Вертикаль вниз
    belowPath.lineTo(midX, end.dy);    // Вертикаль вверх до уровня конца
    belowPath.lineTo(end.dx, end.dy);  // Горизонтальный отрезок к концу
    
    bypassPaths.add(belowPath);
    
    // Вариант 5: отклонение слева от препятствий
    Path leftPath = Path();
    leftPath.moveTo(start.dx, start.dy);
    
    // Выберем X координату левее всех препятствий
    final leftX = leftBoundary - 40; // Отступ в 40 пикселей слева от препятствий
    
    leftPath.lineTo(start.dx, midY);  // Вертикальный отрезок к середине
    leftPath.lineTo(leftX, midY);     // Горизонталь влево
    leftPath.lineTo(end.dx, midY);    // Горизонталь вправо до уровня конца
    leftPath.lineTo(end.dx, end.dy);  // Вертикальный отрезок к концу
    
    bypassPaths.add(leftPath);
    
    // Вариант 6: отклонение справа от препятствий
    Path rightPath = Path();
    rightPath.moveTo(start.dx, start.dy);
    
    // Выберем X координату правее всех препятствий
    final rightX = rightBoundary + 40; // Отступ в 40 пикселей справа от препятствий
    
    rightPath.lineTo(start.dx, midY);  // Вертикальный отрезок к середине
    rightPath.lineTo(rightX, midY);    // Горизонталь вправо
    rightPath.lineTo(end.dx, midY);    // Горизонталь влево до уровня конца
    rightPath.lineTo(end.dx, end.dy);  // Вертикальный отрезок к концу
    
    bypassPaths.add(rightPath);
    
    // Проверим обходные пути на наличие пересечений
    for (final path in bypassPaths) {
      if (!_orthogonalPathIntersectsOtherNodes(path, excludeIds)) {
        return path; // Нашли обходной путь без пересечений
      }
    }
    
    // Если ни один из путей не подходит, возвращаем null
    return null;
  }

  /// Находит узлы, которые пересекаются с прямым путем между двумя точками
  List<TableNode> _findIntersectingNodes(Offset start, Offset end, List<String> excludeIds) {
    final intersectingNodes = <TableNode>[];
    
    for (final node in nodes) {
      if (excludeIds.contains(node.id)) continue; // Пропускаем исключенные узлы
      
      // Получаем границы узла
      final nodeRect = nodeBoundsCache[node] ?? 
          Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);
          
      // Проверяем пересечение прямой линии от start до end с прямоугольником узла
      if (_lineIntersectsRect(start, end, nodeRect)) {
        intersectingNodes.add(node);
      }
    }
    
    return intersectingNodes;
  }

  /// Создание ортогонального пути (только горизонтальные/вертикальные линии)
  Path _createOrthogonalPath(Offset start, Offset end) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Вычисляем промежуточные точки для ортогонального соединения
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    // Определяем направление для начального отрезка
    if (dx.abs() > 20 && dy.abs() > 20) {
      // Если оба направления больше 20 пикселей, создаем L-образный путь
      // Сначала движемся по оси, где расстояние больше, чтобы минимизировать пересечения
      if (dx.abs() > dy.abs()) {
        // Сначала горизонтальный отрезок, затем вертикальный
        final midX = start.dx + dx / 2;
        path.lineTo(midX, start.dy);  // Горизонтальный отрезок от начала
        path.lineTo(midX, end.dy);    // Вертикальный отрезок к концу
        path.lineTo(end.dx, end.dy);  // Горизонтальный отрезок до конечной точки
      } else {
        // Сначала вертикальный отрезок, затем горизонтальный
        final midY = start.dy + dy / 2;
        path.lineTo(start.dx, midY);  // Вертикальный отрезок от начала
        path.lineTo(end.dx, midY);    // Горизонтальный отрезок к концу
        path.lineTo(end.dx, end.dy);  // Вертикальный отрезок до конечной точки
      }
    } else if (dx.abs() <= 20 && dy.abs() > 20) {
      // Горизонтальное расстояние мало, сначала вертикальный отрезок
      final midY = start.dy + dy / 2;
      path.lineTo(start.dx, midY);  // Вертикальный отрезок от начала
      path.lineTo(end.dx, midY);    // Горизонтальный отрезок к концу
      path.lineTo(end.dx, end.dy);  // Вертикальный отрезок до конечной точки
    } else if (dx.abs() > 20 && dy.abs() <= 20) {
      // Вертикальное расстояние мало, сначала горизонтальный отрезок
      final midX = start.dx + dx / 2;
      path.lineTo(midX, start.dy);  // Горизонтальный отрезок от начала
      path.lineTo(midX, end.dy);    // Вертикальный отрезок к концу
      path.lineTo(end.dx, end.dy);  // Горизонтальный отрезок до конечной точки
    } else {
      // Оба расстояния малы, создаем простой путь
      // Используем среднюю точку для избегания слишком резких поворотов
      final midX = start.dx + dx / 2;
      final midY = start.dy + dy / 2;
      
      // Определяем, какой отрезок рисовать первым - горизонтальный или вертикальный
      if (dx.abs() >= dy.abs()) {
        path.lineTo(midX, start.dy);  // Горизонтальный отрезок от начала
        path.lineTo(midX, end.dy);    // Вертикальный отрезок к концу
        path.lineTo(end.dx, end.dy);  // Горизонтальный отрезок до конечной точки
      } else {
        path.lineTo(start.dx, midY);  // Вертикальный отрезок от начала
        path.lineTo(end.dx, midY);    // Горизонтальный отрезок к концу
        path.lineTo(end.dx, end.dy);  // Вертикальный отрезок до конечной точки
      }
    }

    return path;
  }
}