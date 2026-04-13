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

  static const int featureCount = 109;

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
    List<TableNode> nearbyNodes = const <TableNode>[],
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
      ..._computeGroupAFeatures(
        node: node,
        candidateRect: candidateRect,
        candidateCenter: candidateCenter,
        nearbyNodes: nearbyNodes,
        incidentArrows: incidentArrows,
        maxContextSide: maxContextSide,
      ),
      _safeValue((context?.graphNodeCount ?? 0) / 200.0),
      _safeValue((context?.graphEdgeCount ?? 0) / 200.0),
      _safeValue((context?.graphConflictRatio ?? 0).clamp(0.0, 1.0)),
      _safeValue((context?.sequenceIndex ?? 0) / 50.0),
    ],
    schemaVersion: 5,
    );
  }

  List<double> _computeGroupAFeatures({
    required TableNode node,
    required Rect candidateRect,
    required Offset candidateCenter,
    required List<TableNode> nearbyNodes,
    required List<Arrow> incidentArrows,
    required double maxContextSide,
  }) {
    final safeMaxSide = maxContextSide > 0.001 ? maxContextSide : 1.0;
    final neighbors = nearbyNodes.where((n) => n.id != node.id).toList(growable: false);
    final neighborCount = max(1, neighbors.length);

    // --- Alignment (3 features) ---
    const alignThreshold = 4.0;
    var hAlignCount = 0;
    var vAlignCount = 0;
    var bestAlignGap = double.infinity;

    for (final neighbor in neighbors) {
      final nPos = neighbor.aPosition ?? neighbor.position;
      final nRect = Rect.fromLTWH(nPos.dx, nPos.dy, neighbor.size.width, neighbor.size.height);

      final hGap = min(
        (candidateRect.top - nRect.top).abs(),
        min((candidateRect.center.dy - nRect.center.dy).abs(),
            (candidateRect.bottom - nRect.bottom).abs()),
      );
      if (hGap < alignThreshold) hAlignCount++;
      bestAlignGap = min(bestAlignGap, hGap);

      final vGap = min(
        (candidateRect.left - nRect.left).abs(),
        min((candidateRect.center.dx - nRect.center.dx).abs(),
            (candidateRect.right - nRect.right).abs()),
      );
      if (vGap < alignThreshold) vAlignCount++;
      bestAlignGap = min(bestAlignGap, vGap);
    }
    if (!bestAlignGap.isFinite) bestAlignGap = safeMaxSide;

    // --- Edge-to-edge clearance (2 features) ---
    var minClearance = double.infinity;
    var totalClearance = 0.0;

    for (final neighbor in neighbors) {
      final nPos = neighbor.aPosition ?? neighbor.position;
      final nRect = Rect.fromLTWH(nPos.dx, nPos.dy, neighbor.size.width, neighbor.size.height);
      final dx = max(0.0, max(nRect.left - candidateRect.right, candidateRect.left - nRect.right));
      final dy = max(0.0, max(nRect.top - candidateRect.bottom, candidateRect.top - nRect.bottom));
      final clearance = sqrt(dx * dx + dy * dy);
      minClearance = min(minClearance, clearance);
      totalClearance += clearance;
    }
    if (!minClearance.isFinite) minClearance = 0.0;
    final avgClearance = neighbors.isNotEmpty ? totalClearance / neighbors.length : 0.0;

    // --- Neighbor type distribution (4 features) ---
    var neighborBo = 0;
    var neighborGroup = 0;
    var neighborEnum = 0;
    var neighborSwimlane = 0;

    for (final neighbor in neighbors) {
      switch (neighbor.qType) {
        case 'bo':
          neighborBo++;
          break;
        case 'group':
          neighborGroup++;
          break;
        case 'enum':
          neighborEnum++;
          break;
        case 'swimlane':
          neighborSwimlane++;
          break;
      }
    }

    // --- Same-type clustering (2 features) ---
    var sameTypeCount = 0;
    var sameTypeTotalDist = 0.0;

    for (final neighbor in neighbors) {
      if (neighbor.qType == node.qType) {
        sameTypeCount++;
        final nPos = neighbor.aPosition ?? neighbor.position;
        final nCenter = Offset(nPos.dx + neighbor.size.width / 2, nPos.dy + neighbor.size.height / 2);
        sameTypeTotalDist += (candidateCenter - nCenter).distance;
      }
    }
    final sameTypeAvgDist = sameTypeCount > 0 ? sameTypeTotalDist / sameTypeCount : 0.0;

    // --- Flow direction (4 features) ---
    var incomingCount = 0;
    var outgoingCount = 0;
    var flowDirX = 0.0;
    var flowDirY = 0.0;

    final nodeById = <String, TableNode>{};
    for (final n in nearbyNodes) {
      nodeById[n.id] = n;
    }

    for (final arrow in incidentArrows) {
      final isSource = arrow.source == node.id;
      if (isSource) {
        outgoingCount++;
      } else {
        incomingCount++;
      }

      final otherNodeId = isSource ? arrow.target : arrow.source;
      final otherNode = nodeById[otherNodeId];
      Offset otherCenter;
      if (otherNode != null) {
        final otherPos = otherNode.aPosition ?? otherNode.position;
        otherCenter = Offset(otherPos.dx + otherNode.size.width / 2, otherPos.dy + otherNode.size.height / 2);
      } else {
        otherCenter = isSource ? arrow.aPositionTarget : arrow.aPositionSource;
        if (otherCenter == Offset.zero) continue;
      }

      final dir = isSource ? (otherCenter - candidateCenter) : (candidateCenter - otherCenter);
      flowDirX += dir.dx;
      flowDirY += dir.dy;
    }

    final totalIncident = max(1, incomingCount + outgoingCount);
    final flowLen = sqrt(flowDirX * flowDirX + flowDirY * flowDirY);
    final safeFlowLen = flowLen > 0.001 ? flowLen : 1.0;

    // --- Hierarchy (2 features) ---
    final hasParent = node.parent != null ? 1.0 : 0.0;
    final childrenCountNorm = (node.children?.length ?? 0) / max(1.0, neighborCount.toDouble());

    // --- Arrow complexity (1 feature) ---
    var totalWaypoints = 0;
    for (final arrow in incidentArrows) {
      totalWaypoints += arrow.coordinates?.length ?? 0;
    }
    final avgWaypoints = incidentArrows.isNotEmpty ? totalWaypoints / incidentArrows.length : 0.0;

    // --- Spacing variance (2 features) ---
    final distances = <double>[];
    for (final neighbor in neighbors) {
      final nPos = neighbor.aPosition ?? neighbor.position;
      final nCenter = Offset(nPos.dx + neighbor.size.width / 2, nPos.dy + neighbor.size.height / 2);
      distances.add((candidateCenter - nCenter).distance);
    }

    var spacingVariance = 0.0;
    var spacingUniformity = 0.0;
    if (distances.length >= 2) {
      final mean = distances.reduce((a, b) => a + b) / distances.length;
      final variance = distances.map((d) => (d - mean) * (d - mean)).reduce((a, b) => a + b) / distances.length;
      spacingVariance = variance;
      spacingUniformity = mean > 0.001 ? (1.0 - min(1.0, sqrt(variance) / mean)).clamp(0.0, 1.0) : 0.0;
    }

    return <double>[
      _safeValue(hAlignCount / neighborCount),
      _safeValue(vAlignCount / neighborCount),
      _safeRatio(bestAlignGap, safeMaxSide),
      _safeRatio(minClearance, safeMaxSide),
      _safeRatio(avgClearance, safeMaxSide),
      _safeValue(neighborBo / neighborCount),
      _safeValue(neighborGroup / neighborCount),
      _safeValue(neighborEnum / neighborCount),
      _safeValue(neighborSwimlane / neighborCount),
      _safeValue(sameTypeCount / neighborCount),
      _safeRatio(sameTypeAvgDist, safeMaxSide),
      _safeValue(incomingCount / totalIncident),
      _safeValue(outgoingCount / totalIncident),
      _safeValue((flowDirX / safeFlowLen).clamp(-1.0, 1.0)),
      _safeValue((flowDirY / safeFlowLen).clamp(-1.0, 1.0)),
      _safeValue(hasParent),
      _safeValue(childrenCountNorm),
      _safeValue(avgWaypoints / 10.0),
      _safeRatio(spacingVariance, safeMaxSide * safeMaxSide),
      _safeValue(spacingUniformity),
    ];
  }
}
