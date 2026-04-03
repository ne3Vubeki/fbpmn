import 'dart:ui';

import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/layout_candidate_evaluation.dart';
import 'package:fbpmn/src/micro_layout/models/layout_quality_metrics.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_request.dart';
import 'package:fbpmn/src/micro_layout/services/layout_quality_scorer.dart';
import 'package:fbpmn/src/micro_layout/services/layout_simulation_evaluator.dart';
import 'package:fbpmn/src/models/arrow.dart';
import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/utils/editor_config.dart';
import 'package:fbpmn/src/utils/utils.dart';

class RuntimeLayoutSimulationEvaluator implements LayoutSimulationEvaluator {
  final EditorState state;
  final NodeManager nodeManager;
  final ArrowManager arrowManager;
  final LayoutQualityScorer qualityScorer;

  const RuntimeLayoutSimulationEvaluator({
    required this.state,
    required this.nodeManager,
    required this.arrowManager,
    this.qualityScorer = const LayoutQualityScorer(),
  });

  @override
  Future<LayoutCandidateEvaluation> evaluate({
    required LayoutSearchRequest request,
    required LayoutCandidate candidate,
    double predictedScore = 0,
  }) async {
    final node = request.node;
    final originalAbsolutePosition = node.aPosition ?? (state.delta + node.position);
    final originalRelativePosition = node.position;

    final incidentArrows = request.incidentArrows.toSet().toList(growable: false);

    nodeManager.updateNodePositionForLayout(node, candidate.candidatePosition);
    for (final arrow in incidentArrows) {
      arrowManager.getArrowPathInTile(arrow, state.delta);
    }

    final metrics = _buildMetrics(request: request, candidate: candidate, incidentArrows: incidentArrows);
    final exactScore = qualityScorer.score(metrics);

    node.aPosition = originalAbsolutePosition;
    node.position = originalRelativePosition;
    for (final arrow in incidentArrows) {
      arrowManager.getArrowPathInTile(arrow, state.delta);
    }

    return LayoutCandidateEvaluation(
      candidate: candidate,
      metrics: metrics,
      exactScore: exactScore,
      predictedScore: predictedScore,
      accepted: metrics.nodeOverlaps <= 0 && metrics.edgeNodeIntersections <= 0,
    );
  }

  LayoutQualityMetrics _buildMetrics({
    required LayoutSearchRequest request,
    required LayoutCandidate candidate,
    required List<Arrow> incidentArrows,
  }) {
    final candidateRect = Utils.calculateNodeRect(node: request.node, position: candidate.candidatePosition);

    var nodeOverlaps = 0.0;
    for (final nearbyNode in request.nearbyNodes) {
      if (nearbyNode.id == request.node.id) {
        continue;
      }
      final rect = Utils.calculateNodeRect(
        node: nearbyNode,
        position: nearbyNode.aPosition ?? (state.delta + nearbyNode.position),
      );
      if (_overlapArea(candidateRect, rect) > 0) {
        nodeOverlaps += 1;
      }
    }

    final tileArrowIds = request.tileSnapshot.arrowIds.toSet();
    final otherArrows = state.arrows.where((arrow) => tileArrowIds.contains(arrow.id) && !incidentArrows.contains(arrow)).toList(growable: false);

    var edgeNodeIntersections = 0.0;
    for (final arrow in otherArrows) {
      final rects = _arrowRects(arrow);
      for (final rect in rects) {
        if (_overlapArea(candidateRect, rect) > 0) {
          edgeNodeIntersections += 1;
        }
      }
    }

    var edgeCrossings = 0.0;
    var totalIncidentEdgeLength = 0.0;
    for (final incidentArrow in incidentArrows) {
      final incidentRects = _arrowRects(incidentArrow);
      totalIncidentEdgeLength += _arrowLength(incidentArrow);
      for (final arrow in otherArrows) {
        final otherRects = _arrowRects(arrow);
        for (final incidentRect in incidentRects) {
          for (final otherRect in otherRects) {
            if (_overlapArea(incidentRect, otherRect) > 0) {
              edgeCrossings += 1;
            }
          }
        }
      }
    }

    final minDistanceToNeighbor = _minDistanceToNeighbor(request, candidateRect.center);
    final spacingScore = minDistanceToNeighbor / (EditorConfig.tileSize <= 0 ? 1 : EditorConfig.tileSize);
    final alignmentScore = _alignmentScore(request, candidateRect);

    return LayoutQualityMetrics(
      edgeCrossings: edgeCrossings,
      nodeOverlaps: nodeOverlaps,
      edgeNodeIntersections: edgeNodeIntersections,
      totalIncidentEdgeLength: totalIncidentEdgeLength,
      movementDistance: candidate.movementDistance,
      spacingScore: spacingScore,
      alignmentScore: alignmentScore,
    );
  }

  List<Rect> _arrowRects(Arrow arrow) {
    if (arrow.rects != null && arrow.rects!.isNotEmpty) {
      return arrow.rects!;
    }

    final coordinates = arrow.coordinates;
    if (coordinates == null || coordinates.length < 2) {
      return const <Rect>[];
    }

    final rects = <Rect>[];
    for (var index = 0; index < coordinates.length - 1; index++) {
      rects.add(_segmentToRect(coordinates[index], coordinates[index + 1], EditorConfig.arrowSelectedWidth));
    }
    return rects;
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
      start.dx < end.dx ? start.dx - half : end.dx - half,
      start.dy < end.dy ? start.dy - half : end.dy - half,
      start.dx > end.dx ? start.dx + half : end.dx + half,
      start.dy > end.dy ? start.dy + half : end.dy + half,
    );
  }

  double _overlapArea(Rect a, Rect b) {
    final overlap = a.intersect(b);
    if (overlap.isEmpty) {
      return 0;
    }
    return overlap.width * overlap.height;
  }

  double _minDistanceToNeighbor(LayoutSearchRequest request, Offset center) {
    var minDistance = double.infinity;
    for (final node in request.nearbyNodes) {
      if (node.id == request.node.id) {
        continue;
      }
      final rect = Utils.calculateNodeRect(node: node, position: node.aPosition ?? (state.delta + node.position));
      minDistance = (rect.center - center).distance < minDistance ? (rect.center - center).distance : minDistance;
    }
    return minDistance.isFinite ? minDistance : 0;
  }

  double _alignmentScore(LayoutSearchRequest request, Rect candidateRect) {
    var score = 0.0;
    for (final node in request.nearbyNodes) {
      if (node.id == request.node.id) {
        continue;
      }
      final rect = Utils.calculateNodeRect(node: node, position: node.aPosition ?? (state.delta + node.position));
      if ((rect.left - candidateRect.left).abs() <= 8 || (rect.center.dx - candidateRect.center.dx).abs() <= 8) {
        score += 0.5;
      }
      if ((rect.top - candidateRect.top).abs() <= 8 || (rect.center.dy - candidateRect.center.dy).abs() <= 8) {
        score += 0.5;
      }
    }
    return score;
  }
}
