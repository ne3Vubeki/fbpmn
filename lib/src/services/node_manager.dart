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
  
  void selectNodeAtPosition(Offset position) {
    final worldPos = (position - state.offset) / state.scale;
    
    print('Клик на позицию: $worldPos');
    
    TableNode? foundNode;
    Offset foundPosition = Offset.zero;
    
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
        // И если это тот же узел, просто выходим
        if (state.selectedNodeOnTopLayer!.id == foundNode.id) {
          print('Выбран уже выделенный узел, ничего не меняем');
          return;
        }
        
        // Если это другой узел, сохраняем предыдущий и выбираем новый
        print('Сохранение предыдущего узла и выбор нового...');
        _saveNodeToTiles().then((_) {
          // После сохранения выбираем новый узел
          _selectNode(foundNode!);
        });
      } else {
        // Нет выделенного узла, просто выбираем новый
        _selectNode(foundNode);
      }
    } else {
      print('Узел не найден под курсором');
      // Клик на пустую область
      handleEmptyAreaClick();
    }
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
    
    // Перемещаем узел на верхний слой
    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;
    
    // Смещаем позицию на -selectionPadding чтобы рамка выделения
    // отступала от узла на нужное количество пикселей
    state.selectedNodeOffset = Offset(
      foundPosition.dx - selectionPadding,
      foundPosition.dy - selectionPadding,
    );
    
    state.originalNodePosition = foundPosition;
    
    print('Узел перемещен на верхний слой. Скорректированная позиция: ${state.selectedNodeOffset}');
    
    // Удаляем узел из тайлов (только визуально, не из данных)
    tileManager.removeNodeFromTiles(node);
    
    onStateUpdate();
  }
  
  Future<void> _saveNodeToTiles() async {
    if (!state.isNodeOnTopLayer || state.selectedNodeOnTopLayer == null) {
      print('Нет узла для сохранения');
      return;
    }
    
    final node = state.selectedNodeOnTopLayer!;
    print('Сохранение узла "${node.text}" обратно в тайлы...');
    
    // ВАЖНО: добавляем selectionPadding обратно при сохранении
    final correctedOffset = Offset(
      state.selectedNodeOffset.dx + selectionPadding,
      state.selectedNodeOffset.dy + selectionPadding,
    );
    
    // Вычисляем новую позицию узла относительно дельты
    final newPosition = correctedOffset - state.delta;
    print('Новая позиция узла: $newPosition (была: ${node.position})');
    print('Скорректированный offset: $correctedOffset');
    print('Selection padding: $selectionPadding');
    
    // Обновляем позицию узла в оригинальных данных
    node.position = newPosition;
    
    // Добавляем узел обратно в тайлы с СКОРРЕКТИРОВАННОЙ позицией
    await tileManager.addNodeToTiles(node, correctedOffset);
    
    // Снимаем выделение
    node.isSelected = false;
    
    // Сбрасываем состояние
    state.isNodeOnTopLayer = false;
    state.selectedNodeOnTopLayer = null;
    state.selectedNode = null;
    
    onStateUpdate();
    print('Узел сохранен обратно в тайлы');
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
      print('Начало перетаскивания узла');
      state.isNodeDragging = true;
      _nodeDragStart = position;
      _nodeStartPosition = state.selectedNodeOffset;
      onStateUpdate();
    }
  }
  
  void updateNodeDrag(Offset position) {
    if (state.isNodeDragging && state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      final delta = (position - _nodeDragStart) / state.scale;
      state.selectedNodeOffset = _nodeStartPosition + delta;
      onStateUpdate();
    }
  }
  
  void endNodeDrag() {
    print('Конец перетаскивания узла');
    state.isNodeDragging = false;
    onStateUpdate();
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