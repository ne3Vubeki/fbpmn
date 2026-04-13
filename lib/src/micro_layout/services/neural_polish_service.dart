import 'dart:math';
import 'dart:ui';

import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/layout_context_snapshot.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_request.dart';
import 'package:fbpmn/src/micro_layout/models/layout_training_sample.dart';
import 'package:fbpmn/src/micro_layout/models/layout_training_context.dart';
import 'package:fbpmn/src/models/arrow.dart';
import 'package:fbpmn/src/models/attribute.dart';
import 'package:fbpmn/src/models/connections.dart';
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
  static const double _minimumAppliedMovementDistance = 8.0;
  static const int _minAnimationFrames = 2;
  static const int _maxAnimationFrames = 6;
  static const int _animationFrameMillis = 24;
  static const int _progressUpdateStride = 2;
  static const int _animationHeavyUpdateStride = 3;
  static const int _maxGlobalPasses = 3;
  static const int _maxLocalRequeuesPerNode = 2;
  static const int _yieldEveryNNodes = 2;

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
  }) : repository = repository ?? IndexedDbTrainingSampleRepository.createDefault();

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
    if (weights == null) {
      return false;
    }
    return weights.inputSize == CandidateFeatureExtractor.featureCount;
  }

  Future<MicroLayoutModel?> loadStoredModel() async {
    final weights = await repository.getWeights();
    if (weights == null) {
      return null;
    }
    if (weights.inputSize != CandidateFeatureExtractor.featureCount) {
      print('[NEURAL_POLISH] loadStoredModel_skip reason=inputSize_mismatch '
          'expected=${CandidateFeatureExtractor.featureCount} got=${weights.inputSize}');
      return null;
    }
    return MicroLayoutModel.fromWeights(weights);
  }

  Future<void> run({
    MicroLayoutModel? model,
    bool applyBestCandidate = true,
    Set<String>? activeNodeIds,
    Rect? fixedSearchBounds,
  }) async {
    final resolvedModel = model ?? await loadStoredModel();
    if (resolvedModel == null) {
      print('[NEURAL_POLISH] run_skip reason=model_not_found');
      return;
    }

    final allNodes = NodeManager.whereAllNodes(state.nodes, (_) => true).whereType<TableNode>().toList(growable: false);
    final allArrows = state.arrows.whereType<Arrow>().toList(growable: false);
    final schemaBounds = fixedSearchBounds ?? _buildSchemaBounds(allNodes);
    final incidentArrowsByNodeId = _buildIncidentArrowsByNodeId(allArrows);
    final conflictNodeIds = activeNodeIds == null
        ? _resolveConflictNodeIds(allNodes, allArrows, incidentArrowsByNodeId)
        : <String>{...activeNodeIds};
    final movableNodes = allNodes.where((node) => conflictNodeIds.contains(node.id)).toList(growable: false);
    if (movableNodes.isEmpty) {
      print('[NEURAL_POLISH] run_skip reason=no_conflict_nodes');
      return;
    }
    print(
      '[NEURAL_POLISH] run_start applyBestCandidate=$applyBestCandidate '
      'nodes=${movableNodes.length}',
    );
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

    final movableNodeIds = movableNodes.map((node) => node.id).toSet();
    final localRequeueCounts = <String, int>{};
    final processedNodeIds = <String>{};
    var progressStep = 0;
    final totalSteps = max(1, movableNodes.length);

    for (var passIndex = 0; passIndex < _maxGlobalPasses; passIndex++) {
      final queue = <TableNode>[...movableNodes];
      final queuedNodeIds = queue.map((node) => node.id).toSet();
      var movedInPass = false;

      while (queue.isNotEmpty) {
        final node = queue.removeAt(0);
        queuedNodeIds.remove(node.id);
        processedNodeIds.add(node.id);

        final visibleProgress = min(processedNodeIds.length, totalSteps);
        state.currentLayoutProcessProgress = (visibleProgress * 100 / totalSteps).clamp(0, 100).toDouble();
        if (progressStep == 0 || progressStep % _progressUpdateStride == 0) {
          tileManager.onStateUpdate();
          nodeManager.onStateUpdate();
          arrowManager.onStateUpdate();
        }
        progressStep += 1;

        if (progressStep % _yieldEveryNNodes == 0) {
          await Future<void>.delayed(Duration.zero);
        }

        if (!conflictNodeIds.contains(node.id)) {
          continue;
        }

        final runtimeContext = _buildRuntimeContextForNode(node, allNodes, schemaBounds);
        final incidentArrows = incidentArrowsByNodeId[node.id] ?? const <Arrow>[];
        final contextNodes = _resolveContextNodes(runtimeContext, allNodes, node, incidentArrows);
        if (contextNodes.isEmpty) {
          continue;
        }

        final contextSnapshot = _createRuntimeContextSnapshot(runtimeContext, contextNodes);
        final contextArrows = _resolveContextArrows(runtimeContext, contextNodes, incidentArrows);
        final graphConflictRatio = allNodes.isNotEmpty ? conflictNodeIds.length / allNodes.length : 0.0;
        final request = LayoutSearchRequest(
          node: node,
          contextSnapshot: contextSnapshot,
          nearbyNodes: contextNodes,
          incidentArrows: incidentArrows,
          contextArrows: contextArrows,
          freeSpaceRects: _buildFreeSpaceRects(runtimeContext.bounds, contextNodes, node, contextArrows),
          searchBounds: runtimeContext.bounds,
          maxCandidates: 48,
          topKForExactEvaluation: 12,
          graphNodeCount: allNodes.length,
          graphEdgeCount: allArrows.length,
          graphConflictRatio: graphConflictRatio,
        );

        final result = await planner.findBestCandidate(request);
        final bestCandidate = result.bestCandidate;
        if (bestCandidate == null) {
          continue;
        }

        final bestEvaluation = result.evaluatedCandidates.isEmpty ? null : result.evaluatedCandidates.first;
        if (bestEvaluation == null || !bestEvaluation.accepted || bestCandidate.movementDistance < _minimumAppliedMovementDistance) {
          continue;
        }

        arrowManager.recalculateSelectedArrows();
        final globalValidation = _captureContextSnapshot(
          node: node,
          candidatePosition: bestCandidate.candidatePosition,
          nearbyNodes: allNodes,
          incidentArrows: incidentArrows,
          contextArrows: allArrows,
        );
        if (globalValidation.isConflictNode) {
          continue;
        }

        if (applyBestCandidate) {
          await _animateNodeToTarget(
            node: node,
            targetPosition: bestCandidate.candidatePosition,
          );
        }
        movedInPass = true;

        final affectedNodes = _resolveAffectedMovableNodes(
          movedNode: node,
          runtimeContext: runtimeContext,
          contextNodes: contextNodes,
          contextArrows: contextArrows,
          movableNodeIds: movableNodeIds,
          conflictNodeIds: conflictNodeIds,
        );
        for (final affectedNode in affectedNodes) {
          if (affectedNode.id == node.id || queuedNodeIds.contains(affectedNode.id)) {
            continue;
          }
          final nextCount = (localRequeueCounts[affectedNode.id] ?? 0) + 1;
          if (nextCount > _maxLocalRequeuesPerNode) {
            continue;
          }
          localRequeueCounts[affectedNode.id] = nextCount;
          queue.add(affectedNode);
          queuedNodeIds.add(affectedNode.id);
        }
      }

      if (!movedInPass) {
        break;
      }
    }

    state.currentLayoutProcessProgress = 100;
    tileManager.onStateUpdate();
    nodeManager.onStateUpdate();
    arrowManager.onStateUpdate();

    print('[NEURAL_POLISH] run_end processed=${processedNodeIds.length}');
  }

  List<TableNode> _resolveAffectedMovableNodes({
    required TableNode movedNode,
    required ({String id, Rect bounds, Rect sourceBounds, Set<String> nodes, Set<String> arrows}) runtimeContext,
    required List<TableNode> contextNodes,
    required List<Arrow> contextArrows,
    required Set<String> movableNodeIds,
    required Set<String> conflictNodeIds,
  }) {
    final affectedNodeIds = <String>{};

    for (final contextNode in contextNodes) {
      if (contextNode.id != movedNode.id && movableNodeIds.contains(contextNode.id)) {
        affectedNodeIds.add(contextNode.id);
      }
    }

    for (final arrow in contextArrows) {
      if (arrow.source != movedNode.id && movableNodeIds.contains(arrow.source)) {
        affectedNodeIds.add(arrow.source);
      }
      if (arrow.target != movedNode.id && movableNodeIds.contains(arrow.target)) {
        affectedNodeIds.add(arrow.target);
      }
    }

    final affectedNodes = state.nodes
        .whereType<TableNode>()
        .where((node) => affectedNodeIds.contains(node.id))
        .where((node) => conflictNodeIds.contains(node.id))
        .toList(growable: false);

    return affectedNodes;
  }

  Future<void> _animateNodeToTarget({
    required TableNode node,
    required Offset targetPosition,
  }) async {
    final tolerance = max(1.0, EditorConfig.tileSize * 0.005);
    final current = node.aPosition ?? (state.delta + node.position);
    final distance = (targetPosition - current).distance;
    if (distance <= tolerance) {
      nodeManager.updateNodePositionForLayout(node, targetPosition);
      arrowManager.recalculateSelectedArrows();
      tileManager.onStateUpdate();
      nodeManager.onStateUpdate();
      arrowManager.onStateUpdate();
      return;
    }

    final steps = (distance / max(48.0, EditorConfig.tileSize * 0.75))
        .round()
        .clamp(_minAnimationFrames, _maxAnimationFrames);

    for (var step = 1; step <= steps; step++) {
      final t = step / steps;
      final nextPosition = Offset.lerp(current, targetPosition, t) ?? targetPosition;
      nodeManager.updateNodePositionForLayout(node, nextPosition);
      nodeManager.onStateUpdate();
      if (step == steps || step % _animationHeavyUpdateStride == 0) {
        arrowManager.recalculateSelectedArrows();
        tileManager.onStateUpdate();
        arrowManager.onStateUpdate();
      }
      await Future<void>.delayed(const Duration(milliseconds: _animationFrameMillis));
    }

    nodeManager.updateNodePositionForLayout(node, targetPosition);
    arrowManager.recalculateSelectedArrows();
    tileManager.onStateUpdate();
    nodeManager.onStateUpdate();
    arrowManager.onStateUpdate();
  }

  ({String id, Rect bounds, Rect sourceBounds, Set<String> nodes, Set<String> arrows}) _buildRuntimeContextForNode(
    TableNode node,
    List<TableNode> allNodes,
    Rect schemaBounds,
  ) {
    final cellWorldSize = EditorConfig.tileSize.toDouble();
    final position = node.aPosition ?? (state.delta + node.position);
    final gridX = (position.dx / cellWorldSize).floor();
    final gridY = (position.dy / cellWorldSize).floor();
    final sourceLeft = gridX * cellWorldSize;
    final sourceTop = gridY * cellWorldSize;
    final sourceBounds = Rect.fromLTWH(sourceLeft, sourceTop, cellWorldSize, cellWorldSize);
    final bounds = _expandSearchBoundsForNode(schemaBounds, node.size);
    final nodeIds = allNodes.map((candidate) => candidate.id).toSet();
    final arrowIds = state.arrows.map((arrow) => arrow.id).toSet();

    return (
      id: 'runtime_${gridX}_$gridY',
      bounds: bounds,
      sourceBounds: sourceBounds,
      nodes: nodeIds,
      arrows: arrowIds,
    );
  }

  List<Arrow> _resolveContextArrows(
    ({String id, Rect bounds, Rect sourceBounds, Set<String> nodes, Set<String> arrows}) runtimeContext,
    List<TableNode> contextNodes,
    List<Arrow> incidentArrows,
  ) {
    final contextNodeIds = contextNodes.map((node) => node.id).toSet();
    final contextArrows = <Arrow>[];
    final seenArrowIds = <String>{};

    for (final arrow in incidentArrows) {
      if (seenArrowIds.add(arrow.id)) {
        contextArrows.add(arrow);
      }
    }

    for (final arrow in state.arrows) {
      final isRuntimeArrow = runtimeContext.arrows.contains(arrow.id);
      final touchesContextNode = contextNodeIds.contains(arrow.source) || contextNodeIds.contains(arrow.target);
      if ((isRuntimeArrow || touchesContextNode) && seenArrowIds.add(arrow.id)) {
        contextArrows.add(arrow);
      }
    }

    return contextArrows;
  }

  List<TableNode> _resolveContextNodes(
    ({String id, Rect bounds, Rect sourceBounds, Set<String> nodes, Set<String> arrows}) context,
    List<TableNode> allNodes,
    TableNode targetNode,
    List<Arrow> incidentArrows,
  ) {
    final connectedNodeIds = <String>{targetNode.id};
    for (final arrow in incidentArrows) {
      connectedNodeIds.add(arrow.source);
      connectedNodeIds.add(arrow.target);
    }

    final targetPosition = targetNode.aPosition ?? (state.delta + targetNode.position);
    final localBounds = Rect.fromCenter(
      center: Offset(targetPosition.dx + targetNode.size.width / 2, targetPosition.dy + targetNode.size.height / 2),
      width: max(EditorConfig.tileSize * 6.0, targetNode.size.width + EditorConfig.tileSize * 4.0),
      height: max(EditorConfig.tileSize * 6.0, targetNode.size.height + EditorConfig.tileSize * 4.0),
    ).intersect(context.bounds);

    return allNodes.where((node) {
      if (!context.nodes.contains(node.id)) {
        return false;
      }
      if (connectedNodeIds.contains(node.id)) {
        return true;
      }
      final position = node.aPosition ?? (state.delta + node.position);
      final nodeRect = Rect.fromLTWH(position.dx, position.dy, node.size.width, node.size.height);
      return nodeRect.overlaps(localBounds);
    }).toList(growable: false);
  }

  LayoutContextSnapshot _createRuntimeContextSnapshot(
    ({String id, Rect bounds, Rect sourceBounds, Set<String> nodes, Set<String> arrows}) context,
    List<TableNode> contextNodes,
  ) {
    final contextArea = context.bounds.width * context.bounds.height;
    var occupiedArea = 0.0;

    for (final node in contextNodes) {
      final position = node.aPosition ?? (state.delta + node.position);
      final intersection = Rect.fromLTWH(position.dx, position.dy, node.size.width, node.size.height).intersect(context.bounds);
      occupiedArea += intersection.width * intersection.height;
    }

    final safeArea = contextArea <= 0 ? 1.0 : contextArea;
    final occupancyRatio = (occupiedArea / safeArea).clamp(0.0, 1.0);

    return LayoutContextSnapshot(
      bounds: context.bounds,
      sourceBounds: context.sourceBounds,
      occupancyRatio: occupancyRatio,
      freeAreaRatio: (1 - occupancyRatio).clamp(0.0, 1.0),
      localNodeDensity: contextNodes.length / safeArea,
      contextWidth: context.bounds.width,
      contextHeight: context.bounds.height,
    );
  }

  List<Rect> _buildFreeSpaceRects(Rect contextBounds, List<TableNode> contextNodes, TableNode currentNode, List<Arrow> contextArrows) {
    final occupiedRects = contextNodes
        .where((node) => node.id != currentNode.id)
        .map((node) => Rect.fromLTWH(
              (node.aPosition ?? (state.delta + node.position)).dx,
              (node.aPosition ?? (state.delta + node.position)).dy,
              node.size.width,
              node.size.height,
            ))
        .toList(growable: false);

    final arrowObstacles = <Rect>[];
    for (final arrow in contextArrows) {
      arrowObstacles.addAll(_arrowRects(arrow));
    }

    bool isOccupied(Rect rect) {
      if (occupiedRects.any((occupied) => occupied.overlaps(rect))) {
        return true;
      }
      return arrowObstacles.any((arrowRect) => arrowRect.overlaps(rect));
    }

    final freeRects = <Rect>[];
    final anchorPoints = <Offset>[
      contextBounds.topLeft,
      Offset(contextBounds.center.dx - currentNode.size.width / 2, contextBounds.center.dy - currentNode.size.height / 2),
      Offset(contextBounds.right - currentNode.size.width, contextBounds.bottom - currentNode.size.height),
      Offset(contextBounds.left, contextBounds.bottom - currentNode.size.height),
      Offset(contextBounds.right - currentNode.size.width, contextBounds.top),
    ];

    for (final occupiedRect in occupiedRects.take(32)) {
      anchorPoints.addAll(<Offset>[
        Offset(occupiedRect.left - currentNode.size.width, occupiedRect.top),
        Offset(occupiedRect.right, occupiedRect.top),
        Offset(occupiedRect.left, occupiedRect.bottom),
        Offset(occupiedRect.right - currentNode.size.width, occupiedRect.bottom),
      ]);
    }

    for (final point in anchorPoints) {
      final rect = Rect.fromLTWH(point.dx, point.dy, currentNode.size.width, currentNode.size.height);
      if (!isOccupied(rect)) {
        freeRects.add(rect);
        if (freeRects.length >= 24) {
          return freeRects;
        }
      }
    }

    if (freeRects.isNotEmpty) {
      return freeRects;
    }

    final fallback = <Rect>[];
    final step = max(96.0, sqrt(max(1.0, contextBounds.width * contextBounds.height) / 48));
    for (double y = contextBounds.top; y <= contextBounds.bottom - currentNode.size.height; y += step) {
      for (double x = contextBounds.left; x <= contextBounds.right - currentNode.size.width; x += step) {
        final rect = Rect.fromLTWH(x, y, currentNode.size.width, currentNode.size.height);
        if (!isOccupied(rect)) {
          fallback.add(rect);
          if (fallback.length >= 24) {
            return fallback;
          }
        }
      }
    }
    return fallback.take(24).toList(growable: false);
  }

  Future<void> saveAcceptedPlacementSample({
    required TableNode node,
    required Offset originPosition,
    required Offset candidatePosition,
    String sampleSource = 'manual',
    String? sessionId,
    int sequenceIndex = 0,
    int graphNodeCount = 0,
    int graphEdgeCount = 0,
    double graphConflictRatio = 0,
  }) async {
    final isManualSample = sampleSource == 'manual' || sampleSource == 'manual_deferred';
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
      final runtimeContext = _buildRuntimeContextForPosition(
        originPosition,
        candidatePosition,
        allNodes,
        _buildSchemaBounds(allNodes),
        node.size,
      );
      final incidentArrows = arrowManager.getArrowsForNodes(<TableNode?>[node]).whereType<Arrow>().toList(growable: false);
      final contextNodes = _resolveContextNodes(runtimeContext, allNodes, node, incidentArrows).toList(growable: true);
      if (contextNodes.every((candidateNode) => candidateNode.id != node.id)) {
        contextNodes.add(node);
      }

      final contextSnapshot = _createRuntimeContextSnapshot(runtimeContext, contextNodes);
      final contextArrows = _resolveContextArrows(runtimeContext, contextNodes, incidentArrows);
      final request = LayoutSearchRequest(
        node: node,
        contextSnapshot: contextSnapshot,
        nearbyNodes: contextNodes,
        incidentArrows: incidentArrows,
        contextArrows: contextArrows,
        searchBounds: runtimeContext.bounds,
        freeSpaceRects: _buildFreeSpaceRects(runtimeContext.bounds, contextNodes, node, contextArrows),
        graphNodeCount: graphNodeCount,
        graphEdgeCount: graphEdgeCount,
        graphConflictRatio: graphConflictRatio,
      );
      final evaluator = RuntimeLayoutSimulationEvaluator(
        state: state,
        nodeManager: nodeManager,
        arrowManager: arrowManager,
      );
      final sourceContext = _captureContextSnapshot(
        node: node,
        candidatePosition: null,
        nearbyNodes: contextNodes,
        incidentArrows: incidentArrows,
        contextArrows: contextArrows,
      );
      Future<void> savePlacementSample({
        required Offset placementPosition,
        required String placementSampleSource,
        required int deferredStepsObserved,
        required int deferredStepsToResolution,
        required bool? deferredAccepted,
        required double? deferredScore,
        bool isNegativeSample = false,
      }) async {
        final candidate = LayoutCandidate(
          originPosition: originPosition,
          candidatePosition: placementPosition,
          nodeSize: node.size,
        );
        final evaluation = await evaluator.evaluate(request: request, candidate: candidate);
        final nearestFreeSpace = const CandidateFeatureExtractor().resolveNearestFreeSpace(request.freeSpaceRects, candidate.candidateRect);
        final resultContext = _captureContextSnapshot(
          node: node,
          candidatePosition: placementPosition,
          nearbyNodes: contextNodes,
          incidentArrows: incidentArrows,
          contextArrows: contextArrows,
        );
        final isDeferredSample = placementSampleSource == 'manual_deferred';
        final normalizedSampleSource = _normalizeSampleSource(placementSampleSource);
        final trainingContext = LayoutTrainingContext(
          datasetKind: _resolveDatasetKind(placementSampleSource),
          outcomeKind: isDeferredSample ? 'deferred' : 'immediate',
          sampleSource: normalizedSampleSource,
          qType: node.qType,
          isManualSample: isManualSample,
          isConflictNode: sourceContext.isConflictNode,
          totalConnectionCount: sourceContext.totalConnectionCount,
          incidentArrowCount: incidentArrows.length,
          nodeConnectionsBefore: sourceContext.nodeConnections,
          attributeConnectionsBefore: sourceContext.attributeConnections,
          nodeConnectionsAfter: resultContext.nodeConnections,
          attributeConnectionsAfter: resultContext.attributeConnections,
          sourceNodeOverlapCount: sourceContext.nodeOverlapCount,
          sourceEdgeIntersectionCount: sourceContext.edgeIntersectionCount,
          sourceEdgeCrossings: sourceContext.edgeCrossings,
          sourceIncidentArrowLength: sourceContext.totalIncidentArrowLength,
          resultNodeOverlapCount: evaluation.metrics.nodeOverlaps,
          resultEdgeIntersectionCount: evaluation.metrics.edgeNodeIntersections,
          resultEdgeCrossings: evaluation.metrics.edgeCrossings,
          resultIncidentArrowLength: evaluation.metrics.totalIncidentEdgeLength,
          movementDistance: candidate.movementDistance,
          hasDeferredOutcome: isDeferredSample,
          deferredStepsObserved: deferredStepsObserved,
          deferredStepsToResolution: deferredStepsToResolution,
          deferredScore: deferredScore,
          deferredAccepted: deferredAccepted,
          freeSpaceBounds: nearestFreeSpace,
          sessionId: sessionId,
          sequenceIndex: sequenceIndex,
          graphNodeCount: graphNodeCount,
          graphEdgeCount: graphEdgeCount,
          graphConflictRatio: graphConflictRatio,
        );
        final features = const CandidateFeatureExtractor().extract(
          node: node,
          candidate: candidate,
          contextSnapshot: contextSnapshot,
          incidentArrows: incidentArrows,
          nearbyNodes: contextNodes,
          freeSpaceBounds: nearestFreeSpace,
          localNodeDensity: contextNodes.length / max(1, contextSnapshot.bounds.width * contextSnapshot.bounds.height),
          localArrowDensity: contextArrows.length / max(1, contextSnapshot.bounds.width * contextSnapshot.bounds.height),
          minDistanceToNeighbor: evaluation.metrics.spacingScore * EditorConfig.tileSize,
          candidateNodeOverlapCount: evaluation.metrics.nodeOverlaps,
          candidateNodeOverlapAreaRatio: evaluation.metrics.nodeOverlaps / max(1.0, contextNodes.length.toDouble()),
          candidateEdgeIntersectionCount: evaluation.metrics.edgeNodeIntersections,
          candidateIncidentArrowLengthRatio: evaluation.metrics.totalIncidentEdgeLength / max(1.0, contextSnapshot.bounds.longestSide),
          trainingContext: trainingContext,
        );

        final sample = LayoutTrainingSample(
          candidate: candidate,
          features: features,
          metrics: evaluation.metrics,
          contextSnapshot: contextSnapshot,
          targetScore: evaluation.exactScore,
          accepted: isNegativeSample ? false : (isDeferredSample ? (deferredAccepted ?? false) : isManualSample),
          createdAt: DateTime.now(),
          trainingContext: trainingContext,
        );

        await repository.saveSample(sample);
      }

      await savePlacementSample(
        placementPosition: candidatePosition,
        placementSampleSource: sampleSource,
        deferredStepsObserved: 0,
        deferredStepsToResolution: 0,
        deferredAccepted: null,
        deferredScore: null,
      );

      if (isManualSample && sampleSource == 'manual') {
        final observedPositions = _buildDeferredObservationPositions(
          immediatePosition: candidatePosition,
          observedFinalPosition: actualAbsolutePosition,
        );
        var observedStepsToResolution = 0;
        var observedResolved = false;
        var finalObservedPosition = actualAbsolutePosition;

        for (var index = 0; index < observedPositions.length; index++) {
          final observedPosition = observedPositions[index];
          final observedResultContext = _captureContextSnapshot(
            node: node,
            candidatePosition: observedPosition,
            nearbyNodes: contextNodes,
            incidentArrows: incidentArrows,
            contextArrows: contextArrows,
          );
          finalObservedPosition = observedPosition;
          if (!observedResultContext.isConflictNode) {
            observedResolved = true;
            observedStepsToResolution = index + 1;
            break;
          }
        }

        final observedDistance = (finalObservedPosition - candidatePosition).distance;
        await savePlacementSample(
          placementPosition: finalObservedPosition,
          placementSampleSource: 'manual_deferred',
          deferredStepsObserved: observedPositions.length,
          deferredStepsToResolution: observedStepsToResolution,
          deferredAccepted: observedResolved,
          deferredScore: observedDistance <= 0.01 ? null : observedDistance,
        );
      }

      final negativeNodes = contextNodes
          .where((n) => n.id != node.id)
          .toList(growable: false);
      final maxNegativeSamples = min(3, negativeNodes.length);
      for (var negIdx = 0; negIdx < maxNegativeSamples; negIdx++) {
        final negNode = negativeNodes[negIdx];
        final negPos = negNode.aPosition ?? (state.delta + negNode.position);
        if ((negPos - candidatePosition).distance < 1.0) {
          continue;
        }
        await savePlacementSample(
          placementPosition: negPos,
          placementSampleSource: sampleSource,
          deferredStepsObserved: 0,
          deferredStepsToResolution: 0,
          deferredAccepted: null,
          deferredScore: null,
          isNegativeSample: true,
        );
      }
    } finally {
      if (isManualSample) {
        node.aPosition = actualAbsolutePosition;
        node.position = actualRelativePosition;
      }
    }
  }

  String _normalizeSampleSource(String sampleSource) {
    if (sampleSource == 'manual_deferred') {
      return 'manual';
    }
    return sampleSource;
  }

  String _resolveDatasetKind(String sampleSource) {
    switch (sampleSource) {
      case 'auto_repair':
        return 'auto_repair_immediate';
      case 'auto_polish':
        return 'auto_polish_immediate';
      case 'manual_deferred':
        return 'manual_deferred';
      case 'manual':
        return 'manual_immediate';
      case 'auto':
      default:
        return 'auto_immediate';
    }
  }

  List<Offset> _buildDeferredObservationPositions({
    required Offset immediatePosition,
    required Offset observedFinalPosition,
  }) {
    final distance = (observedFinalPosition - immediatePosition).distance;
    if (distance <= 0.01) {
      return <Offset>[observedFinalPosition];
    }

    const maxObservationSteps = 3;
    final positions = <Offset>[];
    for (var step = 1; step <= maxObservationSteps; step++) {
      final t = step / maxObservationSteps;
      positions.add(Offset.lerp(immediatePosition, observedFinalPosition, t) ?? observedFinalPosition);
    }
    return positions;
  }

  ({String id, Rect bounds, Rect sourceBounds, Set<String> nodes, Set<String> arrows}) _buildRuntimeContextForPosition(
    Offset sourcePosition,
    Offset position,
    List<TableNode> allNodes,
    Rect? schemaBounds,
    Size? nodeSize,
  ) {
    final cellWorldSize = EditorConfig.tileSize.toDouble();
    final sourceGridX = (sourcePosition.dx / cellWorldSize).floor();
    final sourceGridY = (sourcePosition.dy / cellWorldSize).floor();
    final gridX = (position.dx / cellWorldSize).floor();
    final gridY = (position.dy / cellWorldSize).floor();
    final baseBounds = schemaBounds ?? _buildSchemaBounds(allNodes);
    final bounds = nodeSize == null ? baseBounds : _expandSearchBoundsForNode(baseBounds, nodeSize);
    final sourceBounds = Rect.fromLTWH(sourceGridX * cellWorldSize, sourceGridY * cellWorldSize, cellWorldSize, cellWorldSize);
    final nodeIds = allNodes.map((candidate) => candidate.id).toSet();
    final arrowIds = state.arrows.map((arrow) => arrow.id).toSet();

    return (
      id: '${gridX}_$gridY',
      bounds: bounds,
      sourceBounds: sourceBounds,
      nodes: nodeIds,
      arrows: arrowIds,
    );
  }

  Rect _buildSchemaBounds(List<TableNode> allNodes) {
    if (allNodes.isEmpty) {
      final size = EditorConfig.tileSize.toDouble();
      return Rect.fromLTWH(0, 0, size, size);
    }

    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;

    for (final node in allNodes) {
      final position = node.aPosition ?? (state.delta + node.position);
      left = min(left, position.dx);
      top = min(top, position.dy);
      right = max(right, position.dx + node.size.width);
      bottom = max(bottom, position.dy + node.size.height);
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _expandSearchBoundsForNode(Rect schemaBounds, Size nodeSize) {
    final padding = max(nodeSize.width, nodeSize.height) * 0.5;
    return Rect.fromLTRB(
      schemaBounds.left - padding,
      schemaBounds.top - padding,
      schemaBounds.right + padding,
      schemaBounds.bottom + padding,
    );
  }

  Map<String, List<Arrow>> _buildIncidentArrowsByNodeId(List<Arrow> allArrows) {
    final result = <String, List<Arrow>>{};
    for (final arrow in allArrows) {
      result.putIfAbsent(arrow.source, () => <Arrow>[]).add(arrow);
      result.putIfAbsent(arrow.target, () => <Arrow>[]).add(arrow);
    }
    return result;
  }

  Set<String> _resolveConflictNodeIds(
    List<TableNode> allNodes,
    List<Arrow> allArrows,
    Map<String, List<Arrow>> incidentArrowsByNodeId,
  ) {
    final result = <String>{};
    for (final node in allNodes) {
      final incidentArrows = incidentArrowsByNodeId[node.id] ?? const <Arrow>[];
      if (_isConflictNode(node, allNodes, allArrows, incidentArrows)) {
        result.add(node.id);
      }
    }
    return result;
  }

  bool _isConflictNode(
    TableNode node,
    List<TableNode> allNodes,
    List<Arrow> allArrows,
    List<Arrow> incidentArrows,
  ) {
    final snapshot = _captureContextSnapshot(
      node: node,
      candidatePosition: null,
      nearbyNodes: allNodes,
      incidentArrows: incidentArrows,
      contextArrows: allArrows,
    );
    return snapshot.isConflictNode;
  }

  _SampleContextSnapshot _captureContextSnapshot({
    required TableNode node,
    required Offset? candidatePosition,
    required List<TableNode> nearbyNodes,
    required List<Arrow> incidentArrows,
    required List<Arrow> contextArrows,
  }) {
    final originalAbsolutePosition = node.aPosition ?? (state.delta + node.position);
    final originalRelativePosition = node.position;
    final originalChildAbsolutePositions = <String, Offset>{};

    void collectChildAbsolutePositions(TableNode currentNode) {
      if (currentNode.children == null || currentNode.children!.isEmpty) {
        return;
      }
      for (final child in currentNode.children!) {
        final childAbsolutePosition = child.aPosition ?? ((currentNode.aPosition ?? (state.delta + currentNode.position)) + child.position);
        originalChildAbsolutePositions[child.id] = childAbsolutePosition;
        collectChildAbsolutePositions(child);
      }
    }

    void restoreChildAbsolutePositions(TableNode currentNode) {
      if (currentNode.children == null || currentNode.children!.isEmpty) {
        return;
      }
      for (final child in currentNode.children!) {
        final originalChildAbsolutePosition = originalChildAbsolutePositions[child.id];
        if (originalChildAbsolutePosition != null) {
          child.aPosition = originalChildAbsolutePosition;
        }
        restoreChildAbsolutePositions(child);
      }
    }

    collectChildAbsolutePositions(node);

    if (candidatePosition != null) {
      nodeManager.updateNodePositionForLayout(node, candidatePosition);
      for (final arrow in incidentArrows) {
        arrowManager.getArrowPathInTile(arrow, state.delta);
      }
    }

    final nodeRect = Rect.fromLTWH(
      (node.aPosition ?? (state.delta + node.position)).dx,
      (node.aPosition ?? (state.delta + node.position)).dy,
      node.size.width,
      node.size.height,
    );
    final otherArrows = contextArrows.where((arrow) => !incidentArrows.contains(arrow)).toList(growable: false);

    var nodeOverlapCount = 0.0;
    for (final nearbyNode in nearbyNodes) {
      if (nearbyNode.id == node.id) {
        continue;
      }
      final nearbyRect = Rect.fromLTWH(
        (nearbyNode.aPosition ?? (state.delta + nearbyNode.position)).dx,
        (nearbyNode.aPosition ?? (state.delta + nearbyNode.position)).dy,
        nearbyNode.size.width,
        nearbyNode.size.height,
      );
      if (_overlapArea(nodeRect, nearbyRect) > 0) {
        nodeOverlapCount += 1;
      }
    }

    var edgeIntersectionCount = 0.0;
    for (final arrow in otherArrows) {
      for (final rect in _arrowRects(arrow)) {
        if (_overlapArea(nodeRect, rect) > 0) {
          edgeIntersectionCount += 1;
        }
      }
    }

    var edgeCrossings = 0.0;
    var totalIncidentArrowLength = 0.0;
    for (final incidentArrow in incidentArrows) {
      final incidentRects = _arrowRects(incidentArrow);
      totalIncidentArrowLength += _arrowLength(incidentArrow);
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

    final snapshot = _SampleContextSnapshot(
      nodeConnections: _captureConnectionsProfile(node.connections),
      attributeConnections: _captureAttributeConnectionsProfile(node.attributes),
      totalConnectionCount: _countConnections(node),
      nodeOverlapCount: nodeOverlapCount,
      edgeIntersectionCount: edgeIntersectionCount,
      edgeCrossings: edgeCrossings,
      totalIncidentArrowLength: totalIncidentArrowLength,
    );

    if (candidatePosition != null) {
      node.aPosition = originalAbsolutePosition;
      node.position = originalRelativePosition;
      restoreChildAbsolutePositions(node);
      for (final arrow in incidentArrows) {
        arrowManager.getArrowPathInTile(arrow, state.delta);
      }
    }

    return snapshot;
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

    return ConnectionSideProfile(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
    );
  }

  int _countConnections(TableNode node) {
    final nodeConnections = _captureConnectionsProfile(node.connections).total;
    final attributeConnections = _captureAttributeConnectionsProfile(node.attributes).total;
    return nodeConnections + attributeConnections;
  }

  double _overlapArea(Rect first, Rect second) {
    final intersection = first.intersect(second);
    if (intersection.isEmpty) {
      return 0;
    }
    return intersection.width * intersection.height;
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
}

class _SampleContextSnapshot {
  final ConnectionSideProfile nodeConnections;
  final ConnectionSideProfile attributeConnections;
  final int totalConnectionCount;
  final double nodeOverlapCount;
  final double edgeIntersectionCount;
  final double edgeCrossings;
  final double totalIncidentArrowLength;

  const _SampleContextSnapshot({
    required this.nodeConnections,
    required this.attributeConnections,
    required this.totalConnectionCount,
    required this.nodeOverlapCount,
    required this.edgeIntersectionCount,
    required this.edgeCrossings,
    required this.totalIncidentArrowLength,
  });

  bool get isConflictNode => nodeOverlapCount > 0 || edgeIntersectionCount > 0;
}
