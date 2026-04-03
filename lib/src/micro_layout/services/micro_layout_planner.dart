import 'dart:math';
import 'dart:ui';

import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/layout_candidate_evaluation.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_request.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_result.dart';
import 'package:fbpmn/src/micro_layout/services/candidate_feature_extractor.dart';
import 'package:fbpmn/src/micro_layout/services/layout_candidate_generator.dart';
import 'package:fbpmn/src/micro_layout/services/layout_simulation_evaluator.dart';
import 'package:fbpmn/src/micro_layout/services/micro_layout_model.dart';

class MicroLayoutPlanner {
  final LayoutCandidateGenerator candidateGenerator;
  final CandidateFeatureExtractor featureExtractor;
  final MicroLayoutModel? model;
  final LayoutSimulationEvaluator evaluator;

  const MicroLayoutPlanner({
    required this.candidateGenerator,
    required this.featureExtractor,
    required this.evaluator,
    this.model,
  });

  Future<LayoutSearchResult> findBestCandidate(LayoutSearchRequest request) async {
    final generatedCandidates = candidateGenerator.generate(request);
    if (generatedCandidates.isEmpty) {
      return const LayoutSearchResult(bestCandidate: null);
    }

    final rankedCandidates = generatedCandidates
        .map((candidate) => (
              candidate: candidate,
              predictedScore: _predictCandidateScore(request, candidate),
            ))
        .toList(growable: false)
      ..sort((a, b) => b.predictedScore.compareTo(a.predictedScore));

    final topK = min(request.topKForExactEvaluation, rankedCandidates.length);
    final exactEvaluations = <LayoutCandidateEvaluation>[];

    for (var index = 0; index < topK; index++) {
      final rankedCandidate = rankedCandidates[index];
      final evaluation = await evaluator.evaluate(
        request: request,
        candidate: rankedCandidate.candidate,
        predictedScore: rankedCandidate.predictedScore,
      );
      exactEvaluations.add(evaluation);
    }

    exactEvaluations.sort((a, b) => b.exactScore.compareTo(a.exactScore));
    final bestEvaluation = exactEvaluations.isEmpty ? null : exactEvaluations.first;

    return LayoutSearchResult(
      bestCandidate: bestEvaluation?.candidate,
      generatedCandidates: generatedCandidates,
      evaluatedCandidates: exactEvaluations,
    );
  }

  double _predictCandidateScore(LayoutSearchRequest request, LayoutCandidate candidate) {
    if (model == null) {
      return candidate.heuristicScore;
    }

    final featureVector = featureExtractor.extract(
      node: request.node,
      candidate: candidate,
      tileSnapshot: request.tileSnapshot,
      incidentArrows: request.incidentArrows,
      freeSpaceBounds: _resolveNearestFreeSpace(request.freeSpaceRects, candidate.candidateRect),
      localNodeDensity: _safeDensity(request.nearbyNodes.length, request.tileSnapshot.bounds),
      localArrowDensity: _safeDensity(request.incidentArrows.length, request.tileSnapshot.bounds),
      minDistanceToNeighbor: _minDistanceToNeighbor(request, candidate),
    );

    return model!.predict(featureVector);
  }

  Rect? _resolveNearestFreeSpace(List<Rect> freeSpaceRects, Rect candidateRect) {
    if (freeSpaceRects.isEmpty) {
      return null;
    }

    Rect? bestRect;
    double? bestDistance;

    for (final rect in freeSpaceRects) {
      final distance = (rect.center - candidateRect.center).distance;
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        bestRect = rect;
      }
    }

    return bestRect;
  }

  double _minDistanceToNeighbor(LayoutSearchRequest request, LayoutCandidate candidate) {
    if (request.nearbyNodes.isEmpty) {
      return 0;
    }

    final center = candidate.candidateRect.center;
    double minDistance = double.infinity;
    for (final node in request.nearbyNodes) {
      if (node.id == request.node.id) {
        continue;
      }
      final nodeCenter = (node.aPosition ?? node.position) + Offset(node.size.width / 2, node.size.height / 2);
      minDistance = min(minDistance, (nodeCenter - center).distance);
    }

    return minDistance.isFinite ? minDistance : 0;
  }

  double _safeDensity(int count, Rect bounds) {
    final area = bounds.width * bounds.height;
    if (area <= 0) {
      return 0;
    }

    return count / area;
  }
}
