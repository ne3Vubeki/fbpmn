import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/table.node.dart';
import '../services/tile_manager.dart';

class NodeManager {
  final EditorState state;
  final TileManager tileManager;
  final VoidCallback onStateUpdate;
  
  Offset _nodeDragStart = Offset.zero;
  Offset _nodeStartPosition = Offset.zero;
  
  // Константа для отступа рамки выделения от узла
  static const double selectionPadding = 4.0; // 4 пикселя отступа
  
  NodeManager({
    required this.state,
    required this.tileManager,
    required this.onStateUpdate,
  });
  
  void selectNodeAtPosition(Offset position, {bool immediateDrag = false}) {
    final worldPos = (position - state.offset) / state.scale;
    
    print('Клик на позицию: $worldPos, immediateDrag: $immediateDrag');
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
            startNodeDrag(position);
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
          _selectNodeImmediate(foundNode, position);
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
          _selectNodeImmediate(foundNode, position);
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
  void _selectNodeImmediate(TableNode node, Offset mousePosition) {
    print('Немедленный выбор узла ${node.text} с началом перетаскивания');
    
    // Снимаем выделение со всех узлов
    _deselectAllNodes();
    
    // Выделяем найденный узел
    node.isSelected = true;
    state.selectedNode = node;
    
    // Сохраняем позицию узла (относительно дельты)
    final foundPosition = state.delta + node.position;
    
    print('Оригинальная позиция узла: ${node.position}');
    print('Дельта: ${state.delta}');
    print('Финальная позиция: $foundPosition');
    print('Текущий scale: ${state.scale}');
    
    // Перемещаем узел на верхний слой
    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;
    
    // Смещаем позицию на отступ
    final double scaleAdjustedPadding = 2.0 / state.scale;
    final double totalOffset = selectionPadding + scaleAdjustedPadding;
    
    state.selectedNodeOffset = Offset(
      foundPosition.dx - totalOffset,
      foundPosition.dy - totalOffset,
    );
    
    state.originalNodePosition = foundPosition;
    
    print('Total offset: $totalOffset');
    print('Узел перемещен на верхний слой. Скорректированная позиция: ${state.selectedNodeOffset}');
    
    // Удаляем узел из тайлов (только визуально, не из данных)
    tileManager.removeNodeFromTiles(node);
    
    // Немедленно начинаем перетаскивание
    startNodeDrag(mousePosition);
    
    onStateUpdate();
  }
  
  void _selectNode(TableNode node) {
    // Снимаем выделение со всех узлов
    _deselectAllNodes();
    
    // Выделяем найденный узел
    node.isSelected = true;
    state.selectedNode = node;
    
    // Сохраняем позицию узла (относительно дельты)
    final foundPosition = state.delta + node.position;
    
    print('Оригинальная позиция узла: ${node.position}');
    print('Дельта: ${state.delta}');
    print('Финальная позиция: $foundPosition');
    print('Текущий scale: ${state.scale}');
    
    // Перемещаем узел на верхний слой
    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;
    
    // Смещаем позицию на отступ
    final double scaleAdjustedPadding = 2.0 / state.scale;
    final double totalOffset = selectionPadding + scaleAdjustedPadding;
    
    state.selectedNodeOffset = Offset(
      foundPosition.dx - totalOffset,
      foundPosition.dy - totalOffset,
    );
    
    state.originalNodePosition = foundPosition;
    
    print('Total offset: $totalOffset');
    print('Узел перемещен на верхний слой. Скорректированная позиция: ${state.selectedNodeOffset}');
    
    // Удаляем узел из тайлов (только визуально, не из данных)
    tileManager.removeNodeFromTiles(node);
    
    onStateUpdate();
  }
  
  // Сохранение узла в фоне (асинхронно, без ожидания)
  Future<void> _saveNodeInBackground(TableNode node) async {
    print('Фоновое сохранение узла "${node.text}"...');
    
    // ВАЖНО: добавляем totalOffset обратно при сохранении
    final double scaleAdjustedPadding = 2.0 / state.scale;
    final double totalOffset = selectionPadding + scaleAdjustedPadding;
    
    final correctedOffset = Offset(
      state.selectedNodeOffset.dx + totalOffset,
      state.selectedNodeOffset.dy + totalOffset,
    );
    
    // Вычисляем новую позицию узла относительно дельты
    final newPosition = correctedOffset - state.delta;
    
    // Обновляем позицию узла в оригинальных данных
    node.position = newPosition;
    
    // Добавляем узел обратно в тайлы с СКОРРЕКТИРОВАННОЙ позицией
    await tileManager.addNodeToTiles(node, correctedOffset);
    
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
    
    // ВАЖНО: добавляем totalOffset обратно при сохранении
    final double scaleAdjustedPadding = 2.0 / state.scale;
    final double totalOffset = selectionPadding + scaleAdjustedPadding;
    
    final correctedOffset = Offset(
      state.selectedNodeOffset.dx + totalOffset,
      state.selectedNodeOffset.dy + totalOffset,
    );
    
    // ВАЖНОЕ ИСПРАВЛЕНИЕ: ограничиваем позицию узла границами тайлов
    final constrainedOffset = _constrainNodePosition(correctedOffset, node);
    
    // Вычисляем новую позицию узла относительно дельты
    final newPosition = constrainedOffset - state.delta;
    print('Новая позиция узла: $newPosition (была: ${node.position})');
    print('Скорректированный offset: $constrainedOffset');
    print('Total offset: $totalOffset');
    
    // Обновляем позицию узла в оригинальных данных
    node.position = newPosition;
    
    // Добавляем узел обратно в тайлы с СКОРРЕКТИРОВАННОЙ И ОГРАНИЧЕННОЙ позицией
    await tileManager.addNodeToTiles(node, constrainedOffset);
    
    // Снимаем выделение
    node.isSelected = false;
    
    // Сбрасываем состояние перетаскивания
    state.isNodeDragging = false;
    
    // Сбрасываем состояние
    state.isNodeOnTopLayer = false;
    state.selectedNodeOnTopLayer = null;
    state.selectedNode = null;
    
    onStateUpdate();
    print('Узел сохранен обратно в тайлы');
  }
  
  // ВАЖНОЕ ИСПРАВЛЕНИЕ: ограничение позиции узла границами тайлов
  Offset _constrainNodePosition(Offset position, TableNode node) {
    if (state.imageTiles.isEmpty) {
      return position;
    }
    
    // Получаем общие границы всех тайлов
    final totalBounds = state.totalBounds;
    
    // Рассчитываем границы узла
    final nodeWidth = node.size.width;
    final nodeHeight = node.size.height;
    
    // Ограничиваем позицию так, чтобы узел не выходил за границы тайлов
    double constrainedX = position.dx;
    double constrainedY = position.dy;
    
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
    
    if (constrained != position) {
      print('Позиция узла ограничена: $position -> $constrained');
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
  
  void startNodeDrag(Offset position) {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      print('Начало перетаскивания узла "${state.selectedNodeOnTopLayer!.text}"');
      print('Позиция мыши: $position');
      print('Текущая позиция узла: ${state.selectedNodeOffset}');
      
      // ВАЖНОЕ ИСПРАВЛЕНИЕ: сбрасываем предыдущие значения
      _nodeDragStart = position;
      _nodeStartPosition = state.selectedNodeOffset;
      
      state.isNodeDragging = true;
      onStateUpdate();
    }
  }
  
  void updateNodeDrag(Offset position) {
    if (state.isNodeDragging && state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      final delta = (position - _nodeDragStart) / state.scale;
      final newPosition = _nodeStartPosition + delta;
      
      // ВАЖНОЕ ИСПРАВЛЕНИЕ: ограничиваем позицию при перетаскивании
      final node = state.selectedNodeOnTopLayer!;
      final constrainedPosition = _constrainNodePosition(newPosition, node);
      
      // Отладочная информация
      if (constrainedPosition != newPosition) {
        print('Позиция ограничена при перетаскивании: $newPosition -> $constrainedPosition');
      }
      
      state.selectedNodeOffset = constrainedPosition;
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