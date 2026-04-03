import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/micro_layout/models/tile_snapshot.dart';
import 'package:fbpmn/src/models/image_tile.dart';
import 'package:fbpmn/src/models/table.node.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/utils/utils.dart';

class RuntimeTileSnapshotFactory {
  final EditorState state;

  const RuntimeTileSnapshotFactory({required this.state});

  TileSnapshot create(ImageTile tile) {
    final nodesInTile = NodeManager.whereAllNodes(state.nodes, (node) => tile.nodes.contains(node.id)).whereType<TableNode>().toList(growable: false);
    final tileArea = tile.bounds.width * tile.bounds.height;
    var occupiedArea = 0.0;

    for (final node in nodesInTile) {
      final position = node.aPosition ?? (state.delta + node.position);
      final intersection = Utils.calculateNodeRect(node: node, position: position).intersect(tile.bounds);
      occupiedArea += intersection.width * intersection.height;
    }

    final safeArea = tileArea <= 0 ? 1.0 : tileArea;
    final occupancyRatio = (occupiedArea / safeArea).clamp(0.0, 1.0);

    return TileSnapshot(
      tileId: tile.id,
      bounds: tile.bounds,
      nodeIds: tile.nodes.whereType<String>().toList(growable: false),
      arrowIds: tile.arrows.whereType<String>().toList(growable: false),
      occupancyRatio: occupancyRatio,
      freeAreaRatio: (1 - occupancyRatio).clamp(0.0, 1.0),
      localNodeDensity: nodesInTile.length / safeArea,
    );
  }
}
