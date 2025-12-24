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
  
  // Константы для рамки выделения (в пикселях)
  static const double framePadding = 4.0; // Отступ рамки от узла
  static const double frameBorderWidth = 2.0; // Толщина рамки
  static const double frameTotalOffset = framePadding + frameBorderWidth; // Общий отступ для рамки
  
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
      _updateFramePosition();
      onStateUpdate();
    }
  }
  
  // Корректировка позиции при изменении offset
  void onOffsetChanged() {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      _updateFramePosition();
      onStateUpdate();
    }
  }
  
  // Обновление позиции РАМКИ на основе позиции УЗЛА
  void _updateFramePosition() {
    if (state.selectedNodeOnTopLayer == null) return;
    
    // Мировые координаты левого верхнего угла узла
    final worldNodePosition = state.originalNodePosition;
    
    // Экранные координаты левого верхнего угла узла
    final screenNodePosition = _worldToScreen(worldNodePosition);
    
    // Позиция рамки: смещаем ОТ узла на общий отступ рамки
    // Рамка окружает узел, поэтому она находится левее и выше узла
    state.selectedNodeOffset = Offset(
      screenNodePosition.dx - frameTotalOffset,
      screenNodePosition.dy - frameTotalOffset,
    );
    
    print('=== ОБНОВЛЕНИЕ ПОЗИЦИИ РАМКИ ===');
    print('МИР: узел на $worldNodePosition');
    print('ЭКРАН: узел на $screenNodePosition');
    print('ЭКРАН: рамка на ${state.selectedNodeOffset}');
    print('Смещение рамки: -$frameTotalOffset пикселей');
    print('Scale: ${state.scale}, Offset: ${state.offset}');
  }
  
  void selectNodeAtPosition(Offset screenPosition, {bool immediateDrag = false}) {
    final worldPos = _screenToWorld(screenPosition);
    
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
        
        // Если это выделенный узел на верхнем слое, игнорируем его
        if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null && 
            state.selectedNodeOnTopLayer!.id == node.id) {
          continue;
        }
        
        if (nodeRect.contains(worldPos)) {
          return node;
        }
        
        if (node.children != null && node.children!.isNotEmpty) {
          final childNode = findNodeRecursive(node.children!, nodeOffset);
          if (childNode != null) {
            return childNode;
          }
        }
      }
      return null;
    }
    
    foundNode = findNodeRecursive(state.nodes, state.delta);
    
    if (foundNode != null) {
      if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
        if (state.selectedNodeOnTopLayer!.id == foundNode.id) {
          if (immediateDrag) {
            startNodeDrag(screenPosition);
          }
          return;
        }
        
        if (immediateDrag) {
          if (state.isNodeDragging) {
            endNodeDrag();
          }
          
          _saveNodeInBackground(state.selectedNodeOnTopLayer!);
          _selectNodeImmediate(foundNode, screenPosition);
        } else {
          _saveNodeToTiles().then((_) {
            _selectNode(foundNode!);
          });
        }
      } else {
        if (immediateDrag) {
          _selectNodeImmediate(foundNode, screenPosition);
        } else {
          _selectNode(foundNode);
        }
      }
    } else {
      handleEmptyAreaClick();
    }
  }
  
  void _selectNodeImmediate(TableNode node, Offset screenPosition) {
    _deselectAllNodes();
    
    node.isSelected = true;
    state.selectedNode = node;
    
    // Сохраняем мировые координаты ЛЕВОГО ВЕРХНЕГО УГЛА узла
    final worldNodePosition = state.delta + node.position;
    state.originalNodePosition = worldNodePosition;
    
    print('=== ВЫБОР УЗЛА ===');
    print('Узел: ${node.text}');
    print('Позиция в данных: ${node.position}');
    print('Дельта: ${state.delta}');
    print('Мировые координаты узла: $worldNodePosition');
    
    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;
    
    _updateFramePosition();
    
    tileManager.removeNodeFromTiles(node);
    
    startNodeDrag(screenPosition);
    
    onStateUpdate();
  }
  
  void _selectNode(TableNode node) {
    _deselectAllNodes();
    
    node.isSelected = true;
    state.selectedNode = node;
    
    final worldNodePosition = state.delta + node.position;
    state.originalNodePosition = worldNodePosition;
    
    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;
    
    _updateFramePosition();
    
    tileManager.removeNodeFromTiles(node);
    
    onStateUpdate();
  }
  
  Future<void> _saveNodeInBackground(TableNode node) async {
    // Мировые координаты узла уже сохранены в originalNodePosition
    final worldNodePosition = state.originalNodePosition;
    
    final constrainedWorldPosition = _constrainNodePosition(worldNodePosition, node);
    final newPosition = constrainedWorldPosition - state.delta;
    
    print('=== СОХРАНЕНИЕ УЗЛА ===');
    print('Старая позиция: ${node.position}');
    print('Новая позиция: $newPosition');
    print('На основе мировых координат: $worldNodePosition');
    
    node.position = newPosition;
    await tileManager.addNodeToTiles(node, constrainedWorldPosition);
    node.isSelected = false;
  }
  
  Future<void> _saveNodeToTiles() async {
    if (!state.isNodeOnTopLayer || state.selectedNodeOnTopLayer == null) {
      return;
    }
    
    final node = state.selectedNodeOnTopLayer!;
    final worldNodePosition = state.originalNodePosition;
    
    final constrainedWorldPosition = _constrainNodePosition(worldNodePosition, node);
    final newPosition = constrainedWorldPosition - state.delta;
    
    node.position = newPosition;
    await tileManager.addNodeToTiles(node, constrainedWorldPosition);
    
    node.isSelected = false;
    state.isNodeDragging = false;
    state.isNodeOnTopLayer = false;
    state.selectedNodeOnTopLayer = null;
    state.selectedNode = null;
    state.selectedNodeOffset = Offset.zero;
    state.originalNodePosition = Offset.zero;
    
    onStateUpdate();
  }
  
  Offset _constrainNodePosition(Offset worldPosition, TableNode node) {
    if (state.imageTiles.isEmpty) return worldPosition;
    
    final totalBounds = state.totalBounds;
    final nodeWidth = node.size.width;
    final nodeHeight = node.size.height;
    
    double x = worldPosition.dx;
    double y = worldPosition.dy;
    
    if (x < totalBounds.left) x = totalBounds.left;
    if (y < totalBounds.top) y = totalBounds.top;
    if (x + nodeWidth > totalBounds.right) x = totalBounds.right - nodeWidth;
    if (y + nodeHeight > totalBounds.bottom) y = totalBounds.bottom - nodeHeight;
    
    return Offset(x, y);
  }
  
  void deleteSelectedNode() {
    if (state.selectedNode != null) {
      if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
        _saveNodeToTiles().then((_) {
          state.nodes.removeWhere((node) => node.id == state.selectedNode!.id);
          state.selectedNode = null;
          tileManager.createTiledImage(state.nodes);
        });
      } else {
        state.nodes.removeWhere((node) => node.id == state.selectedNode!.id);
        state.selectedNode = null;
        tileManager.createTiledImage(state.nodes);
      }
      
      onStateUpdate();
    }
  }
  
  void startNodeDrag(Offset screenPosition) {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      _nodeDragStart = screenPosition;
      _nodeStartWorldPosition = state.originalNodePosition;
      
      state.isNodeDragging = true;
      onStateUpdate();
    }
  }
  
  void updateNodeDrag(Offset screenPosition) {
    if (state.isNodeDragging && state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      final screenDelta = screenPosition - _nodeDragStart;
      final worldDelta = screenDelta / state.scale;
      
      // Обновляем мировые координаты УЗЛА
      final newWorldPosition = _nodeStartWorldPosition + worldDelta;
      state.originalNodePosition = newWorldPosition;
      
      // Обновляем позицию рамки на основе новой позиции узла
      _updateFramePosition();
      
      onStateUpdate();
    }
  }
  
  void endNodeDrag() {
    if (state.isNodeDragging) {
      state.isNodeDragging = false;
      onStateUpdate();
    }
  }
  
  void handleEmptyAreaClick() {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      _saveNodeToTiles();
    } else {
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