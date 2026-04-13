import 'dart:math';

import 'package:fbpmn/src/micro_layout/models/layout_quality_metrics.dart';

class LayoutQualityScorer {
  final double nodeOverlapWeight;
  final double edgeNodeIntersectionWeight;
  final double edgeCrossingWeight;
  final double edgeLengthWeight;
  final double movementWeight;
  final double spacingWeight;
  final double alignmentWeight;

  const LayoutQualityScorer({
    this.nodeOverlapWeight = 0.30,
    this.edgeNodeIntersectionWeight = 0.20,
    this.edgeCrossingWeight = 0.15,
    this.edgeLengthWeight = 0.05,
    this.movementWeight = 0.05,
    this.spacingWeight = 0.15,
    this.alignmentWeight = 0.10,
  });

  double score(LayoutQualityMetrics metrics) {
    final overlapPenalty = _sigmoid(metrics.nodeOverlaps, k: 3.0);
    final edgeNodePenalty = _sigmoid(metrics.edgeNodeIntersections, k: 2.0);
    final crossingPenalty = _sigmoid(metrics.edgeCrossings, k: 1.5);
    final lengthPenalty = _sigmoid(metrics.totalIncidentEdgeLength / 500.0, k: 1.0);
    final movePenalty = _sigmoid(metrics.movementDistance / 200.0, k: 1.5);
    final spacingReward = (metrics.spacingScore).clamp(0.0, 1.0);
    final alignReward = _sigmoid(metrics.alignmentScore, k: -2.0);

    return (1.0 - overlapPenalty) * nodeOverlapWeight +
        (1.0 - edgeNodePenalty) * edgeNodeIntersectionWeight +
        (1.0 - crossingPenalty) * edgeCrossingWeight +
        (1.0 - lengthPenalty) * edgeLengthWeight +
        (1.0 - movePenalty) * movementWeight +
        spacingReward * spacingWeight +
        alignReward * alignmentWeight;
  }

  double _sigmoid(double x, {double k = 1.0}) {
    return 1.0 / (1.0 + exp(-k * x));
  }
}
