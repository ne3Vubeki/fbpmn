import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../models/image_tile.dart';
import '../models/table.node.dart';
import '../editor_state.dart';
import '../utils/bounds_calculator.dart';
import '../utils/node_renderer.dart';
import '../utils/editor_config.dart';

class TileManager {
  final EditorState state;
  final VoidCallback onStateUpdate;

  final BoundsCalculator _boundsCalculator = BoundsCalculator();
  final NodeRenderer _nodeRenderer = NodeRenderer();

  // Временное хранилище для узлов, которые перемещаются
  final Map<TableNode, Set<String>> _movedNodesSourceTiles = {};

  TileManager({required this.state, required this.onStateUpdate});

  Future<void> createTiledImage(List<TableNode> nodes) async {
    try {
      state.isLoading = true;
      onStateUpdate();

      // Очищаем старые данные
      _disposeTiles();

      if (nodes.isEmpty) {
        // Если узлов нет, создаем несколько пустых тайлов для начала
        await _createInitialTiles();
        return;
      }

      // Создаем тайлы только там где есть узлы
      final tiles = await _createTilesForNodes(nodes);

      state.imageTiles = tiles;

      state.isLoading = false;
      onStateUpdate();
    } catch (e) {
      await createFallbackTiles();
    }
  }

  // Создание начальных тайлов
  Future<void> _createInitialTiles() async {
    // Создаем 4 тайла для начальной видимой области
    final tiles = await _createTilesInGrid(0, 0, 2, 2, []);

    state.imageTiles = tiles;
    state.isLoading = false;
    onStateUpdate();
  }

  // Создание тайлов для узлов
  Future<List<ImageTile>> _createTilesForNodes(List<TableNode> allNodes) async {
    final List<ImageTile> tiles = [];
    final Set<String> createdTileIds = {}; // Для отслеживания созданных тайлов

    // Собираем все узлы (включая вложенные) для определения, где создавать тайлы
    final allNodesIncludingChildren = <TableNode>[];
    
    void collectAllNodes(List<TableNode> nodes) {
      for (final node in nodes) {
        allNodesIncludingChildren.add(node);
        
        // Если это развернутый swimlane, добавляем детей как независимые узлы
        if (node.qType == 'swimlane' && !(node.isCollapsed ?? false) && 
            node.children != null && node.children!.isNotEmpty) {
          for (final child in node.children!) {
            allNodesIncludingChildren.add(child);
          }
        } else if (node.children != null && node.children!.isNotEmpty && 
                  !(node.qType == 'swimlane' && (node.isCollapsed ?? false))) {
          // Для других узлов или свернутых swimlane обрабатываем детей традиционно
          collectAllNodes(node.children!);
        }
      }
    }
    
    collectAllNodes(allNodes);

    // Для каждого узла (включая вложенные) создаем тайлы в нужных позициях
    for (final node in allNodesIncludingChildren) {
      // Получаем абсолютную позицию узла
      final nodePosition = node.aPosition ?? (state.delta + node.position);
      final nodeRect = _boundsCalculator.calculateNodeRect(
        node: node,
        position: nodePosition,
      );

      // Рассчитываем grid позиции, которые покрывает узел
      final tileWorldSize = EditorConfig.tileSize.toDouble();
      final gridXStart = (nodeRect.left / tileWorldSize).floor();
      final gridYStart = (nodeRect.top / tileWorldSize).floor();
      final gridXEnd = (nodeRect.right / tileWorldSize).ceil();
      final gridYEnd = (nodeRect.bottom / tileWorldSize).ceil();

      // Создаем тайлы для всех grid позиций
      for (int gridY = gridYStart; gridY < gridYEnd; gridY++) {
        for (int gridX = gridXStart; gridX < gridXEnd; gridX++) {
          final left = gridX * tileWorldSize;
          final top = gridY * tileWorldSize;
          final tileId = _generateTileId(left, top);

          if (!createdTileIds.contains(tileId)) {
            // Создаем тайл в этой позиции
            final tile = await _createTileAtPosition(left, top, allNodes);
            if (tile != null) {
              tiles.add(tile);
              createdTileIds.add(tileId);
            }
          }
        }
      }
    }

    return tiles;
  }

  // Генерация ID тайла на основе мировых координат
  String _generateTileId(double left, double top) {
    return '${left.toInt()}:${top.toInt()}';
  }

  // Создание тайла в указанной позиции
  Future<ImageTile?> _createTileAtPosition(
    double left,
    double top,
    List<TableNode> allNodes,
  ) async {
    try {
      final tileWorldSize = EditorConfig.tileSize.toDouble();

      // Всегда создаем тайл фиксированного размера, кратного 1024
      final tileBounds = Rect.fromLTRB(
        left,
        top,
        left + tileWorldSize,
        top + tileWorldSize,
      );

      // ID тайла в формате 'left:top' (мировые координаты)
      final tileId = _generateTileId(left, top);

      // Получаем узлы для этого тайла (исключая выделенные)
      final nodesInTile = _getNodesForTile(tileBounds, allNodes);

      // Фиксированный размер изображения
      final int tileImageSize = EditorConfig.tileSize;
      final double scale = 1.0; // Масштаб 1:1

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.scale(scale, scale);
      canvas.translate(-tileBounds.left, -tileBounds.top);

      // Прозрачный фон
      canvas.drawRect(
        tileBounds,
        Paint()
          ..color = Colors.transparent
          ..blendMode = BlendMode.src,
      );

      // Рисуем узлы, если они есть
      if (nodesInTile.isNotEmpty) {
        final rootNodes = _filterRootNodes(nodesInTile);
        // ВАЖНО: Сортируем узлы так, чтобы swimlane были после своих детей
        final sortedNodes = _sortNodesWithSwimlaneLast(rootNodes);
        _nodeRenderer.drawRootNodesToTile(
          canvas: canvas,
          rootNodes: sortedNodes,
          tileBounds: tileBounds,
          delta: state.delta,
          cache: state.nodeBoundsCache,
        );
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(tileImageSize, tileImageSize);
      picture.dispose();

      // Создаем карту узлов для этого тайла
      _updateNodeTileMappings(tileId, nodesInTile);

      return ImageTile(
        image: image,
        bounds: tileBounds,
        scale: scale,
        id: tileId,
      );
    } catch (e) {
      return null;
    }
  }

  // Получение узлов для тайла (исключая выделенные)
  List<TableNode> _getNodesForTile(Rect bounds, List<TableNode> allNodes) {
    final List<TableNode> nodesInTile = [];

    void checkNode(TableNode node, Offset parentOffset, bool parentCollapsed, {bool isChildOfExpandedSwimlane = false}) {
      // Для детей развернутого swimlane используем абсолютную позицию напрямую
      // Для остальных случаев - стандартную логику
      final nodePosition = isChildOfExpandedSwimlane 
          ? (node.aPosition ?? node.position) 
          : (node.aPosition ?? (node.position + parentOffset));
      
      final nodeRect = _boundsCalculator.calculateNodeRect(
        node: node,
        position: nodePosition,
      );

      // Проверяем пересечение с тайлом
      if (nodeRect.overlaps(bounds)) {
        // Проверяем, не скрыт ли узел из-за свернутого swimlane родителя
        if (!parentCollapsed) {
          nodesInTile.add(node);
        }
      }

      // Проверяем, является ли текущий узел развернутым swimlane
      // Если да, то его дети должны быть обработаны независимо
      final isCurrentExpandedSwimlane = 
          node.qType == 'swimlane' && !(node.isCollapsed ?? false);

      if (node.children != null && node.children!.isNotEmpty) {
        if (isCurrentExpandedSwimlane) {
          // Для развернутого swimlane обрабатываем детей как независимые узлы
          // Они должны использовать свои абсолютные позиции
          for (final child in node.children!) {
            // Дети развернутого swimlane обрабатываются независимо, 
            // используя свои предварительно рассчитанные абсолютные позиции
            checkNode(
              child,
              Offset.zero, // Используем нулевое смещение, т.к. позиция будет браться напрямую
              parentCollapsed, // Дети развернутого swimlane не скрыты из-за родительского состояния
              isChildOfExpandedSwimlane: true, // Отмечаем, что это дети развернутого swimlane
            );
          }
        } else {
          // Для свернутого swimlane или обычных узлов - традиционная логика
          final isCurrentCollapsed = node.qType == 'swimlane' && (node.isCollapsed ?? false);
          
          if (!isCurrentCollapsed) {
            for (final child in node.children!) {
              checkNode(
                child,
                nodePosition, // Передаем позицию родителя как смещение
                parentCollapsed || isCurrentCollapsed,
              );
            }
          }
        }
      }
    }

    for (final node in allNodes) {
      checkNode(node, state.delta, false, isChildOfExpandedSwimlane: false);
    }

    return nodesInTile;
  }

  // Создание тайлов в grid сетке
  Future<List<ImageTile>> _createTilesInGrid(
    int startX,
    int startY,
    int width,
    int height,
    List<TableNode> allNodes,
  ) async {
    final List<ImageTile> tiles = [];
    final tileWorldSize = EditorConfig.tileSize.toDouble();

    for (int y = startY; y < startY + height; y++) {
      for (int x = startX; x < startX + width; x++) {
        final left = x * tileWorldSize;
        final top = y * tileWorldSize;
        final tile = await _createTileAtPosition(left, top, allNodes);
        if (tile != null) {
          tiles.add(tile);
        }
      }
    }

    return tiles;
  }

  // Обновляем метод для работы с String id
  void _updateNodeTileMappings(String tileId, List<TableNode> nodesInTile) {
    // Ищем индекс тайла по id
    final tileIndex = _findTileIndexById(tileId);
    if (tileIndex == null) {
      return;
    }

    state.tileToNodes[tileIndex] = nodesInTile;

    for (final node in nodesInTile) {
      if (!state.nodeToTiles.containsKey(node)) {
        state.nodeToTiles[node] = {};
      }
      state.nodeToTiles[node]!.add(tileIndex);
    }
  }

  // Поиск индекса тайла по id
  int? _findTileIndexById(String tileId) {
    for (int i = 0; i < state.imageTiles.length; i++) {
      if (state.imageTiles[i].id == tileId) {
        return i;
      }
    }
    return null;
  }

  // Фильтрация корневых узлов
  List<TableNode> _filterRootNodes(List<TableNode> allNodes) {
    return allNodes.where((node) {
      // Для свернутых swimlane всегда считаем их корневыми
      if (node.qType == 'swimlane' && (node.isCollapsed ?? false)) {
        return true;
      }

      bool hasParentInList = false;

      for (final potentialParent in allNodes) {
        // Если потенциальный родитель свернут, его дети не считаются
        if (potentialParent.qType == 'swimlane' &&
            (potentialParent.isCollapsed ?? false)) {
          continue;
        }

        if (potentialParent.children != null) {
          for (final child in potentialParent.children!) {
            if (child.id == node.id) {
              hasParentInList = true;
              break;
            }
          }
        }
        if (hasParentInList) break;
      }

      return !hasParentInList;
    }).toList();
  }

  /// Сортирует узлы так, чтобы swimlane были после своих детей
  List<TableNode> _sortNodesWithSwimlaneLast(List<TableNode> nodes) {
    final List<TableNode> nonSwimlaneNodes = [];
    final List<TableNode> swimlaneNodes = [];

    for (final node in nodes) {
      if (node.qType == 'swimlane') {
        swimlaneNodes.add(node);
      } else {
        nonSwimlaneNodes.add(node);
      }
    }

    // Сначала не-swimlane узлы, потом swimlane
    return [...nonSwimlaneNodes, ...swimlaneNodes];
  }

  /// Удаление детей swimlane из тайлов
  Future<void> _removeSwimlaneChildrenFromTiles(
    TableNode swimlaneNode,
    Set<int> tilesToUpdate,
  ) async {
    if (swimlaneNode.children == null || swimlaneNode.children!.isEmpty) {
      return;
    }

    // Удаляем всех детей из тайлов
    for (final child in swimlaneNode.children!) {
      final childTileIndices = _findTilesContainingNode(child);
      for (final tileIndex in childTileIndices) {
        if (tileIndex < state.imageTiles.length) {
          tilesToUpdate.add(tileIndex);
        }
      }
    }
  }

  // Удаление выделенного узла из тайлов
  Future<void> removeSelectedNodeFromTiles(TableNode node) async {
    final Set<int> tilesToUpdate = {};

    // Проверяем, является ли этот узел дочерним для развернутого swimlane
    TableNode? parentSwimlane = _findParentExpandedSwimlane(node);
    if (parentSwimlane != null) {
      // Если узел является дочерним для развернутого swimlane, 
      // удаляем его как самостоятельный узел
      final tileIndices = _findTilesContainingNode(node);
      for (final tileIndex in tileIndices) {
        if (tileIndex < state.imageTiles.length) {
          tilesToUpdate.add(tileIndex);
        }
      }
    } else {
      // Для swimlane в развернутом состоянии удаляем всех детей
      if (node.qType == 'swimlane' && !(node.isCollapsed ?? false)) {
        await _removeSwimlaneChildrenFromTiles(node, tilesToUpdate);
      }

      // Ищем тайлы, содержащие этот узел
      final tileIndices = _findTilesContainingNode(node);
      for (final tileIndex in tileIndices) {
        if (tileIndex < state.imageTiles.length) {
          tilesToUpdate.add(tileIndex);
        }
      }
    }

    // Обновляем все тайлы, из которых удаляли узлы
    for (final tileIndex in tilesToUpdate) {
      await _updateTileWithAllNodes(tileIndex);
    }
  }

  // Поиск тайлов, содержащих указанный узел
  Set<int> _findTilesContainingNode(TableNode node) {
    final Set<int> tileIndices = {};

    // Проходим по всем тайлам и проверяем, содержит ли тайл этот узел
    for (int i = 0; i < state.imageTiles.length; i++) {
      final tile = state.imageTiles[i];

      // Проверяем, пересекается ли узел с тайлом
      final nodePosition = _findNodeAbsolutePosition(node);
      final nodeRect = _boundsCalculator.calculateNodeRect(
        node: node,
        position: nodePosition,
      );

      if (nodeRect.overlaps(tile.bounds)) {
        tileIndices.add(i);
      }
    }

    return tileIndices;
  }

  // Метод для поиска родительского развернутого swimlane узла
  TableNode? _findParentExpandedSwimlane(TableNode node) {
    TableNode? findParentRecursive(List<TableNode> nodes) {
      for (final currentNode in nodes) {
        // Проверяем, является ли текущий узел развернутым swimlane и содержит ли он искомый узел
        if (currentNode.qType == 'swimlane' && !(currentNode.isCollapsed ?? false)) {
          if (currentNode.children != null) {
            for (final child in currentNode.children!) {
              if (child.id == node.id) {
                return currentNode; // Нашли родительский развернутый swimlane
              }
              
              // Рекурсивно проверяем вложенные узлы
              TableNode? nestedParent = _findParentExpandedSwimlaneInNode(child, node);
              if (nestedParent != null) {
                return nestedParent;
              }
            }
          }
        }
        
        // Продолжаем рекурсивный поиск в дочерних узлах
        if (currentNode.children != null) {
          TableNode? result = findParentRecursive(currentNode.children!);
          if (result != null) {
            return result;
          }
        }
      }
      return null;
    }
    
    return findParentRecursive(state.nodes);
  }

  // Вспомогательный метод для поиска родительского swimlane в иерархии конкретного узла
  TableNode? _findParentExpandedSwimlaneInNode(TableNode parent, TableNode targetNode) {
    if (parent.children != null) {
      for (final child in parent.children!) {
        if (child.id == targetNode.id) {
          if (parent.qType == 'swimlane' && !(parent.isCollapsed ?? false)) {
            return parent; // Нашли родительский развернутый swimlane
          }
        }
        
        // Рекурсивно проверяем вложенные узлы
        TableNode? result = _findParentExpandedSwimlaneInNode(child, targetNode);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  // Поиск абсолютной позиции узла в иерархии
  Offset _findNodeAbsolutePosition(TableNode node) {
    // Ищем узел в state.nodes и его родителей
    Offset? findPositionRecursive(List<TableNode> nodes, Offset parentOffset) {
      for (final currentNode in nodes) {
        if (currentNode.id == node.id) {
          return currentNode.aPosition ?? (parentOffset + currentNode.position);
        }

        if (currentNode.children != null && currentNode.children!.isNotEmpty) {
          final found = findPositionRecursive(
            currentNode.children!,
            currentNode.aPosition ?? (parentOffset + currentNode.position),
          );
          if (found != null) {
            return found;
          }
        }
      }
      return null;
    }

    // Сначала ищем в старых узлах (до удаления)
    final oldPosition = findPositionRecursive(state.nodes, state.delta);
    if (oldPosition != null) {
      return oldPosition;
    }

    // Если не нашли, используем приблизительную позицию
    // (узел уже удален из state.nodes, но нам нужна его старая позиция)
    return node.aPosition ?? (state.delta + node.position);
  }

  // Удаление тайла по id
  Future<void> _removeTile(String tileId) async {
    final tileIndex = _findTileIndexById(tileId);
    if (tileIndex == null) return;

    try {
      final tile = state.imageTiles[tileIndex];
      tile.image.dispose();

      // Удаляем тайл из списка
      state.imageTiles.removeAt(tileIndex);

      // Удаляем связанные данные
      state.tileToNodes.remove(tileIndex);

      // Обновляем маппинги индексов для остальных тайлов
      _reindexTileMappings(tileIndex);

      onStateUpdate();
    } catch (e) {}
  }

  // Переиндексация маппингов после удаления тайла
  void _reindexTileMappings(int removedIndex) {
    // Обновляем tileToNodes
    final newTileToNodes = <int, List<TableNode>>{};
    for (final entry in state.tileToNodes.entries) {
      if (entry.key > removedIndex) {
        newTileToNodes[entry.key - 1] = entry.value;
      } else if (entry.key < removedIndex) {
        newTileToNodes[entry.key] = entry.value;
      }
    }
    state.tileToNodes.clear();
    state.tileToNodes.addAll(newTileToNodes);

    // Обновляем nodeToTiles
    for (final entry in state.nodeToTiles.entries) {
      final newIndices = <int>{};
      for (final index in entry.value) {
        if (index > removedIndex) {
          newIndices.add(index - 1);
        } else if (index < removedIndex) {
          newIndices.add(index);
        }
      }
      state.nodeToTiles[entry.key] = newIndices;
    }
  }

  // Добавление узла в тайлы (после перемещения)
  Future<void> addNodeToTiles(TableNode node, Offset nodePosition) async {
    final Set<int> tilesToUpdate = {};

    // Для swimlane в развернутом состоянии добавляем всех детей
    if (node.qType == 'swimlane' && !(node.isCollapsed ?? false)) {
      await _addSwimlaneChildrenToTiles(node, nodePosition, tilesToUpdate);
    }

    // Для group обновляем позиции всех детей
    if (node.qType == 'group' && node.children != null) {
      node.calculateAbsolutePositions(state.delta);
    }

    // Рассчитываем границы корневого узла
    final nodeRect = _boundsCalculator.calculateNodeRect(
      node: node,
      position: nodePosition,
    );

    // Рассчитываем grid позиции, которые покрывает узел
    final tileWorldSize = EditorConfig.tileSize.toDouble();
    final gridXStart = (nodeRect.left / tileWorldSize).floor();
    final gridYStart = (nodeRect.top / tileWorldSize).floor();
    final gridXEnd = (nodeRect.right / tileWorldSize).ceil();
    final gridYEnd = (nodeRect.bottom / tileWorldSize).ceil();

    // Обрабатываем все grid позиции
    for (int gridY = gridYStart; gridY < gridYEnd; gridY++) {
      for (int gridX = gridXStart; gridX < gridXEnd; gridX++) {
        final left = gridX * tileWorldSize;
        final top = gridY * tileWorldSize;
        final tileId = _generateTileId(left, top);

        // Ищем существующий тайл в этой позиции
        int? existingTileIndex = _findTileIndexById(tileId);

        if (existingTileIndex == null) {
          // СОЗДАЕМ НОВЫЙ ТАЙЛ в этой позиции
          await _createNewTileAtPosition(left, top, node);
        } else {
          // Добавляем тайл в список для обновления
          tilesToUpdate.add(existingTileIndex);
        }
      }
    }

    // Обновляем все тайлы, в которые добавили узлы
    for (final tileIndex in tilesToUpdate) {
      await _updateTileWithAllNodes(tileIndex);
    }

    onStateUpdate();
  }

  /// Добавление детей swimlane в тайлы
  Future<void> _addSwimlaneChildrenToTiles(
    TableNode swimlaneNode,
    Offset parentWorldPosition,
    Set<int> tilesToUpdate,
  ) async {
    if (swimlaneNode.children == null || swimlaneNode.children!.isEmpty) {
      return;
    }

    // Определяем, является ли swimlane развернутым
    final isExpanded = swimlaneNode.qType == 'swimlane' && !(swimlaneNode.isCollapsed ?? false);

    // Добавляем всех детей в тайлы
    for (final child in swimlaneNode.children!) {
      // Вычисляем мировые координаты ребенка
      // Для развернутого swimlane используем абсолютную позицию ребенка напрямую
      final childWorldPosition = isExpanded 
          ? (child.aPosition ?? (parentWorldPosition + child.position))
          : (child.aPosition ?? (parentWorldPosition + child.position));

      final childRect = _boundsCalculator.calculateNodeRect(
        node: child,
        position: childWorldPosition,
      );

      // Рассчитываем grid позиции для ребенка
      final tileWorldSize = EditorConfig.tileSize.toDouble();
      final gridXStart = (childRect.left / tileWorldSize).floor();
      final gridYStart = (childRect.top / tileWorldSize).floor();
      final gridXEnd = (childRect.right / tileWorldSize).ceil();
      final gridYEnd = (childRect.bottom / tileWorldSize).ceil();

      // Обрабатываем все grid позиции ребенка
      for (int gridY = gridYStart; gridY < gridYEnd; gridY++) {
        for (int gridX = gridXStart; gridX < gridXEnd; gridX++) {
          final left = gridX * tileWorldSize;
          final top = gridY * tileWorldSize;
          final tileId = _generateTileId(left, top);

          // Ищем существующий тайл в этой позиции
          int? existingTileIndex = _findTileIndexById(tileId);

          if (existingTileIndex == null) {
            // СОЗДАЕМ НОВЫЙ ТАЙЛ в этой позиции
            await _createNewTileAtPosition(left, top, child);
          } else {
            // Добавляем тайл в список для обновления
            tilesToUpdate.add(existingTileIndex);
          }
        }
      }
    }
  }

  // Создание нового тайла в указанной позиции
  Future<void> _createNewTileAtPosition(
    double left,
    double top,
    TableNode nodeToAdd,
  ) async {
    try {
      final tileId = _generateTileId(left, top);

      // Проверяем, не существует ли уже тайл с таким id
      if (_findTileIndexById(tileId) != null) {
        return;
      }

      // Создаем новый тайл со ВСЕМИ узлами в этой области
      // Используем state.nodes (все узлы, включая только что добавленный)
      final tile = await _createTileAtPosition(left, top, state.nodes);

      if (tile != null) {
        state.imageTiles.add(tile);

        // Обновляем маппинги
        final tileIndex = state.imageTiles.length - 1;

        // Получаем актуальный список узлов для этого тайла
        final nodesInTile = _getNodesForTile(tile.bounds, state.nodes);

        if (nodesInTile.isNotEmpty) {
          state.tileToNodes[tileIndex] = nodesInTile;

          // Обновляем кэш для всех узлов в тайле
          for (final node in nodesInTile) {
            if (!state.nodeToTiles.containsKey(node)) {
              state.nodeToTiles[node] = {};
            }
            state.nodeToTiles[node]!.add(tileIndex);
          }
        } else {
          // Если тайл пустой, удаляем его
          tile.image.dispose();
          state.imageTiles.removeLast();
        }
      }
    } catch (e) {}
  }

  Future<void> updateTilesAfterNodeChange() async {
    // Пересоздаем тайлы с текущими узлами
    await createTiledImage(state.nodes);

    // Уведомляем об изменении
    onStateUpdate();
  }

  // Обновление тайла со ВСЕМИ узлами
  Future<void> _updateTileWithAllNodes(int tileIndex) async {
    if (tileIndex < 0 || tileIndex >= state.imageTiles.length) {
      return;
    }

    try {
      final oldTile = state.imageTiles[tileIndex];
      final tileId = oldTile.id;
      final bounds = oldTile.bounds;

      // Получаем ВСЕ узлы для этого тайла из state.nodes
      final nodesInTile = _getNodesForTile(bounds, state.nodes);

      // Очищаем старый кэш для этого тайла
      state.tileToNodes.remove(tileIndex);

      // Если в тайле есть узлы, обновляем кэш
      if (nodesInTile.isNotEmpty) {
        state.tileToNodes[tileIndex] = nodesInTile;

        // Обновляем кэш nodeToTiles для всех узлов в тайле
        for (final node in nodesInTile) {
          if (!state.nodeToTiles.containsKey(node)) {
            state.nodeToTiles[node] = {};
          }
          state.nodeToTiles[node]!.add(tileIndex);
        }
      }

      oldTile.image.dispose();

      // Перерисовываем тайл со ВСЕМИ узлами
      final newTile = await _createUpdatedTile(bounds, tileId, nodesInTile);
      if (newTile != null) {
        state.imageTiles[tileIndex] = newTile;
      } else if (nodesInTile.isEmpty) {
        // Если тайл пустой, удаляем его
        await _removeTile(tileId);
      }

      onStateUpdate();
    } catch (e) {}
  }

  // Создание обновленного тайла
  // Создание обновленного тайла
  Future<ImageTile?> _createUpdatedTile(
    Rect bounds,
    String tileId,
    List<TableNode> nodes,
  ) async {
    try {
      final rootNodes = _filterRootNodes(nodes);
      // ВАЖНО: Сортируем узлы так, чтобы swimlane были после своих детей
      final sortedNodes = _sortNodesWithSwimlaneLast(rootNodes);

      final int tileImageSize = EditorConfig.tileSize;
      final double scale = 1.0;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.scale(scale, scale);
      canvas.translate(-bounds.left, -bounds.top);

      canvas.drawRect(
        bounds,
        Paint()
          ..color = Colors.transparent
          ..blendMode = BlendMode.src,
      );

      if (sortedNodes.isNotEmpty) {
        _nodeRenderer.drawRootNodesToTile(
          canvas: canvas,
          rootNodes: sortedNodes,
          tileBounds: bounds,
          delta: state.delta,
          cache: state.nodeBoundsCache,
        );
      }

      final picture = recorder.endRecording();

      final image = await picture.toImage(tileImageSize, tileImageSize);
      picture.dispose();

      return ImageTile(image: image, bounds: bounds, scale: scale, id: tileId);
    } catch (e) {
      return null;
    }
  }

  Future<void> createFallbackTiles() async {
    try {
      _disposeTiles();

      // Создаем 4 начальных тайла
      final tiles = await _createTilesInGrid(0, 0, 2, 2, []);

      state.imageTiles = tiles;
      state.isLoading = false;
      onStateUpdate();
    } catch (e) {
      state.isLoading = false;
      onStateUpdate();
    }
  }

  void _disposeTiles() {
    for (final tile in state.imageTiles) {
      tile.image.dispose();
    }
    state.imageTiles.clear();
    state.nodeBoundsCache.clear();
    state.tileToNodes.clear();
    state.nodeToTiles.clear();
    _movedNodesSourceTiles.clear();
  }

  void dispose() {
    _disposeTiles();
  }
}
