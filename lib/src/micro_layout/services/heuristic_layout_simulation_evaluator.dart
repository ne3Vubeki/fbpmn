import 'dart:ui';

import 'dart:math';

import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/layout_candidate_evaluation.dart';
import 'package:fbpmn/src/micro_layout/models/layout_quality_metrics.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_request.dart';
import 'package:fbpmn/src/micro_layout/services/layout_quality_scorer.dart';
import 'package:fbpmn/src/micro_layout/services/layout_simulation_evaluator.dart';
import 'package:fbpmn/src/utils/utils.dart';

class HeuristicLayoutSimulationEvaluator implements LayoutSimulationEvaluator {
  final LayoutQualityScorer qualityScorer;

  const HeuristicLayoutSimulationEvaluator({
    this.qualityScorer = const LayoutQualityScorer(),
  });

  @override
  Future<LayoutCandidateEvaluation> evaluate({
    required LayoutSearchRequest request,
    required LayoutCandidate candidate,
    double predictedScore = 0,
  }) async {
    final candidateRect = candidate.candidateRect;

    var nodeOverlaps = 0.0;
    for (final nearbyNode in request.nearbyNodes) {
      if (nearbyNode.id == request.node.id) {
        continue;
      }
      final position = nearbyNode.aPosition ?? nearbyNode.position;
      final rect = Utils.calculateNodeRect(node: nearbyNode, position: position);
      if (candidateRect.overlaps(rect)) {
        nodeOverlaps += _overlapArea(candidateRect, rect) > 0 ? 1 : 0;
      }
    }

    final movementDistance = candidate.movementDistance;
    final contextArea = max(1.0, request.contextSnapshot.bounds.width * request.contextSnapshot.bounds.height);
    final nodeArea = candidateRect.width * candidateRect.height;
    final spacingScore = max(0.0, (contextArea - nodeArea) / contextArea);
    final alignmentScore = _alignmentScore(request, candidate);

    final metrics = LayoutQualityMetrics(
      nodeOverlaps: nodeOverlaps,
      movementDistance: movementDistance,
      spacingScore: spacingScore,
      alignmentScore: alignmentScore,
    );

    return LayoutCandidateEvaluation(
      candidate: candidate,
      metrics: metrics,
      exactScore: qualityScorer.score(metrics),
      predictedScore: predictedScore,
      accepted: nodeOverlaps <= 0,
    );
  }

  double _alignmentScore(LayoutSearchRequest request, LayoutCandidate candidate) {
    if (request.nearbyNodes.isEmpty) {
      return 0;
    }

    final candidateCenter = candidate.candidateRect.center;
    var score = 0.0;
    for (final nearbyNode in request.nearbyNodes) {
      if (nearbyNode.id == request.node.id) {
        continue;
      }
      final position = nearbyNode.aPosition ?? nearbyNode.position;
      final rect = Utils.calculateNodeRect(node: nearbyNode, position: position);
      if ((rect.center.dx - candidateCenter.dx).abs() <= 8) {
        score += 0.5;
      }
      if ((rect.center.dy - candidateCenter.dy).abs() <= 8) {
        score += 0.5;
      }
    }

    return score;
  }

  double _overlapArea(Rect a, Rect b) {
    final overlap = a.intersect(b);
    if (overlap.isEmpty) {
      return 0;
    }

    return overlap.width * overlap.height;
  }
}
