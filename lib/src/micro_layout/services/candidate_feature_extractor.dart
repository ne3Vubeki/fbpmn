import 'dart:math';
import 'dart:ui';

import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/layout_context_snapshot.dart';
import 'package:fbpmn/src/micro_layout/models/layout_feature_vector.dart';
import 'package:fbpmn/src/micro_layout/models/layout_training_context.dart';
import 'package:fbpmn/src/models/arrow.dart';
import 'package:fbpmn/src/models/table.node.dart';

class CandidateFeatureExtractor {
  const CandidateFeatureExtractor();

  static const int featureCount = 73;

  double _safeValue(double value) {
    return value.isFinite ? value : 0;
  }

  double _safeRatio(double value, double denominator) {
    if (!value.isFinite || !denominator.isFinite || denominator.abs() <= 0.000001) {
      return 0;
    }
    return value / denominator;
  }

  double _safeClamp01(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return value.clamp(0.0, 1.0);
  }

  double _typeFeature(TableNode node, List<String> qTypes, String expectedType) {
    if (!qTypes.contains(node.qType) && node.qType == expectedType) {
      return 1;
    }
    return node.qType == expectedType ? 1 : 0;
  }

  Rect? resolveNearestFreeSpace(List<Rect> freeSpaceRects, Rect candidateRect) {
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

  LayoutFeatureVector extract({
    required TableNode node,
    required LayoutCandidate candidate,
    required LayoutContextSnapshot contextSnapshot,
    List<Arrow> incidentArrows = const <Arrow>[],
    Rect? freeSpaceBounds,
    double localNodeDensity = 0,
    double localArrowDensity = 0,
    double minDistanceToNeighbor = 0,
    double candidateNodeOverlapCount = 0,
    double candidateNodeOverlapAreaRatio = 0,
    double candidateEdgeIntersectionCount = 0,
    double candidateIncidentArrowLengthRatio = 0,
    LayoutTrainingContext? trainingContext,
  }) {
    final delta = candidate.delta;
    final candidateRect = candidate.candidateRect;
    final contextCenter = contextSnapshot.bounds.center;
    final sourceCenter = contextSnapshot.sourceBounds.center;
    final candidateCenter = candidateRect.center;
    final contextWidth = contextSnapshot.contextWidth.abs() <= 0.000001 ? contextSnapshot.bounds.width.abs() : contextSnapshot.contextWidth.abs();
    final contextHeight = contextSnapshot.contextHeight.abs() <= 0.000001 ? contextSnapshot.bounds.height.abs() : contextSnapshot.contextHeight.abs();
    final safeContextWidth = contextWidth <= 0.000001 ? 1.0 : contextWidth;
    final safeContextHeight = contextHeight <= 0.000001 ? 1.0 : contextHeight;
    final contextArea = safeContextWidth * safeContextHeight;
    final sourceWidth = contextSnapshot.sourceBounds.width.abs() <= 0.000001 ? 1.0 : contextSnapshot.sourceBounds.width.abs();
    final sourceHeight = contextSnapshot.sourceBounds.height.abs() <= 0.000001 ? 1.0 : contextSnapshot.sourceBounds.height.abs();
    final freeArea =
        (freeSpaceBounds?.size.width ?? 0) * (freeSpaceBounds?.size.height ?? 0);
    final context = trainingContext;
    final qTypes = <String>['bo', 'group', 'enum', 'swimlane', 'attribute'];
    final nodeConnectionsBefore = context?.nodeConnectionsBefore ?? const ConnectionSideProfile();
    final attributeConnectionsBefore = context?.attributeConnectionsBefore ?? const ConnectionSideProfile();
    final nodeConnectionsAfter = context?.nodeConnectionsAfter ?? nodeConnectionsBefore;
    final attributeConnectionsAfter = context?.attributeConnectionsAfter ?? attributeConnectionsBefore;
    final totalConnectionCount = (context?.totalConnectionCount ?? 0).toDouble();
    final sourceNodeOverlapCount = context?.sourceNodeOverlapCount ?? 0;
    final sourceEdgeIntersectionCount = context?.sourceEdgeIntersectionCount ?? 0;
    final sourceEdgeCrossings = context?.sourceEdgeCrossings ?? 0;
    final sourceIncidentArrowLength = context?.sourceIncidentArrowLength ?? 0;
    final resultNodeOverlapCount = context?.resultNodeOverlapCount ?? candidateNodeOverlapCount;
    final resultEdgeIntersectionCount = context?.resultEdgeIntersectionCount ?? candidateEdgeIntersectionCount;
    final resultEdgeCrossings = context?.resultEdgeCrossings ?? 0;
    final resultIncidentArrowLength = context?.resultIncidentArrowLength ?? candidateIncidentArrowLengthRatio * max(contextSnapshot.bounds.longestSide, 1.0);
    final totalSideConnectionsBefore = max(1.0, (nodeConnectionsBefore.total + attributeConnectionsBefore.total).toDouble());
    final totalSideConnectionsAfter = max(1.0, (nodeConnectionsAfter.total + attributeConnectionsAfter.total).toDouble());
    final maxContextSide = safeContextWidth > safeContextHeight ? safeContextWidth : safeContextHeight;
    final crossesSourceTile = !contextSnapshot.sourceBounds.contains(candidateRect.topLeft) || !contextSnapshot.sourceBounds.contains(candidateRect.bottomRight);
    final sourceToCandidateTileDx = _safeRatio(candidateCenter.dx - sourceCenter.dx, sourceWidth);
    final sourceToCandidateTileDy = _safeRatio(candidateCenter.dy - sourceCenter.dy, sourceHeight);
    final sourceOffsetX = _safeRatio(node.position.dx - contextSnapshot.sourceBounds.left, sourceWidth);
    final sourceOffsetY = _safeRatio(node.position.dy - contextSnapshot.sourceBounds.top, sourceHeight);
    final movementDistance = context?.movementDistance ?? candidate.movementDistance;

    return LayoutFeatureVector(<double>[
      _safeRatio(node.position.dx - contextSnapshot.sourceBounds.left, sourceWidth),
      _safeRatio(node.position.dy - contextSnapshot.sourceBounds.top, sourceHeight),
      _safeRatio(node.position.dx - contextSnapshot.bounds.left, safeContextWidth),
      _safeRatio(node.position.dy - contextSnapshot.bounds.top, safeContextHeight),
      _safeRatio(node.size.width, safeContextWidth),
      _safeRatio(node.size.height, safeContextHeight),
      _safeRatio(node.size.width, sourceWidth),
      _safeRatio(node.size.height, sourceHeight),
      _safeRatio(candidate.candidatePosition.dx - contextSnapshot.bounds.left, safeContextWidth),
      _safeRatio(candidate.candidatePosition.dy - contextSnapshot.bounds.top, safeContextHeight),
      _safeRatio(candidate.candidatePosition.dx - contextSnapshot.sourceBounds.left, sourceWidth),
      _safeRatio(candidate.candidatePosition.dy - contextSnapshot.sourceBounds.top, sourceHeight),
      _safeRatio(delta.dx, safeContextWidth),
      _safeRatio(delta.dy, safeContextHeight),
      _safeRatio(movementDistance, maxContextSide),
      _safeValue(incidentArrows.length.toDouble()),
      _safeValue(contextSnapshot.occupancyRatio.clamp(0.0, 1.0)),
      _safeValue(contextSnapshot.freeAreaRatio.clamp(0.0, 1.0)),
      _safeValue(contextSnapshot.localNodeDensity * contextArea),
      _safeValue(localNodeDensity * contextArea),
      _safeValue(localArrowDensity * contextArea),
      _safeRatio(minDistanceToNeighbor, maxContextSide),
      _safeRatio(candidateRect.left - contextSnapshot.bounds.left, safeContextWidth),
      _safeRatio(candidateRect.top - contextSnapshot.bounds.top, safeContextHeight),
      _safeRatio(candidateRect.right - contextSnapshot.bounds.left, safeContextWidth),
      _safeRatio(candidateRect.bottom - contextSnapshot.bounds.top, safeContextHeight),
      _safeRatio(candidateRect.left - contextSnapshot.sourceBounds.left, sourceWidth),
      _safeRatio(candidateRect.top - contextSnapshot.sourceBounds.top, sourceHeight),
      _safeRatio(candidateRect.right - contextSnapshot.sourceBounds.left, sourceWidth),
      _safeRatio(candidateRect.bottom - contextSnapshot.sourceBounds.top, sourceHeight),
      _safeRatio(candidateCenter.dx - contextCenter.dx, safeContextWidth),
      _safeRatio(candidateCenter.dy - contextCenter.dy, safeContextHeight),
      _safeRatio(candidateCenter.dx - sourceCenter.dx, sourceWidth),
      _safeRatio(candidateCenter.dy - sourceCenter.dy, sourceHeight),
      _safeRatio((freeSpaceBounds?.left ?? contextSnapshot.bounds.left) - contextSnapshot.bounds.left, safeContextWidth),
      _safeRatio((freeSpaceBounds?.top ?? contextSnapshot.bounds.top) - contextSnapshot.bounds.top, safeContextHeight),
      _safeRatio((freeSpaceBounds?.right ?? contextSnapshot.bounds.left) - contextSnapshot.bounds.left, safeContextWidth),
      _safeRatio((freeSpaceBounds?.bottom ?? contextSnapshot.bounds.top) - contextSnapshot.bounds.top, safeContextHeight),
      _safeRatio(freeArea, contextArea),
      _safeValue(contextSnapshot.contextWidth),
      _safeValue(contextSnapshot.contextHeight),
      _safeValue(crossesSourceTile ? 1 : 0),
      _safeValue(sourceOffsetX),
      _safeValue(sourceOffsetY),
      _safeValue(sourceToCandidateTileDx),
      _safeValue(sourceToCandidateTileDy),
      _safeValue(candidate.heuristicScore),
      _safeValue(candidateNodeOverlapCount),
      _safeValue(candidateNodeOverlapAreaRatio.clamp(0.0, 1.0)),
      _safeValue(candidateEdgeIntersectionCount),
      _safeValue(candidateIncidentArrowLengthRatio),
      _safeValue(totalConnectionCount),
      _safeValue(context?.incidentArrowCount.toDouble() ?? incidentArrows.length.toDouble()),
      _safeValue(_typeFeature(node, qTypes, 'bo')),
      _safeValue(_typeFeature(node, qTypes, 'group')),
      _safeValue(_typeFeature(node, qTypes, 'enum')),
      _safeValue(_typeFeature(node, qTypes, 'swimlane')),
      _safeValue(nodeConnectionsBefore.left.toDouble() + attributeConnectionsBefore.left.toDouble()),
      _safeValue(nodeConnectionsBefore.right.toDouble() + attributeConnectionsBefore.right.toDouble()),
      _safeValue(nodeConnectionsBefore.top.toDouble() + attributeConnectionsBefore.top.toDouble()),
      _safeValue(nodeConnectionsBefore.bottom.toDouble() + attributeConnectionsBefore.bottom.toDouble()),
      _safeRatio(nodeConnectionsBefore.left.toDouble() + attributeConnectionsBefore.left.toDouble(), totalSideConnectionsBefore),
      _safeRatio(nodeConnectionsBefore.right.toDouble() + attributeConnectionsBefore.right.toDouble(), totalSideConnectionsBefore),
      _safeRatio(nodeConnectionsBefore.top.toDouble() + attributeConnectionsBefore.top.toDouble(), totalSideConnectionsBefore),
      _safeRatio(nodeConnectionsBefore.bottom.toDouble() + attributeConnectionsBefore.bottom.toDouble(), totalSideConnectionsBefore),
      _safeValue(nodeConnectionsAfter.left.toDouble() + attributeConnectionsAfter.left.toDouble()),
      _safeValue(nodeConnectionsAfter.right.toDouble() + attributeConnectionsAfter.right.toDouble()),
      _safeValue(nodeConnectionsAfter.top.toDouble() + attributeConnectionsAfter.top.toDouble()),
      _safeValue(nodeConnectionsAfter.bottom.toDouble() + attributeConnectionsAfter.bottom.toDouble()),
      _safeRatio(nodeConnectionsAfter.left.toDouble() + attributeConnectionsAfter.left.toDouble(), totalSideConnectionsAfter),
      _safeRatio(nodeConnectionsAfter.right.toDouble() + attributeConnectionsAfter.right.toDouble(), totalSideConnectionsAfter),
      _safeRatio(nodeConnectionsAfter.top.toDouble() + attributeConnectionsAfter.top.toDouble(), totalSideConnectionsAfter),
      _safeRatio(nodeConnectionsAfter.bottom.toDouble() + attributeConnectionsAfter.bottom.toDouble(), totalSideConnectionsAfter),
      _safeValue(sourceNodeOverlapCount),
      _safeValue(sourceEdgeIntersectionCount),
      _safeValue(sourceEdgeCrossings),
      _safeRatio(sourceIncidentArrowLength, maxContextSide),
      _safeValue(resultNodeOverlapCount),
      _safeValue(resultEdgeIntersectionCount),
      _safeValue(resultEdgeCrossings),
      _safeRatio(resultIncidentArrowLength, maxContextSide),
      _safeValue(resultNodeOverlapCount - sourceNodeOverlapCount),
      _safeValue(resultEdgeIntersectionCount - sourceEdgeIntersectionCount),
      _safeValue(resultEdgeCrossings - sourceEdgeCrossings),
      _safeRatio(resultIncidentArrowLength - sourceIncidentArrowLength, maxContextSide),
    ],
    schemaVersion: 4,
    );
  }
}
