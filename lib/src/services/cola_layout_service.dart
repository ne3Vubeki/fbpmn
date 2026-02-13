import 'package:fbpmn/src/cola/cola_interop.dart';
import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/models/table.node.dart';
import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/manager.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:flutter/material.dart';

class ColaLayoutService extends Manager {
  final EditorState state;
  final TileManager tileManager;
  final ArrowManager arrowManager;
  final NodeManager nodeManager;

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

  // Адаптивные параметры раскладки
  double _currentIdealEdgeLength = 300;
  static const double _maxIdealEdgeLength = 1000;
  static const double _edgeLengthIncrement = 50;
  int _restartCount = 0;
  // Убрано ограничение на количество перезапусков — цикл продолжается до устранения пересечений

  // Параметры анимации перемещения узлов
  /// Скорость анимации (0.0 - 1.0). 1.0 = мгновенное перемещение, 0.1 = медленная анимация
  double animationSpeed = 0.15;
  /// Текущие анимированные позиции узлов
  final Map<int, Offset> _animatedPositions = {};
  /// Целевые позиции узлов (из Cola)
  final Map<int, Offset> _targetPositions = {};
  /// Флаг активной анимации
  bool _isAnimating = false;

  ColaLayoutService({
    required this.state,
    required this.tileManager,
    required this.arrowManager,
    required this.nodeManager,
  });

  Future<void> runAutoLayout() async {
    if (_isRunning) return;
    if (state.nodes.isEmpty) return;

    _isRunning = true;
    state.isAutoLayoutMode = true;
    _currentIdealEdgeLength = 150;
    _restartCount = 0;
    _initialPositions.clear(); // Очищаем начальные позиции
    _animatedPositions.clear(); // Очищаем анимированные позиции
    _targetPositions.clear(); // Очищаем целевые позиции
    _isAnimating = false;
    onStateUpdate();

    try {
      // 1. Инициализируем Cola если нужно
      if (!ColaInterop.isReady) {
        await ColaInterop.init();
      }

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
        return;
      }

      // 4. Строим индексную карту узлов
      _buildNodeIndexMap();

      // 5. Удаляем все тайлы (используем метод TileManager)
      tileManager.disposeTiles();

      // 6. Переносим все связи в arrowsSelected (используем метод ArrowManager)
      arrowManager.selectAllArrows();

      // 7. Создаем Cola layout
      _createColaLayout();

      // 8. Запускаем анимированную раскладку
      _runAnimatedLayout();
    } catch (e) {
      print('ColaLayoutService error: $e');
      await _finishLayout();
    }
  }

  void _buildNodeIndexMap() {
    _nodeIndexMap.clear();
    for (int i = 0; i < _nodesList.length; i++) {
      _nodeIndexMap[_nodesList[i].id] = i;
    }
  }

  void _createColaLayout() {
    final nodeCount = _nodesList.length;
    _layout = ColaLayout(nodeCount: nodeCount, idealEdgeLength: _currentIdealEdgeLength);
 
    // Включаем предотвращение перекрытий
    _layout!.setAvoidOverlaps(true);

    // Вычисляем центр масс всех узлов (используем начальные позиции для стабильности)
    double initialSumX = 0;
    double initialSumY = 0;

    // Устанавливаем позиции и размеры узлов
    // При первом запуске сохраняем начальные позиции
    // При перезапуске используем ТЕКУЩИЕ позиции (результат предыдущей итерации)
    for (int i = 0; i < _nodesList.length; i++) {
      final node = _nodesList[i];
      
      // При первом запуске сохраняем начальную позицию
      if (!_initialPositions.containsKey(i)) {
        final initialPos = node.aPosition ?? (state.delta + node.position);
        _initialPositions[i] = initialPos;
      }
      
      // Для Cola используем ТЕКУЩУЮ позицию (чтобы продолжить с того места, где остановились)
      final pos = node.aPosition ?? _initialPositions[i]!;
      final centerX = pos.dx + node.size.width / 2;
      final centerY = pos.dy + node.size.height / 2;
      
      _layout!.setNode(
        i,
        x: centerX,
        y: centerY,
        width: node.size.width,
        height: node.size.height,
      );

      // Суммируем начальные позиции для вычисления центра масс
      final initialPos = _initialPositions[i]!;
      initialSumX += initialPos.dx + node.size.width / 2;
      initialSumY += initialPos.dy + node.size.height / 2;
    }

    // Вычисляем центр масс на основе НАЧАЛЬНЫХ позиций (для стабильности)
    final centerOfMassX = initialSumX / _nodesList.length;
    final centerOfMassY = initialSumY / _nodesList.length;

    // Добавляем page boundary симметрично вокруг центра масс
    // Размер увеличивается с idealEdgeLength чтобы дать место для расхождения
    final boundaryPadding = _currentIdealEdgeLength * 3;
    _layout!.addPageBoundary(
      xMin: centerOfMassX - boundaryPadding,
      xMax: centerOfMassX + boundaryPadding,
      yMin: centerOfMassY - boundaryPadding,
      yMax: centerOfMassY + boundaryPadding,
      weight: 20, // Уменьшаем вес чтобы не мешать расхождению
    );

    // Добавляем рёбра
    for (final arrow in state.arrows) {
      final sourceIndex = _nodeIndexMap[arrow.source];
      final targetIndex = _nodeIndexMap[arrow.target];
      if (sourceIndex != null && targetIndex != null) {
        _layout!.addEdge(sourceIndex, targetIndex);
      }
    }

    // Добавляем ограничения разделения между узлами
    _addSeparationConstraints();

    // Добавляем ограничения для ортогональных связей
    _addOrthogonalConstraints();

    // Настраиваем параметры сходимости
    // _layout!.setConvergence(tolerance: 0.01, maxIterations: 200);
  }

  /// Добавляет ограничения разделения между узлами
  /// Гарантирует минимальный зазор между соседними узлами
  void _addSeparationConstraints() {
    const double minGap = 20.0; // Минимальный зазор между узлами

    // Добавляем ограничения для каждой пары связанных узлов
    for (final arrow in state.arrows) {
      final sourceIndex = _nodeIndexMap[arrow.source];
      final targetIndex = _nodeIndexMap[arrow.target];

      if (sourceIndex == null || targetIndex == null) continue;

      final sourceNode = _nodesList[sourceIndex];
      final targetNode = _nodesList[targetIndex];

      // Вычисляем минимальный зазор на основе размеров узлов
      final horizontalGap = (sourceNode.size.width + targetNode.size.width) / 2 + minGap;
      final verticalGap = (sourceNode.size.height + targetNode.size.height) / 2 + minGap;

      // Добавляем горизонтальное ограничение (source слева от target)
      _layout!.addSeparationConstraint(
        dimension: ConstraintDimension.horizontal,
        leftNode: sourceIndex,
        rightNode: targetIndex,
        gap: horizontalGap,
      );

      // Добавляем вертикальное ограничение (source выше target)
      _layout!.addSeparationConstraint(
        dimension: ConstraintDimension.vertical,
        leftNode: sourceIndex,
        rightNode: targetIndex,
        gap: verticalGap,
      );
    }
  }

  /// Добавляет ограничения для иерархической раскладки
  /// Направление связи определяется на основе connections узла (какая сторона используется)
  void _addOrthogonalConstraints() {
    // 1. Вычисляем уровни узлов (BFS от корней)
    final Map<int, int> nodeLevels = _computeNodeLevels();
    
    // 2. Группируем узлы по уровням
    final Map<int, List<int>> nodesByLevel = {};
    for (final entry in nodeLevels.entries) {
      nodesByLevel.putIfAbsent(entry.value, () => []);
      nodesByLevel[entry.value]!.add(entry.key);
    }

    // 3. Для каждой связи определяем направление на основе connections
    for (final arrow in state.arrows) {
      final sourceIndex = _nodeIndexMap[arrow.source];
      final targetIndex = _nodeIndexMap[arrow.target];

      if (sourceIndex == null || targetIndex == null) continue;

      final sourceNode = _nodesList[sourceIndex];
      final targetNode = _nodesList[targetIndex];

      // Определяем направление связи на основе connections source узла
      final connectionDirection = _getConnectionDirection(sourceNode, arrow.id);

      if (connectionDirection == 'right' || connectionDirection == 'left') {
        // Горизонтальная связь: source и target на одной высоте
        _layout!.addOrthogonalEdgeConstraint(
          dimension: ConstraintDimension.horizontal,
          leftNode: sourceIndex,
          rightNode: targetIndex,
        );

        final minGap = (sourceNode.size.width + targetNode.size.width) / 2 + 50;
        
        if (connectionDirection == 'right') {
          // Target справа от source
          _layout!.addSeparationConstraint(
            dimension: ConstraintDimension.horizontal,
            leftNode: sourceIndex,
            rightNode: targetIndex,
            gap: minGap,
          );
        } else {
          // Target слева от source
          _layout!.addSeparationConstraint(
            dimension: ConstraintDimension.horizontal,
            leftNode: targetIndex,
            rightNode: sourceIndex,
            gap: minGap,
          );
        }
      } else {
        // Вертикальная связь: source и target на одной вертикали
        _layout!.addOrthogonalEdgeConstraint(
          dimension: ConstraintDimension.vertical,
          leftNode: sourceIndex,
          rightNode: targetIndex,
        );

        final minGap = (sourceNode.size.height + targetNode.size.height) / 2 + 50;
        
        if (connectionDirection == 'bottom') {
          // Target ниже source
          _layout!.addSeparationConstraint(
            dimension: ConstraintDimension.vertical,
            leftNode: sourceIndex,
            rightNode: targetIndex,
            gap: minGap,
          );
        } else {
          // Target выше source
          _layout!.addSeparationConstraint(
            dimension: ConstraintDimension.vertical,
            leftNode: targetIndex,
            rightNode: sourceIndex,
            gap: minGap,
          );
        }
      }
    }

    // 4. Узлы одного уровня выравниваем по вертикали (колонки)
    for (final entry in nodesByLevel.entries) {
      final nodesAtLevel = entry.value;
      if (nodesAtLevel.length >= 2) {
        // Сортируем по начальной Y позиции для стабильного порядка
        nodesAtLevel.sort((a, b) {
          final posA = _initialPositions[a]!;
          final posB = _initialPositions[b]!;
          return posA.dy.compareTo(posB.dy);
        });

        // Выравниваем по вертикали (одинаковый X)
        for (int i = 0; i < nodesAtLevel.length - 1; i++) {
          final nodeA = nodesAtLevel[i];
          final nodeB = nodesAtLevel[i + 1];

          _layout!.addOrthogonalEdgeConstraint(
            dimension: ConstraintDimension.vertical,
            leftNode: nodeA,
            rightNode: nodeB,
          );

          // Вертикальный зазор между узлами
          final node1 = _nodesList[nodeA];
          final node2 = _nodesList[nodeB];
          final verticalGap = (node1.size.height + node2.size.height) / 2 + 30;

          _layout!.addSeparationConstraint(
            dimension: ConstraintDimension.vertical,
            leftNode: nodeA,
            rightNode: nodeB,
            gap: verticalGap,
          );
        }
      }
    }
  }

  /// Определяет направление связи на основе connections узла
  /// Возвращает 'right', 'left', 'top', 'bottom'
  String _getConnectionDirection(TableNode node, String arrowId) {
    final connections = node.connections;
    if (connections == null) return 'right'; // По умолчанию — вправо

    // Проверяем, на какой стороне находится эта связь
    if (connections.right?.any((c) => c?.id == arrowId) ?? false) {
      return 'right';
    }
    if (connections.left?.any((c) => c?.id == arrowId) ?? false) {
      return 'left';
    }
    if (connections.bottom?.any((c) => c?.id == arrowId) ?? false) {
      return 'bottom';
    }
    if (connections.top?.any((c) => c?.id == arrowId) ?? false) {
      return 'top';
    }

    // Если связь не найдена в connections, определяем по количеству связей на сторонах
    final rightCount = connections.right?.length ?? 0;
    final leftCount = connections.left?.length ?? 0;
    final bottomCount = connections.bottom?.length ?? 0;
    final topCount = connections.top?.length ?? 0;

    // Выбираем сторону с наибольшим количеством связей
    final maxHorizontal = rightCount >= leftCount ? rightCount : leftCount;
    final maxVertical = bottomCount >= topCount ? bottomCount : topCount;

    if (maxHorizontal >= maxVertical) {
      return rightCount >= leftCount ? 'right' : 'left';
    } else {
      return bottomCount >= topCount ? 'bottom' : 'top';
    }
  }

  /// Вычисляет уровни узлов (BFS от корней)
  /// Корни — узлы без входящих связей
  Map<int, int> _computeNodeLevels() {
    final Map<int, int> levels = {};
    final Set<int> visited = {};
    
    // Находим входящие связи для каждого узла
    final Map<int, List<int>> incomingEdges = {};
    final Map<int, List<int>> outgoingEdges = {};
    
    for (int i = 0; i < _nodesList.length; i++) {
      incomingEdges[i] = [];
      outgoingEdges[i] = [];
    }
    
    for (final arrow in state.arrows) {
      final sourceIndex = _nodeIndexMap[arrow.source];
      final targetIndex = _nodeIndexMap[arrow.target];
      if (sourceIndex != null && targetIndex != null) {
        outgoingEdges[sourceIndex]!.add(targetIndex);
        incomingEdges[targetIndex]!.add(sourceIndex);
      }
    }
    
    // Находим корни (узлы без входящих связей)
    final List<int> roots = [];
    for (int i = 0; i < _nodesList.length; i++) {
      if (incomingEdges[i]!.isEmpty) {
        roots.add(i);
        levels[i] = 0;
      }
    }
    
    // Если нет корней, берём первый узел
    if (roots.isEmpty && _nodesList.isNotEmpty) {
      roots.add(0);
      levels[0] = 0;
    }
    
    // BFS для вычисления уровней
    final queue = List<int>.from(roots);
    visited.addAll(roots);
    
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentLevel = levels[current]!;
      
      for (final target in outgoingEdges[current]!) {
        if (!visited.contains(target)) {
          visited.add(target);
          levels[target] = currentLevel + 1;
          queue.add(target);
        } else if (levels[target]! < currentLevel + 1) {
          // Обновляем уровень если нашли более длинный путь
          levels[target] = currentLevel + 1;
        }
      }
    }
    
    // Узлы без уровня получают уровень 0
    for (int i = 0; i < _nodesList.length; i++) {
      levels.putIfAbsent(i, () => 0);
    }
    
    return levels;
  }

  void _runAnimatedLayout() {
    _animator = AnimatedLayout(
      layout: _layout!,
      onTick: _onLayoutTick,
      onComplete: _onLayoutComplete,
      maxIterations: 50,
    );
    _animator!.start();
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
      final newWorldPosition = Offset(
        pos.x + offsetX - node.size.width / 2,
        pos.y + offsetY - node.size.height / 2,
      );

      _targetPositions[i] = newWorldPosition;

      // Инициализируем анимированную позицию если её нет
      if (!_animatedPositions.containsKey(i)) {
        _animatedPositions[i] = node.aPosition ?? _initialPositions[i]!;
      }
    }

    // Запускаем анимацию если она ещё не запущена
    if (!_isAnimating) {
      _startPositionAnimation();
    }
  }

  /// Запускает анимацию интерполяции позиций узлов
  void _startPositionAnimation() {
    _isAnimating = true;
    _animatePositions();
  }

  /// Анимирует перемещение узлов к целевым позициям
  void _animatePositions() {
    if (!_isRunning) {
      _isAnimating = false;
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
      Future.delayed(const Duration(milliseconds: 16), _animatePositions);
    } else {
      _isAnimating = false;
    }
  }

  void _onLayoutComplete() {
    // Проверяем перекрытия после завершения
    final hasOverlaps = _checkForOverlaps();

    if (hasOverlaps && _currentIdealEdgeLength < _maxIdealEdgeLength) {
      // Увеличиваем idealEdgeLength и перезапускаем
      _restartCount++;
      _currentIdealEdgeLength += _edgeLengthIncrement;
      print(
        'Cola: обнаружены перекрытия, перезапуск с idealEdgeLength=$_currentIdealEdgeLength (попытка $_restartCount)',
      );

      // Освобождаем текущий layout
      _layout?.dispose();
      _layout = null;
      _animator = null;

      // Пересоздаём и перезапускаем
      _createColaLayout();
      _runAnimatedLayout();
    } else {
      _finishLayout();
    }
  }

  /// Проверяет наличие РЕАЛЬНЫХ перекрытий между узлами
  /// Возвращает true только если узлы действительно пересекаются (не просто близко)
  bool _checkForOverlaps() {
    const double minGap = 5.0; // Минимальный зазор для определения пересечения

    for (int i = 0; i < _nodesList.length; i++) {
      final nodeA = _nodesList[i];
      final posA = nodeA.aPosition;
      if (posA == null) continue;

      // Реальный прямоугольник узла A (без расширения)
      final rectA = Rect.fromLTWH(
        posA.dx,
        posA.dy,
        nodeA.size.width,
        nodeA.size.height,
      );

      for (int j = i + 1; j < _nodesList.length; j++) {
        final nodeB = _nodesList[j];
        final posB = nodeB.aPosition;
        if (posB == null) continue;

        // Пропускаем проверку родитель-ребёнок
        if (_isParentChild(nodeA, nodeB)) continue;

        // Реальный прямоугольник узла B
        final rectB = Rect.fromLTWH(posB.dx, posB.dy, nodeB.size.width, nodeB.size.height);

        // Проверяем реальное пересечение (с небольшим допуском)
        final expandedA = rectA.inflate(minGap);
        if (expandedA.overlaps(rectB)) {
          print('Cola: пересечение узлов $i и $j');
          return true;
        }
      }
    }
    return false;
  }

  /// Проверяет, являются ли узлы родителем и ребёнком
  bool _isParentChild(TableNode a, TableNode b) {
    // Проверяем, является ли b ребёнком a
    if (a.children != null && a.children!.contains(b)) return true;
    // Проверяем, является ли a ребёнком b
    if (b.children != null && b.children!.contains(a)) return true;
    return false;
  }

  Future<void> _finishLayout() async {
    // Останавливаем анимацию если она ещё работает
    _animator?.stop();
    _animator = null;

    // Освобождаем Cola layout
    _layout?.dispose();
    _layout = null;

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

    tileManager.onStateUpdate();
    onStateUpdate();
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
