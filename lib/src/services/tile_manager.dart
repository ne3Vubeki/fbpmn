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
      // Получаем узлы для этого тайла (исключая узел на верхнем слое, если он есть)
      final nodesInTile = _boundsCalculator.getNodesForTile(
        bounds: bounds,
        allNodes: allNodes,
        delta: state.delta,
        excludedNode: state.isNodeOnTopLayer ? state.selectedNodeOnTopLayer : null,
      );
      
      // Даже если узлов нет, создаем пустой тайл для сохранения структуры
      
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
      
      // Рисуем узлы, которые попадают в границы тайла
      for (final node in nodesInTile) {
        _nodeRenderer.drawNodeToTile(
          canvas: canvas,
          node: node,
          tileBounds: bounds,
          delta: state.delta,
          cache: state.nodeBoundsCache,
        );
      }
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(finalWidth, finalHeight);
      picture.dispose();
      
      // Создаем карту узлов для этого тайла
      _updateNodeTileMappings(tileIndex, nodesInTile);
      
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
    
    final tileIndices = state.nodeToTiles[node];
    if (tileIndices == null || tileIndices.isEmpty) {
      print('Узел не найден в тайлах');
      return;
    }
    
    print('Обновление тайлов: ${tileIndices.toList()}');
    
    // Обновляем каждый тайл, удаляя узел
    for (final tileIndex in tileIndices) {
      await _updateTileWithoutNode(tileIndex, node);
    }
    
    // Удаляем узел из кэша
    state.nodeToTiles.remove(node);
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
      
      // Фильтруем узлы, исключая удаляемый
      final filteredNodes = currentNodes.where((node) => node.id != nodeToRemove.id).toList();
      
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
    
    // Определяем, в какие тайлы попадает узел с новой позицией
    final tileIndices = _boundsCalculator.getTileIndicesForNode(
      node: node,
      nodePosition: nodePosition,
      imageTiles: state.imageTiles,
    );
    
    if (tileIndices.isEmpty) {
      print('Узел не попадает ни в один тайл');
      return;
    }
    
    print('Узел попадает в тайлы: ${tileIndices.toList()}');
    
    // Обновляем кэш
    state.nodeToTiles[node] = tileIndices;
    
    // Обновляем каждый тайл
    for (final tileIndex in tileIndices) {
      // Добавляем узел в список узлов тайла (если еще нет)
      final nodesInTile = state.tileToNodes[tileIndex] ?? [];
      if (!nodesInTile.any((n) => n.id == node.id)) {
        nodesInTile.add(node);
        state.tileToNodes[tileIndex] = nodesInTile;
      }
      
      // Обновляем тайл
      await _updateTileWithAllNodes(tileIndex);
    }
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
      
      // Рисуем все узлы
      for (final node in nodes) {
        _nodeRenderer.drawNodeToTile(
          canvas: canvas,
          node: node,
          tileBounds: bounds,
          delta: state.delta,
          cache: state.nodeBoundsCache,
        );
      }
      
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