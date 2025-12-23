import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/table.node.dart';
import '../services/tile_manager.dart';

class NodeManager {
  final EditorState state;
  final TileManager tileManager;
  final VoidCallback onStateUpdate;
  
  Offset _nodeDragStart = Offset.zero;
  Offset _nodeStartWorldPosition = Offset.zero;
  
  // Константа для отступа рамки выделения от узла
  static const double selectionPadding = 4.0; // 4 пикселя отступа рамки
  
  NodeManager({
    required this.state,
    required this.tileManager,
    required this.onStateUpdate,
  });
  
  // Метод для получения экранных координат из мировых
  Offset _worldToScreen(Offset worldPosition) {
    return worldPosition * state.scale + state.offset;
  }
  
  // Метод для получения мировых координат из экранных
  Offset _screenToWorld(Offset screenPosition) {
    return (screenPosition - state.offset) / state.scale;
  }
  
  // Корректировка позиции при изменении масштаба
  void onScaleChanged() {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      // Просто пересчитываем экранные координаты на основе мировых
      _updateScreenPosition();
      onStateUpdate();
    }
  }
  
  // ВАЖНОЕ ИСПРАВЛЕНИЕ: Корректировка позиции при изменении offset (панорамировании/скроллинге)
  void onOffsetChanged() {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      // Просто пересчитываем экранные координаты на основе мировых
      _updateScreenPosition();
      onStateUpdate();
    }
  }
  
  // Обновление экранной позиции на основе мировых координат
  void _updateScreenPosition() {
    if (state.selectedNodeOnTopLayer == null) return;
    
    // Мировые координаты центра узла
    final worldPosition = state.originalNodePosition;
    
    // Экранные координаты центра узла
    final screenCenter = _worldToScreen(worldPosition);
    
    // Вычисляем offset для контейнера (левый верхний угол рамки)
    // Учитываем, что рамка имеет отступ selectionPadding
    // И узел будет нарисован с масштабированием внутри
    final node = state.selectedNodeOnTopLayer!;
    final scaledWidth = node.size.width * state.scale;
    final scaledHeight = node.size.height * state.scale;
    
    // КОМПЕНСАЦИОННЫЙ СДВИГ: 2 пикселя с учетом масштаба
    final double scaleAdjustedPadding = 2.0 / state.scale;
    final double totalOffset = selectionPadding + scaleAdjustedPadding;
    
    state.selectedNodeOffset = Offset(
      screenCenter.dx - scaledWidth / 2 - totalOffset,
      screenCenter.dy - scaledHeight / 2 - totalOffset,
    );
  }
  
  void selectNodeAtPosition(Offset screenPosition, {bool immediateDrag = false}) {
    final worldPos = _screenToWorld(screenPosition);
    
    print('Клик на позицию: screen=$screenPosition, world=$worldPos');
    print('Текущее состояние: isNodeDragging=${state.isNodeDragging}');
    
    TableNode? foundNode;
    
    // Ищем узел под курсором (с учетом иерархии)
    TableNode? findNodeRecursive(List<TableNode> nodes, Offset parentOffset) {
      for (int i = nodes.length - 1; i >= 0; i--) {
        final node = nodes[i];
        final nodeOffset = parentOffset + node.position;
        final nodeRect = Rect.fromLTWH(
          nodeOffset.dx,
          nodeOffset.dy,
          node.size.width,
          node.size.height,
        );
        
        if (nodeRect.contains(worldPos)) {
          return node;
        }
        
        // Проверяем детей
        if (node.children != null && node.children!.isNotEmpty) {
          final childNode = findNodeRecursive(node.children!, nodeOffset);
          if (childNode != null) {
            return childNode;
          }
        }
      }
      return null;
    }
    
    // Ищем узел в корневых узлах
    foundNode = findNodeRecursive(state.nodes, state.delta);
    
    if (foundNode != null) {
      print('Найден узел: ${foundNode.text}');
      
      // Если уже есть выделенный узел на верхнем слое
      if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
        // И если это тот же узел
        if (state.selectedNodeOnTopLayer!.id == foundNode.id) {
          print('Выбран уже выделенный узел');
          if (immediateDrag) {
            // Немедленное начало перетаскивания
            startNodeDrag(screenPosition);
          }
          return;
        }
        
        // ВАЖНОЕ ИСПРАВЛЕНИЕ: если требуется немедленное перетаскивание,
        // сразу начинаем перетаскивать новый узел, а старый сохраняем в фоне
        if (immediateDrag) {
          print('Немедленное перетаскивание нового узла с сохранением старого в фоне');
          
          // Завершаем предыдущее перетаскивание
          if (state.isNodeDragging) {
            endNodeDrag();
          }
          
          // Сохраняем старый узел в фоне (не дожидаясь завершения)
          _saveNodeInBackground(state.selectedNodeOnTopLayer!);
          
          // Немедленно выбираем и начинаем перетаскивать новый узел
          _selectNodeImmediate(foundNode, screenPosition);
        } else {
          // Стандартное поведение: сохраняем предыдущий, потом выбираем новый
          print('Сохранение предыдущего узла и выбор нового...');
          _saveNodeToTiles().then((_) {
            // После сохранения выбираем новый узел
            _selectNode(foundNode!);
          });
        }
      } else {
        // Нет выделенного узла
        if (immediateDrag) {
          // Немедленное перетаскивание
          _selectNodeImmediate(foundNode, screenPosition);
        } else {
          // Стандартный выбор
          _selectNode(foundNode);
        }
      }
    } else {
      print('Узел не найден под курсором');
      // Клик на пустую область
      handleEmptyAreaClick();
    }
  }
  
  // Немедленный выбор узла с началом перетаскивания
  void _selectNodeImmediate(TableNode node, Offset screenPosition) {
    print('Немедленный выбор узла ${node.text} с началом перетаскивания');
    
    // Снимаем выделение со всех узлов
    _deselectAllNodes();
    
    // Выделяем найденный узел
    node.isSelected = true;
    state.selectedNode = node;
    
    // Сохраняем мировую позицию центра узла
    final worldCenter = state.delta + node.position + Offset(node.size.width / 2, node.size.height / 2);
    state.originalNodePosition = worldCenter;
    
    print('Мировая позиция центра узла: $worldCenter');
    print('Дельта: ${state.delta}');
    print('Позиция узла в данных: ${node.position}');
    print('Размер узла: ${node.size}');
    print('Текущий scale: ${state.scale}');
    
    // Перемещаем узел на верхний слой
    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;
    
    // Обновляем экранную позицию
    _updateScreenPosition();
    
    print('Узел перемещен на верхний слой. Экранная позиция: ${state.selectedNodeOffset}');
    
    // Удаляем узел из тайлов (только визуально, не из данных)
    tileManager.removeNodeFromTiles(node);
    
    // Немедленно начинаем перетаскивание
    startNodeDrag(screenPosition);
    
    onStateUpdate();
  }
  
  void _selectNode(TableNode node) {
    // Снимаем выделение со всех узлов
    _deselectAllNodes();
    
    // Выделяем найденный узел
    node.isSelected = true;
    state.selectedNode = node;
    
    // Сохраняем мировую позицию центра узла
    final worldCenter = state.delta + node.position + Offset(node.size.width / 2, node.size.height / 2);
    state.originalNodePosition = worldCenter;
    
    print('Мировая позиция центра узла: $worldCenter');
    print('Дельта: ${state.delta}');
    print('Позиция узла в данных: ${node.position}');
    print('Размер узла: ${node.size}');
    print('Текущий scale: ${state.scale}');
    
    // Перемещаем узел на верхний слой
    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;
    
    // Обновляем экранную позицию
    _updateScreenPosition();
    
    print('Узел перемещен на верхний слой. Экранная позиция: ${state.selectedNodeOffset}');
    
    // Удаляем узел из тайлов (только визуально, не из данных)
    tileManager.removeNodeFromTiles(node);
    
    onStateUpdate();
  }
  
  // Сохранение узла в фоне (асинхронно, без ожидания)
  Future<void> _saveNodeInBackground(TableNode node) async {
    print('Фоновое сохранение узла "${node.text}"...');
    
    // Мировые координаты центра узла
    final worldCenter = state.originalNodePosition;
    
    // Вычисляем мировые координаты левого верхнего угла
    // Учитываем компенсационный сдвиг при восстановлении
    final double scaleAdjustedPadding = 2.0 / state.scale;
    final double totalOffset = selectionPadding + scaleAdjustedPadding;
    
    // Чтобы получить правильные мировые координаты, нужно учесть,
    // что selectedNodeOffset уже включает totalOffset
    final screenTopLeft = state.selectedNodeOffset + Offset(totalOffset, totalOffset);
    final worldTopLeft = _screenToWorld(screenTopLeft);
    
    // Ограничиваем позицию узла границами тайлов
    final constrainedWorldPosition = _constrainNodePosition(worldTopLeft, node);
    
    // Вычисляем новую позицию узла относительно дельты
    final newPosition = constrainedWorldPosition - state.delta;
    print('Новая позиция узла: $newPosition (была: ${node.position})');
    
    // Обновляем позицию узла в оригинальных данных
    node.position = newPosition;
    
    // Добавляем узел обратно в тайлы
    await tileManager.addNodeToTiles(node, constrainedWorldPosition);
    
    // Снимаем выделение
    node.isSelected = false;
    
    print('Узел "${node.text}" сохранен в фоне');
  }
  
  Future<void> _saveNodeToTiles() async {
    if (!state.isNodeOnTopLayer || state.selectedNodeOnTopLayer == null) {
      print('Нет узла для сохранения');
      return;
    }
    
    final node = state.selectedNodeOnTopLayer!;
    print('Сохранение узла "${node.text}" обратно в тайлы...');
    
    // Чтобы восстановить правильную позицию, нужно учесть
    // что selectedNodeOffset уже включает totalOffset
    final double scaleAdjustedPadding = 2.0 / state.scale;
    final double totalOffset = selectionPadding + scaleAdjustedPadding;
    
    // Экранные координаты левого верхнего угла узла (без рамки)
    final screenTopLeft = state.selectedNodeOffset + Offset(totalOffset, totalOffset);
    
    // Мировые координаты левого верхнего угла
    final worldTopLeft = _screenToWorld(screenTopLeft);
    
    // ВАЖНОЕ ИСПРАВЛЕНИЕ: ограничиваем позицию узла границами тайлов
    final constrainedWorldPosition = _constrainNodePosition(worldTopLeft, node);
    
    // Вычисляем новую позицию узла относительно дельты
    final newPosition = constrainedWorldPosition - state.delta;
    print('Новая позиция узла: $newPosition (была: ${node.position})');
    
    // Обновляем позицию узла в оригинальных данных
    node.position = newPosition;
    
    // Добавляем узел обратно в тайлы с СКОРРЕКТИРОВАННОЙ И ОГРАНИЧЕННОЙ позицией
    await tileManager.addNodeToTiles(node, constrainedWorldPosition);
    
    // Снимаем выделение
    node.isSelected = false;
    
    // Сбрасываем состояние перетаскивания
    state.isNodeDragging = false;
    
    // Сбрасываем состояние
    state.isNodeOnTopLayer = false;
    state.selectedNodeOnTopLayer = null;
    state.selectedNode = null;
    state.selectedNodeOffset = Offset.zero;
    state.originalNodePosition = Offset.zero;
    
    onStateUpdate();
    print('Узел сохранен обратно в тайлы');
  }
  
  // ВАЖНОЕ ИСПРАВЛЕНИЕ: ограничение позиции узла границами тайлов
  Offset _constrainNodePosition(Offset worldPosition, TableNode node) {
    if (state.imageTiles.isEmpty) {
      return worldPosition;
    }
    
    // Получаем общие границы всех тайлов
    final totalBounds = state.totalBounds;
    
    // Рассчитываем границы узла
    final nodeWidth = node.size.width;
    final nodeHeight = node.size.height;
    
    // Ограничиваем позицию так, чтобы узел не выходил за границы тайлов
    double constrainedX = worldPosition.dx;
    double constrainedY = worldPosition.dy;
    
    // Левый край
    if (constrainedX < totalBounds.left) {
      constrainedX = totalBounds.left;
    }
    
    // Верхний край
    if (constrainedY < totalBounds.top) {
      constrainedY = totalBounds.top;
    }
    
    // Правый край
    if (constrainedX + nodeWidth > totalBounds.right) {
      constrainedX = totalBounds.right - nodeWidth;
    }
    
    // Нижний край
    if (constrainedY + nodeHeight > totalBounds.bottom) {
      constrainedY = totalBounds.bottom - nodeHeight;
    }
    
    // Также ограничиваем минимальные значения
    if (constrainedX < totalBounds.left) {
      constrainedX = totalBounds.left;
    }
    if (constrainedY < totalBounds.top) {
      constrainedY = totalBounds.top;
    }
    
    final constrained = Offset(constrainedX, constrainedY);
    
    if (constrained != worldPosition) {
      print('Позиция узла ограничена: $worldPosition -> $constrained');
    }
    
    return constrained;
  }
  
  void deleteSelectedNode() {
    if (state.selectedNode != null) {
      print('Удаление узла: ${state.selectedNode!.text}');
      
      // Если узел на верхнем слое, сначала сохраняем его
      if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
        _saveNodeToTiles().then((_) {
          // После сохранения удаляем узел из данных
          state.nodes.removeWhere((node) => node.id == state.selectedNode!.id);
          state.selectedNode = null;
          
          // Пересоздаем тайлы без удаленного узла
          tileManager.createTiledImage(state.nodes);
        });
      } else {
        // Удаляем узел из списка
        state.nodes.removeWhere((node) => node.id == state.selectedNode!.id);
        state.selectedNode = null;
        
        // Пересоздаем тайлы без удаленного узла
        tileManager.createTiledImage(state.nodes);
      }
      
      onStateUpdate();
    }
  }
  
  void startNodeDrag(Offset screenPosition) {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      print('Начало перетаскивания узла "${state.selectedNodeOnTopLayer!.text}"');
      print('Позиция мыши: $screenPosition');
      print('Текущая мировая позиция центра узла: ${state.originalNodePosition}');
      
      // Сохраняем начальные позиции
      _nodeDragStart = screenPosition;
      _nodeStartWorldPosition = state.originalNodePosition;
      
      state.isNodeDragging = true;
      onStateUpdate();
    }
  }
  
  void updateNodeDrag(Offset screenPosition) {
    if (state.isNodeDragging && state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      // Вычисляем дельту в мировых координатах
      final screenDelta = screenPosition - _nodeDragStart;
      final worldDelta = screenDelta / state.scale;
      
      // Новая мировая позиция (центра)
      final newWorldPosition = _nodeStartWorldPosition + worldDelta;
      
      // Обновляем мировую позицию
      state.originalNodePosition = newWorldPosition;
      
      // Обновляем экранную позицию
      _updateScreenPosition();
      
      onStateUpdate();
    }
  }
  
  void endNodeDrag() {
    if (state.isNodeDragging) {
      print('Конец перетаскивания узла');
      state.isNodeDragging = false;
      onStateUpdate();
    }
  }
  
  void handleEmptyAreaClick() {
    print('Клик на пустую область');
    
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      // Сохраняем узел обратно в тайлы
      _saveNodeToTiles();
    } else {
      // Просто снимаем выделение
      _deselectAllNodes();
      state.selectedNode = null;
      state.isNodeOnTopLayer = false;
      state.selectedNodeOnTopLayer = null;
      state.selectedNodeOffset = Offset.zero;
      state.originalNodePosition = Offset.zero;
      onStateUpdate();
    }
  }
  
  void _deselectAllNodes() {
    void deselectRecursive(List<TableNode> nodes) {
      for (final node in nodes) {
        node.isSelected = false;
        if (node.children != null && node.children!.isNotEmpty) {
          deselectRecursive(node.children!);
        }
      }
    }
    
    deselectRecursive(state.nodes);
  }
}