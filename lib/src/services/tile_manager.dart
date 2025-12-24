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
      
      final bounds = _boundsCalculator.calculateTotalBounds(
        nodes: nodes,
        delta: state.delta,
        cache: state.nodeBoundsCache,
      );
      
      if (bounds == null) {
        await createFallbackTiles();
        return;
      }
      
      state.totalBounds = bounds;
      print('Общие границы: $bounds');
      
      final tiles = await _createAllTiles(bounds, nodes);
      
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
  
  Future<List<ImageTile>> _createAllTiles(Rect bounds, List<TableNode> allNodes) async {
    final List<ImageTile> tiles = [];
    final double tileWorldSize = EditorConfig.tileSize / EditorConfig.tileScale;
    
    final int tilesX = math.max(1, (bounds.width / tileWorldSize).ceil());
    final int tilesY = math.max(1, (bounds.height / tileWorldSize).ceil());
    
    print('Создаем $tilesX x $tilesY тайлов');
    
    // Создаем все тайлы
    for (int y = 0; y < tilesY; y++) {
      for (int x = 0; x < tilesX; x++) {
        try {
          final tileWorldLeft = bounds.left + (x * tileWorldSize);
          final tileWorldTop = bounds.top + (y * tileWorldSize);
          final tileWorldRight = math.min(bounds.right, tileWorldLeft + tileWorldSize);
          final tileWorldBottom = math.min(bounds.bottom, tileWorldTop + tileWorldSize);
          
          final tileBounds = Rect.fromLTRB(
            tileWorldLeft,
            tileWorldTop,
            tileWorldRight,
            tileWorldBottom,
          );
          
          final tileIndex = y * tilesX + x;
          
          final tile = await _createTile(tileBounds, tileIndex, allNodes);
          if (tile != null) {
            tiles.add(tile);
          }
          
          // Небольшая пауза для предотвращения перегрузки
          if ((x + y * tilesX) % 2 == 0) {
            await Future.delayed(Duration(milliseconds: 1));
          }
        } catch (e) {
          print('Ошибка создания тайла [$x, $y]: $e');
        }
      }
    }
    
    return tiles;
  }
  
  Future<ImageTile?> _createTile(Rect bounds, int tileIndex, List<TableNode> allNodes) async {
    try {
      // Получаем только КОРНЕВЫЕ узлы для этого тайла
      final rootNodesInTile = _getRootNodesForTile(
        bounds: bounds,
        allNodes: allNodes,
        delta: state.delta,
        excludedNode: state.isNodeOnTopLayer ? state.selectedNodeOnTopLayer : null,
      );
      
      // Даже если корневых узлов нет, создаем пустой тайл для сохранения структуры
      
      // Рассчитываем размеры изображения
      final double width = bounds.width;
      final double height = bounds.height;
      
      final int tileWidth = math.max(1, (width * EditorConfig.tileScale).ceil());
      final int tileHeight = math.max(1, (height * EditorConfig.tileScale).ceil());
      
      final int finalWidth = math.min(EditorConfig.tileSize, tileWidth);
      final int finalHeight = math.min(EditorConfig.tileSize, tileHeight);
      
      if (finalWidth <= 0 || finalHeight <= 0) {
        return null;
      }
      
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      canvas.scale(EditorConfig.tileScale, EditorConfig.tileScale);
      canvas.translate(-bounds.left, -bounds.top);
      
      // Прозрачный фон
      canvas.drawRect(
        bounds,
        Paint()
          ..color = Colors.transparent
          ..blendMode = BlendMode.src,
      );
      
      // Рисуем только КОРНЕВЫЕ узлы, их дети нарисуются рекурсивно
      _nodeRenderer.drawRootNodesToTile(
        canvas: canvas,
        rootNodes: rootNodesInTile,
        tileBounds: bounds,
        delta: state.delta,
        cache: state.nodeBoundsCache,
      );
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(finalWidth, finalHeight);
      picture.dispose();
      
      // Создаем карту узлов для этого тайла (включая детей через рекурсию)
      _updateNodeTileMappings(tileIndex, _getAllNodesFromRoots(rootNodesInTile));
      
      return ImageTile(
        image: image,
        bounds: bounds,
        scale: EditorConfig.tileScale,
        index: tileIndex,
      );
      
    } catch (e) {
      print('Ошибка создания тайла [$tileIndex]: $e');
      return null;
    }
  }
  
  /// Получает только корневые узлы для тайла (узлы без родителей в этом тайле)
  List<TableNode> _getRootNodesForTile({
    required Rect bounds,
    required List<TableNode> allNodes,
    required Offset delta,
    required TableNode? excludedNode,
  }) {
    final List<TableNode> rootNodes = [];
    
    void checkNode(TableNode node, Offset parentOffset, bool isRoot) {
      // Пропускаем исключенный узел
      if (excludedNode != null && node.id == excludedNode.id) {
        return;
      }
      
      final shiftedPosition = node.position + parentOffset;
      final nodeRect = _boundsCalculator.calculateNodeRect(
        node: node,
        position: shiftedPosition,
      );
      
      // Проверяем пересечение с тайлом
      if (nodeRect.overlaps(bounds)) {
        // Если это корневой узел (без родителя в списке), добавляем его
        if (isRoot) {
          rootNodes.add(node);
        }
      }
      
      // Рекурсивно проверяем детей
      if (node.children != null && node.children!.isNotEmpty) {
        for (final child in node.children!) {
          checkNode(child, shiftedPosition, false); // Дети не корневые
        }
      }
    }
    
    // Начинаем с корневых узлов
    for (final node in allNodes) {
      checkNode(node, delta, true);
    }
    
    return rootNodes;
  }
  
  /// Получает все узлы (включая детей) из списка корневых узлов
  List<TableNode> _getAllNodesFromRoots(List<TableNode> rootNodes) {
    final List<TableNode> allNodes = [];
    
    void collectNodes(TableNode node) {
      allNodes.add(node);
      if (node.children != null && node.children!.isNotEmpty) {
        for (final child in node.children!) {
          collectNodes(child);
        }
      }
    }
    
    for (final root in rootNodes) {
      collectNodes(root);
    }
    
    return allNodes;
  }
  
  void _updateNodeTileMappings(int tileIndex, List<TableNode> nodesInTile) {
    // Сохраняем узлы для этого тайла
    state.tileToNodes[tileIndex] = nodesInTile;
    
    // Обновляем обратное отображение (узел -> тайлы)
    for (final node in nodesInTile) {
      if (!state.nodeToTiles.containsKey(node)) {
        state.nodeToTiles[node] = {};
      }
      state.nodeToTiles[node]!.add(tileIndex);
    }
  }
  
  Future<void> removeNodeFromTiles(TableNode node) async {
    print('Удаление узла "${node.text}" из тайлов');
    
    // Собираем ВСЕ узлы для удаления (сам узел + все его дети)
    final List<TableNode> nodesToRemove = _collectAllNodes(node);
    
    print('Удаляем ${nodesToRemove.length} узлов: ${nodesToRemove.map((n) => n.text).toList()}');
    
    // Для каждого узла удаляем из тайлов
    for (final nodeToRemove in nodesToRemove) {
      final tileIndices = state.nodeToTiles[nodeToRemove];
      if (tileIndices == null || tileIndices.isEmpty) {
        print('Узел "${nodeToRemove.text}" не найден в тайлах');
        continue;
      }
      
      print('Обновление тайлов для узла "${nodeToRemove.text}": ${tileIndices.toList()}');
      
      // Обновляем каждый тайл, удаляя узел
      for (final tileIndex in tileIndices) {
        await _updateTileWithoutNode(tileIndex, nodeToRemove);
      }
      
      // Удаляем узел из кэша
      state.nodeToTiles.remove(nodeToRemove);
    }
  }
  
  /// Собирает все узлы в иерархии (сам узел + все его дети рекурсивно)
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
  
  Future<void> _updateTileWithoutNode(int tileIndex, TableNode nodeToRemove) async {
    if (tileIndex < 0 || tileIndex >= state.imageTiles.length) {
      print('Неверный индекс тайла: $tileIndex');
      return;
    }
    
    try {
      final oldTile = state.imageTiles[tileIndex];
      final bounds = oldTile.bounds;
      
      // Получаем текущие узлы для этого тайла
      final currentNodes = state.tileToNodes[tileIndex] ?? [];
      
      // Фильтруем узлы, исключая удаляемый и всех его детей
      final List<TableNode> nodesToRemove = _collectAllNodes(nodeToRemove);
      final Set<String> nodesToRemoveIds = nodesToRemove.map((n) => n.id).toSet();
      
      final filteredNodes = currentNodes.where((node) => !nodesToRemoveIds.contains(node.id)).toList();
      
      // Обновляем кэш
      state.tileToNodes[tileIndex] = filteredNodes;
      
      // Освобождаем старое изображение
      oldTile.image.dispose();
      
      // Создаем новый тайл
      final newTile = await _createUpdatedTile(bounds, tileIndex, filteredNodes);
      if (newTile != null) {
        state.imageTiles[tileIndex] = newTile;
      }
      
      onStateUpdate();
    } catch (e) {
      print('Ошибка обновления тайла [$tileIndex] без узла: $e');
    }
  }
  
  Future<void> addNodeToTiles(TableNode node, Offset nodePosition) async {
    print('Добавление узла "${node.text}" в тайлы на позиции $nodePosition');
    
    // Собираем ВСЕ узлы для добавления (сам узел + все его дети)
    final List<TableNode> nodesToAdd = _collectAllNodes(node);
    
    print('Добавляем ${nodesToAdd.length} узлов: ${nodesToAdd.map((n) => n.text).toList()}');
    
    // Для каждого узла определяем тайлы и добавляем
    for (final nodeToAdd in nodesToAdd) {
      // Для детей позиция рассчитывается относительно родителя
      final childNodePosition = nodePosition + _getRelativePosition(node, nodeToAdd);
      
      // Определяем, в какие тайлы попадает узел с его позицией
      final tileIndices = _boundsCalculator.getTileIndicesForNode(
        node: nodeToAdd,
        nodePosition: childNodePosition,
        imageTiles: state.imageTiles,
      );
      
      if (tileIndices.isEmpty) {
        print('Узел "${nodeToAdd.text}" не попадает ни в один тайл');
        continue;
      }
      
      print('Узел "${nodeToAdd.text}" попадает в тайлы: ${tileIndices.toList()}');
      
      // Обновляем кэш
      state.nodeToTiles[nodeToAdd] = tileIndices;
      
      // Обновляем каждый тайл
      for (final tileIndex in tileIndices) {
        // Добавляем узел в список узлов тайла (если еще нет)
        final nodesInTile = state.tileToNodes[tileIndex] ?? [];
        if (!nodesInTile.any((n) => n.id == nodeToAdd.id)) {
          nodesInTile.add(nodeToAdd);
          state.tileToNodes[tileIndex] = nodesInTile;
        }
        
        // Обновляем тайл
        await _updateTileWithAllNodes(tileIndex);
      }
    }
  }
  
  /// Получает позицию дочернего узла относительно корневого родителя
  Offset _getRelativePosition(TableNode rootNode, TableNode targetNode) {
    if (rootNode.id == targetNode.id) {
      return Offset.zero;
    }
    
    // Ищем путь от rootNode к targetNode
    Offset? findPath(TableNode currentNode, Offset currentOffset) {
      if (currentNode.id == targetNode.id) {
        return currentOffset;
      }
      
      if (currentNode.children != null) {
        for (final child in currentNode.children!) {
          final childOffset = currentOffset + child.position;
          final found = findPath(child, childOffset);
          if (found != null) {
            return found;
          }
        }
      }
      
      return null;
    }
    
    final path = findPath(rootNode, Offset.zero);
    return path ?? Offset.zero;
  }
  
  Future<void> _updateTileWithAllNodes(int tileIndex) async {
    if (tileIndex < 0 || tileIndex >= state.imageTiles.length) {
      print('Неверный индекс тайла для обновления: $tileIndex');
      return;
    }
    
    try {
      final oldTile = state.imageTiles[tileIndex];
      final bounds = oldTile.bounds;
      
      final nodesInTile = state.tileToNodes[tileIndex] ?? [];
      
      // Освобождаем старое изображение
      oldTile.image.dispose();
      
      // Создаем новый тайл со всеми узлами
      final newTile = await _createUpdatedTile(bounds, tileIndex, nodesInTile);
      if (newTile != null) {
        state.imageTiles[tileIndex] = newTile;
      }
      
      onStateUpdate();
    } catch (e) {
      print('Ошибка обновления тайла [$tileIndex]: $e');
    }
  }
  
  Future<ImageTile?> _createUpdatedTile(Rect bounds, int tileIndex, List<TableNode> nodes) async {
    try {
      // Фильтруем узлы, оставляя только корневые
      final rootNodes = _filterRootNodes(nodes);
      
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      canvas.scale(EditorConfig.tileScale, EditorConfig.tileScale);
      canvas.translate(-bounds.left, -bounds.top);
      
      // Прозрачный фон
      canvas.drawRect(
        bounds,
        Paint()
          ..color = Colors.transparent
          ..blendMode = BlendMode.src,
      );
      
      // Рисуем только корневые узлы
      _nodeRenderer.drawRootNodesToTile(
        canvas: canvas,
        rootNodes: rootNodes,
        tileBounds: bounds,
        delta: state.delta,
        cache: state.nodeBoundsCache,
      );
      
      final picture = recorder.endRecording();
      
      final double width = bounds.width;
      final double height = bounds.height;
      final int tileWidth = math.max(1, (width * EditorConfig.tileScale).ceil());
      final int tileHeight = math.max(1, (height * EditorConfig.tileScale).ceil());
      final int finalWidth = math.min(EditorConfig.tileSize, tileWidth);
      final int finalHeight = math.min(EditorConfig.tileSize, tileHeight);
      
      final image = await picture.toImage(finalWidth, finalHeight);
      picture.dispose();
      
      return ImageTile(
        image: image,
        bounds: bounds,
        scale: EditorConfig.tileScale,
        index: tileIndex,
      );
      
    } catch (e) {
      print('Ошибка создания обновленного тайла [$tileIndex]: $e');
      return null;
    }
  }
  
  /// Фильтрует список узлов, оставляя только корневые (без родителей в списке)
  List<TableNode> _filterRootNodes(List<TableNode> allNodes) {
    // Создаем Set ID всех узлов для быстрой проверки
    final allIds = allNodes.map((n) => n.id).toSet();
    
    return allNodes.where((node) {
      // Проверяем, есть ли у этого узла родитель в списке
      bool hasParentInList = false;
      
      // Ищем родителя (нужно пройти по всем узлам и проверить их children)
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
  
  Future<void> createFallbackTiles() async {
    try {
      print('Создание запасных тайлов...');
      
      state.totalBounds = Rect.fromLTRB(0, 0, 2000, 2000);
      final bounds = Rect.fromLTRB(0, 0, 2000, 2000);
      
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      canvas.drawRect(
        bounds,
        Paint()..color = Colors.transparent,
      );
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);
      picture.dispose();
      
      _disposeTiles();
      
      state.imageTiles = [
        ImageTile(
          image: image,
          bounds: bounds,
          scale: 1.0,
          index: 0,
        )
      ];
      
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
  }
  
  void dispose() {
    _disposeTiles();
  }
}