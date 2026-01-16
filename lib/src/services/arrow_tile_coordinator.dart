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
    // Проверяем, связаны ли стрелки с узлами в скрытых swimlane
    final effectiveSourceNode = _getEffectiveNode(arrow.source);
    final effectiveTargetNode = _getEffectiveNode(arrow.target);

    // Пропускаем стрелки, связанные с узлами в скрытых swimlane
    if ((effectiveSourceNode != null && 
        _isNodeHiddenInCollapsedSwimlane(effectiveSourceNode)) ||
        (effectiveTargetNode != null && 
        _isNodeHiddenInCollapsedSwimlane(effectiveTargetNode))) {
      return false;
    }

    final path = getArrowPathForTiles(arrow, baseOffset);
    if (path.getBounds().isEmpty) return false;

    // Более точная проверка пересечения с использованием PathMetrics
    // для лучшего определения пересечений с тайлами
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      final pathLength = metric.length;
      // Проверяем точки вдоль пути с более высокой плотностью
      for (double t = 0; t <= pathLength; t += pathLength / 20) {
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
      
      // Также проверяем пересечение с помощью более точного метода
      // Разбиваем путь на отрезки и проверяем пересечение каждого отрезка с тайлом
      for (double t = 0; t < pathLength; t += 10.0) { // шаг 10 пикселей
        try {
          final tangent1 = metric.getTangentForOffset(t);
          final tangent2 = metric.getTangentForOffset(t + 10.0 < pathLength ? t + 10.0 : pathLength);
          
          if (tangent1 != null && tangent2 != null) {
            final segment = Path()
              ..moveTo(tangent1.position.dx, tangent1.position.dy)
              ..lineTo(tangent2.position.dx, tangent2.position.dy);
            
            // Проверяем пересечение отрезка с границами тайла
            if (_doesSegmentIntersectRect(segment, tileBounds)) {
              return true;
            }
          }
        } catch (e) {
          continue;
        }
      }
    }

    return false;
  }

  /// Проверяет, пересекает ли сегмент прямоугольник
  bool _doesSegmentIntersectRect(Path segment, Rect rect) {
    // Получаем точки начала и конца сегмента
    final PathMetrics metrics = segment.computeMetrics();
    for (final metric in metrics) {
      final start = metric.getTangentForOffset(0)?.position;
      final end = metric.getTangentForOffset(metric.length)?.position;
      
      if (start != null && end != null) {
        // Проверяем, находится ли хотя бы одна точка внутри прямоугольника
        if (rect.contains(start) || rect.contains(end)) {
          return true;
        }
        
        // Проверяем пересечение отрезка с границами прямоугольника
        // Левая граница
        if (_doLinesIntersect(start.dx, start.dy, end.dx, end.dy, 
                              rect.left, rect.top, rect.left, rect.bottom)) {
          return true;
        }
        // Правая граница
        if (_doLinesIntersect(start.dx, start.dy, end.dx, end.dy, 
                              rect.right, rect.top, rect.right, rect.bottom)) {
          return true;
        }
        // Верхняя граница
        if (_doLinesIntersect(start.dx, start.dy, end.dx, end.dy, 
                              rect.left, rect.top, rect.right, rect.top)) {
          return true;
        }
        // Нижняя граница
        if (_doLinesIntersect(start.dx, start.dy, end.dx, end.dy, 
                              rect.left, rect.bottom, rect.right, rect.bottom)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Проверяет, пересекаются ли два отрезка
  bool _doLinesIntersect(double x1, double y1, double x2, double y2,
                         double x3, double y3, double x4, double y4) {
    // Формула для проверки пересечения двух отрезков
    double den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (den == 0) return false; // Отрезки параллельны
    
    double t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den;
    double u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den;
    
    return t >= 0 && t <= 1 && u >= 0 && u <= 1;
  }

  /// Проверяет, является ли узел скрытым внутри свернутого swimlane
  bool _isNodeHiddenInCollapsedSwimlane(TableNode? node) {
    if (node == null || node.parent == null) {
      return false;
    }

    // Найти родительский узел
    TableNode? findParent(List<TableNode> nodeList) {
      for (final n in nodeList) {
        if (n.id == node.parent) {
          return n;
        }

        if (n.children != null) {
          final result = findParent(n.children!);
          if (result != null) {
            return result;
          }
        }
      }
      return null;
    }

    final parent = findParent(nodes);
    if (parent != null &&
        parent.qType == 'swimlane' &&
        (parent.isCollapsed ?? false)) {
      return true;
    }

    return false;
  }
}
