import 'dart:math';
import 'dart:async';

import 'package:fbpmn/src/cola/cola_interop.dart';
import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/models/table.node.dart';
import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/manager.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:fbpmn/src/utils/utils.dart';
import 'package:flutter/material.dart';

class ColaLayoutService extends Manager {
  final EditorState state;
  final TileManager tileManager;
  final ArrowManager arrowManager;
  final NodeManager nodeManager;
  final ScrollHandler scrollHandler;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  ColaLayout? _layout;
  AnimatedLayout? _animator;

  // Маппинг индексов Cola -> узлы
  final List<TableNode> _nodesList = [];
  // Маппинг id узла -> индекс в Cola
  final Map<String, int> _nodeIndexMap = {};
  // Начальные позиции узлов (сохраняются при первом запуске)
  final Map<int, Offset> _initialPositions = {};
  // Виртуальный список связей (дети заменены на родителей)
  final List<({String source, String target})> _virtualEdges = [];

  // Параметры раскладки
  double _currentIdealEdgeLength = 300;

  // Параметры анимации перемещения узлов
  /// Скорость анимации (0.0 - 1.0). 1.0 = мгновенное перемещение, 0.1 = медленная анимация
  double animationSpeed = 0.4;
  
  /// Отключить анимацию и показать только конечный результат
  bool skipAnimation = false;

  /// Текущие анимированные позиции узлов
  final Map<int, Offset> _animatedPositions = {};

  /// Целевые позиции узлов (из Cola)
  final Map<int, Offset> _targetPositions = {};

  final Map<int, int> _nodeConnectionCounts = {};

  int _maxNodeConnections = 1;

  Offset _distributionCenter = Offset.zero;

  /// Флаг активной анимации
  bool _isAnimating = false;

  /// Completer для ожидания завершения раскладки
  Completer<void>? _layoutCompleter;

  Completer<void>? _positionAnimationCompleter;

  bool _finishAfterCurrentAnimation = false;

  ColaLayoutService({
    required this.state,
    required this.tileManager,
    required this.arrowManager,
    required this.nodeManager,
    required this.scrollHandler,
  });

  Future<void> runAutoLayout() async {
    if (_isRunning) return;
    if (state.nodes.isEmpty) return;

    // Создаем новый Completer для этого запуска
    _layoutCompleter = Completer<void>();

    _isRunning = true;
    state.isAutoLayoutMode = true;
    _currentIdealEdgeLength = 300; // Уменьшаем для более компактной раскладки
    _initialPositions.clear(); // Очищаем начальные позиции
    _animatedPositions.clear(); // Очищаем анимированные позиции
    _targetPositions.clear(); // Очищаем целевые позиции
    _nodeConnectionCounts.clear();
    _maxNodeConnections = 1;
    _distributionCenter = Offset.zero;
    _isAnimating = false;
    _finishAfterCurrentAnimation = false;
    _positionAnimationCompleter = null;
    animationSpeed = state.autoLayoutSettings.animationSpeed.clamp(0.2, 0.95);
    onStateUpdate();

    try {
      // 0. Сворачиваем все развернутые swimlane узлы перед запуском Cola
      await _collapseExpandedSwimlanes();

      // 2. Включаем loading indicator
      state.isLoading = true;
      tileManager.onStateUpdate();

      // 3. Переносим все узлы в nodesSelected (используем метод NodeManager)
      _nodesList.clear();
      _nodesList.addAll(await nodeManager.selectAllNodesForLayout());

      if (_nodesList.isEmpty) {
        _isRunning = false;
        state.isLoading = false;
        onStateUpdate();
        _layoutCompleter?.complete();
        return;
      }

      // 4. Строим маппинг индексов
      _buildNodeIndexMap();

      // 5. Строим виртуальный список связей (дети заменены на родителей)
      _buildVirtualEdges();

      // 5.1 Собираем degree узлов и фиксируем центр текущей схемы до перераспределения
      _buildNodeConnectionCounts();
      _captureDistributionCenter();

      // 5.2 Инициализируем стартовые и целевые позиции текущим расположением
      _seedCurrentPositions();

      // 6. Удаляем все тайлы (используем метод TileManager)
      tileManager.disposeTiles();

      // 7. Переносим все связи в arrowsSelected (используем метод ArrowManager)
      arrowManager.selectAllArrows();

      if (state.autoLayoutUseCola) {
        // 8. Инициализируем Cola если нужно
        if (!ColaInterop.isReady) {
          await ColaInterop.init();
        }

        // 9. Создаем Cola layout
        _createColaLayout();

        // 10. Запускаем анимированную раскладку
        _runAnimatedLayout();
      } else {
        await _runRepairOnlyLayout();
      }
      
      // Ожидаем завершения раскладки
      await _layoutCompleter!.future;
    } catch (e) {
      print('ColaLayoutService error: $e');
      await _finishLayout();
    }
  }

  /// Сворачивает все развернутые swimlane узлы перед запуском Cola
  Future<void> _collapseExpandedSwimlanes() async {
    // Находим все развернутые swimlane узлы
    final expandedSwimlanes = state.nodes
        .where((node) => node.qType == 'swimlane' && !(node.isCollapsed ?? false))
        .toList();

    if (expandedSwimlanes.isEmpty) return;

    print('Cola: сворачиваем ${expandedSwimlanes.length} развернутых swimlane узлов');

    // Сворачиваем каждый swimlane через NodeManager
    for (final swimlane in expandedSwimlanes) {
      await nodeManager.collapseSwimlane(swimlane);
    }
  }

  void _buildNodeIndexMap() {
    _nodeIndexMap.clear();
    for (int i = 0; i < _nodesList.length; i++) {
      _nodeIndexMap[_nodesList[i].id] = i;
    }
  }

  /// Создаёт виртуальный список связей, заменяя ссылки на детей на ссылки на родителей
  /// Это нужно для того, чтобы связи между детьми group/swimlane узлов
  /// притягивали родительские узлы в Cola
  void _buildVirtualEdges() {
    _virtualEdges.clear();

    // Строим маппинг: id ребёнка -> id родителя
    final Map<String, String> childToParent = {};
    for (final node in _nodesList) {
      if (node.children != null && node.children!.isNotEmpty) {
        for (final child in node.children!) {
          childToParent[child.id] = node.id;
        }
      }
    }

    // Создаём виртуальные связи
    for (final arrow in state.arrows) {
      // Заменяем source на родителя, если это ребёнок
      final virtualSource = childToParent[arrow.source] ?? arrow.source;
      // Заменяем target на родителя, если это ребёнок
      final virtualTarget = childToParent[arrow.target] ?? arrow.target;

      // Добавляем только если оба узла есть в _nodeIndexMap
      if (_nodeIndexMap.containsKey(virtualSource) && _nodeIndexMap.containsKey(virtualTarget)) {
        // Избегаем дублирования связей
        final exists = _virtualEdges.any(
          (e) =>
              (e.source == virtualSource && e.target == virtualTarget) ||
              (e.source == virtualTarget && e.target == virtualSource),
        );
        if (!exists && virtualSource != virtualTarget) {
          _virtualEdges.add((source: virtualSource, target: virtualTarget));
        }
      }
    }

    print('Cola: создано ${_virtualEdges.length} виртуальных связей из ${state.arrows.length} оригинальных');
  }

  void _buildNodeConnectionCounts() {
    _nodeConnectionCounts.clear();
    for (int i = 0; i < _nodesList.length; i++) {
      _nodeConnectionCounts[i] = 0;
    }

    for (final edge in _virtualEdges) {
      final sourceIndex = _nodeIndexMap[edge.source];
      final targetIndex = _nodeIndexMap[edge.target];
      if (sourceIndex != null) {
        _nodeConnectionCounts[sourceIndex] = (_nodeConnectionCounts[sourceIndex] ?? 0) + 1;
      }
      if (targetIndex != null) {
        _nodeConnectionCounts[targetIndex] = (_nodeConnectionCounts[targetIndex] ?? 0) + 1;
      }
    }

    final values = _nodeConnectionCounts.values;
    _maxNodeConnections = values.isEmpty ? 1 : max(1, values.reduce(max));
  }

  void _captureDistributionCenter() {
    if (_nodesList.isEmpty) {
      _distributionCenter = Offset.zero;
      return;
    }

    double sumX = 0;
    double sumY = 0;
    int count = 0;

    for (final node in _nodesList) {
      final position = node.aPosition ?? (state.delta + node.position);
      sumX += position.dx + node.size.width / 2;
      sumY += position.dy + node.size.height / 2;
      count++;
    }

    _distributionCenter = count == 0 ? Offset.zero : Offset(sumX / count, sumY / count);
  }

  void _seedCurrentPositions() {
    for (int i = 0; i < _nodesList.length; i++) {
      final node = _nodesList[i];
      final position = _constrainNodeToCanvas(node, node.aPosition ?? (state.delta + node.position));
      _initialPositions[i] = position;
      _targetPositions[i] = position;
      _animatedPositions[i] = position;
    }
  }

  void _createColaLayout() {
    final nodeCount = _nodesList.length;

    // idealEdgeLength определяет длину связей — это баланс между притяжением и отталкиванием
    // Связи притягивают узлы к этой длине, а setAvoidOverlaps отталкивает при перекрытии
    _layout = ColaLayout(nodeCount: nodeCount, idealEdgeLength: _currentIdealEdgeLength);

    // Включаем предотвращение перекрытий — это создаёт силу отталкивания
    _layout!.setAvoidOverlaps(true);

    // Ограничиваем раскладку текущими динамическими размерами холста
    final layoutBounds = _getDynamicCanvasBounds();
    _layout!.addPageBoundary(
      xMin: layoutBounds.left,
      xMax: layoutBounds.right,
      yMin: layoutBounds.top,
      yMax: layoutBounds.bottom,
      weight: 100,
    );

    // Настраиваем параметры сходимости
    _layout!.setConvergence(tolerance: 0.001, maxIterations: 300);

    // Устанавливаем позиции и размеры узлов
    // Добавляем сильные случайные толчки в РАЗНЫЕ стороны для разрушения симметрии
    final rng = Random(DateTime.now().millisecondsSinceEpoch);

    for (int i = 0; i < _nodesList.length; i++) {
      final node = _nodesList[i];
      final originalPos = state.delta + node.position;
      _initialPositions[i] = originalPos;

      // Сильные случайные толчки в ОБОИХ направлениях (±100px)
      final jitterX = (rng.nextDouble() - 0.5) * 200; // -100 to +100
      final jitterY = (rng.nextDouble() - 0.5) * 200; // -100 to +100

      final centerX = originalPos.dx + node.size.width / 2 + jitterX;
      final centerY = originalPos.dy + node.size.height / 2 + jitterY;

      // Для group/swimlane увеличиваем размеры для Cola, чтобы обеспечить больший зазор
      final isLargeNode = (node.qType == 'group' || node.qType == 'swimlane');
      final padding = isLargeNode ? 80.0 : 0.0;
      final effectiveWidth = node.size.width + padding * 2;
      final effectiveHeight = node.size.height + padding * 2;

      _layout!.setNode(i, x: centerX, y: centerY, width: effectiveWidth, height: effectiveHeight);
    }

    // Добавляем рёбра из ВИРТУАЛЬНОГО списка — они создают силу притяжения к idealEdgeLength
    // Виртуальные связи заменяют ссылки на детей на ссылки на родителей
    for (final edge in _virtualEdges) {
      final sourceIndex = _nodeIndexMap[edge.source];
      final targetIndex = _nodeIndexMap[edge.target];
      if (sourceIndex != null && targetIndex != null) {
        _layout!.addEdge(sourceIndex, targetIndex);
      }
    }
  }

  void _runAnimatedLayout() {
    _animator = AnimatedLayout(layout: _layout!, onTick: _onLayoutTick, onComplete: _onLayoutComplete);
    _animator!.start();
  }

  Future<void> _runRepairOnlyLayout() async {
    arrowManager.recalculateSelectedArrows();
    final repairReport = await _repairLayoutCollisions(maxIterations: 8);
    print(
      'Repair-only: iterations=${repairReport.iterations}, moved=${repairReport.movedNodes}, remaining=${repairReport.hasHardCollisions}',
    );
    await _finishLayout();
  }

  void _onLayoutTick(List<NodePosition> positions) {
    // Вычисляем смещение центра масс относительно начального
    double newSumX = 0;
    double newSumY = 0;
    for (int i = 0; i < positions.length && i < _nodesList.length; i++) {
      newSumX += positions[i].x;
      newSumY += positions[i].y;
    }
    final newCenterX = newSumX / _nodesList.length;
    final newCenterY = newSumY / _nodesList.length;

    // Вычисляем начальный центр масс
    double initialSumX = 0;
    double initialSumY = 0;
    for (int i = 0; i < _nodesList.length; i++) {
      final pos = _initialPositions[i]!;
      final node = _nodesList[i];
      initialSumX += pos.dx + node.size.width / 2;
      initialSumY += pos.dy + node.size.height / 2;
    }
    final initialCenterX = initialSumX / _nodesList.length;
    final initialCenterY = initialSumY / _nodesList.length;

    // Вычисляем коррекцию для центрирования
    final offsetX = initialCenterX - newCenterX;
    final offsetY = initialCenterY - newCenterY;

    // Сохраняем целевые позиции для анимации
    for (int i = 0; i < positions.length && i < _nodesList.length; i++) {
      final node = _nodesList[i];
      final pos = positions[i];

      // Позиция из Cola - это центр узла, преобразуем в левый верхний угол
      // Добавляем коррекцию для сохранения центра масс
      final newWorldPosition = _constrainNodeToCanvas(
        node,
        Offset(pos.x + offsetX - node.size.width / 2, pos.y + offsetY - node.size.height / 2),
      );

      _targetPositions[i] = newWorldPosition;

      // Инициализируем анимированную позицию если её нет
      if (!_animatedPositions.containsKey(i)) {
        _animatedPositions[i] = node.aPosition ?? _initialPositions[i]!;
      }
    }

    // Запускаем анимацию если она ещё не запущена
    // При skipAnimation=true не запускаем анимацию во время тиков Cola
    if (!_isAnimating && !skipAnimation) {
      _startPositionAnimation();
    }
  }

  /// Запускает анимацию интерполяции позиций узлов
  void _startPositionAnimation() {
    if (_isAnimating) {
      return;
    }
    _isAnimating = true;
    _animatePositions();
  }

  Future<void> _animateToTargetsAndWait({bool finishAfter = false}) async {
    if (!_isRunning) {
      return;
    }

    _finishAfterCurrentAnimation = finishAfter;

    if (skipAnimation || !state.autoLayoutSettings.animateRepair) {
      _applyTargetPositionsImmediately();
      if (finishAfter) {
        await _finishLayout();
      }
      return;
    }

    if (_positionAnimationCompleter == null || _positionAnimationCompleter!.isCompleted) {
      _positionAnimationCompleter = Completer<void>();
    }

    if (!_isAnimating) {
      _startPositionAnimation();
    }

    await _positionAnimationCompleter!.future;
  }

  void _applyTargetPositionsImmediately() {
    for (int i = 0; i < _nodesList.length; i++) {
      final target = _targetPositions[i];
      if (target == null) continue;
      final node = _nodesList[i];
      _animatedPositions[i] = target;
      nodeManager.updateNodePositionForLayout(node, target);
    }

    arrowManager.recalculateSelectedArrows();
    arrowManager.onStateUpdate();
    nodeManager.onStateUpdate();
    onStateUpdate();
  }

  void _completeAnimationCycle() {
    if (_positionAnimationCompleter != null && !_positionAnimationCompleter!.isCompleted) {
      _positionAnimationCompleter!.complete();
    }
    _positionAnimationCompleter = null;
  }

  /// Анимирует перемещение узлов к целевым позициям
  void _animatePositions() {
    if (!_isRunning) {
      _isAnimating = false;
      _completeAnimationCycle();
      return;
    }

    // Если анимация отключена — сразу устанавливаем конечные позиции
    if (skipAnimation) {
      _applyTargetPositionsImmediately();
      _isAnimating = false;
      _completeAnimationCycle();
      if (_finishAfterCurrentAnimation) {
        _finishAfterCurrentAnimation = false;
        unawaited(_finishLayout());
      }
      return;
    }

    bool allReached = true;
    const double threshold = 0.5; // Порог достижения цели в пикселях

    for (int i = 0; i < _nodesList.length; i++) {
      final target = _targetPositions[i];
      if (target == null) continue;

      final current = _animatedPositions[i]!;
      final node = _nodesList[i];

      // Интерполируем позицию
      final newX = current.dx + (target.dx - current.dx) * animationSpeed;
      final newY = current.dy + (target.dy - current.dy) * animationSpeed;
      final newPosition = Offset(newX, newY);

      // Проверяем достигнута ли цель
      final distance = (target - newPosition).distance;
      if (distance > threshold) {
        allReached = false;
      }

      _animatedPositions[i] = newPosition;

      // Обновляем позицию узла
      nodeManager.updateNodePositionForLayout(node, newPosition);
    }

    // Пересчитываем координаты стрелок с новыми позициями узлов
    arrowManager.recalculateSelectedArrows();
    // Уведомляем виджеты об обновлении
    arrowManager.onStateUpdate();
    nodeManager.onStateUpdate();
    onStateUpdate();

    // Продолжаем анимацию если не все узлы достигли цели
    if (!allReached) {
      Future.delayed(const Duration(milliseconds: 8), _animatePositions);
    } else {
      _isAnimating = false;

      _completeAnimationCycle();

      if (_finishAfterCurrentAnimation) {
        _finishAfterCurrentAnimation = false;
        unawaited(_finishLayout());
      }
    }
  }

  void _onLayoutComplete() {
    unawaited(_handleLayoutComplete());
  }

  Future<void> _handleLayoutComplete() async {
    await _animateToTargetsAndWait();
    _applyTargetPositionsImmediately();

    await _repairLayoutCollisions(maxIterations: 8);

    print('Cola: расчёт завершён');

    // Освобождаем Cola layout
    _layout?.dispose();
    _layout = null;
    _animator = null;

    // При skipAnimation=true сразу показываем конечные позиции
    if (skipAnimation) {
      _applyTargetPositionsImmediately();
      await _finishLayout();
    } else if (!_isAnimating) {
      await _finishLayout();
    }
  }

  Future<_RepairReport> _repairLayoutCollisions({required int maxIterations}) async {
    var occupancy = _buildOccupancyMap();
    var stats = _collectCollisionStats(occupancy);

    if (!stats.hasHardCollisions) {
      return _RepairReport(iterations: 0, movedNodes: 0, hasHardCollisions: false);
    }

    int movedNodes = 0;
    int executedIterations = 0;

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      occupancy = _buildOccupancyMap();
      stats = _collectCollisionStats(occupancy);
      if (!stats.hasHardCollisions) {
        break;
      }

      executedIterations = iteration + 1;
      bool movedInIteration = false;
      final nodeOrder = stats.nodeScores.entries.toList()
        ..sort((a, b) {
          final hardCompare = b.value.hardCollisionCount.compareTo(a.value.hardCollisionCount);
          if (hardCompare != 0) return hardCompare;

          final connectionCompare = (_nodeConnectionCounts[b.key] ?? 0).compareTo(_nodeConnectionCounts[a.key] ?? 0);
          if (connectionCompare != 0) return connectionCompare;

          final centerCompare = a.value.centerDistance.compareTo(b.value.centerDistance);
          if (centerCompare != 0) return centerCompare;

          return b.value.totalScore.compareTo(a.value.totalScore);
        });

      for (final entry in nodeOrder) {
        occupancy = _buildOccupancyMap();
        final currentStats = _collectCollisionStats(occupancy);
        final currentScore = currentStats.nodeScores[entry.key];
        if (currentScore == null || !currentScore.hasHardCollisions) {
          continue;
        }

        final bestCandidate = _findBestPositionByRings(
          nodeIndex: entry.key,
          occupancy: occupancy,
          currentScore: currentScore,
        );

        if (bestCandidate == null) {
          continue;
        }

        _targetPositions[entry.key] = bestCandidate.position;
        _initialPositions[entry.key] = bestCandidate.position;
        movedNodes++;
        movedInIteration = true;

        final node = _nodesList[entry.key];

        if (skipAnimation || !state.autoLayoutSettings.animateRepair) {
          nodeManager.updateNodePositionForLayout(node, bestCandidate.position);
          _animatedPositions[entry.key] = bestCandidate.position;
          arrowManager.recalculateSelectedArrows();
        } else {
          await _animateToTargetsAndWait();
        }
      }

      occupancy = _buildOccupancyMap();
      stats = _collectCollisionStats(occupancy);
      if (!movedInIteration || !stats.hasHardCollisions) {
        break;
      }
    }

    occupancy = _buildOccupancyMap();
    stats = _collectCollisionStats(occupancy);

    print(
      'Cola repair: iterations=$executedIterations, moved=$movedNodes, remaining=${stats.hardCollisionNodeCount}',
    );

    return _RepairReport(
      iterations: executedIterations,
      movedNodes: movedNodes,
      hasHardCollisions: stats.hasHardCollisions,
    );
  }

  _OccupancyMap _buildOccupancyMap() {
    final childToParent = _buildChildToParentMap();
    final nodeRects = <_OccupiedNodeRect>[];
    final arrowRects = <_OccupiedArrowRect>[];

    for (int i = 0; i < _nodesList.length; i++) {
      final node = _nodesList[i];
      final position = _targetPositions[i] ?? node.aPosition;
      if (position == null) {
        continue;
      }

      nodeRects.add(_OccupiedNodeRect(
        nodeIndex: i,
        rect: _buildNodeOccupiedRect(node, position),
      ));
    }

    for (final arrow in state.arrowsSelected) {
      if (arrow == null) continue;

      final incidentNodeIndices = <int>{};
      final sourceId = childToParent[arrow.source] ?? arrow.source;
      final targetId = childToParent[arrow.target] ?? arrow.target;
      final sourceIndex = _nodeIndexMap[sourceId];
      final targetIndex = _nodeIndexMap[targetId];
      if (sourceIndex != null) incidentNodeIndices.add(sourceIndex);
      if (targetIndex != null) incidentNodeIndices.add(targetIndex);

      final rects = arrow.rects;
      if (rects != null && rects.isNotEmpty) {
        for (final rect in rects) {
          arrowRects.add(_OccupiedArrowRect(
            rect: _expandRect(rect, 8),
            incidentNodeIndices: incidentNodeIndices,
          ));
        }
        continue;
      }

      final coordinates = arrow.coordinates;
      if (coordinates == null || coordinates.length < 2) continue;
      for (int i = 0; i < coordinates.length - 1; i++) {
        final p1 = coordinates[i];
        final p2 = coordinates[i + 1];
        arrowRects.add(_OccupiedArrowRect(
          rect: _segmentToRect(p1, p2, 12),
          incidentNodeIndices: incidentNodeIndices,
        ));
      }
    }

    return _OccupancyMap(nodeRects: nodeRects, arrowRects: arrowRects);
  }

  Map<String, String> _buildChildToParentMap() {
    final childToParent = <String, String>{};
    for (final node in _nodesList) {
      if (node.children == null || node.children!.isEmpty) continue;
      for (final child in node.children!) {
        childToParent[child.id] = node.id;
      }
    }
    return childToParent;
  }

  _CollisionStats _collectCollisionStats(_OccupancyMap occupancy) {
    final nodeScores = <int, _CandidateScore>{};
    for (int i = 0; i < _nodesList.length; i++) {
      final node = _nodesList[i];
      final position = _targetPositions[i] ?? node.aPosition;
      if (position == null) continue;
      nodeScores[i] = _evaluateCandidatePosition(
        nodeIndex: i,
        position: position,
        occupancy: occupancy,
        anchorPosition: position,
      );
    }

    final hardCollisionNodeCount = nodeScores.values.where((score) => score.hasHardCollisions).length;
    return _CollisionStats(
      nodeScores: nodeScores,
      hardCollisionNodeCount: hardCollisionNodeCount,
    );
  }

  _CandidateResult? _findBestPositionByRings({
    required int nodeIndex,
    required _OccupancyMap occupancy,
    required _CandidateScore currentScore,
  }) {
    final node = _nodesList[nodeIndex];
    final currentPosition = _targetPositions[nodeIndex] ?? node.aPosition;
    if (currentPosition == null) {
      return null;
    }

    final baseStep = max(node.size.width, node.size.height) / 2 + _nodeClearance(node) + 20;
    _CandidateResult? bestResult;

    for (int ring = 1; ring <= 8; ring++) {
      final radius = baseStep * ring;
      for (int angleDeg = 0; angleDeg < 360; angleDeg += 15) {
        final angle = angleDeg * pi / 180;
        final candidatePosition = _constrainNodeToCanvas(
          node,
          Offset(
            currentPosition.dx + cos(angle) * radius,
            currentPosition.dy + sin(angle) * radius,
          ),
        );

        final candidateScore = _evaluateCandidatePosition(
          nodeIndex: nodeIndex,
          position: candidatePosition,
          occupancy: occupancy,
          anchorPosition: currentPosition,
        );

        if (!_isScoreBetter(candidateScore, currentScore)) {
          continue;
        }

        if (bestResult == null || _isScoreBetter(candidateScore, bestResult.score)) {
          bestResult = _CandidateResult(position: candidatePosition, score: candidateScore);
        }
      }

      if (bestResult != null && !bestResult.score.hasHardCollisions) {
        break;
      }
    }

    return bestResult;
  }

  _CandidateScore _evaluateCandidatePosition({
    required int nodeIndex,
    required Offset position,
    required _OccupancyMap occupancy,
    required Offset anchorPosition,
  }) {
    final node = _nodesList[nodeIndex];
    final candidateRect = _buildNodeOccupiedRect(node, position);
    double nodeOverlapArea = 0;
    double arrowOverlapArea = 0;
    int nodeOverlapCount = 0;
    int arrowOverlapCount = 0;

    for (final occupiedNode in occupancy.nodeRects) {
      if (occupiedNode.nodeIndex == nodeIndex) continue;
      final overlapArea = _overlapArea(candidateRect, occupiedNode.rect);
      if (overlapArea > 0) {
        nodeOverlapArea += overlapArea;
        nodeOverlapCount++;
      }
    }

    for (final occupiedArrow in occupancy.arrowRects) {
      if (occupiedArrow.incidentNodeIndices.contains(nodeIndex)) continue;
      final overlapArea = _overlapArea(candidateRect, occupiedArrow.rect);
      if (overlapArea > 0) {
        arrowOverlapArea += overlapArea;
        arrowOverlapCount++;
      }
    }

    final nodeCenter = Offset(position.dx + node.size.width / 2, position.dy + node.size.height / 2);
    final centerDistance = (nodeCenter - _distributionCenter).distance;
    final distancePenalty = (position - anchorPosition).distance;
    final settings = state.autoLayoutSettings;
    final centerPenalty = centerDistance * _centerAffinity(nodeIndex) * settings.centerWeight;
    final totalScore =
        nodeOverlapArea * settings.nodeOverlapAreaWeight +
        arrowOverlapArea * settings.arrowOverlapAreaWeight +
        nodeOverlapCount * settings.nodeOverlapCountWeight +
        arrowOverlapCount * settings.arrowOverlapCountWeight +
        distancePenalty * settings.distanceWeight +
        centerPenalty;

    return _CandidateScore(
      nodeOverlapArea: nodeOverlapArea,
      arrowOverlapArea: arrowOverlapArea,
      nodeOverlapCount: nodeOverlapCount,
      arrowOverlapCount: arrowOverlapCount,
      centerDistance: centerDistance,
      centerPenalty: centerPenalty,
      distancePenalty: distancePenalty,
      totalScore: totalScore,
    );
  }

  double _centerAffinity(int nodeIndex) {
    final connectionRatio = (_nodeConnectionCounts[nodeIndex] ?? 0) / _maxNodeConnections;
    if (!state.autoLayoutSettings.centerByConnectivity) {
      return 1.2;
    }

    return 1.4 + connectionRatio * 4.0;
  }

  bool _isScoreBetter(_CandidateScore candidate, _CandidateScore baseline) {
    if (candidate.totalScore >= baseline.totalScore) {
      return false;
    }

    if (candidate.hardCollisionCount > baseline.hardCollisionCount) {
      return false;
    }

    return true;
  }

  Rect _buildNodeOccupiedRect(TableNode node, Offset position) {
    final baseRect = Utils.calculateNodeRect(node: node, position: position);
    final clearance = _nodeClearance(node);
    return _expandRect(baseRect, clearance);
  }

  double _nodeClearance(TableNode node) {
    return (node.qType == 'group' || node.qType == 'swimlane') ? 30.0 : 12.0;
  }

  Rect _expandRect(Rect rect, double padding) {
    return Rect.fromLTRB(
      rect.left - padding,
      rect.top - padding,
      rect.right + padding,
      rect.bottom + padding,
    );
  }

  Rect _segmentToRect(Offset p1, Offset p2, double thickness) {
    final half = thickness / 2;
    return Rect.fromLTRB(
      min(p1.dx, p2.dx) - half,
      min(p1.dy, p2.dy) - half,
      max(p1.dx, p2.dx) + half,
      max(p1.dy, p2.dy) + half,
    );
  }

  double _overlapArea(Rect a, Rect b) {
    final overlapWidth = min(a.right, b.right) - max(a.left, b.left);
    final overlapHeight = min(a.bottom, b.bottom) - max(a.top, b.top);
    if (overlapWidth <= 0 || overlapHeight <= 0) {
      return 0;
    }
    return overlapWidth * overlapHeight;
  }

  Rect _getDynamicCanvasBounds() {
    return Rect.fromLTWH(
      0,
      0,
      scrollHandler.dynamicCanvasWidth,
      scrollHandler.dynamicCanvasHeight,
    );
  }

  Offset _constrainNodeToCanvas(TableNode node, Offset worldPosition) {
    final bounds = _getDynamicCanvasBounds();
    final maxX = max(bounds.left, bounds.right - node.size.width);
    final maxY = max(bounds.top, bounds.bottom - node.size.height);

    return Offset(
      worldPosition.dx.clamp(bounds.left, maxX),
      worldPosition.dy.clamp(bounds.top, maxY),
    );
  }

  Future<void> _finishLayout() async {
    // Останавливаем анимацию если она ещё работает
    _animator?.stop();
    _animator = null;

    // Освобождаем Cola layout (если ещё не освобождён)
    _layout?.dispose();
    _layout = null;

    // Пересчитываем пути связей с финальными позициями
    arrowManager.recalculateSelectedArrows();

    // Пересчитываем размер холста на основе новых позиций узлов
    // ВАЖНО: делаем это ДО saveAllNodesAfterLayout, так как этот метод
    // изменяет state.delta и пересчитывает aPosition
    // scrollHandler.calculateCanvasSizeFromNodes(state.nodes);

    // Сохраняем узлы обратно в тайлы (используем метод NodeManager)
    await nodeManager.saveAllNodesAfterLayout();

    // Выключаем loading indicator и режим автораскладки
    state.isLoading = false;
    state.isAutoLayoutMode = false;
    _isRunning = false;
    _isAnimating = false;

    _nodesList.clear();
    _nodeIndexMap.clear();
    _animatedPositions.clear();
    _targetPositions.clear();
    _nodeConnectionCounts.clear();
    _positionAnimationCompleter = null;
    _finishAfterCurrentAnimation = false;
    
    // Обновляем скролбары
    // scrollHandler.updateScrollControllers();
    
    // Фокусируемся на новом центре (автоподгонка и центрирование)
    // scrollHandler.autoFitAndCenterNodes();

    tileManager.onStateUpdate();
    onStateUpdate();
    
    // Завершаем Completer, чтобы разблокировать await в runAutoLayout
    if (_layoutCompleter != null && !_layoutCompleter!.isCompleted) {
      _layoutCompleter!.complete();
    }
  }

  void stopLayout() {
    if (_isRunning) {
      _animator?.stop();
      _finishLayout();
    }
  }

  @override
  void dispose() {
    stopLayout();
    super.dispose();
  }
}

class _RepairReport {
  final int iterations;
  final int movedNodes;
  final bool hasHardCollisions;

  const _RepairReport({
    required this.iterations,
    required this.movedNodes,
    required this.hasHardCollisions,
  });
}

class _CollisionStats {
  final Map<int, _CandidateScore> nodeScores;
  final int hardCollisionNodeCount;

  const _CollisionStats({
    required this.nodeScores,
    required this.hardCollisionNodeCount,
  });

  bool get hasHardCollisions => hardCollisionNodeCount > 0;
}

class _CandidateResult {
  final Offset position;
  final _CandidateScore score;

  const _CandidateResult({required this.position, required this.score});
}

class _CandidateScore {
  final double nodeOverlapArea;
  final double arrowOverlapArea;
  final int nodeOverlapCount;
  final int arrowOverlapCount;
  final double centerDistance;
  final double centerPenalty;
  final double distancePenalty;
  final double totalScore;

  const _CandidateScore({
    required this.nodeOverlapArea,
    required this.arrowOverlapArea,
    required this.nodeOverlapCount,
    required this.arrowOverlapCount,
    required this.centerDistance,
    required this.centerPenalty,
    required this.distancePenalty,
    required this.totalScore,
  });

  bool get hasHardCollisions => hardCollisionCount > 0;
  int get hardCollisionCount => nodeOverlapCount + arrowOverlapCount;
}

class _OccupancyMap {
  final List<_OccupiedNodeRect> nodeRects;
  final List<_OccupiedArrowRect> arrowRects;

  const _OccupancyMap({required this.nodeRects, required this.arrowRects});
}

class _OccupiedNodeRect {
  final int nodeIndex;
  final Rect rect;

  const _OccupiedNodeRect({required this.nodeIndex, required this.rect});
}

class _OccupiedArrowRect {
  final Rect rect;
  final Set<int> incidentNodeIndices;

  const _OccupiedArrowRect({required this.rect, required this.incidentNodeIndices});
}
