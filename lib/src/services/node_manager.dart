import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../editor_state.dart';
import '../models/table.node.dart';
import '../services/tile_manager.dart';

class NodeManager {
  final EditorState state;
  final TileManager tileManager;
  final VoidCallback onStateUpdate;

  Offset _nodeDragStart = Offset.zero;
  Offset _nodeStartWorldPosition = Offset.zero;

  // Переменные для хранения начальных параметров рамки swimlane
  Rect? _initialSwimlaneBounds;
  EdgeInsets? _initialFramePadding;

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

    final node = state.selectedNodeOnTopLayer!;

    // Для swimlane в раскрытом состоянии рассчитываем общие границы
    if (node.qType == 'swimlane' && !(node.isCollapsed ?? false)) {
      _updateSwimlaneFramePosition(node);
      return;
    }

    // Для обычных узлов и свернутых swimlane
    final worldNodePosition = state.originalNodePosition;
    final screenNodePosition = _worldToScreen(worldNodePosition);

    state.selectedNodeOffset = Offset(
      screenNodePosition.dx - frameTotalOffset,
      screenNodePosition.dy - frameTotalOffset,
    );
    state.framePadding = EdgeInsets.all(framePadding);
  }

  // Метод для обновления рамки выделения swimlane
  void _updateSwimlaneFramePosition(TableNode swimlaneNode) {
    if (state.isNodeDragging && _initialSwimlaneBounds != null) {
      // Если мы перетаскиваем swimlane и у нас есть начальные параметры,
      // просто сдвигаем рамку на ту же величину, что и узел
      final currentWorldPos = state.originalNodePosition;
      final positionDelta = currentWorldPos - _nodeStartWorldPosition;

      // Вычисляем новую позицию рамки
      final newFrameScreenPos =
          _worldToScreen(_initialSwimlaneBounds!.topLeft) +
          Offset(
            positionDelta.dx * state.scale,
            positionDelta.dy * state.scale,
          );

      state.selectedNodeOffset = Offset(
        newFrameScreenPos.dx - frameTotalOffset,
        newFrameScreenPos.dy - frameTotalOffset,
      );

      // Используем сохраненные отступы
      state.framePadding = _initialFramePadding!;
    } else {
      // Находим минимальные и максимальные координаты всех узлов swimlane
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;

      // Добавляем родительский узел
      final parentWorldPos = state.originalNodePosition;
      final parentRect = Rect.fromLTWH(
        parentWorldPos.dx,
        parentWorldPos.dy,
        swimlaneNode.size.width,
        swimlaneNode.size.height,
      );

      minX = math.min(minX, parentRect.left);
      minY = math.min(minY, parentRect.top);
      maxX = math.max(maxX, parentRect.right);
      maxY = math.max(maxY, parentRect.bottom);

      final screenLeftTop = _worldToScreen(Offset(minX, minY));
      final screenRightBottom = _worldToScreen(Offset(maxX, maxY));

      // Добавляем детей
      if (swimlaneNode.children != null) {
        for (final child in swimlaneNode.children!) {
          // Для детей используем их абсолютные позиции, если они установлены
          final childWorldPos =
              child.aPosition ?? (parentWorldPos + child.position);
          final childRect = Rect.fromLTWH(
            childWorldPos.dx,
            childWorldPos.dy,
            child.size.width,
            child.size.height,
          );

          minX = math.min(minX, childRect.left);
          minY = math.min(minY, childRect.top);
          maxX = math.max(maxX, childRect.right);
          maxY = math.max(maxY, childRect.bottom);
        }
      }

      // Экранные координаты
      final screenMin = _worldToScreen(Offset(minX, minY));
      final screenMax = _worldToScreen(Offset(maxX, maxY));

      // Позиция рамки с отступом
      state.selectedNodeOffset = Offset(
        screenMin.dx - frameTotalOffset,
        screenMin.dy - frameTotalOffset,
      );

      // Размер отступов рамки слева и сверху для родительского узла
      state.framePadding = EdgeInsets.only(
        left: screenLeftTop.dx - screenMin.dx + framePadding,
        top: screenLeftTop.dy - screenMin.dy + framePadding,
        right: screenMax.dx - screenRightBottom.dx + framePadding,
        bottom: screenMax.dy - screenRightBottom.dy + framePadding,
      );

      // Сохраняем начальные параметры рамки при первом вычислении
      _initialSwimlaneBounds = Rect.fromLTWH(
        minX,
        minY,
        maxX - minX,
        maxY - minY,
      );
      _initialFramePadding = state.framePadding;
    }
  }

  Future<void> _selectNodeImmediate(
    TableNode node,
    Offset screenPosition,
  ) async {
    _deselectAllNodes();

    node.isSelected = true;
    state.selectedNode = node;

    // Сохраняем мировые координаты ЛЕВОГО ВЕРХНЕГО УГЛА узла
    final worldNodePosition = node.aPosition ?? (state.delta + node.position);
    state.originalNodePosition = worldNodePosition;
    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;

    _updateFramePosition();

    // ВАЖНО: Сначала удаляем узел из state.nodes
    _removeNodeFromNodesList(node);

    // Для swimlane в развернутом состоянии удаляем узел и детей из тайлов
    if (node.qType == 'swimlane' && !(node.isCollapsed ?? false)) {
      // Сохраняем абсолютные позиции детей перед удалением
      if (node.children != null) {
        for (final child in node.children!) {
          child.aPosition ??= state.delta + node.position + child.position;
        }
      }
      await _removeSwimlaneChildrenFromTiles(node);
    }

    // Затем удаляем узел из тайлов и ЖДЕМ завершения
    await tileManager.removeSelectedNodeFromTiles(node);

    startNodeDrag(screenPosition);

    onStateUpdate();
  }

  Future<void> _selectNode(TableNode node) async {
    _deselectAllNodes();

    node.isSelected = true;
    state.selectedNode = node;

    final worldNodePosition = node.aPosition ?? (state.delta + node.position);
    state.originalNodePosition = worldNodePosition;

    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;

    await _prepareNodeForTopLayer(node);

    _updateFramePosition();
    onStateUpdate();
  }

  /// Подготовка узла для перемещения на верхний слой
  Future<void> _prepareNodeForTopLayer(TableNode node) async {
    // Удаляем узел из state.nodes
    _removeNodeFromNodesList(node);

    // Для swimlane в развернутом состоянии удаляем всех детей из тайлов
    if (node.qType == 'swimlane' && !(node.isCollapsed ?? false)) {
      // Сохраняем абсолютные позиции детей перед удалением
      if (node.children != null) {
        for (final child in node.children!) {
          child.aPosition ??= state.delta + node.position + child.position;
        }
      }
      await _removeSwimlaneChildrenFromTiles(node);
    }

    // Удаляем узел из тайлов
    await tileManager.removeSelectedNodeFromTiles(node);
  }

  // Добавляем метод для удаления детей swimlane из тайлов
  Future<void> _removeSwimlaneChildrenFromTiles(TableNode swimlaneNode) async {
    if (swimlaneNode.children == null || swimlaneNode.children!.isEmpty) {
      return;
    }

    // Удаляем всех детей из тайлов
    for (final child in swimlaneNode.children!) {
      await tileManager.removeSelectedNodeFromTiles(child);
    }
  }

  // Новый метод: удаление узла из основного списка узлов
  void _removeNodeFromNodesList(TableNode node) {
    // Проверяем, является ли узел дочерним для какого-либо swimlane
    TableNode? parentSwimlane = _findParentExpandedSwimlaneNode(node);
    if (parentSwimlane != null) {
      // Если узел является дочерним для swimlane, удаляем его из детей родителя
      if (parentSwimlane.children != null) {
        parentSwimlane.children!.removeWhere((child) => child.id == node.id);
      }
    } else {
      // Удаляем только корневой узел из основного списка
      // Вложенные узлы НЕ хранятся отдельно в state.nodes
      state.nodes.removeWhere((n) => n.id == node.id);
    }
  }

  // Новый метод: добавление узла обратно в основной список узлов
  void _addNodeBackToNodesList(TableNode node) {
    // Проверяем, является ли узел дочерним для какого-либо swimlane
    TableNode? parentSwimlane = _findParentExpandedSwimlaneNode(node);
    if (parentSwimlane != null) {
      // Проверяем, что узел еще не в списке детей
      if (parentSwimlane.children != null &&
          !parentSwimlane.children!.any((child) => child.id == node.id)) {
        parentSwimlane.children!.add(node);
      }
    } else {
      // Проверяем, что узел еще не в списке
      if (!state.nodes.any((n) => n.id == node.id)) {
        // Добавляем только корневой узел
        // Вложенные узлы уже являются частью иерархии родителя
        state.nodes.add(node);
      }
    }
  }

  Future<void> _saveNodeToTiles() async {
    if (!state.isNodeOnTopLayer || state.selectedNodeOnTopLayer == null) {
      return;
    }

    final node = state.selectedNodeOnTopLayer!;
    final newPositionDelta = node.aPosition! - state.originalNodePosition;

    // Обновляем абсолютную позицию узла перед сохранением
    node.aPosition = state.originalNodePosition;

    // Находим родительский swimlane, если он существует и развернут
    TableNode? parentSwimlane = _findParentExpandedSwimlaneNode(node);
    if (parentSwimlane != null) {
      // Если узел является дочерним для развернутого swimlane,
      // вычисляем его относительную позицию по отношению к родителю
      node.position = node.aPosition! - state.delta - parentSwimlane.position;
    } else {
      // Для обычных узлов (не дочерних развернутого swimlane)
      final newPosition = node.aPosition! - state.delta;
      node.position = newPosition;

      // Если это swimlane с детьми, обновляем относительные позиции детей
      if (node.children != null) {
        for (final child in node.children!) {
          if (child.aPosition != null) {
            // Рассчитываем новую авсолютную позицию, если изменилась позиция родителя
            child.aPosition = child.aPosition! - newPositionDelta;
            // Рассчитываем относительные координаты ребенка из абсолютных,
            // вычитая delta и позицию родителя
            child.position = child.aPosition! - state.delta - node.position;
          }
        }
      }
    }

    // Добавляем узел обратно в основной список узлов
    _addNodeBackToNodesList(node);

    // Для swimlane в развернутом состоянии добавляем детей в тайлы
    if (node.qType == 'swimlane' && !(node.isCollapsed ?? false)) {
      await _addSwimlaneChildrenToTiles(node, node.aPosition!);
    }

    // Добавляем родительский узел в тайлы
    await tileManager.addNodeToTiles(node, node.aPosition!);

    await tileManager.updateTilesAfterNodeChange();

    node.isSelected = false;

    // Снимаем выделение с детей swimlane
    if (node.qType == 'swimlane' && node.children != null) {
      for (final child in node.children!) {
        child.isSelected = false;
      }
    }

    // Пересчитываем абсолютные позиции для всех узлов
    for (final node in state.nodes) {
      node.initializeAbsolutePositions(state.delta);
    }

    state.isNodeDragging = false;
    state.isNodeOnTopLayer = false;
    state.selectedNodeOnTopLayer = null;
    state.selectedNode = null;
    state.selectedNodeOffset = Offset.zero;
    state.originalNodePosition = Offset.zero;

    onStateUpdate();
  }

  // Метод для поиска родителя swimlane
  TableNode? _findParentExpandedSwimlaneNode(TableNode node) {
    return state.nodes.firstWhereOrNull((n) => n.id == node.parent);
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
    Offset? foundNodeWorldPosition;

    // Ищем узел под курсором (с учетом иерархии)
    TableNode? findNodeRecursive(List<TableNode> nodes, Offset parentOffset) {
      for (int i = nodes.length - 1; i >= 0; i--) {
        final node = nodes[i];
        final nodeOffset = node.aPosition ?? (parentOffset + node.position);
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
          foundNodeWorldPosition = nodeOffset;
          return node;
        }

        // Проверяем, является ли узел свернутым swimlane
        final isCollapsedSwimlane =
            node.qType == 'swimlane' && (node.isCollapsed ?? false);

        // Если узел не свернут, проверяем детей
        if (!isCollapsedSwimlane &&
            node.children != null &&
            node.children!.isNotEmpty) {
          // Для развернутого swimlane, дети используют свои абсолютные позиции
          for (int j = node.children!.length - 1; j >= 0; j--) {
            final child = node.children![j];
            final childOffset =
                child.aPosition ?? (nodeOffset + child.position);
            final childRect = Rect.fromLTWH(
              childOffset.dx,
              childOffset.dy,
              child.size.width,
              child.size.height,
            );

            if (childRect.contains(worldPos)) {
              foundNodeWorldPosition = childOffset;
              return child;
            }
          }

          // Если мы не нашли дочерний узел под курсором, продолжаем с остальными узлами
          final childNode = findNodeRecursive(node.children!, nodeOffset);
          if (childNode != null) {
            return childNode;
          }
        }
      }
      return null;
    }

    foundNode = findNodeRecursive(state.nodes, state.delta);

    if (foundNode != null && foundNodeWorldPosition != null) {
      // Проверяем клик по иконке swimlane
      if (foundNode.qType == 'swimlane' &&
          _isSwimlaneIconClicked(
            foundNode,
            worldPos,
            foundNodeWorldPosition!,
          )) {
        await _toggleSwimlaneCollapsed(foundNode);
        return;
      }

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

  // Метод для переключения состояния swimlane
  Future<void> _toggleSwimlaneCollapsed(TableNode swimlaneNode) async {
    // Создаем копию узла с переключенным состоянием
    final toggledNode = swimlaneNode.toggleCollapsed();

    // Если узел был выделен, снимаем выделение
    if (state.selectedNode?.id == swimlaneNode.id) {
      await _saveNodeToTiles();
    }

    // Обновляем узел в списке узлов
    _updateNodeInList(toggledNode);

    // В зависимости от состояния обновляем тайлы
    if (toggledNode.isCollapsed ?? false) {
      // Удаляем детей из тайлов
      await _removeSwimlaneChildrenFromTiles(swimlaneNode);
    } else {
      // При раскрытии swimlane, когда у детей есть абсолютные позиции,
      // нужно правильно рассчитать их относительные позиции
      if (toggledNode.children != null) {
        for (final child in toggledNode.children!) {
          if (child.aPosition != null) {
            // Рассчитываем относительные координаты ребенка из абсолютных,
            // вычитая delta и позицию родителя
            child.position =
                child.aPosition! - state.delta - toggledNode.position;
          } else {
            // Если у ребенка нет абсолютной позиции, используем текущую относительную
            // Это важно для сохранения перемещенных дочерних узлов
            child.aPosition =
                state.delta + toggledNode.position + child.position;
          }
        }
      }

      // Добавляем детей в тайлы
      final parentWorldPosition = state.delta + toggledNode.position;
      await _addSwimlaneChildrenToTiles(toggledNode, parentWorldPosition);
    }

    // Обновляем тайлы
    await tileManager.updateTilesAfterNodeChange();

    // Пересчитываем абсолютные позиции для всех узлов
    for (final node in state.nodes) {
      node.initializeAbsolutePositions(state.delta);
    }

    onStateUpdate();
  }

  // Вспомогательный метод для обновления узла в списке
  void _updateNodeInList(TableNode updatedNode) {
    for (int i = 0; i < state.nodes.length; i++) {
      if (state.nodes[i].id == updatedNode.id) {
        state.nodes[i] = updatedNode;
        return;
      }
    }
  }

  // Метод для добавления детей swimlane в тайлы
  Future<void> _addSwimlaneChildrenToTiles(
    TableNode swimlaneNode,
    Offset parentWorldPosition,
  ) async {
    if (swimlaneNode.children == null || swimlaneNode.children!.isEmpty) {
      return;
    }

    // Добавляем всех детей в тайлы
    for (final child in swimlaneNode.children!) {
      // Вычисляем мировые координаты ребенка
      final childWorldPosition =
          child.aPosition ?? (parentWorldPosition + child.position);
      await tileManager.addNodeToTiles(child, childWorldPosition);
    }
  }

  // Метод для проверки клика по иконке swimlane
  bool _isSwimlaneIconClicked(
    TableNode node,
    Offset worldPosition,
    Offset nodeWorldPosition,
  ) {
    if (node.qType != 'swimlane') return false;

    final iconSize = 16.0 * state.scale;
    final iconMargin = 8.0 * state.scale;

    // Преобразуем мировые координаты узла в экранные
    final screenNodePosition = _worldToScreen(nodeWorldPosition);

    // Преобразуем мировые координаты клика в экранные
    final screenClickPosition = _worldToScreen(worldPosition);

    // Рассчитываем область иконки в экранных координатах
    // Иконка всегда имеет фиксированный размер в пикселях экрана
    final iconRect = Rect.fromLTWH(
      screenNodePosition.dx + iconMargin,
      screenNodePosition.dy + iconMargin,
      iconSize,
      iconSize,
    );

    return iconRect.contains(screenClickPosition);
  }

  Future<void> deleteSelectedNode() async {
    if (state.selectedNode != null) {
      if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
        await _saveNodeToTiles();
      }
      
      // Remove arrows connected to the node from all tiles BEFORE removing the node
      if (state.selectedNode != null) {
        await tileManager.removeArrowsForSelectedNode(state.selectedNode!);
      }
      
      // Remove the node from the main list
      state.nodes.removeWhere((node) => node.id == state.selectedNode!.id);
      state.selectedNode = null;

      // Пересчитываем абсолютные позиции для всех оставшихся узлов
      for (final node in state.nodes) {
        node.initializeAbsolutePositions(state.delta);
      }

      // Recreate tiles with updated content
      await tileManager.createTiledImage(state.nodes);

      onStateUpdate();
    }
  }

  void startNodeDrag(Offset screenPosition) {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      _nodeDragStart = screenPosition;
      _nodeStartWorldPosition = state.originalNodePosition;

      // Очищаем начальные параметры рамки при начале перетаскивания
      _initialSwimlaneBounds = null;
      _initialFramePadding = null;

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
      // Очищаем начальные параметры рамки после завершения перетаскивания
      _initialSwimlaneBounds = null;
      _initialFramePadding = null;
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
