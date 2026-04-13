import 'dart:math';
import 'dart:ui';

import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/layout_candidate_evaluation.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_request.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_result.dart';
import 'package:fbpmn/src/micro_layout/models/layout_training_context.dart';
import 'package:fbpmn/src/micro_layout/services/candidate_feature_extractor.dart';
import 'package:fbpmn/src/micro_layout/services/layout_candidate_generator.dart';
import 'package:fbpmn/src/micro_layout/services/layout_simulation_evaluator.dart';
import 'package:fbpmn/src/micro_layout/services/micro_layout_model.dart';
import 'package:fbpmn/src/models/arrow.dart';
import 'package:fbpmn/src/models/attribute.dart';
import 'package:fbpmn/src/models/connections.dart';
import 'package:fbpmn/src/models/table.node.dart';
import 'package:fbpmn/src/utils/editor_config.dart';

class MicroLayoutPlanner {
  static const double _minimumExactScoreGain = 0.5;

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

    final originCandidate = generatedCandidates.firstWhere(
      (candidate) => candidate.movementDistance <= 0.01,
      orElse: () => LayoutCandidate(
        originPosition: request.node.aPosition ?? request.node.position,
        candidatePosition: request.node.aPosition ?? request.node.position,
        nodeSize: request.node.size,
        heuristicScore: 1,
      ),
    );

    final baselineEvaluation = await evaluator.evaluate(
      request: request,
      candidate: originCandidate,
      predictedScore: _predictCandidateScore(request, originCandidate),
    );

    final rankedCandidates = generatedCandidates
        .map((candidate) => (
              candidate: candidate,
              predictedScore: _predictCandidateScore(request, candidate),
            ))
        .toList(growable: false)
      ..sort((a, b) => b.predictedScore.compareTo(a.predictedScore));

    final topK = min(max(request.topKForExactEvaluation, 10), rankedCandidates.length);
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

    final hasBaselineInTopK = exactEvaluations.any(
      (evaluation) => evaluation.candidate.movementDistance <= 0.01,
    );
    if (!hasBaselineInTopK) {
      exactEvaluations.add(baselineEvaluation);
    }

    exactEvaluations.sort((a, b) => b.exactScore.compareTo(a.exactScore));
    final bestEvaluation = exactEvaluations.isEmpty ? null : exactEvaluations.first;

    final shouldKeepCurrentPosition = bestEvaluation == null ||
        bestEvaluation.candidate.movementDistance <= 0.01 ||
        bestEvaluation.exactScore <= baselineEvaluation.exactScore + _minimumExactScoreGain;

    return LayoutSearchResult(
      bestCandidate: shouldKeepCurrentPosition ? null : bestEvaluation.candidate,
      generatedCandidates: generatedCandidates,
      evaluatedCandidates: exactEvaluations,
    );
  }

  double _predictCandidateScore(LayoutSearchRequest request, LayoutCandidate candidate) {
    if (model == null) {
      return candidate.heuristicScore;
    }

    final candidateRect = candidate.candidateRect;
    final nearestFreeSpace = featureExtractor.resolveNearestFreeSpace(request.freeSpaceRects, candidateRect);
    final contextSnapshot = request.contextSnapshot;
    final contextWidth = contextSnapshot.contextWidth <= 0 ? contextSnapshot.bounds.width : contextSnapshot.contextWidth;
    final contextHeight = contextSnapshot.contextHeight <= 0 ? contextSnapshot.bounds.height : contextSnapshot.contextHeight;
    final contextArea = max(1.0, contextWidth * contextHeight);
    var overlapCount = 0.0;
    var overlapArea = 0.0;

    for (final node in request.nearbyNodes) {
      if (node.id == request.node.id) {
        continue;
      }

      final nodeCenter = (node.aPosition ?? node.position) + Offset(node.size.width / 2, node.size.height / 2);
      final nodeRect = Rect.fromCenter(
        center: nodeCenter,
        width: node.size.width,
        height: node.size.height,
      );
      final overlap = candidateRect.intersect(nodeRect);
      if (!overlap.isEmpty) {
        overlapCount += 1;
        overlapArea += overlap.width * overlap.height;
      }
    }

    final nodeById = <String, TableNode>{};
    for (final nearbyNode in request.nearbyNodes) {
      nodeById[nearbyNode.id] = nearbyNode;
    }

    final nonIncidentArrows = request.contextArrows
        .where((arrow) => !request.incidentArrows.contains(arrow))
        .toList(growable: false);

    var estimatedIncidentArrowLength = 0.0;
    var estimatedEdgeCrossings = 0.0;
    var estConnAfterTop = 0;
    var estConnAfterRight = 0;
    var estConnAfterBottom = 0;
    var estConnAfterLeft = 0;

    for (final arrow in request.incidentArrows) {
      final otherNodeId = arrow.source == request.node.id ? arrow.target : arrow.source;
      final otherNode = nodeById[otherNodeId];

      Offset otherEnd;
      if (otherNode != null) {
        final otherPos = otherNode.aPosition ?? otherNode.position;
        otherEnd = otherPos + Offset(otherNode.size.width / 2, otherNode.size.height / 2);
      } else {
        final coords = arrow.coordinates;
        if (coords != null && coords.length >= 2) {
          otherEnd = arrow.source == request.node.id ? coords.last : coords.first;
        } else {
          continue;
        }
      }

      estimatedIncidentArrowLength += (candidateRect.center - otherEnd).distance;

      final dx = otherEnd.dx - candidateRect.center.dx;
      final dy = otherEnd.dy - candidateRect.center.dy;
      if (dx.abs() >= dy.abs()) {
        if (dx > 0) { estConnAfterRight++; } else { estConnAfterLeft++; }
      } else {
        if (dy > 0) { estConnAfterBottom++; } else { estConnAfterTop++; }
      }

      final segmentRect = _segmentToRect(candidateRect.center, otherEnd, EditorConfig.arrowSelectedWidth);
      for (final otherArrow in nonIncidentArrows) {
        for (final otherRect in _arrowRects(otherArrow)) {
          if (!segmentRect.intersect(otherRect).isEmpty) {
            estimatedEdgeCrossings += 1;
          }
        }
      }
    }

    final estimatedNodeConnectionsAfter = ConnectionSideProfile(
      top: estConnAfterTop,
      right: estConnAfterRight,
      bottom: estConnAfterBottom,
      left: estConnAfterLeft,
    );

    final sourceMetrics = _buildSourceMetrics(request);
    final trainingContext = LayoutTrainingContext(
      sampleSource: 'auto',
      qType: request.node.qType,
      isManualSample: false,
      isConflictNode: sourceMetrics.nodeOverlapCount > 0 || sourceMetrics.edgeIntersectionCount > 0,
      totalConnectionCount: _countConnections(request.node),
      incidentArrowCount: request.incidentArrows.length,
      nodeConnectionsBefore: _captureConnectionsProfile(request.node.connections),
      attributeConnectionsBefore: _captureAttributeConnectionsProfile(request.node.attributes),
      nodeConnectionsAfter: estimatedNodeConnectionsAfter,
      attributeConnectionsAfter: _captureAttributeConnectionsProfile(request.node.attributes),
      graphNodeCount: request.graphNodeCount,
      graphEdgeCount: request.graphEdgeCount,
      graphConflictRatio: request.graphConflictRatio,
      sourceNodeOverlapCount: sourceMetrics.nodeOverlapCount,
      sourceEdgeIntersectionCount: sourceMetrics.edgeIntersectionCount,
      sourceEdgeCrossings: sourceMetrics.edgeCrossings,
      sourceIncidentArrowLength: sourceMetrics.totalIncidentArrowLength,
      resultNodeOverlapCount: overlapCount,
      resultEdgeIntersectionCount: _countArrowIntersections(candidateRect, request),
      resultEdgeCrossings: estimatedEdgeCrossings,
      resultIncidentArrowLength: estimatedIncidentArrowLength,
      movementDistance: candidate.movementDistance,
      freeSpaceBounds: nearestFreeSpace,
    );

    final featureVector = featureExtractor.extract(
      node: request.node,
      candidate: candidate,
      contextSnapshot: contextSnapshot,
      incidentArrows: request.incidentArrows,
      nearbyNodes: request.nearbyNodes,
      freeSpaceBounds: nearestFreeSpace,
      localNodeDensity: _safeDensity(request.nearbyNodes.length, contextSnapshot.bounds),
      localArrowDensity: _safeDensity(request.contextArrows.length, contextSnapshot.bounds),
      minDistanceToNeighbor: _minDistanceToNeighbor(request, candidate),
      candidateNodeOverlapCount: overlapCount,
      candidateNodeOverlapAreaRatio: overlapArea / contextArea,
      candidateEdgeIntersectionCount: _countArrowIntersections(candidateRect, request),
      candidateIncidentArrowLengthRatio: estimatedIncidentArrowLength / max(contextSnapshot.bounds.longestSide, 1.0),
      trainingContext: trainingContext,
    );

    return model!.predict(featureVector);
  }

  double _countArrowIntersections(Rect candidateRect, LayoutSearchRequest request) {
    var intersections = 0.0;
    final incidentArrowIds = request.incidentArrows.map((a) => a.id).toSet();

    for (final arrow in _resolveRelevantArrows(request)) {
      if (incidentArrowIds.contains(arrow.id)) {
        continue;
      }
      for (final rect in _arrowRects(arrow)) {
        if (!candidateRect.intersect(rect).isEmpty) {
          intersections += 1;
        }
      }
    }

    return intersections;
  }

  List<Arrow> _resolveRelevantArrows(LayoutSearchRequest request) {
    final arrows = <Arrow>[];
    final seen = <String>{};

    for (final arrow in request.contextArrows) {
      if (seen.add(arrow.id)) {
        arrows.add(arrow);
      }
    }

    return arrows;
  }

  ({double nodeOverlapCount, double edgeIntersectionCount, double edgeCrossings, double totalIncidentArrowLength}) _buildSourceMetrics(
    LayoutSearchRequest request,
  ) {
    final nodeRect = request.node.aPosition == null
        ? Rect.fromLTWH(request.node.position.dx, request.node.position.dy, request.node.size.width, request.node.size.height)
        : Rect.fromLTWH(request.node.aPosition!.dx, request.node.aPosition!.dy, request.node.size.width, request.node.size.height);
    final relevantArrows = _resolveRelevantArrows(request);
    final otherArrows = relevantArrows.where((arrow) => !request.incidentArrows.contains(arrow)).toList(growable: false);

    var nodeOverlapCount = 0.0;
    for (final nearbyNode in request.nearbyNodes) {
      if (nearbyNode.id == request.node.id) {
        continue;
      }
      final nodeCenter = (nearbyNode.aPosition ?? nearbyNode.position) + Offset(nearbyNode.size.width / 2, nearbyNode.size.height / 2);
      final nearbyRect = Rect.fromCenter(center: nodeCenter, width: nearbyNode.size.width, height: nearbyNode.size.height);
      if (!nodeRect.intersect(nearbyRect).isEmpty) {
        nodeOverlapCount += 1;
      }
    }

    var edgeIntersectionCount = 0.0;
    for (final arrow in otherArrows) {
      for (final rect in _arrowRects(arrow)) {
        if (!nodeRect.intersect(rect).isEmpty) {
          edgeIntersectionCount += 1;
        }
      }
    }

    var edgeCrossings = 0.0;
    var totalIncidentArrowLength = 0.0;
    for (final incidentArrow in request.incidentArrows) {
      final incidentRects = _arrowRects(incidentArrow);
      totalIncidentArrowLength += _arrowLength(incidentArrow);
      for (final arrow in otherArrows) {
        final otherRects = _arrowRects(arrow);
        for (final incidentRect in incidentRects) {
          for (final otherRect in otherRects) {
            if (!incidentRect.intersect(otherRect).isEmpty) {
              edgeCrossings += 1;
            }
          }
        }
      }
    }

    return (
      nodeOverlapCount: nodeOverlapCount,
      edgeIntersectionCount: edgeIntersectionCount,
      edgeCrossings: edgeCrossings,
      totalIncidentArrowLength: totalIncidentArrowLength,
    );
  }

  ConnectionSideProfile _captureConnectionsProfile(Connections? connections) {
    return ConnectionSideProfile(
      top: connections?.length('top') ?? 0,
      right: connections?.length('right') ?? 0,
      bottom: connections?.length('bottom') ?? 0,
      left: connections?.length('left') ?? 0,
    );
  }

  ConnectionSideProfile _captureAttributeConnectionsProfile(List<Attribute> attributes) {
    var top = 0;
    var right = 0;
    var bottom = 0;
    var left = 0;
    for (final attribute in attributes) {
      top += attribute.connections?.length('top') ?? 0;
      right += attribute.connections?.length('right') ?? 0;
      bottom += attribute.connections?.length('bottom') ?? 0;
      left += attribute.connections?.length('left') ?? 0;
    }
    return ConnectionSideProfile(top: top, right: right, bottom: bottom, left: left);
  }

  int _countConnections(TableNode node) {
    final nodeConnections = _captureConnectionsProfile(node.connections).total;
    final attributeConnections = _captureAttributeConnectionsProfile(node.attributes).total;
    return nodeConnections + attributeConnections;
  }

  List<Rect> _arrowRects(Arrow arrow) {
    final rects = arrow.rects;
    if (rects != null && rects.isNotEmpty) {
      return rects;
    }

    final coordinates = arrow.coordinates;
    if (coordinates == null || coordinates.length < 2) {
      return const <Rect>[];
    }

    final result = <Rect>[];
    for (var index = 0; index < coordinates.length - 1; index++) {
      final start = coordinates[index];
      final end = coordinates[index + 1];
      final half = EditorConfig.arrowSelectedWidth / 2;
      result.add(
        Rect.fromLTRB(
          min(start.dx, end.dx) - half,
          min(start.dy, end.dy) - half,
          max(start.dx, end.dx) + half,
          max(start.dy, end.dy) + half,
        ),
      );
    }
    return result;
  }

  double _arrowLength(Arrow arrow) {
    final coordinates = arrow.coordinates;
    if (coordinates == null || coordinates.length < 2) {
      return 0;
    }

    var length = 0.0;
    for (var index = 0; index < coordinates.length - 1; index++) {
      length += (coordinates[index + 1] - coordinates[index]).distance;
    }
    return length;
  }

  Rect _segmentToRect(Offset start, Offset end, double thickness) {
    final half = thickness / 2;
    return Rect.fromLTRB(
      min(start.dx, end.dx) - half,
      min(start.dy, end.dy) - half,
      max(start.dx, end.dx) + half,
      max(start.dy, end.dy) + half,
    );
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
