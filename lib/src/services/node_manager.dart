import 'dart:math' as math;

import 'package:fbpmn/src/models/attribute_highlight_row.dart';
import 'package:fbpmn/src/models/snap_line.dart';
import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/event_service.dart';
import 'package:fbpmn/src/services/manager.dart';
import 'package:fbpmn/src/services/performance_tracker.dart';
import 'package:fbpmn/src/services/shema_manager.dart';
import 'package:fbpmn/src/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../editor_state.dart';
import '../models/table.node.dart';
import '../services/tile_manager.dart';
import '../utils/editor_config.dart';

class NodeManager extends Manager {
  final EditorState state;
  final TileManager tileManager;
  final ArrowManager arrowManager;
  final ShemaManager schemaManager;

  static const Map<String, double> _arrowIconRotations = {
    'r': 0,
    'l': math.pi,
    't': -math.pi / 2,
    'b': math.pi / 2,
  };

  Offset _nodeDragStart = Offset.zero;
  Offset _nodeStartWorldPosition = Offset.zero;
  // Начальные мировые позиции всех выделенных узлов (для группового перемещения)
  final Map<String, Offset> _multiDragStartPositions = {};

  // Переменные для хранения начальных параметров рамки swimlane
  Rect? _initialSwimlaneBounds;
  EdgeInsets? _initialFramePadding;

  // Переменные для изменения размеров узла
  bool _isResizing = false;
  String? _hoveredResizeHandle;
  Offset _resizeStartPosition = Offset.zero;
  Size _resizeStartSize = Size.zero;
  Offset _resizeStartNodePosition = Offset.zero;

  // Константы для snap-прилипания
  static const double snapThreshold = 15.0; // Порог прилипания в пикселях

  // Константы для рамки выделения (в пикселях)
  double get framePadding => EditorConfig.framePadding * state.scale; // Отступ рамки от узла
  double get frameBorderWidth => EditorConfig.frameBorderWidth * state.scale; // Толщина рамки
  double get frameTotalOffset => framePadding + frameBorderWidth; // Общий отступ для рамки
  double get widthBorderCircle => 1 * state.scale; // граница кружков для создания связей

  // Константы для маркеров изменения размера
  static const double resizeHandleOffset = 14.0; // Отступ маркеров от узла
  static const double resizeHandleWidth = 14.0; // Длина линий маркера
  static const double arrowHandleWidth = 8.0; // Длина линий маркера
  static const double resizeHandleBorderWidth = 2; // Толщина линий маркера

  NodeManager({
    required this.state,
    required this.tileManager,
    required this.arrowManager,
    required this.schemaManager,
  });

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
        final foundNode = getNodeById(node.children!, id);
        if (foundNode != null) {
          return foundNode;
        }
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
    if (state.isNodeDragging && state.nodesIdOnTopLayer.isNotEmpty && state.nodesSelected.isNotEmpty) {
      final screenDelta = screenPosition - _nodeDragStart;
      final worldDelta = screenDelta / state.scale;
      final isMultiSelect = state.nodesSelected.length > 1;

      // Обновляем мировые координаты первого УЗЛА
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

      // При мультивыделении перемещаем все узлы на тот же worldDelta
      if (state.nodesSelected.length > 1) {
        final actualDelta = newWorldPosition - _nodeStartWorldPosition;
        for (final node in state.nodesSelected) {
          if (node == null) continue;
          final startPos = _multiDragStartPositions[node.id];
          if (startPos != null) {
            node.aPosition = startPos + actualDelta;
            // Обновляем позиции детей для group/swimlane
            _updateChildrenPositions(node);
          }
        }
      }

      // Обновляем позицию рамки на основе новой позиции узла
      if (!isMultiSelect) {
        _updateNodePosition();
      }

      onStateUpdate();
      arrowManager.onStateUpdate();
    }
  }

  // Корректировка позиции при изменении масштаба
  void onScaleChanged() {
    if (state.nodesIdOnTopLayer.isNotEmpty && state.nodesSelected.isNotEmpty) {
      _updateNodePosition();
      onStateUpdate();
    }
  }

  // Корректировка позиции при изменении offset
  void onOffsetChanged() {
    if (state.nodesIdOnTopLayer.isNotEmpty && state.nodesSelected.isNotEmpty) {
      _updateNodePosition();
      onStateUpdate();
    }
  }

  /// Создает новый узел из Map и помещает его в центр видимой области
  /// как выделенный узел на верхнем слое.
  Future<void> createNodeFromMap(Map<String, dynamic> nodeMap) async {
    if (state.nodesIdOnTopLayer.isNotEmpty && state.nodesSelected.isNotEmpty) {
      await _saveNodeToTiles();
    }

    final node = TableNode.fromJson(nodeMap);

    final viewportCenterScreen = Offset(state.viewportSize.width / 2, state.viewportSize.height / 2);
    final viewportCenterWorld = Utils.screenToWorld(viewportCenterScreen, state);

    final nodeTopLeftWorld = Offset(
      viewportCenterWorld.dx - node.size.width / 2,
      viewportCenterWorld.dy - node.size.height / 2,
    );

    node.aPosition = nodeTopLeftWorld;
    node.position = nodeTopLeftWorld - state.delta;
    node.isSelected = false;

    // Новый узел сначала добавляется в общую модель,
    // после чего переводится в верхний слой стандартной логикой выделения.
    if (!state.nodes.any((n) => n.id == node.id)) {
      state.nodes.add(node);
      state.nodesSelected.add(node);
    }
      
    await _selectNode(node);
  }

  Future<void> confirmDeleteNode(String nodeId) async {
    print('deleteNode: $nodeId All nodes: ${state.nodes.length}, nodesSelected: ${state.nodesSelected.length} Schema: ${state.schema}');
    final node = getNodeById(state.nodesSelected.toList(), nodeId);
    EventService.apiStatic('confirm_delete_node', 'NodeManager.confirmDeleteNode', {
      'node': node?.toJson(),
      'arrows': state.arrowsSelected.map((arrow) => arrow?.toJson()).toList(),
    });
  }

  Future<void> deleteSelectedNode() async {
    if (state.nodesSelected.isEmpty || state.nodesSelected.first == null) {
      return;
    }

    final node = state.nodesSelected.first!;
    final nodeIdsToDelete = _collectNodeIds(node);
    final nodeId = node.id;

    _deselectAllNodes();
    state.hoveredNode = null;

    _removeNodeFromNodesList(node);
    _removeNodesFromSchema(nodeIdsToDelete);
    state.nodesSelected.clear();
    state.nodesIdOnTopLayer = state.nodesIdOnTopLayer.replaceAll(nodeId, '');

    state.selectedNodeOffset = Offset.zero;
    state.originalNodePosition = Offset.zero;
    state.isNodeDragging = false;

    state.highlightedNodeIds.clear();

    await arrowManager.deleteSelectedArrows();

    arrowManager.compactAllConnections();

    await EventService.apiStatic('schema_update', 'NodeManager.deleteSelectedNode');

    await tileManager.updateTilesAfterNodeChange();

    onStateUpdate();
    arrowManager.onStateUpdate();
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

      _initialFramePadding = state.framePadding;
    }
  }

  Future<void> _selectNodeImmediate(TableNode node, Offset screenPosition) async {
    final tracker = PerformanceTracker();
    tracker.startSelect();

    _deselectAllNodes();
    state.arrowsSelected.clear(); // Очистить выделение связи при выборе узла
    state.hoveredArrow = null;

    node.isSelected = true;
    state.nodesSelected.add(node);

    // Сохраняем мировые координаты ЛЕВОГО ВЕРХНЕГО УГЛА узла
    final worldNodePosition = node.aPosition ?? (state.delta + node.position);
    state.originalNodePosition = worldNodePosition;
    state.nodesSelected.add(node);
    state.nodesIdOnTopLayer += node.id;

    _updateNodePosition();

    // Сначала показываем выделение узла и рамки, затем выполняем тяжёлые операции по тайлам.
    onStateUpdate();

    // Обновляем подсвеченные узлы (связанные с выделенными)
    tileManager.updateHighlightedNodes();

    // Перерисовываем тайлы с подсвеченными узлами
    await tileManager.updateTilesAfterNodeChange();

    // Затем удаляем узел из тайлов и ЖДЕМ завершения
    await tileManager.removeSelectedNodeFromTiles(node);

    // Выделяем стрелки после тяжелой подготовки тайлов, чтобы не было
    // ситуации «сначала стрелки, потом узел».
    arrowManager.selectAllArrows();

    startNodeDrag(screenPosition);

    tracker.endSelect();

    onStateUpdate();
  }

  Future<void> _selectNode(TableNode node) async {
    final tracker = PerformanceTracker();
    tracker.startSelect();

    _deselectAllNodes();
    state.arrowsSelected.clear();
    state.hoveredArrow = null;

    node.isSelected = true;
    state.nodesSelected.add(node);

    final worldNodePosition = node.aPosition ?? (state.delta + node.position);
    state.originalNodePosition = worldNodePosition;

    state.nodesIdOnTopLayer += node.id;

    _updateNodePosition();

    // Сначала показываем выделение узла и рамки, затем выполняем тяжёлые операции по тайлам.
    onStateUpdate();

    // Обновляем подсвеченные узлы (связанные с выделенными)
    tileManager.updateHighlightedNodes();

    // Перерисовываем тайлы с подсвеченными узлами
    await tileManager.updateTilesAfterNodeChange();

    await _prepareNodeForTopLayer(node);

    // Выделяем стрелки после завершения тяжелой работы.
    arrowManager.selectAllArrows();

    tracker.endSelect();

    onStateUpdate();
  }

  /// Добавление узла в существующее выделение (Ctrl+клик)
  Future<void> _addNodeToSelection(TableNode node, {bool deferHeavyUpdate = false}) async {
    // Проверяем, не выделен ли уже этот узел
    if (state.nodesSelected.any((n) => n?.id == node.id)) return;

    state.arrowsSelected.clear();
    state.hoveredArrow = null;

    node.isSelected = true;
    state.nodesSelected.add(node);
    state.nodesIdOnTopLayer += node.id;

    if (deferHeavyUpdate) return;

    // Обновляем подсвеченные узлы (связанные с выделенными)
    tileManager.updateHighlightedNodes();

    // Сначала показываем обновлённое выделение узлов.
    onStateUpdate();

    // Перерисовываем тайлы с подсвеченными узлами
    await tileManager.updateTilesAfterNodeChange();

    await _prepareNodeForTopLayer(node);

    arrowManager.selectAllArrows();

    onStateUpdate();
  }

  /// Подготовка узла для перемещения на верхний слой
  Future<void> _prepareNodeForTopLayer(TableNode node) async {
    // Для swimlane в развернутом состоянии удаляем всех детей из тайлов
    if (node.qType == 'swimlane' && !(node.isCollapsed ?? false)) {
      // Сохраняем абсолютные позиции детей перед удалением
      if (node.children != null) {
        for (final child in node.children!) {
          child.aPosition ??= state.delta + node.position + child.position;
        }
      }
      final tilesToUpdate = <String>{};
      await tileManager.removeSwimlaneChildrenFromTiles(node, tilesToUpdate);
      // Обновляем все затронутые тайлы
      for (final tileId in tilesToUpdate) {
        await tileManager.updateTileWithAllContent(state.imageTiles[tileId]!);
      }
    }

    // Удаляем узел из тайлов
    await tileManager.removeSelectedNodesFromTiles(state.nodesSelected);

    // Удаляем узел из state.nodes только после завершения обновления тайлов
    _removeNodeFromNodesList(node);
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
    if (state.nodesIdOnTopLayer.isEmpty || state.nodesSelected.isEmpty) {
      return;
    }

    final tracker = PerformanceTracker();
    tracker.startDeselect();

    final selectedNodes = state.nodesSelected.whereType<TableNode>().toList();

    // Обрабатываем все выделенные узлы
    for (final node in state.nodesSelected) {
      if (node == null) continue;

      _saveOneNodeBack(node);
    }

    _syncNodesToSchema(selectedNodes);
    await EventService.apiStatic('schema_update', 'NodeManager._saveNodeToTiles');

    // Очищаем подсветку ПЕРЕД перерисовкой тайлов
    state.highlightedNodeIds.clear();

    state.isNodeDragging = false;
    state.nodesIdOnTopLayer = '';
    state.nodesSelected.clear();
    state.arrowsSelected.clear();
    state.selectedNodeOffset = Offset.zero;
    state.originalNodePosition = Offset.zero;

    await tileManager.updateTilesAfterNodeChange();

    // Пересчитываем абсолютные позиции для всех узлов
    for (final node in state.nodes) {
      node.initializeAbsolutePositions(state.delta);
    }

    tracker.endDeselect();

    onStateUpdate();
    arrowManager.onStateUpdate();
  }

  Future<void> commitNodeSelectionBeforeArrowSelection() async {
    if (state.nodesIdOnTopLayer.isNotEmpty && state.nodesSelected.isNotEmpty) {
      await _saveNodeToTiles();
      return;
    }

    final shouldRedrawTiles =
        state.selectAndHide ||
        state.highlightedNodeIds.isNotEmpty ||
        state.nodesSelected.isNotEmpty;

    _deselectAllNodes();
    state.nodesSelected.clear();
    state.nodesIdOnTopLayer = '';
    state.selectedNodeOffset = Offset.zero;
    state.originalNodePosition = Offset.zero;
    state.isNodeDragging = false;
    state.hoveredNode = null;

    if (state.highlightedNodeIds.isNotEmpty) {
      state.highlightedNodeIds.clear();
    }

    if (shouldRedrawTiles) {
      await tileManager.updateTilesAfterNodeChange();
    }

    onStateUpdate();
    arrowManager.onStateUpdate();
  }

  /// Возвращает один узел обратно в state.nodes и тайлы
  void _saveOneNodeBack(TableNode node) {
    final currentNodePosition = node.aPosition ?? (state.delta + node.position);

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
            // Рассчитываем относительные координаты ребенка из абсолютных,
            // вычитая delta и позицию родителя
            child.position = child.aPosition! - state.delta - node.position;
          }
        }
      }
    }

    // Добавляем узел обратно в основной список узлов
    _addNodeBackToNodesList(node);

    node.isSelected = false;

    // Снимаем выделение с детей swimlane
    if (node.qType == 'swimlane' && node.children != null) {
      for (final child in node.children!) {
        child.isSelected = false;
      }
    }
  }

  void _syncNodesToSchema(List<TableNode> nodes) {
    if (nodes.isEmpty) {
      return;
    }

    final schema = Map<String, dynamic>.from(state.schema);
    final objects = List<dynamic>.from(schema['objects'] as List<dynamic>? ?? const []);

    for (final node in nodes) {
      final nodeJson = node.toJson();
      final nodeId = nodeJson['id']?.toString() ?? node.id;
      final existingIndex = objects.indexWhere((item) => item is Map && item['id']?.toString() == nodeId);

      if (existingIndex >= 0) {
        objects[existingIndex] = nodeJson;
      } else {
        objects.add(nodeJson);
      }
    }

    final metadata = Map<String, dynamic>.from(schema['metadata'] as Map<String, dynamic>? ?? const {});
    metadata['dx'] = state.delta.dx;
    metadata['dy'] = state.delta.dy;
    metadata['objects'] = objects.length;

    schema['objects'] = objects;
    schema['metadata'] = metadata;
    state.schema = schema;
  }

  List<String> _collectNodeIds(TableNode node) {
    final ids = <String>[node.id];

    if (node.children != null && node.children!.isNotEmpty) {
      for (final child in node.children!) {
        ids.addAll(_collectNodeIds(child));
      }
    }

    return ids;
  }

  void _removeNodesFromSchema(List<String> nodeIds) {
    if (nodeIds.isEmpty) {
      return;
    }

    final schema = Map<String, dynamic>.from(state.schema);
    final objects = List<dynamic>.from(schema['objects'] as List<dynamic>? ?? const []);

    objects.removeWhere((item) => item is Map && nodeIds.contains(item['id']?.toString()));

    final metadata = Map<String, dynamic>.from(schema['metadata'] as Map<String, dynamic>? ?? const {});
    metadata['dx'] = state.delta.dx;
    metadata['dy'] = state.delta.dy;
    metadata['objects'] = objects.length;

    schema['objects'] = objects;
    schema['metadata'] = metadata;
    state.schema = schema;
  }

  // Метод для поиска родителя swimlane
  TableNode? _findParentExpandedSwimlaneNode(TableNode node) {
    return state.nodes.firstWhereOrNull((n) => n.id == node.parent);
  }

  TableNode? _findTopGroupAncestor(TableNode node) {
    TableNode? currentGroup = node.qType == 'group' ? node : null;
    String? parentId = node.parent;

    while (parentId != null) {
      final parentNode = getNodeById(state.nodes, parentId);
      if (parentNode == null) {
        break;
      }

      if (parentNode.qType == 'group') {
        currentGroup = parentNode;
      }

      parentId = parentNode.parent;
    }

    return currentGroup;
  }

  Future<void> handleEmptyAreaClick() async {
    if (isResizing) {
      return;
    }
    if (state.arrowCreated != null) {
      if (state.ignoreNextCreatedArrowCancel) {
        state.ignoreNextCreatedArrowCancel = false;
        return;
      }
      arrowManager.clearStartCreatedArrow();
      onStateUpdate();
      return;
    }
    if (state.nodesIdOnTopLayer.isNotEmpty && state.nodesSelected.isNotEmpty) {
      await _saveNodeToTiles();
    } else {
      final shouldRedrawTiles =
          state.selectAndHide ||
          state.highlightedNodeIds.isNotEmpty ||
          state.nodesSelected.isNotEmpty ||
          state.arrowsSelected.isNotEmpty;

      _deselectAllNodes();
      state.nodesSelected.clear();
      state.arrowsSelected.clear();
      state.hoveredArrow = null;

      // await EventService.apiStatic('schema_update', 'NodeManager.handleEmptyAreaClick');

      // Очищаем подсветку и перерисовываем тайлы
      if (state.highlightedNodeIds.isNotEmpty) {
        state.highlightedNodeIds.clear();
      }

      if (shouldRedrawTiles) {
        await tileManager.updateTilesAfterNodeChange();
      }

      state.nodesIdOnTopLayer = '';
      state.selectedNodeOffset = Offset.zero;
      state.originalNodePosition = Offset.zero;
      onStateUpdate();
      arrowManager.onStateUpdate();
    }
  }

  void startAreaSelection(Offset screenPosition) {
    state.isAreaSelecting = true;
    state.selectionStart = screenPosition;
    state.selectionCurrent = screenPosition;
    onStateUpdate();
  }

  void updateAreaSelection(Offset screenPosition) {
    if (!state.isAreaSelecting) {
      return;
    }

    state.selectionCurrent = screenPosition;
    onStateUpdate();
  }

  Future<void> endAreaSelection() async {
    if (!state.isAreaSelecting) {
      return;
    }

    final selectionRect = Rect.fromPoints(state.selectionStart, state.selectionCurrent);

    state.isAreaSelecting = false;
    state.selectionStart = Offset.zero;
    state.selectionCurrent = Offset.zero;

    if (selectionRect.width < 2 && selectionRect.height < 2) {
      await handleEmptyAreaClick();
      return;
    }

    await selectNodesInArea(selectionRect);
  }

  Future<void> cancelAreaSelection() async {
    if (!state.isAreaSelecting) {
      return;
    }

    state.isAreaSelecting = false;
    state.selectionStart = Offset.zero;
    state.selectionCurrent = Offset.zero;
    onStateUpdate();
  }

  Future<void> selectNodesInArea(Rect screenSelectionRect) async {
    final worldTopLeft = Utils.screenToWorld(screenSelectionRect.topLeft, state);
    final worldBottomRight = Utils.screenToWorld(screenSelectionRect.bottomRight, state);
    final worldSelectionRect = Rect.fromPoints(worldTopLeft, worldBottomRight);
    final allNodes = <TableNode>[];

    void collectSelectableNodes(List<TableNode> nodes) {
      for (final node in nodes) {
        allNodes.add(node);

        if (node.children == null || node.children!.isEmpty) {
          continue;
        }

        if (node.qType == 'swimlane' && (node.isCollapsed ?? false)) {
          continue;
        }

        collectSelectableNodes(node.children!);
      }
    }

    collectSelectableNodes(state.nodes);
    final selectedNodesById = <String, TableNode>{};

    for (final node in allNodes) {
      final nodePosition = node.aPosition ?? (state.delta + node.position);
      final nodeRect = Rect.fromLTWH(
        nodePosition.dx,
        nodePosition.dy,
        node.size.width,
        node.size.height,
      );
      if (nodeRect.overlaps(worldSelectionRect)) {
        final groupNode = _findTopGroupAncestor(node);
        if (groupNode != null) {
          selectedNodesById[groupNode.id] = groupNode;
          continue;
        }

        selectedNodesById[node.id] = node;
      }
    }

    final selectedNodes = selectedNodesById.values.toList();

    if (state.nodesIdOnTopLayer.isNotEmpty && state.nodesSelected.isNotEmpty) {
      await _saveNodeToTiles();
    } else {
      _deselectAllNodes();
      state.nodesSelected.clear();
      state.arrowsSelected.clear();
      state.hoveredArrow = null;
      state.nodesIdOnTopLayer = '';
      state.selectedNodeOffset = Offset.zero;
      state.originalNodePosition = Offset.zero;
      state.isNodeDragging = false;
      state.highlightedNodeIds.clear();
    }

    if (selectedNodes.isEmpty) {
      await tileManager.updateTilesAfterNodeChange();
      onStateUpdate();
      arrowManager.onStateUpdate();
      return;
    }

    for (final node in selectedNodes) {
      await _addNodeToSelection(node, deferHeavyUpdate: true);
    }

    if (selectedNodes.length == 1) {
      final selectedNode = selectedNodes.first;
      state.originalNodePosition = selectedNode.aPosition ?? (state.delta + selectedNode.position);
      _updateNodePosition();
    } else {
      final boundsResult = Utils.getNodesWorldBounds(state.nodesSelected.toList(), state.delta);
      if (boundsResult != null) {
        state.originalNodePosition = boundsResult.worldBounds.topLeft;
      }
    }

    tileManager.updateHighlightedNodes();
    onStateUpdate();

    await tileManager.updateTilesAfterNodeChange();

    for (final node in selectedNodes) {
      await _prepareNodeForTopLayer(node);
    }

    arrowManager.selectAllArrows();

    onStateUpdate();
  }

  Future<void> selectNodeAtPosition(Offset screenPosition, {bool immediateDrag = false}) async {
    final worldPos = Utils.screenToWorld(screenPosition, state);

    final nodeHit = findNodeAtWorldPosition(worldPos);
    if (nodeHit == null) {
      await handleEmptyAreaClick();
      return;
    }

    final foundNode = nodeHit.node;
    final foundNodeWorldPosition = nodeHit.worldPosition;

    // Проверяем клик по иконке swimlane
    if (foundNode.qType == 'swimlane' && _isSwimlaneIconClicked(foundNode, worldPos, foundNodeWorldPosition)) {
      await _toggleSwimlaneCollapsed(foundNode);
      return;
    }

    // Ctrl+клик — добавляем узел в существующее выделение
    if (state.isCtrlPressed && state.nodesSelected.isNotEmpty) {
      await _addNodeToSelection(foundNode);
      return;
    }

    if (state.nodesIdOnTopLayer.isNotEmpty && state.nodesSelected.isNotEmpty) {
      if (state.nodesSelected.any((n) => n?.id == foundNode.id)) {
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
  }

  ({TableNode node, Offset worldPosition})? findNodeAtWorldPosition(Offset worldPos) {
    final tile = tileManager.getTileAtWorldPosition(worldPos);
    if (tile == null) {
      return null;
    }

    final nodeIdsInTile = Set<String>.from(tile.nodes);
    final nodesInTile = _collectNodesByIds(state.nodes, nodeIdsInTile);

    for (int i = 0; i < nodesInTile.length; i++) {
      final node = nodesInTile[i];

      if (state.nodesIdOnTopLayer.isNotEmpty &&
          state.nodesSelected.isNotEmpty &&
          state.nodesSelected.first?.id == node.id) {
        continue;
      }

      final nodeWorldPos = node.aPosition ?? (state.delta + node.position);
      final nodeRect = Rect.fromLTWH(nodeWorldPos.dx, nodeWorldPos.dy, node.size.width, node.size.height);

      if (nodeRect.contains(worldPos)) {
        return (node: node, worldPosition: nodeWorldPos);
      }

      if (node.qType == 'swimlane' && !(node.isCollapsed ?? false) && node.children != null) {
        for (int j = node.children!.length - 1; j >= 0; j--) {
          final child = node.children![j];
          if (!nodeIdsInTile.contains(child.id)) continue;

          final childWorldPos = child.aPosition ?? (nodeWorldPos + child.position);
          final childRect = Rect.fromLTWH(childWorldPos.dx, childWorldPos.dy, child.size.width, child.size.height);

          if (childRect.contains(worldPos)) {
            return (node: child, worldPosition: childWorldPos);
          }
        }
      }
    }

    return null;
  }

  List<TableNode> _collectNodesByIds(List<TableNode> nodes, Set<String> nodeIds) {
    final result = <TableNode>[];

    void traverse(List<TableNode> nodeList) {
      for (final node in nodeList) {
        if (nodeIds.contains(node.id)) {
          result.add(node);
        }

        if (node.children != null && node.children!.isNotEmpty) {
          traverse(node.children!);
        }
      }
    }

    traverse(nodes);
    return result;
  }

  // Метод для переключения состояния swimlane
  // TODO: УДАЛИТЬ замер времени после отладки производительности
  Future<void> _toggleSwimlaneCollapsed(TableNode swimlaneNode) async {
    final tracker = PerformanceTracker();
    tracker.startSwimlaneToggle();

    state.toggleSwimlaneNode = swimlaneNode;

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
      final tilesToUpdate = <String>{};
      await tileManager.removeSwimlaneChildrenFromTiles(swimlaneNode, tilesToUpdate);
      // Обновляем все затронутые тайлы
      for (final tileId in tilesToUpdate) {
        await tileManager.updateTileWithAllContent(state.imageTiles[tileId]!);
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
    await tileManager.updateTilesAfterNodeChange(isToggleSwimlane: true);

    // Пересчитываем абсолютные позиции для всех узлов
    for (final node in state.nodes) {
      node.initializeAbsolutePositions(state.delta);
    }

    tracker.endSwimlaneToggle();

    onStateUpdate();
  }

  /// Публичный метод для сворачивания swimlane узла
  /// Используется ColaLayoutService перед запуском раскладки
  Future<void> collapseSwimlane(TableNode swimlaneNode) async {
    // Проверяем, что узел — развернутый swimlane
    if (swimlaneNode.qType != 'swimlane' || (swimlaneNode.isCollapsed ?? false)) {
      return;
    }

    // Создаем копию узла со свернутым состоянием
    final collapsedNode = swimlaneNode.toggleCollapsed();

    // Обновляем узел в списке узлов
    _updateNodeInList(collapsedNode);

    // Удаляем детей из тайлов
    final tilesToUpdate = <String>{};
    await tileManager.removeSwimlaneChildrenFromTiles(swimlaneNode, tilesToUpdate);
    // Обновляем все затронутые тайлы
    for (final tileId in tilesToUpdate) {
      await tileManager.updateTileWithAllContent(state.imageTiles[tileId]!);
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
    if (state.nodesIdOnTopLayer.isNotEmpty && state.nodesSelected.isNotEmpty) {
      _nodeDragStart = screenPosition;
      _nodeStartWorldPosition = state.originalNodePosition;

      // Сохраняем начальные мировые позиции всех выделенных узлов
      _multiDragStartPositions.clear();
      for (final node in state.nodesSelected) {
        if (node == null) continue;
        _multiDragStartPositions[node.id] = node.aPosition ?? (state.delta + node.position);
      }

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

  /// Обновляет aPosition детей узла на основе его текущей aPosition
  void _updateChildrenPositions(TableNode node) {
    if (node.children == null || node.children!.isEmpty) return;
    final parentPos = node.aPosition;
    if (parentPos == null) return;

    for (final child in node.children!) {
      // child.position — относительная позиция внутри родителя
      child.aPosition = parentPos + child.position;
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

  /// Выделяет все узлы для автораскладки Cola
  /// Возвращает список только родительских узлов (из state.nodes)
  /// Вложенные узлы добавляются в nodesSelected для отображения, но не возвращаются
  Future<List<TableNode>> selectAllNodesForLayout() async {
    // Снимаем текущее выделение если есть
    if (state.nodesSelected.isNotEmpty) {
      await handleEmptyAreaClick();
    }

    final parentNodes = <TableNode>[];

    // Собираем только родительские узлы для Cola
    // Вложенные узлы добавляем в nodesSelected для отображения
    for (final node in state.nodes) {
      parentNodes.add(node);
      node.isSelected = true;
      state.nodesSelected.add(node);
      state.nodesIdOnTopLayer += node.id;
    }

    onStateUpdate();

    return parentNodes;
  }

  /// Обновляет позицию узла программно (для Cola layout)
  /// Принимает мировые координаты нового положения узла
  void updateNodePositionForLayout(TableNode node, Offset newWorldPosition) {
    node.aPosition = newWorldPosition;
    node.position = newWorldPosition - state.delta;

    // Обновляем позиции детей для group/swimlane
    _updateChildrenPositions(node);
  }

  /// Сохраняет все узлы обратно в тайлы после автораскладки
  Future<void> saveAllNodesAfterLayout() async {
    // Обновляем относительные позиции узлов
    for (final node in state.nodesSelected) {
      if (node == null) continue;
      if (node.aPosition != null) {
        node.position = node.aPosition! - state.delta;
      }
      node.isSelected = false;
    }

    _syncNodesToSchema(state.nodes);

    // Очищаем выделение
    state.nodesSelected.clear();
    state.arrowsSelected.clear();
    state.nodesIdOnTopLayer = '';
    state.selectedNodeOffset = Offset.zero;
    state.originalNodePosition = Offset.zero;

    // Пересоздаем тайлы
    await tileManager.createTiledImage(state.nodes, state.arrows);

    // НЕ пересчитываем абсолютные позиции здесь, так как
    // calculateCanvasSizeFromNodes уже это сделал (и мог изменить delta)

    onStateUpdate();
    arrowManager.onStateUpdate();
  }

  // Применяет snap-прилипание к позиции узла
  ({Offset position, List<SnapLine> snapLines}) _applySnap(Offset worldPosition) {
    if (state.nodesSelected.isEmpty || state.nodesSelected.first == null) {
      return (position: worldPosition, snapLines: []);
    }

    // ID всех выделенных узлов — исключаем из snap-точек
    final selectedIds = <String>{};
    for (final n in state.nodesSelected) {
      if (n != null) selectedIds.add(n.id);
    }

    // Получаем видимые узлы в viewport (исключая все выделенные)
    final visibleNodes = _getVisibleNodes();

    // Собираем все snap-точки от видимых невыделенных узлов
    final snapPointsX = <double>[];
    final snapPointsY = <double>[];

    for (final node in visibleNodes) {
      if (selectedIds.contains(node.id)) continue;

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

    // Вычисляем worldDelta из общей стартовой точки drag
    final worldDelta = worldPosition - _nodeStartWorldPosition;

    // Ищем ближайшие snap-точки среди ВСЕХ выделенных узлов
    double correctionX = 0;
    double correctionY = 0;
    double? bestSnapX;
    double bestSnapDistX = snapThreshold / state.scale;
    double? bestSnapY;
    double bestSnapDistY = snapThreshold / state.scale;

    for (final selected in state.nodesSelected) {
      if (selected == null) continue;

      // Предполагаемая позиция этого узла после перемещения
      final startPos = _multiDragStartPositions[selected.id];
      if (startPos == null) continue;
      final movedPos = startPos + worldDelta;
      final nodeSize = selected.size;

      final nodeLeft = movedPos.dx;
      final nodeRight = movedPos.dx + nodeSize.width;
      final nodeCenterX = movedPos.dx + nodeSize.width / 2;
      final nodeTop = movedPos.dy;
      final nodeBottom = movedPos.dy + nodeSize.height;
      final nodeCenterY = movedPos.dy + nodeSize.height / 2;

      // Проверяем snap по X
      for (final snapX in snapPointsX) {
        final distLeft = (nodeLeft - snapX).abs();
        if (distLeft < bestSnapDistX) {
          bestSnapDistX = distLeft;
          bestSnapX = snapX;
          correctionX = snapX - nodeLeft;
        }
        final distRight = (nodeRight - snapX).abs();
        if (distRight < bestSnapDistX) {
          bestSnapDistX = distRight;
          bestSnapX = snapX;
          correctionX = snapX - nodeRight;
        }
        final distCenter = (nodeCenterX - snapX).abs();
        if (distCenter < bestSnapDistX) {
          bestSnapDistX = distCenter;
          bestSnapX = snapX;
          correctionX = snapX - nodeCenterX;
        }
      }

      // Проверяем snap по Y
      for (final snapY in snapPointsY) {
        final distTop = (nodeTop - snapY).abs();
        if (distTop < bestSnapDistY) {
          bestSnapDistY = distTop;
          bestSnapY = snapY;
          correctionY = snapY - nodeTop;
        }
        final distBottom = (nodeBottom - snapY).abs();
        if (distBottom < bestSnapDistY) {
          bestSnapDistY = distBottom;
          bestSnapY = snapY;
          correctionY = snapY - nodeBottom;
        }
        final distCenter = (nodeCenterY - snapY).abs();
        if (distCenter < bestSnapDistY) {
          bestSnapDistY = distCenter;
          bestSnapY = snapY;
          correctionY = snapY - nodeCenterY;
        }
      }
    }

    final snapLines = <SnapLine>[];

    if (bestSnapX != null) {
      final screenX = bestSnapX * state.scale + state.offset.dx;
      snapLines.add(SnapLine(type: SnapLineType.vertical, position: screenX));
    }

    if (bestSnapY != null) {
      final screenY = bestSnapY * state.scale + state.offset.dy;
      snapLines.add(SnapLine(type: SnapLineType.horizontal, position: screenY));
    }

    // Корректируем позицию первого узла
    final newX = worldPosition.dx + correctionX;
    final newY = worldPosition.dy + correctionY;

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
  ({Offset position, Size size, List<SnapLine> snapLines}) _applySnapForResize(Offset worldPosition, Size nodeSize) {
    if (state.nodesSelected.isEmpty || state.nodesSelected.first == null) {
      return (position: worldPosition, size: nodeSize, snapLines: []);
    }

    final selectedNode = state.nodesSelected.first!;

    // Границы изменяемого узла
    final nodeRight = worldPosition.dx + nodeSize.width;
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

    // Для маркеров, изменяющих правую границу (tr, r, br)
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

    // Для маркеров, изменяющих нижнюю границу (bl, b, br)
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

    return (position: Offset(newX, newY), size: Size(newWidth, newHeight), snapLines: snapLines);
  }

  // ============ МЕТОДЫ ДЛЯ ИЗМЕНЕНИЯ РАЗМЕРОВ УЗЛА ============

  /// Начало изменения размера узла
  void startResize(Offset screenPosition) {
    if (state.nodesSelected.isEmpty) return;

    final node = state.nodesSelected.first!;
    _isResizing = true;
    _resizeStartPosition = Utils.screenToWorld(screenPosition, state);
    _resizeStartSize = node.size;
    _resizeStartNodePosition = node.aPosition ?? (state.delta + node.position);

    onStateUpdate();
  }

  /// Обновление размера узла при перемещении курсора
  void updateResize(Offset screenPosition) {
    if (!_isResizing || state.nodesSelected.isEmpty) return;

    final node = state.nodesSelected.first!;
    final currentWorldPos = Utils.screenToWorld(screenPosition, state);
    final delta = currentWorldPos - _resizeStartPosition;

    Size newSize = _resizeStartSize;
    Offset newPosition = _resizeStartNodePosition;

    // Минимальные размеры узла
    const double minWidth = 80.0;
    final double minHeight = node.qType == 'group' ? 80.0 : 30.0;

    newSize = Size(
      (_resizeStartSize.width + delta.dx).clamp(minWidth, double.infinity),
      (_resizeStartSize.height + delta.dy).clamp(minHeight, double.infinity),
    );
    newPosition = _resizeStartNodePosition;

    // Применяем snap-прилипание, если включено
    if (state.snapEnabled) {
      final snapResult = _applySnapForResize(newPosition, newSize);
      newPosition = snapResult.position;
      newSize = snapResult.size;
      state.snapLines = snapResult.snapLines;
    } else {
      state.snapLines = [];
    }

    // Обновляем размер и позицию узла
    node.size = newSize;
    node.aPosition = newPosition;
    node.position = newPosition - state.delta;

    if (node.qType == 'group' && node.children != null && node.children!.isNotEmpty) {
      for (final child in node.children!) {
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

  void onHover(Offset localPosition) {
    final worldPos = Utils.screenToWorld(localPosition, state);
    final foundNode = findNodeAtWorldPosition(worldPos);
    final selectedNode = state.nodesSelected.isNotEmpty ? state.nodesSelected.first : null;
    TableNode? nextHoveredNode = foundNode?.node;

    if (state.arrowCreated != null && state.hoveredNode?.aPosition != null) {
      final hoveredNode = state.hoveredNode!;
      final scale = state.scale;
      final offset = resizeHandleOffset * scale;
      final frame = frameTotalOffset;
      final hoverPadding = arrowHandleWidth * scale * 3 / 2;
      final currentOverlayRect = Rect.fromLTWH(
        hoveredNode.aPosition!.dx * scale + state.offset.dx - offset - frame - hoverPadding,
        hoveredNode.aPosition!.dy * scale + state.offset.dy - offset - frame - hoverPadding,
        hoveredNode.size.width * scale + offset * 2 + frame * 2 + hoverPadding * 2,
        hoveredNode.size.height * scale + offset * 2 + frame * 2 + hoverPadding * 2,
      );

      if (currentOverlayRect.contains(localPosition)) {
        nextHoveredNode = hoveredNode;
      }
    }

    if (state.arrowCreated != null && nextHoveredNode == null) {
      final scale = state.scale;
      final offset = resizeHandleOffset * scale;
      final frame = frameTotalOffset;
      final hoverPadding = arrowHandleWidth * scale * 3 / 2;
      final allNodes = whereAllNodes(state.nodes, (_) => true).whereType<TableNode>().toList();

      for (int i = allNodes.length - 1; i >= 0; i--) {
        final node = allNodes[i];
        if (node.id == selectedNode?.id || node.aPosition == null) {
          continue;
        }

        final overlayRect = Rect.fromLTWH(
          node.aPosition!.dx * scale + state.offset.dx - offset - frame - hoverPadding,
          node.aPosition!.dy * scale + state.offset.dy - offset - frame - hoverPadding,
          node.size.width * scale + offset * 2 + frame * 2 + hoverPadding * 2,
          node.size.height * scale + offset * 2 + frame * 2 + hoverPadding * 2,
        );

        if (overlayRect.contains(localPosition)) {
          nextHoveredNode = node;
          break;
        }
      }
    }

    // Не показываем ховер над выделенным узлом
    if (nextHoveredNode?.id == selectedNode?.id) {
      if (state.hoveredNode != null) {
        state.hoveredNode = null;
        onStateUpdate();
      }
    }
    // Для остальных узлов показываем ховер
    else if (state.hoveredNode?.id != nextHoveredNode?.id) {
      state.hoveredNode = nextHoveredNode;
      onStateUpdate();
    }
  }

  void clearHoveredNode() {
    if (state.hoveredNode != null) {
      state.hoveredNode = null;
      onStateUpdate();
    }
  }

  /// Определяет, на каком маркере изменения размера находится курсор
  String? getResizeHandleAtPosition(Offset screenPosition) {
    if (state.nodesSelected.isEmpty) return null;

    final node = state.nodesSelected.first!;
    final scale = state.scale;
    final offset = resizeHandleOffset * scale;
    final length = resizeHandleWidth * scale;
    final width = resizeHandleBorderWidth * scale;

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

  /// Создаёт боковой маркер для создания связей узел->
  Widget buildSideHandle(
    String handle,
    double left,
    double top,
    double length,
    double width,
    Map isHovered, {
    String? sourceId,
    MouseCursor? cursor,
    dynamic setState,
  }) {
    final isHoveredHandle = isHovered[handle] ?? false;
    final hoverAreaSize = length * 3;
    final createdArrowSourceId = state.arrowCreated?.source;
    final selectedNode = state.nodesSelected.isNotEmpty ? state.nodesSelected.first : null;
    final effectiveSourceId = sourceId ?? selectedNode?.id;
    final isSelectedNodeHandleDisabled = createdArrowSourceId != null && effectiveSourceId == createdArrowSourceId;

    return Positioned(
      left: left - (hoverAreaSize - length) / 2,
      top: top - (hoverAreaSize - length) / 2,
      width: hoverAreaSize,
      height: hoverAreaSize,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        cursor: isSelectedNodeHandleDisabled ? SystemMouseCursors.basic : (cursor ?? SystemMouseCursors.resizeUpDown),
        onEnter: isSelectedNodeHandleDisabled
            ? null
            : (_) {
                if (setState != null) {
                  setState(() {
                    isHovered[handle] = true;
                  });
                }
              },
        onHover: isSelectedNodeHandleDisabled
            ? null
            : (_) {
                if (setState != null && isHovered[handle] != true) {
                  setState(() {
                    isHovered[handle] = true;
                  });
                }
              },
        onExit: isSelectedNodeHandleDisabled
            ? null
            : (_) {
                if (setState != null) {
                  setState(() {
                    isHovered[handle] = false;
                  });
                }
              },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: effectiveSourceId == null || isSelectedNodeHandleDisabled
              ? null
              : () async {
                  await arrowManager.startCreateArrowFromMap({'source': effectiveSourceId}, handle);
                },
          child: isSelectedNodeHandleDisabled
              ? Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: length,
                    height: length,
                    alignment: Alignment.center,
                    child: AnimatedScale(
                      scale: !isSelectedNodeHandleDisabled && isHoveredHandle ? 3.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: length,
                        height: length,
                        decoration: BoxDecoration(
                          color: !isSelectedNodeHandleDisabled && isHoveredHandle ? Colors.blue : Colors.blue.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: widthBorderCircle),
                        ),
                        child: !isSelectedNodeHandleDisabled && isHoveredHandle
                            ? Center(child: _buildConnectionArrowIcon(handle, length))
                            : null,
                      ),
                    ),
                  ),
                )
              : Tooltip(
                  message: 'Создать связь объекта',
                  ignorePointer: true,
                  exitDuration: const Duration(milliseconds: 10),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      width: length,
                      height: length,
                      alignment: Alignment.center,
                      child: AnimatedScale(
                        scale: !isSelectedNodeHandleDisabled && isHoveredHandle ? 3.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: Container(
                          width: length,
                          height: length,
                          decoration: BoxDecoration(
                            color: !isSelectedNodeHandleDisabled && isHoveredHandle ? Colors.blue : Colors.blue.shade50,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: widthBorderCircle),
                          ),
                          child: !isSelectedNodeHandleDisabled && isHoveredHandle
                              ? Center(child: _buildConnectionArrowIcon(handle, length))
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// Создаёт подсветку атрибутов для всех узлов, включая вложенные в группу
  Widget buildAllAttributesHighlights(
    dynamic node,
    Size nodeSize,
    double offset,
    double scale,
    double length,
    double width,
    Map isHovered,
    dynamic setState,
  ) {
    // Собираем все узлы для отображения атрибутов (текущий узел и вложенные, если это группа)
    final List<dynamic> nodesToProcess = [];

    if (node.qType == 'group' && node.children != null) {
      // Явно приводим children к списку и фильтруем
      final children = List<dynamic>.from(node.children);
      for (var child in children) {
        if (child.attributes != null && child.attributes.isNotEmpty) {
          nodesToProcess.add(child);
        }
      }
    }

    // Добавляем текущий узел, если у него есть атрибуты
    if (node.attributes != null && node.attributes.isNotEmpty) {
      nodesToProcess.add(node);
    }

    if (nodesToProcess.isEmpty) return Container();

    final minHeaderHeight = EditorConfig.minHeaderHeight;
    final attributeRows = _buildAttributeHighlightRows(nodesToProcess, node, offset, minHeaderHeight, scale);

    return Positioned(
      top: offset,
      left: 0,
      child: SizedBox(
        width: offset * 2 + nodeSize.width,
        height: nodeSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: _buildAllAttributesHighlightChildren(attributeRows, length, isHovered, setState),
        ),
      ),
    );
  }

  /// Создаёт дочерние виджеты кружки с лева и права атрибута для создания связи атрибут->
  List<Widget> _buildAllAttributesHighlightChildren(
    List<AttributeHighlightRow> attributeRows,
    double length,
    Map isHovered,
    dynamic setState,
  ) {
    final List<Widget> children = [];
    final hoverAreaSize = length * 3; // Увеличиваем область для ховера в 3 раза
    final createdArrowId = state.arrowCreated?.id;

    bool hasCommittedConnections(Set<dynamic>? sideConnections) {
      if (sideConnections == null || sideConnections.isEmpty) {
        return false;
      }

      for (final connection in sideConnections) {
        if (connection == null) {
          continue;
        }
        if (createdArrowId != null && connection.id == createdArrowId) {
          continue;
        }
        return true;
      }

      return false;
    }

    bool hasAnyConnections(Set<dynamic>? sideConnections) {
      return (sideConnections?.isNotEmpty ?? false);
    }

    for (final row in attributeRows) {
      final attribute = row.node.attributes[row.rowIndex];
      final leftConnections = attribute.connections?.get('left');
      final rightConnections = attribute.connections?.get('right');
      final isLeftConnected = hasCommittedConnections(leftConnections);
      final isRightConnected = hasCommittedConnections(rightConnections);
      final isLeftHoverDisabled = hasAnyConnections(leftConnections);
      final isRightHoverDisabled = hasAnyConnections(rightConnections);

      children.add(
        _buildAttributeConnectionCircle(
          row: row,
          side: 'left',
          centerX: row.leftCircleCenterX,
          centerY: row.circleCenterY,
          length: length,
          hoverAreaSize: hoverAreaSize,
          isHovered: isHovered,
          setState: setState,
          isConnected: isLeftConnected,
          isHoverDisabled: isLeftHoverDisabled,
          attributeId: attribute.id,
        ),
      );

      children.add(
        _buildAttributeConnectionCircle(
          row: row,
          side: 'right',
          centerX: row.rightCircleCenterX,
          centerY: row.circleCenterY,
          length: length,
          hoverAreaSize: hoverAreaSize,
          isHovered: isHovered,
          setState: setState,
          isConnected: isRightConnected,
          isHoverDisabled: isRightHoverDisabled,
          attributeId: attribute.id,
        ),
      );
    }

    return children;
  }

  Widget _buildConnectionArrowIcon(String direction, double length) {
    return Transform.rotate(
      angle: _arrowIconRotations[direction] ?? 0,
      child: Icon(
        Icons.arrow_forward,
        color: Colors.white,
        size: length * 0.75,
      ),
    );
  }

  Widget _buildAttributeConnectionCircle({
    required AttributeHighlightRow row,
    required String side,
    required double centerX,
    required double centerY,
    required double length,
    required double hoverAreaSize,
    required Map isHovered,
    required dynamic setState,
    required bool isConnected,
    required bool isHoverDisabled,
    required String attributeId,
  }) {
    final GlobalKey<TooltipState> tooltipkey = GlobalKey<TooltipState>();
    final hoverKey = 'attr_${side}_${row.node.id}_${row.rowIndex}';
    final isHoveredCircle = isHovered[hoverKey] ?? false;
    final direction = side == 'left' ? 'l' : 'r';
    final createdArrowSourceId = state.arrowCreated?.source;
    final isSelectedObjectCircleDisabled =
        createdArrowSourceId != null &&
        (createdArrowSourceId == row.node.id ||
            row.node.attributes.any((attribute) => attribute.id == createdArrowSourceId));
    final circleVisual = Center(
      child: AnimatedScale(
        scale: !isHoverDisabled && !isSelectedObjectCircleDisabled && isHoveredCircle ? 3.0 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          width: length,
          height: length,
          decoration: BoxDecoration(
            color: isConnected || (!isHoverDisabled && !isSelectedObjectCircleDisabled && isHoveredCircle)
                ? Colors.blue
                : Colors.blue.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: widthBorderCircle),
          ),
          child: !isHoverDisabled && !isSelectedObjectCircleDisabled && isHoveredCircle
              ? Center(child: _buildConnectionArrowIcon(direction, length))
              : null,
        ),
      ),
    );

    return Positioned(
      left: centerX - hoverAreaSize / 2 + widthBorderCircle / 2,
      top: centerY - hoverAreaSize / 2 + widthBorderCircle / 2,
      width: hoverAreaSize,
      height: hoverAreaSize,
      child: MouseRegion(
        cursor: isHoverDisabled || isSelectedObjectCircleDisabled ? SystemMouseCursors.basic : SystemMouseCursors.alias,
        hitTestBehavior: HitTestBehavior.translucent,
        onEnter: isHoverDisabled || isSelectedObjectCircleDisabled
            ? null
            : (_) {
                if (setState != null) {
                  setState(() {
                    isHovered[hoverKey] = true;
                  });
                }
              },
        onHover: isHoverDisabled || isSelectedObjectCircleDisabled
            ? null
            : (_) {
                if (setState != null && isHovered[hoverKey] != true) {
                  setState(() {
                    isHovered[hoverKey] = true;
                  });
                }
              },
        onExit: isHoverDisabled || isSelectedObjectCircleDisabled
            ? null
            : (_) {
                if (setState != null) {
                  setState(() {
                    isHovered[hoverKey] = false;
                  });
                }
              },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isHoverDisabled || isSelectedObjectCircleDisabled
              ? null
              : () async {
                  await arrowManager.startCreateArrowFromMap({'source': attributeId}, direction);
                },
          child: isHoverDisabled || isSelectedObjectCircleDisabled
              ? circleVisual
              : Tooltip(key: tooltipkey, message: 'Создать связь атрибута', child: circleVisual),
        ),
      ),
    );
  }

  List<AttributeHighlightRow> _buildAttributeHighlightRows(
    List<dynamic> nodesToProcess,
    dynamic mainNode,
    double offset,
    double minHeaderHeight,
    double scale,
  ) {
    final rows = <AttributeHighlightRow>[];

    for (final node in nodesToProcess) {
      if (node.attributes == null || node.attributes.isEmpty) continue;

      final nodeOffsetY = node == mainNode ? 0.0 : node.position.dy * scale;
      final nodeOffsetX = node == mainNode ? 0.0 : node.position.dx * scale;
      final currentNodeWidth = node.size.width * scale;
      final currentNodeLeft = offset + nodeOffsetX;
      final isGroup = node.qType == 'group';
      final totalMinContentHeight = minHeaderHeight + EditorConfig.minRowHeight * node.attributes.length;

      double headerHeight;
      double actualRowHeight;

      if (!isGroup) {
        if (node.heightHeader != null) {
          headerHeight = node.heightHeader as double;
          actualRowHeight = math.max(
            (node.size.height - headerHeight) / node.attributes.length,
            EditorConfig.minRowHeight,
          );
        } else if (node.size.height > totalMinContentHeight) {
          final extraHeight = node.size.height - totalMinContentHeight;
          final headerShare = minHeaderHeight / totalMinContentHeight;
          headerHeight = minHeaderHeight + extraHeight * headerShare;
          actualRowHeight = (node.size.height - headerHeight) / node.attributes.length;
        } else {
          headerHeight = minHeaderHeight;
          actualRowHeight = math.max(
            (node.size.height - headerHeight) / node.attributes.length,
            EditorConfig.minRowHeight,
          );
        }
      } else {
        headerHeight = minHeaderHeight;
        actualRowHeight = EditorConfig.minRowHeight;
      }

      final rowHeightScaled = actualRowHeight * scale;
      final maxVisibleHeight = nodeOffsetY + node.size.height * scale;

      for (int rowIndex = 0; rowIndex < node.attributes.length; rowIndex++) {
        final attribute = node.attributes[rowIndex];
        if (attribute.qType != 'attribute') continue;

        final rowTop = (headerHeight + actualRowHeight * rowIndex) * scale + nodeOffsetY;
        final rowBottom = rowTop + rowHeightScaled;
        if (rowBottom > maxVisibleHeight) {
          break;
        }

        rows.add(
          AttributeHighlightRow(
            node: node,
            rowIndex: rowIndex,
            currentNodeLeft: currentNodeLeft,
            currentNodeWidth: currentNodeWidth,
            rowTop: rowTop,
            rowBottom: rowBottom,
            rowHeightScaled: rowHeightScaled,
            leftCircleCenterX: currentNodeLeft,
            rightCircleCenterX: currentNodeLeft + currentNodeWidth,
            circleCenterY: rowTop + rowHeightScaled / 2,
          ),
        );
      }
    }

    return rows;
  }
}
