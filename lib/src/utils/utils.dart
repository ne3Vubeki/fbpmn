import 'dart:math' as math;
import 'dart:ui';

import '../editor_state.dart';
import '../models/table.node.dart';

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
  static ({Rect worldBounds, List<TableNode> validNodes})? getNodesWorldBounds(
    List<TableNode?> nodes,
    Offset delta,
  ) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    final validNodes = <TableNode>[];
    for (final n in nodes) {
      if (n == null) continue;
      validNodes.add(n);

      final worldPos = n.aPosition ?? (delta + n.position);
      minX = math.min(minX, worldPos.dx);
      minY = math.min(minY, worldPos.dy);
      maxX = math.max(maxX, worldPos.dx + n.size.width);
      maxY = math.max(maxY, worldPos.dy + n.size.height);

      // Учитываем детей для развернутых swimlane
      if (n.children != null && !(n.isCollapsed ?? false)) {
        for (final child in n.children!) {
          final childPos = child.aPosition ?? (worldPos + child.position);
          minX = math.min(minX, childPos.dx);
          minY = math.min(minY, childPos.dy);
          maxX = math.max(maxX, childPos.dx + child.size.width);
          maxY = math.max(maxY, childPos.dy + child.size.height);
        }
      }
    }

    if (validNodes.isEmpty) return null;

    return (
      worldBounds: Rect.fromLTRB(minX, minY, maxX, maxY),
      validNodes: validNodes,
    );
  }
}