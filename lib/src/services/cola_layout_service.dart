import 'dart:math';

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
  // Виртуальный список связей (дети заменены на родителей)
  final List<({String source, String target})> _virtualEdges = [];

  // Параметры раскладки
  double _currentIdealEdgeLength = 300;

  // Параметры анимации перемещения узлов
  /// Скорость анимации (0.0 - 1.0). 1.0 = мгновенное перемещение, 0.1 = медленная анимация
  double animationSpeed = 0.15;

  /// Текущие анимированные позиции узлов
  final Map<int, Offset> _animatedPositions = {};

  /// Целевые позиции узлов (из Cola)
  final Map<int, Offset> _targetPositions = {};

  /// Флаг активной анимации
  bool _isAnimating = false;

  /// Флаг завершения расчёта Cola (анимация может продолжаться)
  bool _colaCompleted = false;

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
    _currentIdealEdgeLength = 300; // Уменьшаем для более компактной раскладки
    _initialPositions.clear(); // Очищаем начальные позиции
    _animatedPositions.clear(); // Очищаем анимированные позиции
    _targetPositions.clear(); // Очищаем целевые позиции
    _isAnimating = false;
    _colaCompleted = false; // Сбрасываем флаг завершения Cola
    onStateUpdate();

    try {
      // 0. Сворачиваем все развернутые swimlane узлы перед запуском Cola
      await _collapseExpandedSwimlanes();

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

      // 4. Строим маппинг индексов
      _buildNodeIndexMap();

      // 5. Строим виртуальный список связей (дети заменены на родителей)
      _buildVirtualEdges();

      // 6. Удаляем все тайлы (используем метод TileManager)
      tileManager.disposeTiles();

      // 7. Переносим все связи в arrowsSelected (используем метод ArrowManager)
      arrowManager.selectAllArrows();

      // 8. Создаем Cola layout
      _createColaLayout();

      // 8. Запускаем анимированную раскладку
      _runAnimatedLayout();
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

  void _createColaLayout() {
    final nodeCount = _nodesList.length;

    // idealEdgeLength определяет длину связей — это баланс между притяжением и отталкиванием
    // Связи притягивают узлы к этой длине, а setAvoidOverlaps отталкивает при перекрытии
    _layout = ColaLayout(nodeCount: nodeCount, idealEdgeLength: _currentIdealEdgeLength);

    // Включаем предотвращение перекрытий — это создаёт силу отталкивания
    _layout!.setAvoidOverlaps(true);

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
      final newWorldPosition = Offset(pos.x + offsetX - node.size.width / 2, pos.y + offsetY - node.size.height / 2);

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

      // Если Cola уже завершила расчёт, завершаем раскладку
      if (_colaCompleted) {
        print('Cola: анимация завершена, завершаем раскладку');
        _finishLayout();
      }
    }
  }

  void _onLayoutComplete() {
    // ВАЖНО: Обновляем позиции узлов до ЦЕЛЕВЫХ перед проверкой пересечений
    // Иначе recalculateSelectedArrows() использует старые позиции
    for (int i = 0; i < _nodesList.length; i++) {
      final target = _targetPositions[i];
      if (target == null) continue;
      final node = _nodesList[i];
      nodeManager.updateNodePositionForLayout(node, target);
      _animatedPositions[i] = target;
    }
    
    // Пересчитываем пути связей с НОВЫМИ позициями
    arrowManager.recalculateSelectedArrows();

    // Проверяем, пересекают ли связи узлы
    final hasEdgeIntersections = _checkEdgeNodeIntersections();

    // Проверяем, пересекаются ли узлы друг с другом (минимальный зазор 40px)
    final hasNodeOverlaps = _checkNodeOverlaps(minGap: 40.0);

    if ((hasEdgeIntersections || hasNodeOverlaps) && _currentIdealEdgeLength < 800) {
      // Увеличиваем idealEdgeLength и перезапускаем
      _currentIdealEdgeLength += 75;
      print(
        'Cola: пересечения (связи=$hasEdgeIntersections, узлы=$hasNodeOverlaps), увеличиваем idealEdgeLength до $_currentIdealEdgeLength',
      );

      // Освобождаем текущий layout
      _layout?.dispose();
      _layout = null;
      _animator = null;

      // Обновляем начальные позиции на текущие целевые С НОВЫМИ ТОЛЧКАМИ
      // Это помогает выйти из локального минимума
      final rng = Random(DateTime.now().millisecondsSinceEpoch);
      for (int i = 0; i < _nodesList.length; i++) {
        if (_targetPositions.containsKey(i)) {
          final targetPos = _targetPositions[i]!;
          final node = _nodesList[i];
          // Для group/swimlane используем более сильные толчки (±150px)
          final isLargeNode = (node.qType == 'group' || node.qType == 'swimlane');
          final jitterMagnitude = isLargeNode ? 300.0 : 100.0;
          final jitterX = (rng.nextDouble() - 0.5) * jitterMagnitude;
          final jitterY = (rng.nextDouble() - 0.5) * jitterMagnitude;
          _initialPositions[i] = Offset(targetPos.dx + jitterX, targetPos.dy + jitterY);
        }
      }

      // Перезапускаем с новыми параметрами
      _createColaLayout();
      _runAnimatedLayout();
    } else {
      print('Cola: расчёт завершён, ожидаем завершения анимации');
      _colaCompleted = true;

      // Освобождаем Cola layout
      _layout?.dispose();
      _layout = null;
      _animator = null;

      // Если анимация уже завершена, завершаем раскладку
      // Иначе анимация сама вызовет _finishLayout когда достигнет целей
      if (!_isAnimating) {
        _finishLayout();
      }
    }
  }

  /// Проверяет пересечение связей с узлами и смещает узлы
  /// Смещение перпендикулярно линии связи на расстояние выхода за пределы пересечения
  bool _checkEdgeNodeIntersections() {
    final Map<int, Offset> totalDisplacements = {};
    
    // Строим маппинг: id ребёнка -> id родителя
    final Map<String, String> childToParent = {};
    for (final node in _nodesList) {
      if (node.children != null && node.children!.isNotEmpty) {
        for (final child in node.children!) {
          childToParent[child.id] = node.id;
        }
      }
    }

    for (final arrow in state.arrowsSelected) {
      if (arrow == null) continue;

      // Получаем индексы source/target, учитывая родителей
      final virtualSource = childToParent[arrow.source] ?? arrow.source;
      final virtualTarget = childToParent[arrow.target] ?? arrow.target;
      final sourceIndex = _nodeIndexMap[virtualSource];
      final targetIndex = _nodeIndexMap[virtualTarget];

      // Используем уже рассчитанные координаты связи (после recalculateSelectedArrows)
      final coordinates = arrow.coordinates;
      if (coordinates == null || coordinates.length < 2) continue;

      // Проверяем все остальные узлы
      for (int i = 0; i < _nodesList.length; i++) {
        // Пропускаем source и target (включая родителей)
        if (i == sourceIndex || i == targetIndex) continue;

        final node = _nodesList[i];
        // Используем целевую позицию из Cola
        final nodePos = _targetPositions[i] ?? node.aPosition;
        if (nodePos == null) continue;
        
        // Минимальный отступ от связи
        final minGap = (node.qType == 'group' || node.qType == 'swimlane') ? 30.0 : 10.0;

        // Прямоугольник узла с отступом
        final nodeRect = Rect.fromLTWH(
          nodePos.dx - minGap,
          nodePos.dy - minGap,
          node.size.width + minGap * 2,
          node.size.height + minGap * 2,
        );
        
        // Центр узла
        final nodeCenter = Offset(nodePos.dx + node.size.width / 2, nodePos.dy + node.size.height / 2);

        // Проверяем каждый сегмент ортогонального пути
        for (int seg = 0; seg < coordinates.length - 1; seg++) {
          final p1 = coordinates[seg];
          final p2 = coordinates[seg + 1];

          if (_lineIntersectsRect(p1, p2, nodeRect)) {
            // Определяем направление сегмента (горизонтальный или вертикальный)
            final isHorizontal = (p1.dy - p2.dy).abs() < 1.0;
            final isVertical = (p1.dx - p2.dx).abs() < 1.0;
            
            Offset displacement;
            
            if (isHorizontal) {
              // Горизонтальный сегмент — смещаем по вертикали
              final lineY = p1.dy;
              // Если центр узла выше линии — смещаем вверх, иначе вниз
              if (nodeCenter.dy < lineY) {
                // Узел выше линии — смещаем вверх
                final requiredY = lineY - (node.size.height / 2 + minGap + 5);
                displacement = Offset(0, requiredY - nodePos.dy);
              } else {
                // Узел ниже линии — смещаем вниз
                final requiredY = lineY + minGap + 5;
                displacement = Offset(0, requiredY - nodePos.dy);
              }
            } else if (isVertical) {
              // Вертикальный сегмент — смещаем по горизонтали
              final lineX = p1.dx;
              // Если центр узла левее линии — смещаем влево, иначе вправо
              if (nodeCenter.dx < lineX) {
                // Узел левее линии — смещаем влево
                final requiredX = lineX - (node.size.width / 2 + minGap + 5);
                displacement = Offset(requiredX - nodePos.dx, 0);
              } else {
                // Узел правее линии — смещаем вправо
                final requiredX = lineX + minGap + 5;
                displacement = Offset(requiredX - nodePos.dx, 0);
              }
            } else {
              // Диагональный сегмент — смещаем перпендикулярно
              final segDir = Offset(p2.dx - p1.dx, p2.dy - p1.dy);
              final segLen = segDir.distance;
              if (segLen > 0) {
                // Перпендикуляр к сегменту
                var perpendicular = Offset(-segDir.dy / segLen, segDir.dx / segLen);
                // Определяем направление: от линии к центру узла
                final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
                final toNode = Offset(nodeCenter.dx - midPoint.dx, nodeCenter.dy - midPoint.dy);
                // Если перпендикуляр направлен в противоположную сторону — инвертируем
                if (toNode.dx * perpendicular.dx + toNode.dy * perpendicular.dy < 0) {
                  perpendicular = Offset(-perpendicular.dx, -perpendicular.dy);
                }
                // Смещаем на размер узла + отступ
                final moveDistance = (node.size.width + node.size.height) / 2 + minGap + 5;
                displacement = Offset(perpendicular.dx * moveDistance, perpendicular.dy * moveDistance);
              } else {
                displacement = Offset.zero;
              }
            }
            
            // Накапливаем смещение
            if (totalDisplacements.containsKey(i)) {
              totalDisplacements[i] = totalDisplacements[i]! + displacement;
            } else {
              totalDisplacements[i] = displacement;
            }
            
            print('Cola: связь ${arrow.id} (сегмент $seg, ${isHorizontal ? "гориз" : isVertical ? "верт" : "диаг"}) пересекает узел $i (${node.qType}), смещение: $displacement');
          }
        }
      }
    }
    
    // Применяем смещения
    if (totalDisplacements.isNotEmpty) {
      for (final entry in totalDisplacements.entries) {
        final nodeIndex = entry.key;
        final displacement = entry.value;
        final currentPos = _targetPositions[nodeIndex];
        if (currentPos == null) continue;
        
        final newPos = Offset(currentPos.dx + displacement.dx, currentPos.dy + displacement.dy);
        _targetPositions[nodeIndex] = newPos;
        _initialPositions[nodeIndex] = newPos;
        
        print('Cola: применяю смещение узла $nodeIndex на ${displacement.dx}, ${displacement.dy}');
      }
      return true;
    }
    
    return false;
  }

  /// Проверяет, пересекает ли отрезок прямоугольник
  bool _lineIntersectsRect(Offset p1, Offset p2, Rect rect) {
    // Проверяем, находятся ли обе точки с одной стороны прямоугольника
    if (p1.dx < rect.left && p2.dx < rect.left) return false;
    if (p1.dx > rect.right && p2.dx > rect.right) return false;
    if (p1.dy < rect.top && p2.dy < rect.top) return false;
    if (p1.dy > rect.bottom && p2.dy > rect.bottom) return false;

    // Проверяем пересечение с каждой стороной прямоугольника
    final topLeft = Offset(rect.left, rect.top);
    final topRight = Offset(rect.right, rect.top);
    final bottomLeft = Offset(rect.left, rect.bottom);
    final bottomRight = Offset(rect.right, rect.bottom);

    if (_segmentsIntersect(p1, p2, topLeft, topRight)) return true;
    if (_segmentsIntersect(p1, p2, topRight, bottomRight)) return true;
    if (_segmentsIntersect(p1, p2, bottomRight, bottomLeft)) return true;
    if (_segmentsIntersect(p1, p2, bottomLeft, topLeft)) return true;

    // Проверяем, находится ли одна из точек внутри прямоугольника
    if (rect.contains(p1) || rect.contains(p2)) return true;

    return false;
  }

  /// Проверяет пересечение двух отрезков
  bool _segmentsIntersect(Offset a1, Offset a2, Offset b1, Offset b2) {
    final d1 = _crossProduct(b2 - b1, a1 - b1);
    final d2 = _crossProduct(b2 - b1, a2 - b1);
    final d3 = _crossProduct(a2 - a1, b1 - a1);
    final d4 = _crossProduct(a2 - a1, b2 - a1);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }

    // Проверяем коллинеарные случаи
    if (d1 == 0 && _onSegment(b1, a1, b2)) return true;
    if (d2 == 0 && _onSegment(b1, a2, b2)) return true;
    if (d3 == 0 && _onSegment(a1, b1, a2)) return true;
    if (d4 == 0 && _onSegment(a1, b2, a2)) return true;

    return false;
  }

  /// Векторное произведение
  double _crossProduct(Offset a, Offset b) {
    return a.dx * b.dy - a.dy * b.dx;
  }

  /// Проверяет, лежит ли точка q на отрезке pr
  bool _onSegment(Offset p, Offset q, Offset r) {
    return q.dx <= (p.dx > r.dx ? p.dx : r.dx) &&
        q.dx >= (p.dx < r.dx ? p.dx : r.dx) &&
        q.dy <= (p.dy > r.dy ? p.dy : r.dy) &&
        q.dy >= (p.dy < r.dy ? p.dy : r.dy);
  }

  /// Проверяет пересечение узлов друг с другом и смещает их
  /// Смещение по прямой от центра одного узла к центру другого на расстояние выхода за пределы пересечения
  bool _checkNodeOverlaps({required double minGap}) {
    final Map<int, Offset> totalDisplacements = {};
    
    for (int i = 0; i < _nodesList.length; i++) {
      final nodeA = _nodesList[i];
      final posA = _targetPositions[i] ?? nodeA.aPosition;
      if (posA == null) continue;

      // Для group/swimlane увеличиваем отступ
      final paddingA = (nodeA.qType == 'group' || nodeA.qType == 'swimlane') ? 20.0 : 0.0;
      final rectA = Rect.fromLTWH(
        posA.dx - paddingA,
        posA.dy - paddingA,
        nodeA.size.width + paddingA * 2,
        nodeA.size.height + paddingA * 2,
      );
      
      // Центр узла A
      final centerA = Offset(posA.dx + nodeA.size.width / 2, posA.dy + nodeA.size.height / 2);

      for (int j = i + 1; j < _nodesList.length; j++) {
        final nodeB = _nodesList[j];
        final posB = _targetPositions[j] ?? nodeB.aPosition;
        if (posB == null) continue;

        // Для group/swimlane увеличиваем отступ
        final paddingB = (nodeB.qType == 'group' || nodeB.qType == 'swimlane') ? 20.0 : 0.0;
        final rectB = Rect.fromLTWH(
          posB.dx - paddingB,
          posB.dy - paddingB,
          nodeB.size.width + paddingB * 2,
          nodeB.size.height + paddingB * 2,
        );
        
        // Центр узла B
        final centerB = Offset(posB.dx + nodeB.size.width / 2, posB.dy + nodeB.size.height / 2);

        // Вычисляем расстояние между границами
        final horizontalGap = _horizontalGap(rectA, rectB);
        final verticalGap = _verticalGap(rectA, rectB);

        // Для пар group/swimlane используем увеличенный минимальный зазор
        final isLargeNodeA = (nodeA.qType == 'group' || nodeA.qType == 'swimlane');
        final isLargeNodeB = (nodeB.qType == 'group' || nodeB.qType == 'swimlane');
        final effectiveMinGap = (isLargeNodeA || isLargeNodeB) ? minGap + 30.0 : minGap;

        // Пересечение если оба зазора < effectiveMinGap
        if (horizontalGap < effectiveMinGap && verticalGap < effectiveMinGap) {
          print(
            'Cola: узлы $i (${nodeA.qType}) и $j (${nodeB.qType}) пересекаются (hGap=$horizontalGap, vGap=$verticalGap, minGap=$effectiveMinGap)',
          );
          
          // Вычисляем направление от центра A к центру B
          var dirAtoB = Offset(centerB.dx - centerA.dx, centerB.dy - centerA.dy);
          final dist = dirAtoB.distance;
          
          if (dist > 0) {
            dirAtoB = Offset(dirAtoB.dx / dist, dirAtoB.dy / dist);
          } else {
            // Если центры совпадают, смещаем по диагонали
            dirAtoB = const Offset(0.707, 0.707);
          }
          
          // Вычисляем необходимое смещение для выхода за пределы пересечения
          // Нужно сместить так, чтобы зазор стал >= effectiveMinGap
          final overlapX = horizontalGap < 0 ? -horizontalGap : effectiveMinGap - horizontalGap;
          final overlapY = verticalGap < 0 ? -verticalGap : effectiveMinGap - verticalGap;
          
          // Смещаем в направлении от центра к центру на величину перекрытия + запас
          final moveDistance = (overlapX + overlapY) / 2 + 10;
          
          // Узел A смещается в противоположном направлении (от B)
          final displacementA = Offset(-dirAtoB.dx * moveDistance / 2, -dirAtoB.dy * moveDistance / 2);
          if (totalDisplacements.containsKey(i)) {
            totalDisplacements[i] = totalDisplacements[i]! + displacementA;
          } else {
            totalDisplacements[i] = displacementA;
          }
          
          // Узел B смещается в направлении от A
          final displacementB = Offset(dirAtoB.dx * moveDistance / 2, dirAtoB.dy * moveDistance / 2);
          if (totalDisplacements.containsKey(j)) {
            totalDisplacements[j] = totalDisplacements[j]! + displacementB;
          } else {
            totalDisplacements[j] = displacementB;
          }
          
          print('Cola: смещение узлов $i и $j на $moveDistance px в направлении $dirAtoB');
        }
      }
    }
    
    // Применяем смещения
    if (totalDisplacements.isNotEmpty) {
      for (final entry in totalDisplacements.entries) {
        final nodeIndex = entry.key;
        final displacement = entry.value;
        final currentPos = _targetPositions[nodeIndex];
        if (currentPos == null) continue;
        
        final newPos = Offset(currentPos.dx + displacement.dx, currentPos.dy + displacement.dy);
        _targetPositions[nodeIndex] = newPos;
        _initialPositions[nodeIndex] = newPos;
        
        print('Cola: применяю смещение узла $nodeIndex на ${displacement.dx}, ${displacement.dy}');
      }
      return true;
    }
    
    return false;
  }

  /// Вычисляет горизонтальный зазор между прямоугольниками
  double _horizontalGap(Rect a, Rect b) {
    if (a.right < b.left) return b.left - a.right;
    if (b.right < a.left) return a.left - b.right;
    return -1; // Пересечение по горизонтали
  }

  /// Вычисляет вертикальный зазор между прямоугольниками
  double _verticalGap(Rect a, Rect b) {
    if (a.bottom < b.top) return b.top - a.bottom;
    if (b.bottom < a.top) return a.top - b.bottom;
    return -1; // Пересечение по вертикали
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

    // Отладка: выводим финальные позиции узлов
    print('Cola: финальные позиции узлов:');
    for (int i = 0; i < _nodesList.length; i++) {
      final node = _nodesList[i];
      final targetPos = _targetPositions[i];
      final aPos = node.aPosition;
      print('  Узел $i: target=$targetPos, aPosition=$aPos');
    }

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
