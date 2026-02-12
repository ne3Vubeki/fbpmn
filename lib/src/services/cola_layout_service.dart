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

  // Адаптивные параметры раскладки
  double _currentIdealEdgeLength = 150;
  static const double _maxIdealEdgeLength = 1000;
  static const double _edgeLengthIncrement = 50;
  int _restartCount = 0;
  static const int _maxRestarts = 20;

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
    _layout = ColaLayout(
      nodeCount: nodeCount,
      idealEdgeLength: _currentIdealEdgeLength,
    );

    // Устанавливаем позиции и размеры узлов
    for (int i = 0; i < _nodesList.length; i++) {
      final node = _nodesList[i];
      final pos = node.aPosition ?? (state.delta + node.position);
      _layout!.setNode(
        i,
        x: pos.dx + node.size.width / 2,
        y: pos.dy + node.size.height / 2,
        width: node.size.width,
        height: node.size.height,
      );
    }

    // Добавляем рёбра
    for (final arrow in state.arrows) {
      final sourceIndex = _nodeIndexMap[arrow.source];
      final targetIndex = _nodeIndexMap[arrow.target];
      if (sourceIndex != null && targetIndex != null) {
        _layout!.addEdge(sourceIndex, targetIndex);
      }
    }

    // Включаем предотвращение перекрытий
    _layout!.setAvoidOverlaps(true);

    // Настраиваем параметры сходимости
    _layout!.setConvergence(tolerance: 0.01, maxIterations: 200);
  }

  void _runAnimatedLayout() {
    _animator = AnimatedLayout(
      layout: _layout!,
      onTick: _onLayoutTick,
      onComplete: _onLayoutComplete,
      maxIterations: 5,
    );
    _animator!.start();
  }

  void _onLayoutTick(List<NodePosition> positions) {
    // Обновляем позиции узлов через NodeManager
    for (int i = 0; i < positions.length && i < _nodesList.length; i++) {
      final node = _nodesList[i];
      final pos = positions[i];

      // Позиция из Cola - это центр узла, преобразуем в левый верхний угол
      final newWorldPosition = Offset(
        pos.x - node.size.width / 2,
        pos.y - node.size.height / 2,
      );

      // Используем метод NodeManager для обновления позиции
      nodeManager.updateNodePositionForLayout(node, newWorldPosition);
    }

    // Пересчитываем координаты стрелок с новыми позициями узлов
    arrowManager.recalculateSelectedArrows();

    // Уведомляем виджеты об обновлении
    arrowManager.onStateUpdate();
    nodeManager.onStateUpdate();
    onStateUpdate();
  }

  void _onLayoutComplete() {
    // Проверяем перекрытия после завершения
    final hasOverlaps = _checkForOverlaps();
    
    if (hasOverlaps && _restartCount < _maxRestarts && _currentIdealEdgeLength < _maxIdealEdgeLength) {
      // Увеличиваем idealEdgeLength и перезапускаем
      _restartCount++;
      _currentIdealEdgeLength += _edgeLengthIncrement;
      print('Cola: обнаружены перекрытия, перезапуск с idealEdgeLength=$_currentIdealEdgeLength (попытка $_restartCount)');
      
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

  /// Проверяет наличие перекрытий между узлами
  bool _checkForOverlaps() {
    const double overlapThreshold = 5.0; // Минимальный допустимый зазор
    
    for (int i = 0; i < _nodesList.length; i++) {
      final nodeA = _nodesList[i];
      final posA = nodeA.aPosition;
      if (posA == null) continue;
      
      final rectA = Rect.fromLTWH(
        posA.dx - overlapThreshold,
        posA.dy - overlapThreshold,
        nodeA.size.width + overlapThreshold * 2,
        nodeA.size.height + overlapThreshold * 2,
      );
      
      for (int j = i + 1; j < _nodesList.length; j++) {
        final nodeB = _nodesList[j];
        final posB = nodeB.aPosition;
        if (posB == null) continue;
        
        // Пропускаем проверку родитель-ребёнок
        if (_isParentChild(nodeA, nodeB)) continue;
        
        final rectB = Rect.fromLTWH(
          posB.dx,
          posB.dy,
          nodeB.size.width,
          nodeB.size.height,
        );
        
        if (rectA.overlaps(rectB)) {
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

    _nodesList.clear();
    _nodeIndexMap.clear();

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
