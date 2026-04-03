import 'dart:math';
import 'dart:ui';

import 'package:fbpmn/src/editor_state.dart';
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
import 'package:fbpmn/src/micro_layout/services/runtime_tile_snapshot_factory.dart';
import 'package:fbpmn/src/micro_layout/services/training_sample_repository.dart';
import 'package:fbpmn/src/models/image_tile.dart';
import 'package:fbpmn/src/models/table.node.dart';
import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/services/tile_manager.dart';

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

  Future<void> run({MicroLayoutModel? model}) async {
    final planner = MicroLayoutPlanner(
      candidateGenerator: const LayoutCandidateGenerator(),
      featureExtractor: const CandidateFeatureExtractor(),
      evaluator: RuntimeLayoutSimulationEvaluator(
        state: state,
        nodeManager: nodeManager,
        arrowManager: arrowManager,
      ),
      model: model,
    );

    final snapshotFactory = RuntimeTileSnapshotFactory(state: state);
    final processedNodeIds = <String>{};

    for (final tile in state.imageTiles.values) {
      final tileNodes = _resolveTileNodes(tile);
      if (tileNodes.isEmpty) {
        continue;
      }

      final tileSnapshot = snapshotFactory.create(tile);
      for (final node in tileNodes) {
        if (!processedNodeIds.add(node.id)) {
          continue;
        }

        final incidentArrows = arrowManager.getArrowsForNodes(<TableNode?>[node]).whereType<Arrow>().toList(growable: false);
        final request = LayoutSearchRequest(
          node: node,
          tileSnapshot: tileSnapshot,
          nearbyNodes: tileNodes,
          incidentArrows: incidentArrows,
          freeSpaceRects: _buildFreeSpaceRects(tile, tileNodes, node),
          searchBounds: tile.bounds,
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

        nodeManager.updateNodePositionForLayout(node, bestCandidate.candidatePosition);
        for (final arrow in incidentArrows) {
          arrowManager.getArrowPathInTile(arrow, state.delta);
        }
        await tileManager.recreateTiles(
          nodeIds: <String>[node.id],
          arrowIds: incidentArrows.map((arrow) => arrow.id).toList(growable: false),
        );
        await _storeSamples(request, result, acceptedCandidateNodeId: node.id);
      }
    }
  }

  List<TableNode> _resolveTileNodes(ImageTile tile) {
    return NodeManager.whereAllNodes(state.nodes, (node) => tile.nodes.contains(node.id)).whereType<TableNode>().toList(growable: false);
  }

  List<Rect> _buildFreeSpaceRects(ImageTile tile, List<TableNode> tileNodes, TableNode currentNode) {
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
      tile.bounds.topLeft,
      Offset(tile.bounds.center.dx - currentNode.size.width / 2, tile.bounds.center.dy - currentNode.size.height / 2),
      Offset(tile.bounds.right - currentNode.size.width, tile.bounds.bottom - currentNode.size.height),
      Offset(tile.bounds.left, tile.bounds.bottom - currentNode.size.height),
      Offset(tile.bounds.right - currentNode.size.width, tile.bounds.top),
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
    final step = max(24.0, min(tile.bounds.width, tile.bounds.height) / 6);
    for (double y = tile.bounds.top; y <= tile.bounds.bottom - currentNode.size.height; y += step) {
      for (double x = tile.bounds.left; x <= tile.bounds.right - currentNode.size.width; x += step) {
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
}
