import 'dart:ui';

import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_request.dart';

class LayoutCandidateGenerator {
  const LayoutCandidateGenerator();

  List<LayoutCandidate> generate(LayoutSearchRequest request) {
    final candidates = <LayoutCandidate>[];
    final seenKeys = <String>{};
    final origin = request.node.aPosition ?? request.node.position;

    void addCandidate(Offset position, {double heuristicScore = 0}) {
      final constrained = _constrainPosition(request.searchBounds, position, request.node.size);
      final key = '${constrained.dx.toStringAsFixed(2)}:${constrained.dy.toStringAsFixed(2)}';
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

    for (final freeRect in request.freeSpaceRects) {
      addCandidate(freeRect.topLeft, heuristicScore: 4);
      addCandidate(Offset(freeRect.center.dx - request.node.size.width / 2, freeRect.center.dy - request.node.size.height / 2), heuristicScore: 5);
      addCandidate(Offset(freeRect.right - request.node.size.width, freeRect.bottom - request.node.size.height), heuristicScore: 3);
    }

    candidates.sort((a, b) => b.heuristicScore.compareTo(a.heuristicScore));
    if (candidates.length <= request.maxCandidates) {
      return candidates;
    }

    return candidates.take(request.maxCandidates).toList(growable: false);
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
