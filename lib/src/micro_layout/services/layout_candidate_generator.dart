import 'dart:ui';

import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_request.dart';
import 'package:fbpmn/src/models/table.node.dart';

class LayoutCandidateGenerator {
  const LayoutCandidateGenerator();

  List<LayoutCandidate> generate(LayoutSearchRequest request) {
    final candidates = <LayoutCandidate>[];
    final seenKeys = <String>{};
    final origin = request.node.aPosition ?? request.node.position;
    final nodeW = request.node.size.width;
    final nodeH = request.node.size.height;

    void addCandidate(Offset position, {double heuristicScore = 0}) {
      final constrained = _constrainPosition(request.searchBounds, position, request.node.size);
      final key = '${constrained.dx.toStringAsFixed(1)}:${constrained.dy.toStringAsFixed(1)}';
      if (!seenKeys.add(key)) {
        return;
      }

      candidates.add(
        LayoutCandidate(
          originPosition: origin,
          candidatePosition: constrained,
          nodeSize: request.node.size,
          heuristicScore: heuristicScore,
        ),
      );
    }

    addCandidate(origin, heuristicScore: 1);

    final gridStep = request.gridStep;
    if (gridStep > 1) {
      final snappedX = (origin.dx / gridStep).round() * gridStep;
      final snappedY = (origin.dy / gridStep).round() * gridStep;
      addCandidate(Offset(snappedX.toDouble(), snappedY.toDouble()), heuristicScore: 2);
    }

    for (final freeRect in request.freeSpaceRects) {
      addCandidate(freeRect.topLeft, heuristicScore: 4);
      addCandidate(Offset(freeRect.center.dx - nodeW / 2, freeRect.center.dy - nodeH / 2), heuristicScore: 5);
      addCandidate(Offset(freeRect.right - nodeW, freeRect.bottom - nodeH), heuristicScore: 3);
    }

    final maxAlignCandidates = (request.maxCandidates * 0.4).round();
    var alignCount = 0;
    for (final neighbor in request.nearbyNodes) {
      if (neighbor.id == request.node.id || alignCount >= maxAlignCandidates) break;
      final nPos = _nodePosition(neighbor);

      addCandidate(Offset(nPos.dx, origin.dy), heuristicScore: 3);
      addCandidate(Offset(origin.dx, nPos.dy), heuristicScore: 3);

      final nCenter = Offset(nPos.dx + neighbor.size.width / 2, nPos.dy + neighbor.size.height / 2);
      addCandidate(Offset(nCenter.dx - nodeW / 2, origin.dy), heuristicScore: 3.5);
      addCandidate(Offset(origin.dx, nCenter.dy - nodeH / 2), heuristicScore: 3.5);

      alignCount += 4;
    }

    candidates.sort((a, b) => b.heuristicScore.compareTo(a.heuristicScore));
    if (candidates.length <= request.maxCandidates) {
      return candidates;
    }

    return candidates.take(request.maxCandidates).toList(growable: false);
  }

  Offset _nodePosition(TableNode node) {
    return node.aPosition ?? node.position;
  }

  Offset _constrainPosition(Rect bounds, Offset position, Size size) {
    final maxX = bounds.right - size.width;
    final maxY = bounds.bottom - size.height;

    return Offset(
      position.dx.clamp(bounds.left, maxX).toDouble(),
      position.dy.clamp(bounds.top, maxY).toDouble(),
    );
  }
}
