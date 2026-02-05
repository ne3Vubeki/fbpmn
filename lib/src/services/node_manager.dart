import 'dart:math' as math;

import 'package:fbpmn/src/models/snap_line.dart';
import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/manager.dart';
import 'package:fbpmn/src/utils/utils.dart';
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

  // Переменные для изменения размеров узла
  bool _isResizing = false;
  String? _resizeHandle; // 'tl', 'tr', 'bl', 'br', 't', 'r', 'b', 'l'
  String? _hoveredResizeHandle;
  Offset _resizeStartPosition = Offset.zero;
  Size _resizeStartSize = Size.zero;
  Offset _resizeStartNodePosition = Offset.zero;

  // Константы для snap-прилипания
  static const double snapThreshold = 15.0; // Порог прилипания в пикселях

  // Константы для рамки выделения (в пикселях)
  double get framePadding => 2.0 * state.scale; // Отступ рамки от узла
  double get frameBorderWidth => 2.0 * state.scale; // Толщина рамки
  double get frameTotalOffset => framePadding + frameBorderWidth; // Общий отступ для рамки

  // Константы для маркеров изменения размера
  static const double resizeHandleOffset = 12.0; // Отступ маркеров от узла
  static const double resizeHandleLength = 12.0; // Длина линий маркера
  static const double resizeHandleWidth = 2.0; // Толщина линий маркера

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
      if (node.children != null && node.children!.isNotEmpty) {
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
    if (state.isNodeDragging && state.isNodeOnTopLayer && state.nodesSelected.isNotEmpty) {
      final screenDelta = screenPosition - _nodeDragStart;
      final worldDelta = screenDelta / state.scale;

      // Обновляем мировые координаты УЗЛА
      var newWorldPosition = _nodeStartWorldPosition + worldDelta;

      // Применяем snap-прилипание (если включено)
      if (state.snapEnabled) {
        final snapResult = _applySnap(newWorldPosition);
        newWorldPosition = snapResult.position;
        state.snapLines = snapResult.snapLines;
      } else {
        state.snapLines = [];
      }

      state.originalNodePosition = newWorldPosition;

      // Обновляем позицию рамки на основе новой позиции узла
      _updateNodePosition();

      onStateUpdate();
      arrowManager.onStateUpdate();
    }
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
    final screenNodePosition = Utils.worldToScreen(worldNodePosition, state);

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
          Utils.worldToScreen(_initialSwimlaneBounds!.topLeft, state) +
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

      final screenLeftTop = Utils.worldToScreen(Offset(minX, minY), state);
      final screenRightBottom = Utils.worldToScreen(Offset(maxX, maxY), state);

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
      final screenMin = Utils.worldToScreen(Offset(minX, minY), state);
      final screenMax = Utils.worldToScreen(Offset(maxX, maxY), state);

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

    // Используем текущую позицию узла (которая могла измениться при resize)
    // вместо сброса к originalNodePosition
    final currentNodePosition = node.aPosition ?? (state.delta + node.position);
    final newPositionDelta = currentNodePosition - state.originalNodePosition;

    // Находим родительский swimlane, если он существует и развернут
    TableNode? parentSwimlane = _findParentExpandedSwimlaneNode(node);
    if (parentSwimlane != null) {
      // Если узел является дочерним для развернутого swimlane,
      // вычисляем его относительную позицию по отношению к родителю
      node.position = currentNodePosition - state.delta - parentSwimlane.position;
    } else {
      // Для обычных узлов (не дочерних развернутого swimlane)
      final newPosition = currentNodePosition - state.delta;
      node.position = newPosition;

      // Если это swimlane с детьми, обновляем относительные позиции детей
      if (node.children != null) {
        for (final child in node.children!) {
          if (child.aPosition != null) {
            // Рассчитываем новую авсолютную позицию, если изменилась позиция родителя
            child.aPosition = child.aPosition! + newPositionDelta;
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

  Future<void> handleEmptyAreaClick() async {
    if (state.isNodeOnTopLayer && state.nodesSelected.isNotEmpty) {
      await _saveNodeToTiles();
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
    final worldPos = Utils.screenToWorld(screenPosition, state);

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
      await handleEmptyAreaClick();
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
    final screenNodePosition = Utils.worldToScreen(nodeWorldPosition, state);

    // Преобразуем мировые координаты клика в экранные
    final screenClickPosition = Utils.worldToScreen(worldPosition, state);

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
      // Очищаем snap-линии
      clearSnapLines();
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

  // Применяет snap-прилипание к позиции узла
  ({Offset position, List<SnapLine> snapLines}) _applySnap(Offset worldPosition) {
    if (state.nodesSelected.isEmpty || state.nodesSelected.first == null) {
      return (position: worldPosition, snapLines: []);
    }

    final selectedNode = state.nodesSelected.first!;
    final nodeSize = selectedNode.size;

    // Границы и центр перемещаемого узла
    final nodeLeft = worldPosition.dx;
    final nodeRight = worldPosition.dx + nodeSize.width;
    final nodeCenterX = worldPosition.dx + nodeSize.width / 2;
    final nodeTop = worldPosition.dy;
    final nodeBottom = worldPosition.dy + nodeSize.height;
    final nodeCenterY = worldPosition.dy + nodeSize.height / 2;

    // Получаем видимые узлы в viewport
    final visibleNodes = _getVisibleNodes();

    // Собираем все snap-точки от видимых узлов
    final snapPointsX = <double>[]; // Вертикальные линии (X координаты)
    final snapPointsY = <double>[]; // Горизонтальные линии (Y координаты)

    for (final node in visibleNodes) {
      if (node.id == selectedNode.id) continue;

      final nodeWorldPos = node.aPosition ?? (state.delta + node.position);
      final left = nodeWorldPos.dx;
      final right = nodeWorldPos.dx + node.size.width;
      final centerX = nodeWorldPos.dx + node.size.width / 2;
      final top = nodeWorldPos.dy;
      final bottom = nodeWorldPos.dy + node.size.height;
      final centerY = nodeWorldPos.dy + node.size.height / 2;

      snapPointsX.addAll([left, right, centerX]);
      snapPointsY.addAll([top, bottom, centerY]);
    }

    // Ищем ближайшие snap-точки
    double newX = worldPosition.dx;
    double newY = worldPosition.dy;
    final snapLines = <SnapLine>[];

    // Проверяем snap по X (вертикальные линии)
    double? bestSnapX;
    double bestSnapDistX = snapThreshold / state.scale;

    for (final snapX in snapPointsX) {
      // Проверяем левую границу
      final distLeft = (nodeLeft - snapX).abs();
      if (distLeft < bestSnapDistX) {
        bestSnapDistX = distLeft;
        bestSnapX = snapX;
        newX = snapX;
      }
      // Проверяем правую границу
      final distRight = (nodeRight - snapX).abs();
      if (distRight < bestSnapDistX) {
        bestSnapDistX = distRight;
        bestSnapX = snapX;
        newX = snapX - nodeSize.width;
      }
      // Проверяем центр
      final distCenter = (nodeCenterX - snapX).abs();
      if (distCenter < bestSnapDistX) {
        bestSnapDistX = distCenter;
        bestSnapX = snapX;
        newX = snapX - nodeSize.width / 2;
      }
    }

    if (bestSnapX != null) {
      final screenX = bestSnapX * state.scale + state.offset.dx;
      snapLines.add(SnapLine(type: SnapLineType.vertical, position: screenX));
    }

    // Проверяем snap по Y (горизонтальные линии)
    double? bestSnapY;
    double bestSnapDistY = snapThreshold / state.scale;

    for (final snapY in snapPointsY) {
      // Проверяем верхнюю границу
      final distTop = (nodeTop - snapY).abs();
      if (distTop < bestSnapDistY) {
        bestSnapDistY = distTop;
        bestSnapY = snapY;
        newY = snapY;
      }
      // Проверяем нижнюю границу
      final distBottom = (nodeBottom - snapY).abs();
      if (distBottom < bestSnapDistY) {
        bestSnapDistY = distBottom;
        bestSnapY = snapY;
        newY = snapY - nodeSize.height;
      }
      // Проверяем центр
      final distCenter = (nodeCenterY - snapY).abs();
      if (distCenter < bestSnapDistY) {
        bestSnapDistY = distCenter;
        bestSnapY = snapY;
        newY = snapY - nodeSize.height / 2;
      }
    }

    if (bestSnapY != null) {
      final screenY = bestSnapY * state.scale + state.offset.dy;
      snapLines.add(SnapLine(type: SnapLineType.horizontal, position: screenY));
    }

    return (position: Offset(newX, newY), snapLines: snapLines);
  }

  // Получает список видимых узлов в viewport
  List<TableNode> _getVisibleNodes() {
    final visibleNodes = <TableNode>[];

    // Вычисляем видимую область в мировых координатах
    final viewportLeft = -state.offset.dx / state.scale;
    final viewportTop = -state.offset.dy / state.scale;
    final viewportRight = viewportLeft + state.viewportSize.width / state.scale;
    final viewportBottom = viewportTop + state.viewportSize.height / state.scale;
    final viewportRect = Rect.fromLTRB(viewportLeft, viewportTop, viewportRight, viewportBottom);

    void checkNodeVisibility(TableNode node, Offset parentOffset) {
      final nodeWorldPos = node.aPosition ?? (parentOffset + node.position);
      final nodeRect = Rect.fromLTWH(nodeWorldPos.dx, nodeWorldPos.dy, node.size.width, node.size.height);

      if (viewportRect.overlaps(nodeRect)) {
        visibleNodes.add(node);
      }

      // Проверяем детей для развернутых swimlane
      if (node.qType == 'swimlane' && !(node.isCollapsed ?? false) && node.children != null) {
        for (final child in node.children!) {
          checkNodeVisibility(child, nodeWorldPos);
        }
      }
    }

    for (final node in state.nodes) {
      checkNodeVisibility(node, state.delta);
    }

    return visibleNodes;
  }

  // Очищает snap-линии
  void clearSnapLines() {
    state.snapLines.clear();
  }

  // Применяет snap-прилипание при изменении размера узла
  ({Offset position, Size size, List<SnapLine> snapLines}) _applySnapForResize(
    Offset worldPosition,
    Size nodeSize,
    String handle,
  ) {
    if (state.nodesSelected.isEmpty || state.nodesSelected.first == null) {
      return (position: worldPosition, size: nodeSize, snapLines: []);
    }

    final selectedNode = state.nodesSelected.first!;

    // Границы изменяемого узла
    final nodeLeft = worldPosition.dx;
    final nodeRight = worldPosition.dx + nodeSize.width;
    final nodeTop = worldPosition.dy;
    final nodeBottom = worldPosition.dy + nodeSize.height;

    // Получаем видимые узлы в viewport
    final visibleNodes = _getVisibleNodes();

    // Собираем все snap-точки от видимых узлов
    final snapPointsX = <double>[];
    final snapPointsY = <double>[];

    for (final node in visibleNodes) {
      if (node.id == selectedNode.id) continue;

      final nodeWorldPos = node.aPosition ?? (state.delta + node.position);
      final left = nodeWorldPos.dx;
      final right = nodeWorldPos.dx + node.size.width;
      final top = nodeWorldPos.dy;
      final bottom = nodeWorldPos.dy + node.size.height;

      snapPointsX.addAll([left, right]);
      snapPointsY.addAll([top, bottom]);
    }

    // Результирующие значения
    double newX = worldPosition.dx;
    double newY = worldPosition.dy;
    double newWidth = nodeSize.width;
    double newHeight = nodeSize.height;
    final snapLines = <SnapLine>[];

    final threshold = snapThreshold / state.scale;

    // Применяем snap в зависимости от того, какой маркер используется
    // Для маркеров, изменяющих левую границу (tl, l, bl)
    if (handle.contains('l')) {
      double? bestSnapX;
      double bestSnapDistX = threshold;

      for (final snapX in snapPointsX) {
        final dist = (nodeLeft - snapX).abs();
        if (dist < bestSnapDistX) {
          bestSnapDistX = dist;
          bestSnapX = snapX;
        }
      }

      if (bestSnapX != null) {
        final widthDiff = nodeLeft - bestSnapX;
        newWidth = nodeSize.width + widthDiff;
        newX = bestSnapX;
        final screenX = bestSnapX * state.scale + state.offset.dx;
        snapLines.add(SnapLine(type: SnapLineType.vertical, position: screenX));
      }
    }

    // Для маркеров, изменяющих правую границу (tr, r, br)
    if (handle.contains('r')) {
      double? bestSnapX;
      double bestSnapDistX = threshold;

      for (final snapX in snapPointsX) {
        final dist = (nodeRight - snapX).abs();
        if (dist < bestSnapDistX) {
          bestSnapDistX = dist;
          bestSnapX = snapX;
        }
      }

      if (bestSnapX != null) {
        newWidth = bestSnapX - worldPosition.dx;
        final screenX = bestSnapX * state.scale + state.offset.dx;
        snapLines.add(SnapLine(type: SnapLineType.vertical, position: screenX));
      }
    }

    // Для маркеров, изменяющих верхнюю границу (tl, t, tr)
    if (handle.contains('t')) {
      double? bestSnapY;
      double bestSnapDistY = threshold;

      for (final snapY in snapPointsY) {
        final dist = (nodeTop - snapY).abs();
        if (dist < bestSnapDistY) {
          bestSnapDistY = dist;
          bestSnapY = snapY;
        }
      }

      if (bestSnapY != null) {
        final heightDiff = nodeTop - bestSnapY;
        newHeight = nodeSize.height + heightDiff;
        newY = bestSnapY;
        final screenY = bestSnapY * state.scale + state.offset.dy;
        snapLines.add(SnapLine(type: SnapLineType.horizontal, position: screenY));
      }
    }

    // Для маркеров, изменяющих нижнюю границу (bl, b, br)
    if (handle.contains('b')) {
      double? bestSnapY;
      double bestSnapDistY = threshold;

      for (final snapY in snapPointsY) {
        final dist = (nodeBottom - snapY).abs();
        if (dist < bestSnapDistY) {
          bestSnapDistY = dist;
          bestSnapY = snapY;
        }
      }

      if (bestSnapY != null) {
        newHeight = bestSnapY - worldPosition.dy;
        final screenY = bestSnapY * state.scale + state.offset.dy;
        snapLines.add(SnapLine(type: SnapLineType.horizontal, position: screenY));
      }
    }

    return (
      position: Offset(newX, newY),
      size: Size(newWidth, newHeight),
      snapLines: snapLines,
    );
  }

  // ============ МЕТОДЫ ДЛЯ ИЗМЕНЕНИЯ РАЗМЕРОВ УЗЛА ============

  /// Начало изменения размера узла
  void startResize(String handle, Offset screenPosition) {
    if (state.nodesSelected.isEmpty) return;

    final node = state.nodesSelected.first!;
    _isResizing = true;
    _resizeHandle = handle;
    _resizeStartPosition = Utils.screenToWorld(screenPosition, state);
    _resizeStartSize = node.size;
    _resizeStartNodePosition = node.aPosition ?? (state.delta + node.position);

    onStateUpdate();
  }

  /// Обновление размера узла при перемещении курсора
  void updateResize(Offset screenPosition) {
    if (!_isResizing || state.nodesSelected.isEmpty || _resizeHandle == null) return;

    final node = state.nodesSelected.first!;
    final currentWorldPos = Utils.screenToWorld(screenPosition, state);
    final delta = currentWorldPos - _resizeStartPosition;

    Size newSize = _resizeStartSize;
    Offset newPosition = _resizeStartNodePosition;

    // Минимальные размеры узла
    const double minWidth = 50.0;
    final double minHeight = node.qType == 'group' ? 80.0 : 30.0;

    switch (_resizeHandle) {
      // Угловые маркеры
      case 'tl': // Top-Left
        newSize = Size(
          (_resizeStartSize.width - delta.dx).clamp(minWidth, double.infinity),
          (_resizeStartSize.height - delta.dy).clamp(minHeight, double.infinity),
        );
        newPosition = Offset(
          _resizeStartNodePosition.dx + (_resizeStartSize.width - newSize.width),
          _resizeStartNodePosition.dy + (_resizeStartSize.height - newSize.height),
        );
        break;
      case 'tr': // Top-Right
        newSize = Size(
          (_resizeStartSize.width + delta.dx).clamp(minWidth, double.infinity),
          (_resizeStartSize.height - delta.dy).clamp(minHeight, double.infinity),
        );
        newPosition = Offset(
          _resizeStartNodePosition.dx,
          _resizeStartNodePosition.dy + (_resizeStartSize.height - newSize.height),
        );
        break;
      case 'bl': // Bottom-Left
        newSize = Size(
          (_resizeStartSize.width - delta.dx).clamp(minWidth, double.infinity),
          (_resizeStartSize.height + delta.dy).clamp(minHeight, double.infinity),
        );
        newPosition = Offset(
          _resizeStartNodePosition.dx + (_resizeStartSize.width - newSize.width),
          _resizeStartNodePosition.dy,
        );
        break;
      case 'br': // Bottom-Right
        newSize = Size(
          (_resizeStartSize.width + delta.dx).clamp(minWidth, double.infinity),
          (_resizeStartSize.height + delta.dy).clamp(minHeight, double.infinity),
        );
        newPosition = _resizeStartNodePosition;
        break;

      // Боковые маркеры
      case 't': // Top
        newSize = Size(_resizeStartSize.width, (_resizeStartSize.height - delta.dy).clamp(minHeight, double.infinity));
        newPosition = Offset(
          _resizeStartNodePosition.dx,
          _resizeStartNodePosition.dy + (_resizeStartSize.height - newSize.height),
        );
        break;
      case 'r': // Right
        newSize = Size((_resizeStartSize.width + delta.dx).clamp(minWidth, double.infinity), _resizeStartSize.height);
        newPosition = _resizeStartNodePosition;
        break;
      case 'b': // Bottom
        newSize = Size(_resizeStartSize.width, (_resizeStartSize.height + delta.dy).clamp(minHeight, double.infinity));
        newPosition = _resizeStartNodePosition;
        break;
      case 'l': // Left
        newSize = Size((_resizeStartSize.width - delta.dx).clamp(minWidth, double.infinity), _resizeStartSize.height);
        newPosition = Offset(
          _resizeStartNodePosition.dx + (_resizeStartSize.width - newSize.width),
          _resizeStartNodePosition.dy,
        );
        break;
    }

    // Применяем snap-прилипание, если включено
    if (state.snapEnabled) {
      final snapResult = _applySnapForResize(newPosition, newSize, _resizeHandle!);
      newPosition = snapResult.position;
      newSize = snapResult.size;
      state.snapLines = snapResult.snapLines;
    } else {
      state.snapLines = [];
    }

    // Проверяем минимальные размеры после snap-прилипания
    if (newSize.width < minWidth) {
      newSize = Size(minWidth, newSize.height);
      // Корректируем позицию для маркеров, изменяющих левую границу
      if (_resizeHandle!.contains('l')) {
        newPosition = Offset(
          _resizeStartNodePosition.dx + (_resizeStartSize.width - minWidth),
          newPosition.dy,
        );
      }
    }
    if (newSize.height < minHeight) {
      newSize = Size(newSize.width, minHeight);
      // Корректируем позицию для маркеров, изменяющих верхнюю границу
      if (_resizeHandle!.contains('t')) {
        newPosition = Offset(
          newPosition.dx,
          _resizeStartNodePosition.dy + (_resizeStartSize.height - minHeight),
        );
      }
    }

    // Обновляем размер и позицию узла
    node.size = newSize;
    node.aPosition = newPosition;
    node.position = newPosition - state.delta;

    if(node.qType == 'group' && node.children != null && node.children!.isNotEmpty){
      for(final child in node.children!){
        child.size = Size(node.size.width - 50, node.size.height - 50);
        child.aPosition = Offset(node.aPosition!.dx + 25, node.aPosition!.dy + 25);
      }
    }
    
    // Обновляем originalNodePosition для корректного расчёта связей
    state.originalNodePosition = newPosition;

    // Обновляем позицию выделенного узла на экране
    final screenNodePosition = Utils.worldToScreen(newPosition, state);
    state.selectedNodeOffset = Offset(
      screenNodePosition.dx - frameTotalOffset,
      screenNodePosition.dy - frameTotalOffset,
    );

    // Обновляем состояние и связи
    onStateUpdate();
    arrowManager.onStateUpdate();
  }

  /// Завершение изменения размера узла
  Future<void> endResize() async {
    if (!_isResizing || state.nodesSelected.isEmpty) return;

    _isResizing = false;
    _resizeHandle = null;
    clearSnapLines();

    onStateUpdate();
  }

  /// Проверяет, идёт ли сейчас изменение размера
  bool get isResizing => _isResizing;

  /// Возвращает текущий наведенный resize handle
  String? get hoveredResizeHandle => _hoveredResizeHandle;

  /// Обновляет состояние наведённого resize handle
  void updateHoveredResizeHandle(Offset position) {
    if (_isResizing) {
      _hoveredResizeHandle = null;
      return;
    }
    
    final handle = getResizeHandleAtPosition(position);
    if (_hoveredResizeHandle != handle) {
      _hoveredResizeHandle = handle;
      onStateUpdate();
    }
  }

  /// Определяет, на каком маркере изменения размера находится курсор
  String? getResizeHandleAtPosition(Offset screenPosition) {
    if (state.nodesSelected.isEmpty) return null;

    final node = state.nodesSelected.first!;
    final scale = state.scale;
    final offset = resizeHandleOffset * scale;
    final length = resizeHandleLength * scale;
    final width = resizeHandleWidth * scale;

    final nodeSize = Size(node.size.width * scale, node.size.height * scale);
    final resizeBoxContainerSize = Size(
      nodeSize.width + offset * 2 + width * 4,
      nodeSize.height + offset * 2 + width * 4,
    );

    // Позиция resize box (совпадает с позиционированием в ResizeHandles)
    final resizeBoxLeft = state.selectedNodeOffset.dx - offset;
    final resizeBoxTop = state.selectedNodeOffset.dy - offset;

    // Локальная позиция относительно resize box
    final localX = screenPosition.dx - resizeBoxLeft;
    final localY = screenPosition.dy - resizeBoxTop;

    // Проверяем угловые маркеры (координаты совпадают с ResizeHandles)
    final corners = {
      'tl': Rect.fromLTWH(0, 0, length, length),
      'tr': Rect.fromLTWH(resizeBoxContainerSize.width - length - width / 2, 0, length, length),
      'bl': Rect.fromLTWH(0, resizeBoxContainerSize.height - length - width / 2, length, length),
      'br': Rect.fromLTWH(
        resizeBoxContainerSize.width - length - width / 2,
        resizeBoxContainerSize.height - length - width / 2,
        length,
        length,
      ),
    };

    for (final entry in corners.entries) {
      if (entry.value.contains(Offset(localX, localY))) {
        return entry.key;
      }
    }

    // Проверяем боковые маркеры (координаты совпадают с ResizeHandles)
    final sides = {
      't': Rect.fromLTWH(
        resizeBoxContainerSize.width / 2 - length / 2,
        0 - width / 2,
        length + width / 2,
        length + width / 2,
      ),
      'r': Rect.fromLTWH(
        resizeBoxContainerSize.width - length - width / 4,
        resizeBoxContainerSize.height / 2 - length / 2,
        length + width / 2,
        length + width / 2,
      ),
      'b': Rect.fromLTWH(
        resizeBoxContainerSize.width / 2 - length / 2,
        resizeBoxContainerSize.height - length - width / 4,
        length + width / 2,
        length + width / 2,
      ),
      'l': Rect.fromLTWH(
        0 - width / 2,
        resizeBoxContainerSize.height / 2 - length / 2,
        length + width / 2,
        length + width / 2,
      ),
    };

    for (final entry in sides.entries) {
      if (entry.value.contains(Offset(localX, localY))) {
        return entry.key;
      }
    }

    return null;
  }

  /// Возвращает курсор для маркера изменения размера
  MouseCursor getResizeCursor(String? handle) {
    if (handle == null) return SystemMouseCursors.basic;

    switch (handle) {
      case 'tl':
      case 'br':
        return SystemMouseCursors.resizeUpLeftDownRight;
      case 'tr':
      case 'bl':
        return SystemMouseCursors.resizeUpRightDownLeft;
      case 't':
      case 'b':
        return SystemMouseCursors.resizeUpDown;
      case 'l':
      case 'r':
        return SystemMouseCursors.resizeLeftRight;
      default:
        return SystemMouseCursors.basic;
    }
  }
}
