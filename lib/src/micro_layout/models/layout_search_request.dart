import 'dart:ui';

import 'package:fbpmn/src/micro_layout/models/layout_context_snapshot.dart';
import 'package:fbpmn/src/models/arrow.dart';
import 'package:fbpmn/src/models/table.node.dart';

class LayoutSearchRequest {
  final TableNode node;
  final LayoutContextSnapshot contextSnapshot;
  final List<TableNode> nearbyNodes;
  final List<Arrow> incidentArrows;
  final List<Arrow> contextArrows;
  final List<Rect> freeSpaceRects;
  final Rect searchBounds;
  final double gridStep;
  final int maxCandidates;
  final int topKForExactEvaluation;
  final int graphNodeCount;
  final int graphEdgeCount;
  final double graphConflictRatio;

  const LayoutSearchRequest({
    required this.node,
    required this.contextSnapshot,
    this.nearbyNodes = const <TableNode>[],
    this.incidentArrows = const <Arrow>[],
    this.contextArrows = const <Arrow>[],
    this.freeSpaceRects = const <Rect>[],
    required this.searchBounds,
    this.gridStep = 48,
    this.maxCandidates = 24,
    this.topKForExactEvaluation = 5,
    this.graphNodeCount = 0,
    this.graphEdgeCount = 0,
    this.graphConflictRatio = 0,
  });
}
