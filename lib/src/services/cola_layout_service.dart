import 'dart:math';
import 'dart:async';

import 'package:fbpmn/src/cola/cola_interop.dart';
import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/models/attribute.dart';
import 'package:fbpmn/src/micro_layout/services/neural_polish_service.dart';
import 'package:fbpmn/src/models/table.node.dart';
import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/event_service.dart';
import 'package:fbpmn/src/services/manager.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:fbpmn/src/utils/editor_config.dart';
import 'package:fbpmn/src/utils/utils.dart';
import 'package:flutter/material.dart';

class ColaLayoutService extends Manager {
  final EditorState state;
  final TileManager tileManager;
  final ArrowManager arrowManager;
  final NodeManager nodeManager;
  final ScrollHandler scrollHandler;
  late final NeuralPolishService _neuralPolishService;

  static const bool _animateRepair = true;
  static const double _defaultAnimationSpeed = 0.9;
  static const double _nodeOverlapAreaWeight = 1000.0;
  static const double _arrowOverlapAreaWeight = 700.0;
  static const double _nodeOverlapCountWeight = 5000.0;
  static const double _arrowOverlapCountWeight = 2500.0;
  static const double _distanceWeight = 1.0;
  static const double _centerWeight = 1.0;
  static const double _connectedNodeDistanceWeight = 0.42;
  static const double _connectedNodeDirectionWeight = 0.2;
  static const double _attributeClusterWeight = 0.24;
  static const double _centerAffinityBase = 1.4;
  static const double _centerAffinityConnectivityFactor = 4.0;

  static const double _polishNodeOverlapAreaWeight = 1400.0;
  static const double _polishArrowOverlapAreaWeight = 2200.0;
  static const double _polishNodeOverlapCountWeight = 6200.0;
  static const double _polishArrowOverlapCountWeight = 9200.0;
  static const double _polishDistanceWeight = 0.45;
  static const double _polishCenterWeight = 1.45;
  static const double _polishConnectedNodeDistanceWeight = 0.32;
  static const double _polishConnectedNodeDirectionWeight = 0.14;
  static const double _polishAttributeClusterWeight = 0.18;

  static const double _lazyNodeActivationThreshold = 0.14;
  static const double _lazyNodeDistancePenaltyBoost = 34.0;
  static const double _lazyNodeCenterBoost = 12.0;
  static const double _lazyNodeMinRadiusFactor = 0.06;

  bool _isRunning = false;
  bool get isRunning => _isRunning;
  bool _isFinishing = false;

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

  final Map<int, int> _nodeSourceConnectionCounts = {};

  final Map<int, int> _nodeTargetConnectionCounts = {};

  int _maxNodeConnections = 1;

  final Map<int, Set<int>> _adjacentNodeIndices = {};

  final Map<int, Set<String>> _nodeAttributeClusterKeys = {};

  final Map<String, Set<int>> _attributeClusterNodeIndices = {};

  Offset _distributionCenter = Offset.zero;

  /// Флаг активной анимации
  bool _isAnimating = false;

  /// Completer для ожидания завершения раскладки
  Completer<void>? _layoutCompleter;

  Completer<void>? _positionAnimationCompleter;

  bool _finishAfterCurrentAnimation = false;

  Stopwatch? _layoutStopwatch;
  Timer? _layoutElapsedTimer;

  ColaLayoutService({
    required this.state,
    required this.tileManager,
    required this.arrowManager,
    required this.nodeManager,
    required this.scrollHandler,
  }) {
    _neuralPolishService = NeuralPolishService.withIndexedDb(
      state: state,
      tileManager: tileManager,
      arrowManager: arrowManager,
      nodeManager: nodeManager,
    );
  }

  void _setCurrentLayoutProcess(String value) {
    if (state.currentLayoutProcess == value) {
      return;
    }
    state.currentLayoutProcess = value;
    state.currentLayoutProcessProgress = null;
    state.currentLayoutProcessCanStop = true;
    state.currentLayoutProcessAiCollecting = false;
    tileManager.onStateUpdate();
    onStateUpdate();
  }

  Future<void> runAutoLayout() async {
    print(
      '[NEURAL_POLISH] runAutoLayout_enter isRunning=$_isRunning '
      'nodes=${state.nodes.length} autoLayoutUseNeuralPolish=${state.autoLayoutUseNeuralPolish} '
      'autoLayoutUsePolish=${state.autoLayoutUsePolish}',
    );
    if (_isRunning) {
      print('[NEURAL_POLISH] runAutoLayout_skip reason=already_running');
      return;
    }
    if (state.nodes.isEmpty) {
      print('[NEURAL_POLISH] runAutoLayout_skip reason=no_nodes');
      return;
    }

    // Создаем новый Completer для этого запуска
    _layoutCompleter = Completer<void>();

    _isRunning = true;
    state.isAutoLayoutMode = true;
    _currentIdealEdgeLength = 300; // Уменьшаем для более компактной раскладки
    _initialPositions.clear(); // Очищаем начальные позиции
    _animatedPositions.clear(); // Очищаем анимированные позиции
    _targetPositions.clear(); // Очищаем целевые позиции
    _nodeConnectionCounts.clear();
    _nodeSourceConnectionCounts.clear();
    _nodeTargetConnectionCounts.clear();
    _adjacentNodeIndices.clear();
    _nodeAttributeClusterKeys.clear();
    _attributeClusterNodeIndices.clear();
    _maxNodeConnections = 1;
    _distributionCenter = Offset.zero;
    _isAnimating = false;
    _finishAfterCurrentAnimation = false;
    _positionAnimationCompleter = null;
    animationSpeed = _defaultAnimationSpeed.clamp(0.2, 0.95);
    _isFinishing = false;
    state.autoLayoutElapsedMilliseconds = 0;
    _layoutStopwatch?.stop();
    _layoutStopwatch = Stopwatch()..start();
    _layoutElapsedTimer?.cancel();
    _layoutElapsedTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (!_isRunning || _isFinishing) {
        return;
      }
      final elapsed = _layoutStopwatch?.elapsedMilliseconds ?? 0;
      if (state.autoLayoutElapsedMilliseconds == elapsed) {
        return;
      }
      state.autoLayoutElapsedMilliseconds = elapsed;
      tileManager.onStateUpdate();
      onStateUpdate();
    });
    onStateUpdate();

    try {
      // 0. Сворачиваем все развернутые swimlane узлы перед запуском Cola
      print('[NEURAL_POLISH] runAutoLayout_before_collapse');
      await _collapseExpandedSwimlanes();
      print('[NEURAL_POLISH] runAutoLayout_after_collapse');

      // 2. Включаем loading indicator
      state.isLoading = true;
      tileManager.onStateUpdate();
      print('[NEURAL_POLISH] runAutoLayout_before_selectAllNodes');

      // 3. Переносим все узлы в nodesSelected (используем метод NodeManager)
      _nodesList.clear();
      _nodesList.addAll(await nodeManager.selectAllNodesForLayout());
      print('[NEURAL_POLISH] runAutoLayout_after_selectAllNodes count=${_nodesList.length}');

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
      _buildTopologyMetadata();
      _captureDistributionCenter();

      // 5.2 Инициализируем стартовые и целевые позиции текущим расположением
      _seedCurrentPositions();

      // 6. Удаляем все тайлы (используем метод TileManager)
      tileManager.disposeTiles();

      // 7. Переносим все связи в arrowsSelected (используем метод ArrowManager)
      arrowManager.selectAllArrows();

      if (state.autoLayoutUseCola) {
        print('[NEURAL_POLISH] runAutoLayout_branch cola');
        // 8. Инициализируем Cola если нужно
        if (!ColaInterop.isReady) {
          print('[NEURAL_POLISH] runAutoLayout_before_cola_init');
          await ColaInterop.init();
          print('[NEURAL_POLISH] runAutoLayout_after_cola_init');
        }

        // 9. Создаем Cola layout
        _createColaLayout();
        print('[NEURAL_POLISH] runAutoLayout_after_createColaLayout');

        // 10. Запускаем анимированную раскладку
        _setCurrentLayoutProcess('Смешивание');
        _runAnimatedLayout();
      } else {
        print('[NEURAL_POLISH] runAutoLayout_branch repair_only');
        _setCurrentLayoutProcess('Расстановка');
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
    _nodeSourceConnectionCounts.clear();
    _nodeTargetConnectionCounts.clear();
    for (int i = 0; i < _nodesList.length; i++) {
      _nodeConnectionCounts[i] = 0;
      _nodeSourceConnectionCounts[i] = 0;
      _nodeTargetConnectionCounts[i] = 0;
    }

    for (final edge in _virtualEdges) {
      final sourceIndex = _nodeIndexMap[edge.source];
      final targetIndex = _nodeIndexMap[edge.target];
      if (sourceIndex != null) {
        _nodeConnectionCounts[sourceIndex] = (_nodeConnectionCounts[sourceIndex] ?? 0) + 1;
        _nodeSourceConnectionCounts[sourceIndex] = (_nodeSourceConnectionCounts[sourceIndex] ?? 0) + 1;
      }
      if (targetIndex != null) {
        _nodeConnectionCounts[targetIndex] = (_nodeConnectionCounts[targetIndex] ?? 0) + 1;
        _nodeTargetConnectionCounts[targetIndex] = (_nodeTargetConnectionCounts[targetIndex] ?? 0) + 1;
      }
    }

    for (int i = 0; i < _nodesList.length; i++) {
      final node = _nodesList[i];
      if (node.qType != 'group' || node.children == null || node.children!.isEmpty) {
        continue;
      }

      int sourceCount = 0;
      int targetCount = 0;
      final childIds = node.children!.map((child) => child.id).toSet();
      for (final arrow in state.arrows) {
        if (childIds.contains(arrow.source)) {
          sourceCount++;
        }
        if (childIds.contains(arrow.target)) {
          targetCount++;
        }
      }

      _nodeSourceConnectionCounts[i] = sourceCount;
      _nodeTargetConnectionCounts[i] = targetCount;
      _nodeConnectionCounts[i] = sourceCount + targetCount;
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
      final nodeIndex = _nodeIndexMap[node.id];
      final position = (nodeIndex != null ? _targetPositions[nodeIndex] : null) ?? node.aPosition ?? (state.delta + node.position);
      sumX += position.dx + node.size.width / 2;
      sumY += position.dy + node.size.height / 2;
      count++;
    }

    _distributionCenter = count == 0 ? Offset.zero : Offset(sumX / count, sumY / count);
  }

  void _buildTopologyMetadata() {
    _adjacentNodeIndices.clear();
    _nodeAttributeClusterKeys.clear();
    _attributeClusterNodeIndices.clear();

    for (int i = 0; i < _nodesList.length; i++) {
      _adjacentNodeIndices[i] = <int>{};
      final clusterKeys = _buildAttributeClusterKeys(_nodesList[i]);
      _nodeAttributeClusterKeys[i] = clusterKeys;
      for (final key in clusterKeys) {
        _attributeClusterNodeIndices.putIfAbsent(key, () => <int>{}).add(i);
      }
    }

    for (final edge in _virtualEdges) {
      final sourceIndex = _nodeIndexMap[edge.source];
      final targetIndex = _nodeIndexMap[edge.target];
      if (sourceIndex == null || targetIndex == null) {
        continue;
      }
      _adjacentNodeIndices[sourceIndex]?.add(targetIndex);
      _adjacentNodeIndices[targetIndex]?.add(sourceIndex);
    }
  }

  Set<String> _buildAttributeClusterKeys(TableNode node) {
    final keys = <String>{
      'qType:${node.qType.toLowerCase()}',
    };

    if ((node.parent ?? '').isNotEmpty) {
      keys.add('parent:${node.parent}');
    }

    for (final attribute in node.attributes) {
      final normalizedKeys = _buildNormalizedAttributeKeys(attribute);
      keys.addAll(normalizedKeys);
    }

    return keys;
  }

  Set<String> _buildNormalizedAttributeKeys(Attribute attribute) {
    final keys = <String>{
      'attr_qType:${attribute.qType.toLowerCase()}',
    };

    final qAttributeType = attribute.qAttributeType?.trim().toLowerCase();
    if (qAttributeType != null && qAttributeType.isNotEmpty) {
      keys.add('attr_kind:$qAttributeType');
    }

    final boAttributeTypeId = attribute.boAttributeTypeId?.trim().toLowerCase();
    if (boAttributeTypeId != null && boAttributeTypeId.isNotEmpty) {
      keys.add('attr_type:$boAttributeTypeId');
    }

    final normalizedText = attribute.text.trim().toLowerCase();
    if (normalizedText.isNotEmpty) {
      keys.add('attr_text:$normalizedText');
    }

    return keys;
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
    _captureDistributionCenter();
    arrowManager.recalculateSelectedArrows();
    final repairReport = await _repairLayoutCollisions(maxIterations: 8);
    print(
      'Repair-only: iterations=${repairReport.iterations}, moved=${repairReport.movedNodes}, remaining=${repairReport.hasHardCollisions}',
    );
    await _runPostRepairStages();
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

    if (skipAnimation || !_animateRepair) {
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

    final positionAnimationCompleter = _positionAnimationCompleter;
    if (positionAnimationCompleter == null) {
      return;
    }

    await positionAnimationCompleter.future;
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
    if (!_isRunning || _isFinishing) {
      return;
    }
    _applyTargetPositionsImmediately();
    _captureDistributionCenter();

    await _runPostRepairStages();
  }

  Future<void> _runPostRepairStages() async {
    if (!_isRunning || _isFinishing) {
      return;
    }

    _setCurrentLayoutProcess('Расстановка');
    await _repairLayoutCollisions(maxIterations: 8);

    if (!_isRunning || _isFinishing) {
      return;
    }

    if (state.autoLayoutUsePolish) {
      _captureDistributionCenter();
      _setCurrentLayoutProcess('Корректировка');
      if (state.autoLayoutTrainNeuralPolish) {
        state.currentLayoutProcessAiCollecting = true;
        onStateUpdate();
      }
      await _runPolishLayout(maxIterations: 24);
    }

    if (!_isRunning || _isFinishing) {
      return;
    }

    final hasStoredNeuralModel = await _neuralPolishService.hasStoredModel();
    print(
      '[NEURAL_POLISH] gate autoLayoutUseNeuralPolish=${state.autoLayoutUseNeuralPolish} '
      'hasStoredModel=$hasStoredNeuralModel isRunning=$_isRunning isFinishing=$_isFinishing',
    );

    if (state.autoLayoutUseNeuralPolish && hasStoredNeuralModel) {
      print('[NEURAL_POLISH] stage_start');
      _setCurrentLayoutProcess('Нейрокоррекция');
      await _neuralPolishService.run();
      print('[NEURAL_POLISH] stage_end');
    }

    if (!_isRunning || _isFinishing) {
      return;
    }

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
      if (!_isRunning || _isFinishing) {
        break;
      }
      occupancy = _buildOccupancyMap();
      stats = _collectCollisionStats(occupancy);
      if (!stats.hasHardCollisions) {
        break;
      }

      executedIterations = iteration + 1;
      bool movedInIteration = false;
      final activeNodeIndices = stats.nodeScores.entries
          .where((entry) => entry.value.hasHardCollisions && _hasActualHardCollision(entry.key))
          .map((entry) => entry.key)
          .toSet();
      final nodeOrder = stats.nodeScores.entries.toList()
        ..sort((a, b) {
          final hardCompare = b.value.hardCollisionCount.compareTo(a.value.hardCollisionCount);
          if (hardCompare != 0) return hardCompare;

          final lazinessCompare = _nodeLaziness(a.key).compareTo(_nodeLaziness(b.key));
          if (lazinessCompare != 0) return lazinessCompare;

          final centerCompare = a.value.centerDistance.compareTo(b.value.centerDistance);
          if (centerCompare != 0) return centerCompare;

          return b.value.totalScore.compareTo(a.value.totalScore);
        });

      for (final entry in nodeOrder) {
        if (!_isRunning || _isFinishing) {
          break;
        }
        if (!activeNodeIndices.contains(entry.key)) {
          continue;
        }
        occupancy = _buildOccupancyMap();
        final currentStats = _collectCollisionStats(occupancy);
        final currentScore = currentStats.nodeScores[entry.key];
        if (currentScore == null || !currentScore.hasHardCollisions || !_hasActualHardCollision(entry.key)) {
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
        final originPosition = node.aPosition ?? (state.delta + node.position);
        if (state.autoLayoutTrainNeuralPolish) {
          await _neuralPolishService.saveAcceptedPlacementSample(
            node: node,
            originPosition: originPosition,
            candidatePosition: bestCandidate.position,
            sampleSource: 'auto_repair',
          );
        }

        if (skipAnimation || !_animateRepair) {
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

    return _RepairReport(
      iterations: executedIterations,
      movedNodes: movedNodes,
      hasHardCollisions: stats.hasHardCollisions,
    );
  }

  Future<_RepairReport> _runPolishLayout({required int maxIterations}) async {
    var occupancy = _buildOccupancyMap();
    var stats = _collectCollisionStats(occupancy, mode: _ScoringMode.polish);

    if (!stats.hasHardCollisions) {
      return const _RepairReport(iterations: 0, movedNodes: 0, hasHardCollisions: false);
    }

    int movedNodes = 0;
    int executedIterations = 0;

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      if (!_isRunning || _isFinishing) {
        break;
      }
      occupancy = _buildOccupancyMap();
      stats = _collectCollisionStats(occupancy, mode: _ScoringMode.polish);
      if (!stats.hasHardCollisions) {
        break;
      }

      final nodeOrder = stats.nodeScores.entries.where((entry) => entry.value.hasHardCollisions).toList()
        ..sort((a, b) {
          final arrowCompare = b.value.arrowOverlapCount.compareTo(a.value.arrowOverlapCount);
          if (arrowCompare != 0) return arrowCompare;

          final arrowAreaCompare = b.value.arrowOverlapArea.compareTo(a.value.arrowOverlapArea);
          if (arrowAreaCompare != 0) return arrowAreaCompare;

          final lazinessCompare = _nodeLaziness(a.key).compareTo(_nodeLaziness(b.key));
          if (lazinessCompare != 0) return lazinessCompare;

          return b.value.totalScore.compareTo(a.value.totalScore);
        });
      final activeNodeIndices = nodeOrder.where((entry) => _hasActualHardCollision(entry.key)).map((entry) => entry.key).toSet();

      if (nodeOrder.isEmpty) {
        break;
      }

      executedIterations = iteration + 1;
      bool movedInIteration = false;

      for (final entry in nodeOrder) {
        if (!_isRunning || _isFinishing) {
          break;
        }
        if (!activeNodeIndices.contains(entry.key)) {
          continue;
        }
        occupancy = _buildOccupancyMap();
        final currentStats = _collectCollisionStats(occupancy, mode: _ScoringMode.polish);
        final currentScore = currentStats.nodeScores[entry.key];
        if (currentScore == null || !currentScore.hasHardCollisions || !_hasActualHardCollision(entry.key)) {
          continue;
        }

        final bestCandidate = _findBestPositionByRings(
          nodeIndex: entry.key,
          occupancy: occupancy,
          currentScore: currentScore,
          mode: _ScoringMode.polish,
          maxRings: 20,
          angleStepDegrees: 10,
        );

        if (bestCandidate == null) {
          continue;
        }

        _targetPositions[entry.key] = bestCandidate.position;
        _initialPositions[entry.key] = bestCandidate.position;
        movedNodes++;
        movedInIteration = true;

        final node = _nodesList[entry.key];
        final originPosition = node.aPosition ?? (state.delta + node.position);
        if (state.autoLayoutTrainNeuralPolish) {
          await _neuralPolishService.saveAcceptedPlacementSample(
            node: node,
            originPosition: originPosition,
            candidatePosition: bestCandidate.position,
            sampleSource: 'auto_polish',
          );
        }
        if (skipAnimation || !_animateRepair) {
          nodeManager.updateNodePositionForLayout(node, bestCandidate.position);
          _animatedPositions[entry.key] = bestCandidate.position;
          arrowManager.recalculateSelectedArrows();
        } else {
          await _animateToTargetsAndWait();
        }

        final refreshedOccupancy = _buildOccupancyMap();
        final refreshedStats = _collectCollisionStats(refreshedOccupancy, mode: _ScoringMode.polish);
        if (!refreshedStats.hasHardCollisions) {
          return _RepairReport(
            iterations: executedIterations,
            movedNodes: movedNodes,
            hasHardCollisions: false,
          );
        }
      }

      occupancy = _buildOccupancyMap();
      stats = _collectCollisionStats(occupancy, mode: _ScoringMode.polish);
      if (!movedInIteration || !stats.hasHardCollisions) {
        break;
      }
    }

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
            rect: _expandRect(rect, 14),
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
          rect: _segmentToRect(p1, p2, 20),
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

  bool _hasActualHardCollision(int nodeIndex) {
    final node = _nodesList[nodeIndex];
    final position = _targetPositions[nodeIndex] ?? node.aPosition;
    if (position == null) {
      return false;
    }

    final candidateRect = Utils.calculateNodeRect(node: node, position: position);

    for (int i = 0; i < _nodesList.length; i++) {
      if (i == nodeIndex) {
        continue;
      }
      final otherNode = _nodesList[i];
      final otherPosition = _targetPositions[i] ?? otherNode.aPosition;
      if (otherPosition == null) {
        continue;
      }
      final otherRect = Utils.calculateNodeRect(node: otherNode, position: otherPosition);
      if (_overlapArea(candidateRect, otherRect) > 0) {
        return true;
      }
    }

    final childToParent = _buildChildToParentMap();
    for (final arrow in state.arrowsSelected) {
      if (arrow == null) continue;

      final incidentNodeIndices = <int>{};
      final sourceId = childToParent[arrow.source] ?? arrow.source;
      final targetId = childToParent[arrow.target] ?? arrow.target;
      final sourceIndex = _nodeIndexMap[sourceId];
      final targetIndex = _nodeIndexMap[targetId];
      if (sourceIndex != null) incidentNodeIndices.add(sourceIndex);
      if (targetIndex != null) incidentNodeIndices.add(targetIndex);
      if (incidentNodeIndices.contains(nodeIndex)) {
        continue;
      }

      final rects = arrow.rects;
      if (rects != null && rects.isNotEmpty) {
        for (final rect in rects) {
          if (_overlapArea(candidateRect, rect) > 0) {
            return true;
          }
        }
        continue;
      }

      final coordinates = arrow.coordinates;
      if (coordinates == null || coordinates.length < 2) {
        continue;
      }
      for (int i = 0; i < coordinates.length - 1; i++) {
        final segmentRect = _segmentToRect(coordinates[i], coordinates[i + 1], EditorConfig.arrowSelectedWidth);
        if (_overlapArea(candidateRect, segmentRect) > 0) {
          return true;
        }
      }
    }

    return false;
  }

  _CollisionStats _collectCollisionStats(_OccupancyMap occupancy, { _ScoringMode mode = _ScoringMode.repair }) {
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
        mode: mode,
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
    _ScoringMode mode = _ScoringMode.repair,
    int maxRings = 8,
    int angleStepDegrees = 15,
  }) {
    final node = _nodesList[nodeIndex];
    final currentPosition = _targetPositions[nodeIndex] ?? node.aPosition ?? Offset.zero;
    final baseStep = max(24.0, (max(node.size.width, node.size.height) / 2 + _nodeClearance(node) + 20) * 0.4);
    final effectiveMaxRings = _effectiveMaxRings(nodeIndex, mode, maxRings);
    _CandidateResult? bestResult;
    final prioritizedAngles = _buildPrioritizedAngles(nodeIndex, node, currentPosition, angleStepDegrees: angleStepDegrees);

    for (int ring = 1; ring <= effectiveMaxRings; ring++) {
      final radius = baseStep * ring;
      for (final angle in prioritizedAngles) {
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
          mode: mode,
        );
        bestResult = _considerCandidateResult(
          nodeIndex: nodeIndex,
          occupancy: occupancy,
          currentPosition: currentPosition,
          baselineScore: currentScore,
          bestResult: bestResult,
          candidatePosition: candidatePosition,
          candidateScore: candidateScore,
          mode: mode,
        );
      }

      final supplementalCandidates = _buildSupplementalCandidatePositions(
        nodeIndex: nodeIndex,
        currentPosition: currentPosition,
        radius: radius,
        mode: mode,
      );
      for (final candidatePosition in supplementalCandidates) {
        final candidateScore = _evaluateCandidatePosition(
          nodeIndex: nodeIndex,
          position: candidatePosition,
          occupancy: occupancy,
          anchorPosition: currentPosition,
          mode: mode,
        );
        bestResult = _considerCandidateResult(
          nodeIndex: nodeIndex,
          occupancy: occupancy,
          currentPosition: currentPosition,
          baselineScore: currentScore,
          bestResult: bestResult,
          candidatePosition: candidatePosition,
          candidateScore: candidateScore,
          mode: mode,
        );
      }

      if (bestResult != null && !bestResult.score.hasHardCollisions) {
        break;
      }
    }

    return bestResult;
  }

  _CandidateResult? _considerCandidateResult({
    required int nodeIndex,
    required _OccupancyMap occupancy,
    required Offset currentPosition,
    required _CandidateScore baselineScore,
    required _CandidateResult? bestResult,
    required Offset candidatePosition,
    required _CandidateScore candidateScore,
    required _ScoringMode mode,
  }) {
    if (_isScoreBetter(candidateScore, baselineScore)) {
      if (bestResult == null || _isScoreBetter(candidateScore, bestResult.score)) {
        bestResult = _CandidateResult(position: candidatePosition, score: candidateScore);
      }
    }

    final snappedResult = _buildSnappedCandidateResult(
      nodeIndex: nodeIndex,
      occupancy: occupancy,
      currentPosition: currentPosition,
      candidatePosition: candidatePosition,
      baselineScore: baselineScore,
      mode: mode,
    );

    if (snappedResult == null) {
      return bestResult;
    }

    if (bestResult == null || _isScoreBetter(snappedResult.score, bestResult.score)) {
      return snappedResult;
    }

    return bestResult;
  }

  _CandidateResult? _buildSnappedCandidateResult({
    required int nodeIndex,
    required _OccupancyMap occupancy,
    required Offset currentPosition,
    required Offset candidatePosition,
    required _CandidateScore baselineScore,
    required _ScoringMode mode,
  }) {
    if (!_isSectorSnapEnabled(mode)) {
      return null;
    }

    final snappedPositions = _buildSectorSnapCandidatePositions(
      nodeIndex: nodeIndex,
      occupancy: occupancy,
      candidatePosition: candidatePosition,
      mode: mode,
    );
    if (snappedPositions.isEmpty) {
      return null;
    }

    _CandidateResult? bestSnappedResult;
    for (final snappedPosition in snappedPositions) {
      if ((snappedPosition - candidatePosition).distance <= 0.01) {
        continue;
      }

      final snappedScore = _evaluateCandidatePosition(
        nodeIndex: nodeIndex,
        position: snappedPosition,
        occupancy: occupancy,
        anchorPosition: currentPosition,
        mode: mode,
      );

      if (!_isScoreBetter(snappedScore, baselineScore)) {
        continue;
      }

      if (bestSnappedResult == null || _isScoreBetter(snappedScore, bestSnappedResult.score)) {
        bestSnappedResult = _CandidateResult(position: snappedPosition, score: snappedScore);
      }
    }

    return bestSnappedResult;
  }

  bool _isSectorSnapEnabled(_ScoringMode mode) {
    switch (mode) {
      case _ScoringMode.repair:
        return state.autoLayoutUseSnapOnRepair;
      case _ScoringMode.polish:
        return state.autoLayoutUseSnapOnPolish;
    }
  }

  List<Offset> _buildSectorSnapCandidatePositions({
    required int nodeIndex,
    required _OccupancyMap occupancy,
    required Offset candidatePosition,
    required _ScoringMode mode,
  }) {
    final node = _nodesList[nodeIndex];
    final nodeCenter = Offset(
      candidatePosition.dx + node.size.width / 2,
      candidatePosition.dy + node.size.height / 2,
    );
    final sector = _resolveSnapSector(nodeCenter);

    final eligibleNodeIndices = _resolveEligibleSectorSnapNodeIndices(nodeIndex, sector);
    if (eligibleNodeIndices.isEmpty) {
      return const [];
    }

    final lanes = _buildSectorLanes(eligibleNodeIndices, sector);
    if (lanes.isEmpty) {
      return const [];
    }

    final itemGap = _estimateLaneItemGap(lanes, sector, nodeIndex: nodeIndex).clamp(24.0, 120.0);
    final laneSpacing = _resolveSectorLaneSpacing(
      baseSpacing: _estimateLaneSpacing(lanes, fallback: itemGap).clamp(24.0, 120.0),
      itemGap: itemGap,
      mode: mode,
    );
    final candidateLanes = _buildCandidateLanesForSnap(
      lanes,
      sector,
      candidatePosition,
      node.size,
      laneSpacing,
    );
    final result = <Offset>[];
    final seen = <String>{};

    void addPosition(Offset rawPosition) {
      final constrained = _constrainNodeToCanvas(node, rawPosition);
      if (_isSnapPositionOccupied(nodeIndex: nodeIndex, occupancy: occupancy, position: constrained)) {
        return;
      }
      final signature = '${constrained.dx.toStringAsFixed(2)}:${constrained.dy.toStringAsFixed(2)}';
      if (seen.add(signature)) {
        result.add(constrained);
      }
    }

    for (final lane in candidateLanes) {
      final positions = _buildLanePositionCandidates(
        lane: lane,
        sector: sector,
        candidatePosition: candidatePosition,
        itemGap: itemGap,
        nodeSize: node.size,
        mode: mode,
      );
      for (final position in positions) {
        addPosition(position);
      }
    }

    return result;
  }

  List<int> _resolveEligibleSectorSnapNodeIndices(int nodeIndex, _SnapSector sector) {
    final node = _nodesList[nodeIndex];
    if ((node.qType == 'group' || node.qType == 'swimlane') && node.parent != null) {
      final parentIndex = _nodeIndexMap[node.parent!];
      if (parentIndex == null || parentIndex == nodeIndex) {
        return const [];
      }
      return [parentIndex];
    }

    final result = <int>[];
    for (int i = 0; i < _nodesList.length; i++) {
      if (i == nodeIndex) {
        continue;
      }
      final otherPosition = _targetPositions[i] ?? _nodesList[i].aPosition;
      if (otherPosition == null) {
        continue;
      }
      final otherCenter = Offset(
        otherPosition.dx + _nodesList[i].size.width / 2,
        otherPosition.dy + _nodesList[i].size.height / 2,
      );
      if (_resolveSnapSector(otherCenter) == sector) {
        result.add(i);
      }
    }
    return result;
  }

  List<_SectorLane> _buildSectorLanes(List<int> nodeIndices, _SnapSector sector) {
    const laneTolerance = 28.0;
    final lanes = <_SectorLane>[];

    for (final nodeIndex in nodeIndices) {
      final node = _nodesList[nodeIndex];
      final position = _targetPositions[nodeIndex] ?? node.aPosition;
      if (position == null) {
        continue;
      }
      final line = switch (sector) {
        _SnapSector.top => position.dy + node.size.height,
        _SnapSector.bottom => position.dy,
        _SnapSector.left => position.dx + node.size.width,
        _SnapSector.right => position.dx,
      };
      final item = _SectorLaneItem(
        nodeIndex: nodeIndex,
        left: position.dx,
        right: position.dx + node.size.width,
        top: position.dy,
        bottom: position.dy + node.size.height,
        width: node.size.width,
        height: node.size.height,
      );

      _SectorLane? targetLane;
      double bestDistance = double.infinity;
      for (final lane in lanes) {
        final distance = (lane.line - line).abs();
        if (distance <= laneTolerance && distance < bestDistance) {
          bestDistance = distance;
          targetLane = lane;
        }
      }

      if (targetLane == null) {
        lanes.add(_SectorLane(line: line, items: [item]));
      } else {
        targetLane.items.add(item);
        final count = targetLane.items.length;
        targetLane.line = ((targetLane.line * (count - 1)) + line) / count;
      }
    }

    for (final lane in lanes) {
      lane.items.sort((a, b) {
        final first = _isHorizontalSector(sector) ? a.left : a.top;
        final second = _isHorizontalSector(sector) ? b.left : b.top;
        return first.compareTo(second);
      });
    }
    lanes.sort((a, b) => a.line.compareTo(b.line));
    return lanes;
  }

  double _estimateLaneItemGap(List<_SectorLane> lanes, _SnapSector sector, {required int nodeIndex}) {
    final gaps = <double>[];
    for (final lane in lanes) {
      for (int i = 0; i < lane.items.length - 1; i++) {
        final current = lane.items[i];
        final next = lane.items[i + 1];
        final gap = _isHorizontalSector(sector) ? next.left - current.right : next.top - current.bottom;
        if (gap > 0) {
          gaps.add(gap);
        }
      }
    }
    if (gaps.isNotEmpty) {
      gaps.sort();
      return gaps[gaps.length ~/ 2];
    }
    final node = _nodesList[nodeIndex];
    return _isHorizontalSector(sector) ? max(32.0, node.size.width * 0.35) : max(32.0, node.size.height * 0.35);
  }

  double _estimateLaneSpacing(List<_SectorLane> lanes, {required double fallback}) {
    final distances = <double>[];
    for (int i = 0; i < lanes.length - 1; i++) {
      final distance = (lanes[i + 1].line - lanes[i].line).abs();
      if (distance > 0) {
        distances.add(distance);
      }
    }
    if (distances.isNotEmpty) {
      distances.sort();
      return distances[distances.length ~/ 2];
    }
    return fallback;
  }

  double _resolveSectorLaneSpacing({
    required double baseSpacing,
    required double itemGap,
    required _ScoringMode mode,
  }) {
    if (mode != _ScoringMode.polish) {
      return baseSpacing;
    }

    final denseSpacing = max(18.0, itemGap * 0.85);
    return min(baseSpacing, denseSpacing);
  }

  List<_SectorLane> _buildCandidateLanesForSnap(
    List<_SectorLane> lanes,
    _SnapSector sector,
    Offset candidatePosition,
    Size nodeSize,
    double laneSpacing,
  ) {
    final candidateLine = switch (sector) {
      _SnapSector.top => candidatePosition.dy + nodeSize.height,
      _SnapSector.bottom => candidatePosition.dy,
      _SnapSector.left => candidatePosition.dx + nodeSize.width,
      _SnapSector.right => candidatePosition.dx,
    };
    final cloned = lanes.map((lane) => _SectorLane(line: lane.line, items: List<_SectorLaneItem>.from(lane.items))).toList();
    cloned.sort((a, b) => (a.line - candidateLine).abs().compareTo((b.line - candidateLine).abs()));
    if (cloned.isEmpty) {
      return [];
    }

    final baseLane = cloned.first;
    final extraLanes = <_SectorLane>[...cloned];
    extraLanes.add(_SectorLane(line: baseLane.line - laneSpacing, items: []));
    extraLanes.add(_SectorLane(line: baseLane.line + laneSpacing, items: []));
    extraLanes.sort((a, b) => (a.line - candidateLine).abs().compareTo((b.line - candidateLine).abs()));
    return extraLanes;
  }

  List<Offset> _buildLanePositionCandidates({
    required _SectorLane lane,
    required _SnapSector sector,
    required Offset candidatePosition,
    required double itemGap,
    required Size nodeSize,
    required _ScoringMode mode,
  }) {
    final bounds = _getDynamicCanvasBounds();
    final maxLeft = max(bounds.left, bounds.right - nodeSize.width);
    final maxTop = max(bounds.top, bounds.bottom - nodeSize.height);
    final candidates = <Offset>[];
    final seen = <String>{};
    final compactGap = mode == _ScoringMode.polish ? max(16.0, itemGap * 0.72) : itemGap;

    void add(Offset position) {
      final clamped = Offset(
        position.dx.clamp(bounds.left, maxLeft).toDouble(),
        position.dy.clamp(bounds.top, maxTop).toDouble(),
      );
      final key = '${clamped.dx.toStringAsFixed(2)}:${clamped.dy.toStringAsFixed(2)}';
      if (seen.add(key)) {
        candidates.add(clamped);
      }
    }

    add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: candidatePosition, nodeSize: nodeSize));

    if (lane.items.isEmpty) {
      return candidates;
    }

    if (_isHorizontalSector(sector)) {
      add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: Offset(lane.items.first.left - compactGap - nodeSize.width, candidatePosition.dy), nodeSize: nodeSize));
      add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: Offset(lane.items.last.right + compactGap, candidatePosition.dy), nodeSize: nodeSize));

      for (int i = 0; i < lane.items.length - 1; i++) {
        final current = lane.items[i];
        final next = lane.items[i + 1];
        final freeSpace = next.left - current.right;
        if (freeSpace >= nodeSize.width) {
          add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: Offset(current.right + compactGap, candidatePosition.dy), nodeSize: nodeSize));
          add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: Offset(next.left - compactGap - nodeSize.width, candidatePosition.dy), nodeSize: nodeSize));
          if (mode != _ScoringMode.polish) {
            add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: Offset(current.right + (freeSpace - nodeSize.width) / 2, candidatePosition.dy), nodeSize: nodeSize));
          }
        }
      }
    } else {
      add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: Offset(candidatePosition.dx, lane.items.first.top - compactGap - nodeSize.height), nodeSize: nodeSize));
      add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: Offset(candidatePosition.dx, lane.items.last.bottom + compactGap), nodeSize: nodeSize));

      for (int i = 0; i < lane.items.length - 1; i++) {
        final current = lane.items[i];
        final next = lane.items[i + 1];
        final freeSpace = next.top - current.bottom;
        if (freeSpace >= nodeSize.height) {
          add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: Offset(candidatePosition.dx, current.bottom + compactGap), nodeSize: nodeSize));
          add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: Offset(candidatePosition.dx, next.top - compactGap - nodeSize.height), nodeSize: nodeSize));
          if (mode != _ScoringMode.polish) {
            add(_positionOnLane(sector: sector, laneLine: lane.line, candidatePosition: Offset(candidatePosition.dx, current.bottom + (freeSpace - nodeSize.height) / 2), nodeSize: nodeSize));
          }
        }
      }
    }

    candidates.sort((a, b) => (a - candidatePosition).distance.compareTo((b - candidatePosition).distance));
    return candidates;
  }

  Offset _positionOnLane({
    required _SnapSector sector,
    required double laneLine,
    required Offset candidatePosition,
    required Size nodeSize,
  }) {
    return switch (sector) {
      _SnapSector.top => Offset(candidatePosition.dx, laneLine - nodeSize.height),
      _SnapSector.bottom => Offset(candidatePosition.dx, laneLine),
      _SnapSector.left => Offset(laneLine - nodeSize.width, candidatePosition.dy),
      _SnapSector.right => Offset(laneLine, candidatePosition.dy),
    };
  }

  bool _isHorizontalSector(_SnapSector sector) {
    return sector == _SnapSector.top || sector == _SnapSector.bottom;
  }

  bool _isSnapPositionOccupied({
    required int nodeIndex,
    required _OccupancyMap occupancy,
    required Offset position,
  }) {
    final node = _nodesList[nodeIndex];
    final candidateRect = _buildNodeOccupiedRect(node, position);

    for (final occupiedNode in occupancy.nodeRects) {
      if (occupiedNode.nodeIndex == nodeIndex) {
        continue;
      }
      if (_overlapArea(candidateRect, occupiedNode.rect) > 0) {
        return true;
      }
    }

    for (final occupiedArrow in occupancy.arrowRects) {
      if (occupiedArrow.incidentNodeIndices.contains(nodeIndex)) {
        continue;
      }
      if (_overlapArea(candidateRect, occupiedArrow.rect) > 0) {
        return true;
      }
    }

    return false;
  }

  _SnapSector _resolveSnapSector(Offset nodeCenter) {
    final dx = nodeCenter.dx - _distributionCenter.dx;
    final dy = nodeCenter.dy - _distributionCenter.dy;

    if (dy <= -dx && dy <= dx) {
      return _SnapSector.top;
    }
    if (dx >= dy && dx >= -dy) {
      return _SnapSector.right;
    }
    if (dy >= dx && dy >= -dx) {
      return _SnapSector.bottom;
    }
    return _SnapSector.left;
  }

  List<double> _buildPrioritizedAngles(int nodeIndex, TableNode node, Offset currentPosition, {required int angleStepDegrees}) {
    final nodeCenter = Offset(
      currentPosition.dx + node.size.width / 2,
      currentPosition.dy + node.size.height / 2,
    );
    final baseVector = _resolveRepairPriorityVector(nodeIndex, node, nodeCenter);
    final baseAngle = baseVector.distance <= 0.001 ? 0.0 : atan2(baseVector.dy, baseVector.dx);

    final prioritized = <double>[];
    final seen = <int>{};

    void addAngle(int degrees) {
      final normalized = ((degrees % 360) + 360) % 360;
      if (seen.add(normalized)) {
        prioritized.add(normalized * pi / 180);
      }
    }

    final baseDegrees = (baseAngle * 180 / pi).round();

    for (int offset = 0; offset <= 45; offset += angleStepDegrees) {
      addAngle(baseDegrees + offset);
      if (offset != 0) {
        addAngle(baseDegrees - offset);
      }
    }

    for (int offset = 60; offset <= 180; offset += angleStepDegrees) {
      addAngle(baseDegrees + offset);
      addAngle(baseDegrees - offset);
    }

    return prioritized;
  }

  Offset _resolveRepairPriorityVector(int nodeIndex, TableNode node, Offset nodeCenter) {
    if (node.qType == 'swimlane') {
      return const Offset(1, 1);
    }
    return nodeCenter - _distributionCenter;
  }

  List<Offset> _buildSupplementalCandidatePositions({
    required int nodeIndex,
    required Offset currentPosition,
    required double radius,
    _ScoringMode mode = _ScoringMode.repair,
  }) {
    final node = _nodesList[nodeIndex];
    final candidates = <Offset>[];
    final seen = <String>{};

    void addCandidate(Offset raw) {
      final constrained = _constrainNodeToCanvas(node, raw);
      final signature = '${constrained.dx.toStringAsFixed(2)}:${constrained.dy.toStringAsFixed(2)}';
      if (seen.add(signature)) {
        candidates.add(constrained);
      }
    }

    final neighborAnchor = _calculateNeighborAnchorPosition(nodeIndex);
    if (neighborAnchor != null) {
      addCandidate(neighborAnchor);
      final vector = neighborAnchor - currentPosition;
      if (vector.distance > 0.001) {
        final normalized = vector / vector.distance;
        addCandidate(currentPosition + normalized * (radius * 0.6));
      }
    }

    final clusterAnchor = _calculateAttributeClusterAnchorPosition(nodeIndex);
    if (clusterAnchor != null) {
      addCandidate(clusterAnchor);
      final vector = clusterAnchor - currentPosition;
      if (vector.distance > 0.001) {
        final normalized = vector / vector.distance;
        addCandidate(currentPosition + normalized * (radius * 0.75));
      }
    }

    if (neighborAnchor != null && clusterAnchor != null) {
      addCandidate(Offset(
        (neighborAnchor.dx + clusterAnchor.dx) / 2,
        (neighborAnchor.dy + clusterAnchor.dy) / 2,
      ));
    }

    if (mode == _ScoringMode.polish) {
      final nodeCenter = Offset(
        currentPosition.dx + node.size.width / 2,
        currentPosition.dy + node.size.height / 2,
      );
      final toCenter = _distributionCenter - nodeCenter;
      if (toCenter.distance > 0.001) {
        final normalized = toCenter / toCenter.distance;
        final centerSteps = <double>[
          max(16.0, radius * 0.35),
          max(24.0, radius * 0.65),
          max(32.0, radius),
        ];
        for (final step in centerSteps) {
          addCandidate(currentPosition + normalized * step);
        }

        final centerAlignedPosition = Offset(
          _distributionCenter.dx - node.size.width / 2,
          _distributionCenter.dy - node.size.height / 2,
        );
        addCandidate(Offset(
          currentPosition.dx,
          centerAlignedPosition.dy,
        ));
        addCandidate(Offset(
          centerAlignedPosition.dx,
          currentPosition.dy,
        ));
        addCandidate(centerAlignedPosition);
      }
    }

    return candidates;
  }

  Offset? _calculateNeighborAnchorPosition(int nodeIndex) {
    final adjacentIndices = _adjacentNodeIndices[nodeIndex];
    if (adjacentIndices == null || adjacentIndices.isEmpty) {
      return null;
    }

    double sumX = 0;
    double sumY = 0;
    int count = 0;
    for (final adjacentIndex in adjacentIndices) {
      final center = _nodeCenterAtIndex(adjacentIndex);
      if (center == null) {
        continue;
      }
      final adjacentNode = _nodesList[adjacentIndex];
      sumX += center.dx - adjacentNode.size.width / 2;
      sumY += center.dy - adjacentNode.size.height / 2;
      count++;
    }

    if (count == 0) {
      return null;
    }

    final node = _nodesList[nodeIndex];
    return Offset(
      sumX / count - node.size.width / 2,
      sumY / count - node.size.height / 2,
    );
  }

  Offset? _calculateAttributeClusterAnchorPosition(int nodeIndex) {
    final clusterKeys = _nodeAttributeClusterKeys[nodeIndex];
    if (clusterKeys == null || clusterKeys.isEmpty) {
      return null;
    }

    double sumX = 0;
    double sumY = 0;
    double totalWeight = 0;

    for (final key in clusterKeys) {
      final clusterNodes = _attributeClusterNodeIndices[key];
      if (clusterNodes == null || clusterNodes.length < 2) {
        continue;
      }

      for (final clusterNodeIndex in clusterNodes) {
        if (clusterNodeIndex == nodeIndex) {
          continue;
        }
        final center = _nodeCenterAtIndex(clusterNodeIndex);
        if (center == null) {
          continue;
        }
        final weight = key.startsWith('attr_text:') ? 0.6 : 1.0;
        sumX += center.dx * weight;
        sumY += center.dy * weight;
        totalWeight += weight;
      }
    }

    if (totalWeight <= 0) {
      return null;
    }

    final node = _nodesList[nodeIndex];
    return Offset(sumX / totalWeight - node.size.width / 2, sumY / totalWeight - node.size.height / 2);
  }

  Offset? _nodeCenterAtIndex(int nodeIndex) {
    final node = _nodesList[nodeIndex];
    final position = _targetPositions[nodeIndex] ?? node.aPosition;
    if (position == null) {
      return null;
    }
    return Offset(position.dx + node.size.width / 2, position.dy + node.size.height / 2);
  }

  _CandidateScore _evaluateCandidatePosition({
    required int nodeIndex,
    required Offset position,
    required _OccupancyMap occupancy,
    required Offset anchorPosition,
    _ScoringMode mode = _ScoringMode.repair,
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
    final rawDistancePenalty = (position - anchorPosition).distance;
    final weights = _weightsForMode(mode);
    final distancePenalty = rawDistancePenalty * _lazyDistanceMultiplier(nodeIndex, mode);
    final centerPenalty = centerDistance * _centerAffinity(nodeIndex) * _lazyCenterMultiplier(nodeIndex, mode) * weights.centerWeight;
    final connectedNodeDistancePenalty = _connectedNodeDistancePenalty(nodeIndex, nodeCenter);
    final connectedNodeDirectionPenalty = _connectedNodeDirectionPenalty(nodeIndex, position, anchorPosition);
    final attributeClusterPenalty = _attributeClusterPenalty(nodeIndex, nodeCenter);
    final totalScore =
        nodeOverlapArea * weights.nodeOverlapAreaWeight +
        arrowOverlapArea * weights.arrowOverlapAreaWeight +
        nodeOverlapCount * weights.nodeOverlapCountWeight +
        arrowOverlapCount * weights.arrowOverlapCountWeight +
        distancePenalty * weights.distanceWeight +
        centerPenalty +
        connectedNodeDistancePenalty * weights.connectedNodeDistanceWeight +
        connectedNodeDirectionPenalty * weights.connectedNodeDirectionWeight +
        attributeClusterPenalty * weights.attributeClusterWeight;

    return _CandidateScore(
      nodeOverlapArea: nodeOverlapArea,
      arrowOverlapArea: arrowOverlapArea,
      nodeOverlapCount: nodeOverlapCount,
      arrowOverlapCount: arrowOverlapCount,
      centerDistance: centerDistance,
      centerPenalty: centerPenalty,
      distancePenalty: distancePenalty,
      connectedNodeDistancePenalty: connectedNodeDistancePenalty,
      connectedNodeDirectionPenalty: connectedNodeDirectionPenalty,
      attributeClusterPenalty: attributeClusterPenalty,
      totalScore: totalScore,
    );
  }

  double _connectedNodeDistancePenalty(int nodeIndex, Offset nodeCenter) {
    final adjacentIndices = _adjacentNodeIndices[nodeIndex];
    if (adjacentIndices == null || adjacentIndices.isEmpty) {
      return 0;
    }

    double penalty = 0;
    int count = 0;
    for (final adjacentIndex in adjacentIndices) {
      final adjacentCenter = _nodeCenterAtIndex(adjacentIndex);
      if (adjacentCenter == null) {
        continue;
      }
      penalty += (nodeCenter - adjacentCenter).distance;
      count++;
    }

    return count == 0 ? 0 : penalty / count;
  }

  double _connectedNodeDirectionPenalty(int nodeIndex, Offset position, Offset anchorPosition) {
    final neighborAnchor = _calculateNeighborAnchorPosition(nodeIndex);
    if (neighborAnchor == null) {
      return 0;
    }

    final desiredVector = neighborAnchor - anchorPosition;
    final actualVector = position - anchorPosition;
    if (desiredVector.distance <= 0.001 || actualVector.distance <= 0.001) {
      return 0;
    }

    final dot = desiredVector.dx * actualVector.dx + desiredVector.dy * actualVector.dy;
    final cosine = (dot / (desiredVector.distance * actualVector.distance)).clamp(-1.0, 1.0);
    return (1 - cosine) * actualVector.distance;
  }

  double _attributeClusterPenalty(int nodeIndex, Offset nodeCenter) {
    final clusterKeys = _nodeAttributeClusterKeys[nodeIndex];
    if (clusterKeys == null || clusterKeys.isEmpty) {
      return 0;
    }

    double penalty = 0;
    double totalWeight = 0;
    for (final key in clusterKeys) {
      final clusterNodeIndices = _attributeClusterNodeIndices[key];
      if (clusterNodeIndices == null || clusterNodeIndices.length < 2) {
        continue;
      }

      for (final clusterNodeIndex in clusterNodeIndices) {
        if (clusterNodeIndex == nodeIndex) {
          continue;
        }
        final clusterCenter = _nodeCenterAtIndex(clusterNodeIndex);
        if (clusterCenter == null) {
          continue;
        }
        final weight = key.startsWith('attr_text:') ? 0.5 : 1.0;
        penalty += (nodeCenter - clusterCenter).distance * weight;
        totalWeight += weight;
      }
    }

    return totalWeight == 0 ? 0 : penalty / totalWeight;
  }

  double _centerAffinity(int nodeIndex) {
    final connectionRatio = (_nodeConnectionCounts[nodeIndex] ?? 0) / _maxNodeConnections;
    return _centerAffinityBase + connectionRatio * _centerAffinityConnectivityFactor;
  }

  double _nodeLaziness(int nodeIndex) {
    final connectionRatio = ((_nodeConnectionCounts[nodeIndex] ?? 0) / max(1, _maxNodeConnections)).clamp(0.0, 1.0);
    if (connectionRatio <= _lazyNodeActivationThreshold) {
      return 0;
    }
    final normalized =
        ((connectionRatio - _lazyNodeActivationThreshold) / (1 - _lazyNodeActivationThreshold)).clamp(0.0, 1.0);
    return normalized * normalized * normalized;
  }

  double _lazyDistanceMultiplier(int nodeIndex, _ScoringMode mode) {
    if (mode != _ScoringMode.repair && mode != _ScoringMode.polish) {
      return 1;
    }
    return 1 + _nodeLaziness(nodeIndex) * _lazyNodeDistancePenaltyBoost;
  }

  double _lazyCenterMultiplier(int nodeIndex, _ScoringMode mode) {
    if (mode != _ScoringMode.repair && mode != _ScoringMode.polish) {
      return 1;
    }
    return 1 + _nodeLaziness(nodeIndex) * _lazyNodeCenterBoost;
  }

  int _effectiveMaxRings(int nodeIndex, _ScoringMode mode, int baseMaxRings) {
    if (mode != _ScoringMode.repair && mode != _ScoringMode.polish) {
      return baseMaxRings;
    }
    final laziness = _nodeLaziness(nodeIndex);
    final radiusFactor = (1 - laziness * (1 - _lazyNodeMinRadiusFactor)).clamp(_lazyNodeMinRadiusFactor, 1.0);
    return max(1, (baseMaxRings * radiusFactor).round());
  }

  _LayoutWeights _weightsForMode(_ScoringMode mode) {
    switch (mode) {
      case _ScoringMode.polish:
        return const _LayoutWeights(
          nodeOverlapAreaWeight: _polishNodeOverlapAreaWeight,
          arrowOverlapAreaWeight: _polishArrowOverlapAreaWeight,
          nodeOverlapCountWeight: _polishNodeOverlapCountWeight,
          arrowOverlapCountWeight: _polishArrowOverlapCountWeight,
          distanceWeight: _polishDistanceWeight,
          centerWeight: _polishCenterWeight,
          connectedNodeDistanceWeight: _polishConnectedNodeDistanceWeight,
          connectedNodeDirectionWeight: _polishConnectedNodeDirectionWeight,
          attributeClusterWeight: _polishAttributeClusterWeight,
        );
      case _ScoringMode.repair:
        return const _LayoutWeights(
          nodeOverlapAreaWeight: _nodeOverlapAreaWeight,
          arrowOverlapAreaWeight: _arrowOverlapAreaWeight,
          nodeOverlapCountWeight: _nodeOverlapCountWeight,
          arrowOverlapCountWeight: _arrowOverlapCountWeight,
          distanceWeight: _distanceWeight,
          centerWeight: _centerWeight,
          connectedNodeDistanceWeight: _connectedNodeDistanceWeight,
          connectedNodeDirectionWeight: _connectedNodeDirectionWeight,
          attributeClusterWeight: _attributeClusterWeight,
        );
    }
  }

  bool _isScoreBetter(_CandidateScore candidate, _CandidateScore baseline) {
    if (candidate.hardCollisionCount > baseline.hardCollisionCount) {
      return false;
    }

    if (candidate.hardCollisionCount < baseline.hardCollisionCount) {
      return true;
    }

    if (candidate.arrowOverlapCount > baseline.arrowOverlapCount) {
      return false;
    }

    if (candidate.arrowOverlapCount < baseline.arrowOverlapCount) {
      return true;
    }

    if (candidate.nodeOverlapCount > baseline.nodeOverlapCount) {
      return false;
    }

    if (candidate.nodeOverlapCount < baseline.nodeOverlapCount) {
      return true;
    }

    if (candidate.arrowOverlapArea > baseline.arrowOverlapArea + 0.01) {
      return false;
    }

    if (candidate.arrowOverlapArea + 0.01 < baseline.arrowOverlapArea) {
      return true;
    }

    if (candidate.nodeOverlapArea > baseline.nodeOverlapArea + 0.01) {
      return false;
    }

    if (candidate.nodeOverlapArea + 0.01 < baseline.nodeOverlapArea) {
      return true;
    }

    if (candidate.totalScore >= baseline.totalScore) {
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
    return scrollHandler.navigationBounds;
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
    if (_isFinishing) {
      return;
    }
    _isFinishing = true;
    _isRunning = false;
    _layoutElapsedTimer?.cancel();
    _layoutElapsedTimer = null;
    _layoutStopwatch?.stop();
    state.autoLayoutElapsedMilliseconds = _layoutStopwatch?.elapsedMilliseconds ?? state.autoLayoutElapsedMilliseconds;

    // Останавливаем анимацию если она ещё работает
    _animator?.stop();
    _animator = null;

        // Освобождаем Cola layout (если ещё не освобождён)
        _layout?.dispose();
        _layout = null;

        // ВАЖНО: пересчитываем все пути связей ДО сохранения узлов обратно в тайлы,
        // чтобы тайлы сразу строились по финальной геометрии стрелок.
        arrowManager.recalculateAllArrows();

        // Пересчитываем размер холста на основе новых позиций узлов
        // ВАЖНО: делаем это ДО saveAllNodesAfterLayout, так как этот метод
        // изменяет state.delta и пересчитывает aPosition
        scrollHandler.calculateCanvasSizeFromNodes(state.nodes);

        // Сохраняем узлы обратно в тайлы (используем метод NodeManager)
        await nodeManager.saveAllNodesAfterLayout();
        scrollHandler.autoFitAndCenterNodes();

        await EventService.apiStatic('schema_update', 'ColaLayoutService._finishLayout');

        // Выключаем loading indicator и режим автораскладки
        state.isLoading = false;
        state.isAutoLayoutMode = false;
        state.currentLayoutProcess = '';
        state.currentLayoutProcessProgress = null;
        state.currentLayoutProcessCanStop = true;
        state.currentLayoutProcessAiCollecting = false;
        _isRunning = false;
        _isAnimating = false;
    state.isLoading = false;
    state.isAutoLayoutMode = false;
    state.currentLayoutProcess = '';
    state.currentLayoutProcessProgress = null;
    state.currentLayoutProcessCanStop = true;
    state.currentLayoutProcessAiCollecting = false;
    _isRunning = false;
    _isAnimating = false;

    _nodesList.clear();
    _nodeIndexMap.clear();
    _animatedPositions.clear();
    _targetPositions.clear();
    _nodeConnectionCounts.clear();
    _nodeSourceConnectionCounts.clear();
    _nodeTargetConnectionCounts.clear();
    _adjacentNodeIndices.clear();
    _nodeAttributeClusterKeys.clear();
    _attributeClusterNodeIndices.clear();
    _positionAnimationCompleter = null;
    _finishAfterCurrentAnimation = false;
    _isFinishing = false;
    _layoutStopwatch = null;
    
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

  Future<void> stopLayout() async {
    if (_isRunning) {
      _setCurrentLayoutProcess('Остановка');
      _animator?.stop();
      await _finishLayout();
    }
  }

  @override
  void dispose() {
    unawaited(stopLayout());
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

enum _ScoringMode {
  repair,
  polish,
}

enum _SnapSector {
  top,
  right,
  bottom,
  left,
}

class _SectorLane {
  double line;
  final List<_SectorLaneItem> items;

  _SectorLane({required this.line, required this.items});
}

class _SectorLaneItem {
  final int nodeIndex;
  final double left;
  final double right;
  final double top;
  final double bottom;
  final double width;
  final double height;

  const _SectorLaneItem({
    required this.nodeIndex,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.width,
    required this.height,
  });
}

class _LayoutWeights {
  final double nodeOverlapAreaWeight;
  final double arrowOverlapAreaWeight;
  final double nodeOverlapCountWeight;
  final double arrowOverlapCountWeight;
  final double distanceWeight;
  final double centerWeight;
  final double connectedNodeDistanceWeight;
  final double connectedNodeDirectionWeight;
  final double attributeClusterWeight;

  const _LayoutWeights({
    required this.nodeOverlapAreaWeight,
    required this.arrowOverlapAreaWeight,
    required this.nodeOverlapCountWeight,
    required this.arrowOverlapCountWeight,
    required this.distanceWeight,
    required this.centerWeight,
    required this.connectedNodeDistanceWeight,
    required this.connectedNodeDirectionWeight,
    required this.attributeClusterWeight,
  });
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
  final double connectedNodeDistancePenalty;
  final double connectedNodeDirectionPenalty;
  final double attributeClusterPenalty;
  final double totalScore;

  const _CandidateScore({
    required this.nodeOverlapArea,
    required this.arrowOverlapArea,
    required this.nodeOverlapCount,
    required this.arrowOverlapCount,
    required this.centerDistance,
    required this.centerPenalty,
    required this.distancePenalty,
    required this.connectedNodeDistancePenalty,
    required this.connectedNodeDirectionPenalty,
    required this.attributeClusterPenalty,
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
