import 'dart:ui';

import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/layout_feature_vector.dart';
import 'package:fbpmn/src/micro_layout/models/tile_snapshot.dart';
import 'package:fbpmn/src/models/arrow.dart';
import 'package:fbpmn/src/models/table.node.dart';

class CandidateFeatureExtractor {
  const CandidateFeatureExtractor();

  LayoutFeatureVector extract({
    required TableNode node,
    required LayoutCandidate candidate,
    required TileSnapshot tileSnapshot,
    List<Arrow> incidentArrows = const <Arrow>[],
    Rect? freeSpaceBounds,
    double localNodeDensity = 0,
    double localArrowDensity = 0,
    double minDistanceToNeighbor = 0,
  }) {
    final delta = candidate.delta;
    final candidateRect = candidate.candidateRect;
    final tileCenter = tileSnapshot.bounds.center;
    final candidateCenter = candidateRect.center;
    final freeArea =
        (freeSpaceBounds?.size.width ?? 0) * (freeSpaceBounds?.size.height ?? 0);

    return LayoutFeatureVector(<double>[
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.size.height,
      candidate.candidatePosition.dx,
      candidate.candidatePosition.dy,
      delta.dx,
      delta.dy,
      candidate.movementDistance,
      incidentArrows.length.toDouble(),
      tileSnapshot.occupancyRatio,
      tileSnapshot.freeAreaRatio,
      tileSnapshot.localNodeDensity,
      localNodeDensity,
      localArrowDensity,
      minDistanceToNeighbor,
      candidateRect.left,
      candidateRect.top,
      candidateRect.right,
      candidateRect.bottom,
      candidateCenter.dx - tileCenter.dx,
      candidateCenter.dy - tileCenter.dy,
      freeSpaceBounds?.left ?? 0,
      freeSpaceBounds?.top ?? 0,
      freeSpaceBounds?.right ?? 0,
      freeSpaceBounds?.bottom ?? 0,
      freeArea,
      candidate.heuristicScore,
    ]);
  }
}
