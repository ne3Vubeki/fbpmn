import 'package:fbpmn/src/micro_layout/models/layout_quality_metrics.dart';

class LayoutQualityScorer {
  final double edgeCrossingPenalty;
  final double nodeOverlapPenalty;
  final double edgeNodeIntersectionPenalty;
  final double incidentEdgeLengthPenalty;
  final double movementPenalty;
  final double spacingReward;
  final double alignmentReward;

  const LayoutQualityScorer({
    this.edgeCrossingPenalty = 10,
    this.nodeOverlapPenalty = 12,
    this.edgeNodeIntersectionPenalty = 8,
    this.incidentEdgeLengthPenalty = 0.01,
    this.movementPenalty = 0.02,
    this.spacingReward = 2,
    this.alignmentReward = 1,
  });

  double score(LayoutQualityMetrics metrics) {
    return -(metrics.edgeCrossings * edgeCrossingPenalty) -
        (metrics.nodeOverlaps * nodeOverlapPenalty) -
        (metrics.edgeNodeIntersections * edgeNodeIntersectionPenalty) -
        (metrics.totalIncidentEdgeLength * incidentEdgeLengthPenalty) -
        (metrics.movementDistance * movementPenalty) +
        (metrics.spacingScore * spacingReward) +
        (metrics.alignmentScore * alignmentReward);
  }
}
