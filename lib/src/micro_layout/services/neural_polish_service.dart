import 'dart:math';
import 'dart:ui';

import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/tile_snapshot.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_result.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_request.dart';
import 'package:fbpmn/src/micro_layout/models/layout_training_sample.dart';
import 'package:fbpmn/src/models/arrow.dart';
import 'package:fbpmn/src/micro_layout/services/candidate_feature_extractor.dart';
import 'package:fbpmn/src/micro_layout/services/layout_candidate_generator.dart';
import 'package:fbpmn/src/micro_layout/services/indexed_db_training_sample_repository.dart';
import 'package:fbpmn/src/micro_layout/services/micro_layout_model.dart';
import 'package:fbpmn/src/micro_layout/services/micro_layout_planner.dart';
import 'package:fbpmn/src/micro_layout/services/runtime_layout_simulation_evaluator.dart';
import 'package:fbpmn/src/micro_layout/services/training_sample_repository.dart';
import 'package:fbpmn/src/models/table.node.dart';
import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:fbpmn/src/utils/editor_config.dart';

class NeuralPolishService {
  final EditorState state;
  final TileManager tileManager;
  final ArrowManager arrowManager;
  final NodeManager nodeManager;
  final TrainingSampleRepository repository;

  NeuralPolishService({
    required this.state,
    required this.tileManager,
    required this.arrowManager,
    required this.nodeManager,
    TrainingSampleRepository? repository,
  }) : repository = repository ?? InMemoryTrainingSampleRepository();

  factory NeuralPolishService.withIndexedDb({
    required EditorState state,
    required TileManager tileManager,
    required ArrowManager arrowManager,
    required NodeManager nodeManager,
  }) {
    return NeuralPolishService(
      state: state,
      tileManager: tileManager,
      arrowManager: arrowManager,
      nodeManager: nodeManager,
      repository: IndexedDbTrainingSampleRepository.createDefault(),
    );
  }

  Future<bool> hasStoredModel() async {
    final weights = await repository.getWeights();
    return weights != null;
  }

  Future<MicroLayoutModel?> loadStoredModel() async {
    final weights = await repository.getWeights();
    if (weights == null) {
      return null;
    }
    return MicroLayoutModel.fromWeights(weights);
  }

  Future<void> run({MicroLayoutModel? model, bool applyBestCandidate = true}) async {
    final resolvedModel = model ?? await loadStoredModel();
    final planner = MicroLayoutPlanner(
      candidateGenerator: const LayoutCandidateGenerator(),
      featureExtractor: const CandidateFeatureExtractor(),
      evaluator: RuntimeLayoutSimulationEvaluator(
        state: state,
        nodeManager: nodeManager,
        arrowManager: arrowManager,
      ),
      model: resolvedModel,
    );

    final processedNodeIds = <String>{};

    final allNodes = NodeManager.whereAllNodes(state.nodes, (_) => true).whereType<TableNode>().toList(growable: false);
    for (final node in allNodes) {
      if (!processedNodeIds.add(node.id)) {
        continue;
      }

      final runtimeTile = _buildRuntimeTileForNode(node, allNodes);
      final tileNodes = _resolveTileNodes(runtimeTile, allNodes);
      if (tileNodes.isEmpty) {
        continue;
      }

      final tileSnapshot = _createRuntimeTileSnapshot(runtimeTile, tileNodes);
      final incidentArrows = arrowManager.getArrowsForNodes(<TableNode?>[node]).whereType<Arrow>().toList(growable: false);
      final request = LayoutSearchRequest(
        node: node,
        tileSnapshot: tileSnapshot,
        nearbyNodes: tileNodes,
        incidentArrows: incidentArrows,
        freeSpaceRects: _buildFreeSpaceRects(runtimeTile.bounds, tileNodes, node),
        searchBounds: runtimeTile.bounds,
        maxCandidates: 20,
        topKForExactEvaluation: 5,
      );

      final result = await planner.findBestCandidate(request);
      final bestCandidate = result.bestCandidate;
      if (bestCandidate == null) {
        await _storeSamples(request, result, acceptedCandidateNodeId: null);
        continue;
      }

      final bestEvaluation = result.evaluatedCandidates.isEmpty ? null : result.evaluatedCandidates.first;
      if (bestEvaluation == null || !bestEvaluation.accepted || bestCandidate.movementDistance <= 0.01) {
        await _storeSamples(request, result, acceptedCandidateNodeId: null);
        continue;
      }

      if (applyBestCandidate) {
        nodeManager.updateNodePositionForLayout(node, bestCandidate.candidatePosition);
        for (final arrow in incidentArrows) {
          arrowManager.getArrowPathInTile(arrow, state.delta);
        }
        await tileManager.recreateTiles(
          nodeIds: <String>[node.id],
          arrowIds: incidentArrows.map((arrow) => arrow.id).toList(growable: false),
        );
      }
      await _storeSamples(request, result, acceptedCandidateNodeId: node.id);
    }
  }

  ({String id, Rect bounds, Set<String> nodes, Set<String> arrows}) _buildRuntimeTileForNode(
    TableNode node,
    List<TableNode> allNodes,
  ) {
    final tileWorldSize = EditorConfig.tileSize.toDouble();
    final position = node.aPosition ?? (state.delta + node.position);
    final gridX = (position.dx / tileWorldSize).floor();
    final gridY = (position.dy / tileWorldSize).floor();
    final left = gridX * tileWorldSize;
    final top = gridY * tileWorldSize;
    final bounds = Rect.fromLTWH(left, top, tileWorldSize, tileWorldSize);

    final nodeIds = allNodes
        .where((candidate) {
          final candidatePosition = candidate.aPosition ?? (state.delta + candidate.position);
          final candidateRect = Rect.fromLTWH(
            candidatePosition.dx,
            candidatePosition.dy,
            candidate.size.width,
            candidate.size.height,
          );
          return candidateRect.overlaps(bounds);
        })
        .map((candidate) => candidate.id)
        .toSet();

    final arrowIds = state.arrows
        .where((arrow) => nodeIds.contains(arrow.source) || nodeIds.contains(arrow.target))
        .map((arrow) => arrow.id)
        .toSet();

    return (
      id: '${left.toInt()}:${top.toInt()}',
      bounds: bounds,
      nodes: nodeIds,
      arrows: arrowIds,
    );
  }

  List<TableNode> _resolveTileNodes(
    ({String id, Rect bounds, Set<String> nodes, Set<String> arrows}) tile,
    List<TableNode> allNodes,
  ) {
    return allNodes.where((node) => tile.nodes.contains(node.id)).toList(growable: false);
  }

  TileSnapshot _createRuntimeTileSnapshot(
    ({String id, Rect bounds, Set<String> nodes, Set<String> arrows}) tile,
    List<TableNode> tileNodes,
  ) {
    final tileArea = tile.bounds.width * tile.bounds.height;
    var occupiedArea = 0.0;

    for (final node in tileNodes) {
      final position = node.aPosition ?? (state.delta + node.position);
      final intersection = Rect.fromLTWH(position.dx, position.dy, node.size.width, node.size.height).intersect(tile.bounds);
      occupiedArea += intersection.width * intersection.height;
    }

    final safeArea = tileArea <= 0 ? 1.0 : tileArea;
    final occupancyRatio = (occupiedArea / safeArea).clamp(0.0, 1.0);

    return TileSnapshot(
      tileId: tile.id,
      bounds: tile.bounds,
      nodeIds: tile.nodes.toList(growable: false),
      arrowIds: tile.arrows.toList(growable: false),
      occupancyRatio: occupancyRatio,
      freeAreaRatio: (1 - occupancyRatio).clamp(0.0, 1.0),
      localNodeDensity: tileNodes.length / safeArea,
    );
  }

  List<Rect> _buildFreeSpaceRects(Rect tileBounds, List<TableNode> tileNodes, TableNode currentNode) {
    final occupiedRects = tileNodes
        .where((node) => node.id != currentNode.id)
        .map((node) => Rect.fromLTWH(
              (node.aPosition ?? (state.delta + node.position)).dx,
              (node.aPosition ?? (state.delta + node.position)).dy,
              node.size.width,
              node.size.height,
            ))
        .toList(growable: false);

    final freeRects = <Rect>[];
    final anchorPoints = <Offset>[
      tileBounds.topLeft,
      Offset(tileBounds.center.dx - currentNode.size.width / 2, tileBounds.center.dy - currentNode.size.height / 2),
      Offset(tileBounds.right - currentNode.size.width, tileBounds.bottom - currentNode.size.height),
      Offset(tileBounds.left, tileBounds.bottom - currentNode.size.height),
      Offset(tileBounds.right - currentNode.size.width, tileBounds.top),
    ];

    for (final point in anchorPoints) {
      final rect = Rect.fromLTWH(point.dx, point.dy, currentNode.size.width, currentNode.size.height);
      final overlaps = occupiedRects.any((occupied) => occupied.overlaps(rect));
      if (!overlaps) {
        freeRects.add(rect);
      }
    }

    if (freeRects.isNotEmpty) {
      return freeRects;
    }

    final fallback = <Rect>[];
    final step = max(24.0, min(tileBounds.width, tileBounds.height) / 6);
    for (double y = tileBounds.top; y <= tileBounds.bottom - currentNode.size.height; y += step) {
      for (double x = tileBounds.left; x <= tileBounds.right - currentNode.size.width; x += step) {
        final rect = Rect.fromLTWH(x, y, currentNode.size.width, currentNode.size.height);
        if (!occupiedRects.any((occupied) => occupied.overlaps(rect))) {
          fallback.add(rect);
        }
      }
    }
    return fallback.take(12).toList(growable: false);
  }

  Future<void> _storeSamples(
    LayoutSearchRequest request,
    LayoutSearchResult result, {
    required String? acceptedCandidateNodeId,
  }) async {
    if (!state.autoLayoutTrainNeuralPolish) {
      return;
    }

    for (final evaluation in result.evaluatedCandidates) {
      final features = const CandidateFeatureExtractor().extract(
        node: request.node,
        candidate: evaluation.candidate,
        tileSnapshot: request.tileSnapshot,
        incidentArrows: request.incidentArrows,
        freeSpaceBounds: request.freeSpaceRects.isEmpty ? null : request.freeSpaceRects.first,
        localNodeDensity: request.nearbyNodes.length / max(1, request.tileSnapshot.bounds.width * request.tileSnapshot.bounds.height),
        localArrowDensity: request.incidentArrows.length / max(1, request.tileSnapshot.bounds.width * request.tileSnapshot.bounds.height),
      );

      final sample = LayoutTrainingSample(
        id: '${request.node.id}_${evaluation.candidate.candidatePosition.dx}_${evaluation.candidate.candidatePosition.dy}_${DateTime.now().microsecondsSinceEpoch}',
        nodeId: request.node.id,
        tileId: request.tileSnapshot.tileId,
        candidate: evaluation.candidate,
        features: features,
        metrics: evaluation.metrics,
        snapshot: request.tileSnapshot,
        targetScore: evaluation.exactScore,
        accepted: acceptedCandidateNodeId == request.node.id && evaluation.accepted,
        createdAt: DateTime.now(),
      );
      await repository.saveSample(sample);
    }
  }

  Future<void> saveAcceptedPlacementSample({
    required TableNode node,
    required Offset originPosition,
    required Offset candidatePosition,
    String sampleSource = 'polish',
  }) async {
    final isManualSample = sampleSource == 'manual';
    final isTrainingEnabled = isManualSample ? state.manualLayoutTrainNeuralPolish : state.autoLayoutTrainNeuralPolish;
    if (!isTrainingEnabled) {
      return;
    }

    final movementDistance = (candidatePosition - originPosition).distance;
    if (movementDistance <= 0.01) {
      return;
    }

    final actualAbsolutePosition = node.aPosition ?? (state.delta + node.position);
    final actualRelativePosition = node.position;
    if (isManualSample) {
      node.aPosition = originPosition;
      node.position = originPosition - state.delta;
    }

    try {
      final allNodes = NodeManager.whereAllNodes(state.nodes, (_) => true).whereType<TableNode>().toList(growable: true);
      final hasNode = allNodes.any((candidateNode) => candidateNode.id == node.id);
      if (!hasNode) {
        allNodes.add(node);
      }
      final runtimeTile = _buildRuntimeTileForPosition(candidatePosition, allNodes);
      final tileNodes = _resolveTileNodes(runtimeTile, allNodes).toList(growable: true);
      if (tileNodes.every((candidateNode) => candidateNode.id != node.id)) {
        tileNodes.add(node);
      }

      final tileSnapshot = _createRuntimeTileSnapshot(runtimeTile, tileNodes);
      final incidentArrows = arrowManager.getArrowsForNodes(<TableNode?>[node]).whereType<Arrow>().toList(growable: false);
      final request = LayoutSearchRequest(
        node: node,
        tileSnapshot: tileSnapshot,
        nearbyNodes: tileNodes,
        incidentArrows: incidentArrows,
        searchBounds: runtimeTile.bounds,
        freeSpaceRects: _buildFreeSpaceRects(runtimeTile.bounds, tileNodes, node),
      );
      final evaluator = RuntimeLayoutSimulationEvaluator(
        state: state,
        nodeManager: nodeManager,
        arrowManager: arrowManager,
      );
      final candidate = LayoutCandidate(
        nodeId: node.id,
        originPosition: originPosition,
        candidatePosition: candidatePosition,
        nodeSize: node.size,
        tileId: runtimeTile.id,
      );
      final evaluation = await evaluator.evaluate(request: request, candidate: candidate);
      final features = const CandidateFeatureExtractor().extract(
        node: node,
        candidate: candidate,
        tileSnapshot: tileSnapshot,
        incidentArrows: incidentArrows,
        localNodeDensity: tileNodes.length / max(1, tileSnapshot.bounds.width * tileSnapshot.bounds.height),
        localArrowDensity: incidentArrows.length / max(1, tileSnapshot.bounds.width * tileSnapshot.bounds.height),
      );

      final sample = LayoutTrainingSample(
        id: '${sampleSource}_${node.id}_${candidatePosition.dx}_${candidatePosition.dy}_${DateTime.now().microsecondsSinceEpoch}',
        nodeId: node.id,
        tileId: runtimeTile.id,
        candidate: candidate,
        features: features,
        metrics: evaluation.metrics,
        snapshot: tileSnapshot,
        targetScore: evaluation.exactScore,
        accepted: true,
        createdAt: DateTime.now(),
      );

      await repository.saveSample(
        sample,
      );
    } finally {
      if (isManualSample) {
        node.aPosition = actualAbsolutePosition;
        node.position = actualRelativePosition;
      }
    }
  }

  ({String id, Rect bounds, Set<String> nodes, Set<String> arrows}) _buildRuntimeTileForPosition(
    Offset position,
    List<TableNode> allNodes,
  ) {
    final tileWorldSize = EditorConfig.tileSize.toDouble();
    final gridX = (position.dx / tileWorldSize).floor();
    final gridY = (position.dy / tileWorldSize).floor();
    final left = gridX * tileWorldSize;
    final top = gridY * tileWorldSize;
    final bounds = Rect.fromLTWH(left, top, tileWorldSize, tileWorldSize);

    final nodeIds = allNodes
        .where((candidate) {
          final candidatePosition = candidate.aPosition ?? (state.delta + candidate.position);
          final candidateRect = Rect.fromLTWH(
            candidatePosition.dx,
            candidatePosition.dy,
            candidate.size.width,
            candidate.size.height,
          );
          return candidateRect.overlaps(bounds);
        })
        .map((candidate) => candidate.id)
        .toSet();

    final arrowIds = state.arrows
        .where((arrow) => nodeIds.contains(arrow.source) || nodeIds.contains(arrow.target))
        .map((arrow) => arrow.id)
        .toSet();

    return (
      id: '${left.toInt()}:${top.toInt()}',
      bounds: bounds,
      nodes: nodeIds,
      arrows: arrowIds,
    );
  }
}
