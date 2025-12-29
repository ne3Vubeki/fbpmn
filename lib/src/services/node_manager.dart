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
  static const double frameTotalOffset =
      framePadding + frameBorderWidth; // Общий отступ для рамки

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
  }

  Future<void> _selectNodeImmediate(
    TableNode node,
    Offset screenPosition,
  ) async {
    _deselectAllNodes();

    node.isSelected = true;
    state.selectedNode = node;

    // Сохраняем мировые координаты ЛЕВОГО ВЕРХНЕГО УГЛА узла
    final worldNodePosition = state.delta + node.position;
    state.originalNodePosition = worldNodePosition;

    print('=== ВЫБОР УЗЛА (immediate) ===');
    print('Узел: ${node.text}');
    print('Позиция в данных: ${node.position.dx}:${node.position.dy}');
    print('Дельта: ${state.delta.dx}:${state.delta.dy}');
    print(
      'Мировые координаты узла: ${worldNodePosition.dx}:${worldNodePosition.dy}',
    );

    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;

    _updateFramePosition();

    // ВАЖНО: Сначала удаляем узел из state.nodes
    _removeNodeFromNodesList(node);

    // Затем удаляем узел из тайлов и ЖДЕМ завершения
    await tileManager.removeSelectedNodeFromTiles(node);

    startNodeDrag(screenPosition);

    onStateUpdate();
  }

  Future<void> _selectNode(TableNode node) async {
    _deselectAllNodes();

    node.isSelected = true;
    state.selectedNode = node;

    final worldNodePosition = state.delta + node.position;
    state.originalNodePosition = worldNodePosition;

    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;

    _updateFramePosition();

    // ВАЖНО: Сначала удаляем узел из state.nodes
    _removeNodeFromNodesList(node);

    // Затем удаляем узел из тайлов и ЖДЕМ завершения
    await tileManager.removeSelectedNodeFromTiles(node);

    onStateUpdate();
  }

  // Новый метод: удаление узла из основного списка узлов
  void _removeNodeFromNodesList(TableNode node) {
    print('Удаляем узел "${node.text}" из state.nodes');

    // Удаляем только корневой узел из основного списка
    // Вложенные узлы НЕ хранятся отдельно в state.nodes
    state.nodes.removeWhere((n) => n.id == node.id);
  }

  // Новый метод: добавление узла обратно в основной список узлов
  void _addNodeBackToNodesList(TableNode node) {
    // Проверяем, что узел еще не в списке
    if (!state.nodes.any((n) => n.id == node.id)) {
      // Добавляем только корневой узел
      // Вложенные узлы уже являются частью иерархии родителя
      state.nodes.add(node);
    }
  }

  Future<void> _saveNodeToTiles() async {
    if (!state.isNodeOnTopLayer || state.selectedNodeOnTopLayer == null) {
      return;
    }

    final node = state.selectedNodeOnTopLayer!;
    final worldNodePosition = state.originalNodePosition;

    final constrainedWorldPosition = worldNodePosition;
    final newPosition = constrainedWorldPosition - state.delta;

    print('=== СОХРАНЕНИЕ УЗЛА В ТАЙЛЫ (без ограничений) ===');
    print('Старая позиция: ${node.position.dx}:${node.position.dy}');
    print('Новая позиция: ${newPosition.dx}:${newPosition.dy}');

    // Обновляем позицию родителя
    node.position = newPosition;

    // Обновляем позиции всех детей относительно родителя
    _updateChildrenPositions(node, newPosition);

    // Добавляем узел обратно в основной список узлов
    _addNodeBackToNodesList(node);

    // Добавляем узел в тайлы на новом месте
    await tileManager.addNodeToTiles(node, constrainedWorldPosition);
    await tileManager.updateTilesAfterNodeChange();

    node.isSelected = false;
    state.isNodeDragging = false;
    state.isNodeOnTopLayer = false;
    state.selectedNodeOnTopLayer = null;
    state.selectedNode = null;
    state.selectedNodeOffset = Offset.zero;
    state.originalNodePosition = Offset.zero;

    onStateUpdate();
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

  Future<void> selectNodeAtPosition(
    Offset screenPosition, {
    bool immediateDrag = false,
  }) async {
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
        if (state.isNodeOnTopLayer &&
            state.selectedNodeOnTopLayer != null &&
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

          // Сохраняем текущий выделенный узел в тайлы
          await _saveNodeToTiles();
          // Выделяем новый узел
          await _selectNodeImmediate(foundNode, screenPosition);
        } else {
          // Сохраняем текущий выделенный узел в тайлы
          await _saveNodeToTiles();
          // Выделяем новый узел
          await _selectNode(foundNode);
        }
      } else {
        if (immediateDrag) {
          await _selectNodeImmediate(foundNode, screenPosition);
        } else {
          await _selectNode(foundNode);
        }
      }
    } else {
      handleEmptyAreaClick();
    }
  }

  /// Обновляет позиции всех детей относительно нового положения родителя
  void _updateChildrenPositions(
    TableNode parentNode,
    Offset parentNewPosition,
  ) {
    void updateRecursive(TableNode node, Offset parentOffset) {
      // Для детей позиция уже правильная относительно родителя
      // Не нужно их перемещать, они уже в правильных относительных координатах
      if (node.children != null && node.children!.isNotEmpty) {
        for (final child in node.children!) {
          updateRecursive(child, parentOffset + node.position);
        }
      }
    }

    updateRecursive(parentNode, parentNewPosition);
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
    if (state.isNodeDragging &&
        state.isNodeOnTopLayer &&
        state.selectedNodeOnTopLayer != null) {
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
