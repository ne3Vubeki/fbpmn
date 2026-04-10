import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/micro_layout/models/layout_context_snapshot.dart';
import 'package:fbpmn/src/models/image_tile.dart';
import 'package:fbpmn/src/models/table.node.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/utils/utils.dart';

class RuntimeContextSnapshotFactory {
  final EditorState state;

  const RuntimeContextSnapshotFactory({required this.state});

  LayoutContextSnapshot create(ImageTile tile) {
    final contextNodes = NodeManager.whereAllNodes(state.nodes, (node) => tile.nodes.contains(node.id)).whereType<TableNode>().toList(growable: false);
    final contextArea = tile.bounds.width * tile.bounds.height;
    var occupiedArea = 0.0;

    for (final node in contextNodes) {
      final position = node.aPosition ?? (state.delta + node.position);
      final intersection = Utils.calculateNodeRect(node: node, position: position).intersect(tile.bounds);
      occupiedArea += intersection.width * intersection.height;
    }

    final safeArea = contextArea <= 0 ? 1.0 : contextArea;
    final occupancyRatio = (occupiedArea / safeArea).clamp(0.0, 1.0);

    return LayoutContextSnapshot(
      bounds: tile.bounds,
      sourceBounds: tile.bounds,
      occupancyRatio: occupancyRatio,
      freeAreaRatio: (1 - occupancyRatio).clamp(0.0, 1.0),
      localNodeDensity: contextNodes.length / safeArea,
      contextWidth: tile.bounds.width,
      contextHeight: tile.bounds.height,
    );
  }
}
