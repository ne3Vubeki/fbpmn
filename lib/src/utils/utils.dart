import 'dart:math' as math;
import 'dart:ui';

import '../editor_state.dart';
import '../models/arrow.dart';
import '../models/table.node.dart';
import 'editor_config.dart';

class Utils {
  // Метод для получения экранных координат из мировых
  static Offset worldToScreen(Offset worldPosition, EditorState state) {
    return worldPosition * state.scale + state.offset;
  }

  // Метод для получения мировых координат из экранных
  static Offset screenToWorld(Offset screenPosition, EditorState state) {
    return (screenPosition - state.offset) / state.scale;
  }

  /// Вычисляет bounding box списка узлов в мировых координатах.
  /// Возвращает ({Rect worldBounds, List<TableNode> validNodes}) или null, если нет валидных узлов.
  /// Учитывает детей для развернутых swimlane.
  static ({Rect worldBounds, List<TableNode> validNodes})? getNodesWorldBounds(List<TableNode?> nodes, Offset delta) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    final validNodes = <TableNode>[];
    for (final n in nodes) {
      if (n == null) continue;
      validNodes.add(n);

      final worldPos = n.aPosition ?? (delta + n.position);
      final nodeRect = calculateNodeRect(node: n, position: worldPos);
      minX = math.min(minX, nodeRect.left);
      minY = math.min(minY, nodeRect.top);
      maxX = math.max(maxX, nodeRect.right);
      maxY = math.max(maxY, nodeRect.bottom);

      // Учитываем детей для развернутых swimlane
      if (n.children != null && !(n.isCollapsed ?? false)) {
        for (final child in n.children!) {
          final childPos = child.aPosition ?? (worldPos + child.position);
          final childRect = calculateNodeRect(node: child, position: childPos);
          minX = math.min(minX, childRect.left);
          minY = math.min(minY, childRect.top);
          maxX = math.max(maxX, childRect.right);
          maxY = math.max(maxY, childRect.bottom);
        }
      }
    }

    if (validNodes.isEmpty) return null;

    return (worldBounds: Rect.fromLTRB(minX, minY, maxX, maxY), validNodes: validNodes);
  }

  /// Рассчитывает прямоугольник, который вмещает все стрелки
  static Rect calculateBoundingRect(List<Arrow?> arrows, EditorState state) {
    if (arrows.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final arrow in arrows) {
      if (arrow == null) continue;

      // Координаты в arrow.coordinates — мировые координаты
      if (arrow.coordinates != null && arrow.coordinates!.isNotEmpty) {
        for (final worldCoordinate in arrow.coordinates!) {
          minX = worldCoordinate.dx < minX ? worldCoordinate.dx : minX;
          minY = worldCoordinate.dy < minY ? worldCoordinate.dy : minY;
          maxX = worldCoordinate.dx > maxX ? worldCoordinate.dx : maxX;
          maxY = worldCoordinate.dy > maxY ? worldCoordinate.dy : maxY;
        }
      } else {
        // Если coordinates отсутствуют, используем source и target позиции
        minX = arrow.aPositionSource.dx < minX ? arrow.aPositionSource.dx : minX;
        minY = arrow.aPositionSource.dy < minY ? arrow.aPositionSource.dy : minY;
        maxX = arrow.aPositionSource.dx > maxX ? arrow.aPositionSource.dx : maxX;
        maxY = arrow.aPositionSource.dy > maxY ? arrow.aPositionSource.dy : maxY;

        minX = arrow.aPositionTarget.dx < minX ? arrow.aPositionTarget.dx : minX;
        minY = arrow.aPositionTarget.dy < minY ? arrow.aPositionTarget.dy : minY;
        maxX = arrow.aPositionTarget.dx > maxX ? arrow.aPositionTarget.dx : maxX;
        maxY = arrow.aPositionTarget.dy > maxY ? arrow.aPositionTarget.dy : maxY;
      }
    }

    // Добавляем толщину связи, если ширина или высота равна 0
    const arrowThickness = EditorConfig.arrowSelectedWidth;
    final width = maxX - minX;
    final height = maxY - minY;

    if (width == 0) {
      minX -= arrowThickness / 2;
      maxX += arrowThickness / 2;
    }

    if (height == 0) {
      minY -= arrowThickness / 2;
      maxY += arrowThickness / 2;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static Rect calculateNodeRect({required TableNode node, required Offset position}) {
    final actualWidth = node.size.width;
    final minHeight = _calculateMinHeight(node);
    final actualHeight = math.max(node.size.height, minHeight);

    return Rect.fromLTWH(position.dx - 20, position.dy - 20, actualWidth + 40, actualHeight + 40);
  }

  static double _calculateMinHeight(TableNode node) {
    return EditorConfig.headerHeight + (node.attributes.length * EditorConfig.minRowHeight);
  }
}
