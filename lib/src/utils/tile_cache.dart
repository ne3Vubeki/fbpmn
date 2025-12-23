import '../models/table.node.dart';

class TileCache {
  final Map<int, List<TableNode>> _tileToNodes = {};
  final Map<TableNode, Set<int>> _nodeToTiles = {};
  
  void addTileMapping(int tileIndex, List<TableNode> nodes) {
    _tileToNodes[tileIndex] = nodes;
    for (final node in nodes) {
      if (!_nodeToTiles.containsKey(node)) {
        _nodeToTiles[node] = {};
      }
      _nodeToTiles[node]!.add(tileIndex);
    }
  }
  
  List<TableNode>? getNodesForTile(int tileIndex) {
    return _tileToNodes[tileIndex];
  }
  
  Set<int>? getTilesForNode(TableNode node) {
    return _nodeToTiles[node];
  }
  
  void removeNode(TableNode node) {
    final tileIndices = _nodeToTiles.remove(node);
    if (tileIndices != null) {
      for (final tileIndex in tileIndices) {
        final nodes = _tileToNodes[tileIndex];
        if (nodes != null) {
          nodes.remove(node);
        }
      }
    }
  }
  
  void clear() {
    _tileToNodes.clear();
    _nodeToTiles.clear();
  }
}