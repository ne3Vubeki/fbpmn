import 'dart:ui';

import 'package:fbpmn/src/micro_layout/models/tile_snapshot.dart';
import 'package:fbpmn/src/models/arrow.dart';
import 'package:fbpmn/src/models/table.node.dart';

class LayoutSearchRequest {
  final TableNode node;
  final TileSnapshot tileSnapshot;
  final List<TableNode> nearbyNodes;
  final List<Arrow> incidentArrows;
  final List<Rect> freeSpaceRects;
  final Rect searchBounds;
  final double gridStep;
  final int maxCandidates;
  final int topKForExactEvaluation;

  const LayoutSearchRequest({
    required this.node,
    required this.tileSnapshot,
    this.nearbyNodes = const <TableNode>[],
    this.incidentArrows = const <Arrow>[],
    this.freeSpaceRects = const <Rect>[],
    required this.searchBounds,
    this.gridStep = 48,
    this.maxCandidates = 24,
    this.topKForExactEvaluation = 5,
  });
}
