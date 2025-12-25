import 'dart:async';
import 'dart:math' as math;
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
  
  TileManager({
    required this.state,
    required this.onStateUpdate,
  });
  
  Future<void> createTiledImage(List<TableNode> nodes) async {
    try {
      state.isLoading = true;
      onStateUpdate();
      
      print('Создание тайлового изображения...');
      
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
      print('Создано ${tiles.length} тайлов');
      
      state.isLoading = false;
      onStateUpdate();
      
    } catch (e, stackTrace) {
      print('Ошибка создания тайлового изображения: $e');
      print('Stack trace: $stackTrace');
      
      await createFallbackTiles();
    }
  }
  
  // Создание начальных тайлов
  Future<void> _createInitialTiles() async {
    print('Создание начальных тайлов...');
    
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
    
    // Для каждого узла создаем тайлы в нужных позициях
    for (final node in allNodes) {
      final nodesInHierarchy = _collectAllNodes(node);
      
      for (final currentNode in nodesInHierarchy) {
        final nodePosition = _getAbsolutePosition(currentNode, node);
        final nodeRect = _boundsCalculator.calculateNodeRect(
          node: currentNode,
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
    }
    
    return tiles;
  }
  
  // Генерация ID тайла на основе мировых координат
  String _generateTileId(double left, double top) {
    return '${left.toInt()}:${top.toInt()}';
  }
  
  // Создание тайла в указанной позиции
  Future<ImageTile?> _createTileAtPosition(double left, double top, List<TableNode> allNodes) async {
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
        _nodeRenderer.drawRootNodesToTile(
          canvas: canvas,
          rootNodes: rootNodes,
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
      print('Ошибка создания тайла в позиции [$left, $top]: $e');
      return null;
    }
  }
  
  // Получение узлов для тайла (исключая выделенные)
  List<TableNode> _getNodesForTile(Rect bounds, List<TableNode> allNodes) {
    final List<TableNode> nodesInTile = [];
    
    void checkNode(TableNode node, Offset parentOffset) {
      final shiftedPosition = node.position + parentOffset;
      final nodeRect = _boundsCalculator.calculateNodeRect(
        node: node,
        position: shiftedPosition,
      );
      
      // Проверяем, является ли узел выделенным (на верхнем слое)
      final isSelectedNode = state.isNodeOnTopLayer && 
          state.selectedNodeOnTopLayer != null &&
          _isNodeInHierarchy(node, state.selectedNodeOnTopLayer!);
      
      // Если узел не выделенный и пересекается с тайлом, добавляем его
      if (!isSelectedNode && nodeRect.overlaps(bounds)) {
        nodesInTile.add(node);
      }
      
      // Рекурсивно проверяем детей
      if (node.children != null && node.children!.isNotEmpty) {
        for (final child in node.children!) {
          checkNode(child, shiftedPosition);
        }
      }
    }
    
    for (final node in allNodes) {
      checkNode(node, state.delta);
    }
    
    return nodesInTile;
  }
  
  // Создание тайлов в grid сетке
  Future<List<ImageTile>> _createTilesInGrid(int startX, int startY, int width, int height, List<TableNode> allNodes) async {
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
  
  // Получение абсолютной позиции узла в иерархии
  Offset _getAbsolutePosition(TableNode targetNode, TableNode rootNode) {
    if (targetNode.id == rootNode.id) {
      return state.delta + rootNode.position;
    }
    
    Offset? findPath(TableNode currentNode, Offset currentOffset) {
      if (currentNode.id == targetNode.id) {
        return currentOffset;
      }
      
      if (currentNode.children != null) {
        for (final child in currentNode.children!) {
          final found = findPath(child, currentOffset + child.position);
          if (found != null) {
            return found;
          }
        }
      }
      
      return null;
    }
    
    final rootPosition = state.delta + rootNode.position;
    final found = findPath(rootNode, rootPosition);
    return found ?? rootPosition;
  }
  
  // Проверка, находится ли узел в иерархии другого узла
  bool _isNodeInHierarchy(TableNode node, TableNode rootNode) {
    if (node.id == rootNode.id) return true;
    
    if (rootNode.children != null) {
      for (final child in rootNode.children!) {
        if (_isNodeInHierarchy(node, child)) {
          return true;
        }
      }
    }
    
    return false;
  }
  
  // Обновляем метод для работы с String id
  void _updateNodeTileMappings(String tileId, List<TableNode> nodesInTile) {
    // Ищем индекс тайла по id
    final tileIndex = _findTileIndexById(tileId);
    if (tileIndex == null) {
      print('Тайл с id $tileId не найден для обновления маппинга');
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
      bool hasParentInList = false;
      
      for (final potentialParent in allNodes) {
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
  
  // Удаление выделенного узла из тайлов
  Future<void> removeSelectedNodeFromTiles(TableNode node) async {
    print('=== УДАЛЕНИЕ ВЫДЕЛЕННОГО УЗЛА "${node.text}" ИЗ ТАЙЛОВ ===');
    
    final nodesToRemove = _collectAllNodes(node);
    
    print('Удаляем ${nodesToRemove.length} узлов иерархии');
    
    // Сохраняем информацию о исходных тайлах для последующей проверки
    for (final nodeToRemove in nodesToRemove) {
      final tileIndices = state.nodeToTiles[nodeToRemove];
      if (tileIndices == null || tileIndices.isEmpty) {
        print('Узел "${nodeToRemove.text}" не найден в тайлах');
        continue;
      }
      
      // Сохраняем id тайлов, из которых удаляем узел
      final sourceTileIds = <String>{};
      for (final tileIndex in tileIndices) {
        if (tileIndex < state.imageTiles.length) {
          sourceTileIds.add(state.imageTiles[tileIndex].id);
        }
      }
      
      _movedNodesSourceTiles[nodeToRemove] = sourceTileIds;
      
      print('Узел "${nodeToRemove.text}" находится в тайлах: ${sourceTileIds.toList()}');
      
      // Удаляем узел из тайлов
      for (final tileIndex in tileIndices) {
        await _removeNodeFromTile(tileIndex, nodeToRemove);
      }
      
      // Удаляем узел из кэша
      state.nodeToTiles.remove(nodeToRemove);
    }
  }
  
  // Удаление конкретного узла из тайла
  Future<void> _removeNodeFromTile(int tileIndex, TableNode nodeToRemove) async {
    if (tileIndex < 0 || tileIndex >= state.imageTiles.length) {
      print('Неверный индекс тайла: $tileIndex');
      return;
    }
    
    try {
      final oldTile = state.imageTiles[tileIndex];
      final tileId = oldTile.id;
      final bounds = oldTile.bounds;
      
      final currentNodes = state.tileToNodes[tileIndex] ?? [];
      
      // Удаляем узел и всех его детей
      final nodesToRemove = _collectAllNodes(nodeToRemove);
      final nodesToRemoveIds = nodesToRemove.map((n) => n.id).toSet();
      final filteredNodes = currentNodes.where((node) => !nodesToRemoveIds.contains(node.id)).toList();
      
      print('Тайл $tileId: было ${currentNodes.length} узлов, осталось ${filteredNodes.length}');
      
      state.tileToNodes[tileIndex] = filteredNodes;
      
      oldTile.image.dispose();
      
      // Перерисовываем тайл со всеми оставшимися узлами
      final newTile = await _createUpdatedTile(bounds, tileId, filteredNodes);
      if (newTile != null) {
        state.imageTiles[tileIndex] = newTile;
      }
      
      onStateUpdate();
    } catch (e) {
      print('Ошибка удаления узла "${nodeToRemove.text}" из тайла: $e');
    }
  }
  
  // Проверка и удаление пустого тайла
  Future<void> _checkAndRemoveEmptyTile(String tileId) async {
    final tileIndex = _findTileIndexById(tileId);
    if (tileIndex == null) return;
    
    final nodesInTile = state.tileToNodes[tileIndex];
    if (nodesInTile == null || nodesInTile.isEmpty) {
      print('Тайл $tileId пустой, удаляем...');
      await _removeTile(tileId);
    }
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
      
      print('Тайл $tileId удален');
      
      onStateUpdate();
    } catch (e) {
      print('Ошибка удаления тайла $tileId: $e');
    }
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
  
  List<TableNode> _collectAllNodes(TableNode rootNode) {
    final List<TableNode> allNodes = [rootNode];
    
    void collectChildren(TableNode node) {
      if (node.children != null && node.children!.isNotEmpty) {
        for (final child in node.children!) {
          allNodes.add(child);
          collectChildren(child);
        }
      }
    }
    
    collectChildren(rootNode);
    return allNodes;
  }
  
  // Добавление узла в тайлы (после перемещения)
  Future<void> addNodeToTiles(TableNode node, Offset nodePosition) async {
    print('=== СОХРАНЕНИЕ УЗЛА В НОВОМ МЕСТЕ ===');
    print('Узел: "${node.text}" на позиции $nodePosition');
    
    final nodesToAdd = _collectAllNodes(node);
    
    print('Добавляем ${nodesToAdd.length} узлов иерархии');
    
    // Создаем новые тайлы для нового положения узла
    for (final nodeToAdd in nodesToAdd) {
      final childNodePosition = nodePosition + _getRelativePosition(node, nodeToAdd);
      
      // Рассчитываем границы узла
      final nodeRect = _boundsCalculator.calculateNodeRect(
        node: nodeToAdd,
        position: childNodePosition,
      );
      
      // Рассчитываем grid позиции, которые покрывает узел
      final tileWorldSize = EditorConfig.tileSize.toDouble();
      final gridXStart = (nodeRect.left / tileWorldSize).floor();
      final gridYStart = (nodeRect.top / tileWorldSize).floor();
      final gridXEnd = (nodeRect.right / tileWorldSize).ceil();
      final gridYEnd = (nodeRect.bottom / tileWorldSize).ceil();
      
      print('Узел "${nodeToAdd.text}" покрывает grid позиции: X[$gridXStart..$gridXEnd], Y[$gridYStart..$gridYEnd]');
      
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
            print('Создаем новый тайл $tileId в позиции [$left, $top]');
            await _createNewTileAtPosition(left, top, nodeToAdd);
          } else {
            // Добавляем узел в существующий тайл
            final nodesInTile = state.tileToNodes[existingTileIndex] ?? [];
            if (!nodesInTile.any((n) => n.id == nodeToAdd.id)) {
              nodesInTile.add(nodeToAdd);
              state.tileToNodes[existingTileIndex] = nodesInTile;
              
              // Обновляем кэш
              if (!state.nodeToTiles.containsKey(nodeToAdd)) {
                state.nodeToTiles[nodeToAdd] = {};
              }
              state.nodeToTiles[nodeToAdd]!.add(existingTileIndex);
              
              // Перерисовываем тайл со ВСЕМИ узлами
              await _updateTileWithAllNodes(existingTileIndex);
            }
          }
        }
      }
    }
    
    // Теперь проверяем исходные тайлы на пустоту (после того как узел добавлен в новые места)
    await _checkSourceTilesAfterMove(nodesToAdd);
    
    onStateUpdate();
  }
  
  // Проверка исходных тайлов после перемещения узла
  Future<void> _checkSourceTilesAfterMove(List<TableNode> movedNodes) async {
    print('=== ПРОВЕРКА ИСХОДНЫХ ТАЙЛОВ ПОСЛЕ ПЕРЕМЕЩЕНИЯ ===');
    
    final Set<String> sourceTilesToCheck = {};
    
    // Собираем все исходные тайлы для перемещенных узлов
    for (final node in movedNodes) {
      final sourceTileIds = _movedNodesSourceTiles[node];
      if (sourceTileIds != null) {
        sourceTilesToCheck.addAll(sourceTileIds);
      }
    }
    
    // Проверяем каждый исходный тайл
    for (final tileId in sourceTilesToCheck) {
      await _checkAndRemoveEmptyTile(tileId);
    }
    
    // Очищаем временное хранилище
    for (final node in movedNodes) {
      _movedNodesSourceTiles.remove(node);
    }
  }
  
  // Создание нового тайла в указанной позиции
  Future<void> _createNewTileAtPosition(double left, double top, TableNode nodeToAdd) async {
    try {
      final tileId = _generateTileId(left, top);
      
      // Проверяем, не существует ли уже тайл с таким id
      if (_findTileIndexById(tileId) != null) {
        print('Тайл $tileId уже существует');
        return;
      }
      
      // Создаем новый тайл только с этим узлом
      final tile = await _createTileAtPosition(left, top, [nodeToAdd]);
      
      if (tile != null) {
        state.imageTiles.add(tile);
        
        // Обновляем маппинги
        final tileIndex = state.imageTiles.length - 1;
        final nodesInTile = [nodeToAdd];
        state.tileToNodes[tileIndex] = nodesInTile;
        
        if (!state.nodeToTiles.containsKey(nodeToAdd)) {
          state.nodeToTiles[nodeToAdd] = {};
        }
        state.nodeToTiles[nodeToAdd]!.add(tileIndex);
        
        print('Создан новый тайл $tileId в позиции [$left, $top]');
      }
    } catch (e) {
      print('Ошибка создания нового тайла: $e');
    }
  }
  
  Offset _getRelativePosition(TableNode rootNode, TableNode targetNode) {
    if (rootNode.id == targetNode.id) return Offset.zero;
    
    Offset? findPath(TableNode currentNode, Offset currentOffset) {
      if (currentNode.id == targetNode.id) return currentOffset;
      
      if (currentNode.children != null) {
        for (final child in currentNode.children!) {
          final childOffset = currentOffset + child.position;
          final found = findPath(child, childOffset);
          if (found != null) return found;
        }
      }
      
      return null;
    }
    
    return findPath(rootNode, Offset.zero) ?? Offset.zero;
  }
  
  // Обновление тайла со ВСЕМИ узлами
  Future<void> _updateTileWithAllNodes(int tileIndex) async {
    if (tileIndex < 0 || tileIndex >= state.imageTiles.length) {
      print('Неверный индекс тайла для обновления: $tileIndex');
      return;
    }
    
    try {
      final oldTile = state.imageTiles[tileIndex];
      final tileId = oldTile.id;
      final bounds = oldTile.bounds;
      
      final nodesInTile = state.tileToNodes[tileIndex] ?? [];
      
      oldTile.image.dispose();
      
      // Перерисовываем тайл со ВСЕМИ узлами
      final newTile = await _createUpdatedTile(bounds, tileId, nodesInTile);
      if (newTile != null) {
        state.imageTiles[tileIndex] = newTile;
      }
      
      onStateUpdate();
    } catch (e) {
      print('Ошибка обновления тайла [$tileIndex]: $e');
    }
  }
  
  // Создание обновленного тайла
  Future<ImageTile?> _createUpdatedTile(Rect bounds, String tileId, List<TableNode> nodes) async {
    try {
      final rootNodes = _filterRootNodes(nodes);
      
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
      
      if (rootNodes.isNotEmpty) {
        _nodeRenderer.drawRootNodesToTile(
          canvas: canvas,
          rootNodes: rootNodes,
          tileBounds: bounds,
          delta: state.delta,
          cache: state.nodeBoundsCache,
        );
      }
      
      final picture = recorder.endRecording();
      
      final image = await picture.toImage(tileImageSize, tileImageSize);
      picture.dispose();
      
      return ImageTile(
        image: image,
        bounds: bounds,
        scale: scale,
        id: tileId,
      );
      
    } catch (e) {
      print('Ошибка создания обновленного тайла [$tileId]: $e');
      return null;
    }
  }
  
  Future<void> createFallbackTiles() async {
    try {
      print('Создание запасных тайлов...');
      
      _disposeTiles();
      
      // Создаем 4 начальных тайла
      final tiles = await _createTilesInGrid(0, 0, 2, 2, []);
      
      state.imageTiles = tiles;
      state.isLoading = false;
      onStateUpdate();
      
    } catch (e) {
      print('Ошибка создания запасных тайлов: $e');
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