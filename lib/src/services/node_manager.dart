import 'dart:math' as math;

import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../editor_state.dart';
import '../models/table.node.dart';
import '../services/tile_manager.dart';

class NodeManager extends Manager {
  final EditorState state;
  final TileManager tileManager;
  final ArrowManager arrowManager;

  Offset _nodeDragStart = Offset.zero;
  Offset _nodeStartWorldPosition = Offset.zero;

  // Переменные для хранения начальных параметров рамки swimlane
  Rect? _initialSwimlaneBounds;
  EdgeInsets? _initialFramePadding;

  // Константы для рамки выделения (в пикселях)
  static const double framePadding = 4.0; // Отступ рамки от узла
  static const double frameBorderWidth = 2.0; // Толщина рамки
  static const double frameTotalOffset = framePadding + frameBorderWidth; // Общий отступ для рамки

  NodeManager({required this.state, required this.tileManager, required this.arrowManager});

  static List<TableNode?> whereAllNodes(List<TableNode?> nodes, Function test) {
    List<TableNode?> testNodes = [];
    for (final node in nodes) {
      if (test(node)) {
        testNodes.add(node);
      }
      if (node?.children != null && node!.children!.isNotEmpty) {
        testNodes.addAll(whereAllNodes(node.children!, test));
      }
    }
    return testNodes;
  }

  static TableNode? getNodeById(List<TableNode?> nodes, String id) {
    for (final node in nodes) {
      if (node!.id == id) {
        return node;
      }
      if (node.children != null && node!.children!.isNotEmpty) {
        return getNodeById(node.children!, id);
      }
    }
    return null;
  }

  double calculateGridAlphaForLevel(int level) {

    // Для каждого уровня идеальный масштаб = 1 / (4^level)
    // Например:
    // level = 0: idealScale = 1.0 (базовый масштаб)
    // level = 1: idealScale = 1/4 = 0.25
    // level = -1: idealScale = 4.0
    // level = -2: idealScale = 16.0
    double idealScale = 1.0 / math.pow(4, level).toDouble();

    // Разница в логарифмической шкале между текущим масштабом и идеальным
    // log(scale) - log(idealScale) = log(scale / idealScale)
    double logDifference = (math.log(state.scale) - math.log(idealScale)).abs();

    // Максимальная допустимая разница (2.0 означает примерно e^2 ≈ 7.4 раза)
    double maxLogDifference = 2.0;

    // Вычисляем alpha (прозрачность) по формуле:
    // alpha = (1 - (logDifference / maxLogDifference)) * 0.8
    // Где:
    // - 0.8 - максимальная alpha
    // - logDifference/maxLogDifference - относительная разница (0..1)
    // - 1 - (logDifference/maxLogDifference) - обратная пропорция
    double alpha = (1.0 - (logDifference / maxLogDifference)).clamp(0.0, 1.0) * 0.8;

    return alpha;
  }

  void updateNodeDrag(Offset screenPosition) {
    if (state.isNodeDragging &&
        state.isNodeOnTopLayer &&
        state.nodesSelected.isNotEmpty) {
      final screenDelta = screenPosition - _nodeDragStart;
      final worldDelta = screenDelta / state.scale;

      // Обновляем мировые координаты УЗЛА
      final newWorldPosition = _nodeStartWorldPosition + worldDelta;
      state.originalNodePosition = newWorldPosition;

      // Обновляем позицию рамки на основе новой позиции узла
      _updateNodePosition();

      onStateUpdate();
      arrowManager.onStateUpdate();
    }
  }

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
    if (state.isNodeOnTopLayer && state.nodesSelected.isNotEmpty) {
      _updateNodePosition();
      onStateUpdate();
    }
  }

  // Корректировка позиции при изменении offset
  void onOffsetChanged() {
    if (state.isNodeOnTopLayer && state.nodesSelected.isNotEmpty) {
      _updateNodePosition();
      onStateUpdate();
    }
  }

  // Обновление позиции РАМКИ на основе позиции УЗЛА
  void _updateNodePosition() {
    if (state.nodesSelected.isEmpty) return;

    final node = state.nodesSelected.first!;

    // Для swimlane в раскрытом состоянии рассчитываем общие границы
    if (node.qType == 'swimlane' && !(node.isCollapsed ?? false)) {
      _updateSwimlaneNodePosition(node);
      return;
    }

    // Для обычных узлов и свернутых swimlane
    final worldNodePosition = state.originalNodePosition;
    final screenNodePosition = _worldToScreen(worldNodePosition);

    state.selectedNodeOffset = Offset(
      screenNodePosition.dx - frameTotalOffset,
      screenNodePosition.dy - frameTotalOffset,
    );

    node.position = worldNodePosition - state.delta;
    node.aPosition = worldNodePosition;
    if (node.children != null && node.children!.isNotEmpty) {
      for (final child in node.children!) {
        child.aPosition = worldNodePosition + child.position;
      }
    }

    state.framePadding = EdgeInsets.all(framePadding);
  }

  // Метод для обновления рамки выделения swimlane
  void _updateSwimlaneNodePosition(TableNode swimlaneNode) {
    if (state.isNodeDragging && _initialSwimlaneBounds != null) {
      // Если мы перетаскиваем swimlane и у нас есть начальные параметры,
      // просто сдвигаем рамку на ту же величину, что и узел
      final worldNodePosition = state.originalNodePosition;
      final positionDelta = worldNodePosition - _nodeStartWorldPosition;

      // Вычисляем новую позицию рамки
      final newFrameScreenPos =
          _worldToScreen(_initialSwimlaneBounds!.topLeft) +
          Offset(positionDelta.dx * state.scale, positionDelta.dy * state.scale);

      state.selectedNodeOffset = Offset(
        newFrameScreenPos.dx - frameTotalOffset,
        newFrameScreenPos.dy - frameTotalOffset,
      );

      swimlaneNode.position = worldNodePosition - state.delta;
      swimlaneNode.aPosition = worldNodePosition;
      if (swimlaneNode.children != null && swimlaneNode.children!.isNotEmpty) {
        for (final child in swimlaneNode.children!) {
          child.aPosition = worldNodePosition + child.position;
        }
      }

      print('Двигается узел из swimlane');

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
          final childWorldPos = child.aPosition ?? (parentWorldPos + child.position);
          final childRect = Rect.fromLTWH(childWorldPos.dx, childWorldPos.dy, child.size.width, child.size.height);

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
      state.selectedNodeOffset = Offset(screenMin.dx - frameTotalOffset, screenMin.dy - frameTotalOffset);

      // Размер отступов рамки слева и сверху для родительского узла
      state.framePadding = EdgeInsets.only(
        left: screenLeftTop.dx - screenMin.dx + framePadding,
        top: screenLeftTop.dy - screenMin.dy + framePadding,
        right: screenMax.dx - screenRightBottom.dx + framePadding,
        bottom: screenMax.dy - screenRightBottom.dy + framePadding,
      );

      // Сохраняем начальные параметры рамки при первом вычислении
      _initialSwimlaneBounds = Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);

      print('Двигается весь swimlane');

      _initialFramePadding = state.framePadding;
    }
  }

  Future<void> _selectNodeImmediate(TableNode node, Offset screenPosition) async {
    _deselectAllNodes();

    node.isSelected = true;
    state.nodesSelected.add(node);

    // Сохраняем мировые координаты ЛЕВОГО ВЕРХНЕГО УГЛА узла
    final worldNodePosition = node.aPosition ?? (state.delta + node.position);
    state.originalNodePosition = worldNodePosition;
    state.nodesSelected.add(node);
    state.isNodeOnTopLayer = true;

    _updateNodePosition();

    // Затем удаляем узел из тайлов и ЖДЕМ завершения
    await tileManager.removeSelectedNodeFromTiles(node);

    arrowManager.selectAllArrows();

    startNodeDrag(screenPosition);

    onStateUpdate();
  }

  Future<void> _selectNode(TableNode node) async {
    _deselectAllNodes();

    node.isSelected = true;
    state.nodesSelected.add(node);

    final worldNodePosition = node.aPosition ?? (state.delta + node.position);
    state.originalNodePosition = worldNodePosition;

    state.nodesSelected.add(node);
    state.isNodeOnTopLayer = true;

    await _prepareNodeForTopLayer(node);

    _updateNodePosition();

    arrowManager.selectAllArrows();

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
      final tilesToUpdate = <int>{};
      await tileManager.removeSwimlaneChildrenFromTiles(node, tilesToUpdate);
      // Обновляем все затронутые тайлы
      for (final tileIndex in tilesToUpdate) {
        await tileManager.updateTileWithAllContent(state.imageTiles[tileIndex]);
      }
    }

    // Удаляем узел из тайлов
    await tileManager.removeSelectedNodeFromTiles(node);
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
      if (parentSwimlane.children != null && !parentSwimlane.children!.any((child) => child.id == node.id)) {
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
    if (!state.isNodeOnTopLayer || state.nodesSelected.isEmpty) {
      return;
    }

    final node = state.nodesSelected.first!;
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
    state.nodesSelected.clear();
    state.arrowsSelected.clear();
    state.selectedNodeOffset = Offset.zero;
    state.originalNodePosition = Offset.zero;

    onStateUpdate();
    arrowManager.onStateUpdate();
  }

  // Метод для поиска родителя swimlane
  TableNode? _findParentExpandedSwimlaneNode(TableNode node) {
    return state.nodes.firstWhereOrNull((n) => n.id == node.parent);
  }

  void handleEmptyAreaClick() {
    if (state.isNodeOnTopLayer && state.nodesSelected.isNotEmpty) {
      _saveNodeToTiles();
    } else {
      _deselectAllNodes();
      state.nodesSelected.clear();
      state.arrowsSelected.clear();
      state.isNodeOnTopLayer = false;
      state.selectedNodeOffset = Offset.zero;
      state.originalNodePosition = Offset.zero;
      onStateUpdate();
      arrowManager.onStateUpdate();
    }
  }

  Future<void> selectNodeAtPosition(Offset screenPosition, {bool immediateDrag = false}) async {
    final worldPos = _screenToWorld(screenPosition);

    TableNode? foundNode;
    Offset? foundNodeWorldPosition;

    // Ищем узел под курсором (с учетом иерархии)
    TableNode? findNodeRecursive(List<TableNode> nodes, Offset parentOffset) {
      for (int i = nodes.length - 1; i >= 0; i--) {
        final node = nodes[i];
        final nodeOffset = node.aPosition ?? (parentOffset + node.position);
        final nodeRect = Rect.fromLTWH(nodeOffset.dx, nodeOffset.dy, node.size.width, node.size.height);

        // Если это выделенный узел на верхнем слое, игнорируем его
        if (state.isNodeOnTopLayer && state.nodesSelected.isNotEmpty && state.nodesSelected.first!.id == node.id) {
          continue;
        }

        if (nodeRect.contains(worldPos)) {
          foundNodeWorldPosition = nodeOffset;
          return node;
        }

        // Проверяем, является ли узел свернутым swimlane
        final isCollapsedSwimlane = node.qType == 'swimlane' && (node.isCollapsed ?? false);

        // Если узел не свернут, проверяем детей
        if (!isCollapsedSwimlane && node.children != null && node.children!.isNotEmpty) {
          // Для развернутого swimlane, дети используют свои абсолютные позиции
          for (int j = node.children!.length - 1; j >= 0; j--) {
            final child = node.children![j];
            final childOffset = child.aPosition ?? (nodeOffset + child.position);
            final childRect = Rect.fromLTWH(childOffset.dx, childOffset.dy, child.size.width, child.size.height);

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
      if (foundNode.qType == 'swimlane' && _isSwimlaneIconClicked(foundNode, worldPos, foundNodeWorldPosition!)) {
        await _toggleSwimlaneCollapsed(foundNode);
        return;
      }

      if (state.isNodeOnTopLayer && state.nodesSelected.isNotEmpty) {
        if (state.nodesSelected.first!.id == foundNode.id) {
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
    // if (state.nodesSelected.isNotEmpty && state.nodesSelected.first?.id == swimlaneNode.id) {
    //   await _saveNodeToTiles();
    // }

    // Обновляем узел в списке узлов
    _updateNodeInList(toggledNode);

    // В зависимости от состояния обновляем тайлы
    if (toggledNode.isCollapsed ?? false) {
      // Удаляем детей из тайлов
      final tilesToUpdate = <int>{};
      await tileManager.removeSwimlaneChildrenFromTiles(swimlaneNode, tilesToUpdate);
      // Обновляем все затронутые тайлы
      for (final tileIndex in tilesToUpdate) {
        await tileManager.updateTileWithAllContent(state.imageTiles[tileIndex]);
      }
    } else {
      // При раскрытии swimlane, когда у детей есть абсолютные позиции,
      // нужно правильно рассчитать их относительные позиции
      if (toggledNode.children != null) {
        for (final child in toggledNode.children!) {
          if (child.aPosition != null) {
            // Рассчитываем относительные координаты ребенка из абсолютных,
            // вычитая delta и позицию родителя
            child.position = child.aPosition! - state.delta - toggledNode.position;
          } else {
            // Если у ребенка нет абсолютной позиции, используем текущую относительную
            // Это важно для сохранения перемещенных дочерних узлов
            child.aPosition = state.delta + toggledNode.position + child.position;
          }
        }
      }
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

  // Метод для проверки клика по иконке swimlane
  bool _isSwimlaneIconClicked(TableNode node, Offset worldPosition, Offset nodeWorldPosition) {
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

  void startNodeDrag(Offset screenPosition) {
    if (state.isNodeOnTopLayer && state.nodesSelected.isNotEmpty) {
      _nodeDragStart = screenPosition;
      _nodeStartWorldPosition = state.originalNodePosition;

      // Очищаем начальные параметры рамки при начале перетаскивания
      _initialSwimlaneBounds = null;
      _initialFramePadding = null;

      state.isNodeDragging = true;
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
