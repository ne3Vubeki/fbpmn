import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/image_tile.dart';
import '../models/table.node.dart';
import '../models/arrow.dart';
import '../editor_state.dart';
import '../utils/bounds_calculator.dart';
import '../utils/node_renderer.dart';
import '../utils/editor_config.dart';
import '../painters/arrow_tile_painter.dart';
import 'arrow_manager.dart';

class TileManager {
  final EditorState state;
  final VoidCallback onStateUpdate;

  final BoundsCalculator _boundsCalculator = BoundsCalculator();
  final NodeRenderer _nodeRenderer = NodeRenderer();

  late ArrowManager arrowManager;

  TileManager({required this.state, required this.onStateUpdate}) {
    // Создаем ArrowManager для проверки пересечений
    arrowManager = ArrowManager(
      arrows: state.arrows,
      nodes: state.nodes,
      nodeBoundsCache: state.nodeBoundsCache,
    );
  }

  Future<void> createTiledImage(
    List<TableNode?> nodes,
    List<Arrow?> arrows, {
    bool isUpdate = false,
  }) async {
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

      // Создаем тайлы только там где есть узлы или стрелки
      final tiles = await _createTilesForContent(nodes, arrows);

      if (isUpdate) {
        for (final tile in tiles) {
          if (state.imageTiles.any((t) => t.id == tile.id)) {
            state.imageTilesChanged.any((tileId) => tileId == tile.id)
                ? _restoreTile(tile.id, tile)
                : null;
          } else {
            state.imageTiles.add(tile);
          }
        }
      } else {
        state.imageTiles = tiles;
      }

      state.isLoading = false;
      onStateUpdate();
    } catch (e) {
      await createFallbackTiles();
    }
  }

  // Создание начальных тайлов
  Future<void> _createInitialTiles() async {
    // Создаем 4 тайла для начальной видимой области
    final tiles = await _createTilesInGrid(0, 0, 2, 2, [], []);

    state.imageTiles = tiles;

    state.isLoading = false;
    onStateUpdate();
  }

  // Создание тайлов для узлов и стрелок
  Future<List<ImageTile>> _createTilesForContent(
    List<TableNode?> allNodes,
    List<Arrow?> allArrows,
  ) async {
    final Map<String, List<TableNode?>> mapNodesInTile =
        {}; // узлы для создаваемых тайлов
    final Map<String, List<Arrow?>> mapArrowssInTile =
        {}; // связи для создаваемых тайлов
    final createdTiles = <String>[];

    // Собираем все узлы (включая вложенные) для определения, где создавать тайлы
    final allNodesIncludingChildren = <TableNode>[];

    void collectAllNodes(List<TableNode?> nodes, {TableNode? parent}) {
      for (final node in nodes) {
        if (parent == null) {
          allNodesIncludingChildren.add(node!);
          if (node.children != null && node.children!.isNotEmpty) {
            collectAllNodes(node.children!, parent: node);
          }
        } else {
          if (parent.isCollapsed == null || !parent.isCollapsed!) {
            allNodesIncludingChildren.add(node!);
          }
        }
      }
    }

    Future<void> createTiles({
      required double left,
      required double top,
      TableNode? node,
      Arrow? arrow,
    }) async {
      final tileId = _generateTileId(left, top);
      if (!createdTiles.contains(tileId)) {
        createdTiles.add(tileId);
      }
      if (mapNodesInTile[tileId] == null) {
        // Создаем маптайл в этой позиции
        mapNodesInTile[tileId] = node != null ? [node] : <TableNode>[];
      } else {
        node != null && !mapNodesInTile[tileId]!.contains(node)
            ? mapNodesInTile[tileId]!.add(node)
            : null;
      }
      if (mapArrowssInTile[tileId] == null) {
        // Создаем маптайл в этой позиции
        mapArrowssInTile[tileId] = arrow != null ? [arrow] : <Arrow>[];
      } else {
        arrow != null && !mapArrowssInTile[tileId]!.contains(arrow)
            ? mapArrowssInTile[tileId]!.add(arrow)
            : null;
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
          await createTiles(top: top, left: left, node: node);
        }
      }
    }

    // Теперь обрабатываем стрелки - для каждой стрелки, которая пересекает тайлы, убедимся, что тайлы созданы
    for (final arrow in allArrows) {
      final Arrow arrowCopy = arrow!.copyWith();

      /// Перенаправляем связи скрытых узлов на узел родителя
      for (final n in allNodesIncludingChildren) {
        if (n.isCollapsed == true &&
            n.children != null &&
            n.children!.isNotEmpty) {
          final children = n.children;
          for (final child in children!) {
            if (arrowCopy.source == child.id) {
              arrowCopy.source = n.id;
              break;
            }
            if (arrowCopy.target == child.id) {
              arrowCopy.target = n.id;
              break;
            }
          }
        }
      }

      // Получаем полный путь стрелки
      final coordinates = arrowManager
          .getArrowPathForTiles(arrowCopy, state.delta)
          .coordinates;
      final tileWorldSize = EditorConfig.tileSize.toDouble();

      if (coordinates.isNotEmpty) {
        for (int ind = 0; ind < coordinates.length - 1; ind++) {
          final coordStart = coordinates[ind];
          final coordEnd = coordinates[ind + 1];

          /// Вертикальный отрезок связи
          if (coordStart.dx == coordEnd.dx) {
            final gridYStart =
                (math.min(coordStart.dy, coordEnd.dy) / tileWorldSize).floor();
            final gridYEnd =
                (math.max(coordStart.dy, coordEnd.dy) / tileWorldSize).ceil();
            final gridX = (coordStart.dx / tileWorldSize).floor();
            for (int gridY = gridYStart; gridY < gridYEnd; gridY++) {
              final left = gridX * tileWorldSize;
              final top = gridY * tileWorldSize;
              await createTiles(top: top, left: left, arrow: arrow);
            }
          }
          /// Горизонтальный отрезок связи
          else {
            final gridXStart =
                (math.min(coordStart.dx, coordEnd.dx) / tileWorldSize).floor();
            final gridXEnd =
                (math.max(coordStart.dx, coordEnd.dx) / tileWorldSize).ceil();
            final gridY = (coordStart.dy / tileWorldSize).floor();
            for (int gridX = gridXStart; gridX < gridXEnd; gridX++) {
              final left = gridX * tileWorldSize;
              final top = gridY * tileWorldSize;
              await createTiles(top: top, left: left, arrow: arrow);
            }
          }
        }
      }
    }

    final List<ImageTile> tiles = [];

    /// Создание тайлов рассчитанным узлам и связям
    for (final tileId in createdTiles) {
      final tilePos = tileId.split(':');
      final left = double.tryParse(tilePos.first);
      final top = double.tryParse(tilePos.last);
      final List<TableNode?> nodesInTile = mapNodesInTile[tileId]!;
      final List<Arrow?> arrowsInTile = mapArrowssInTile[tileId]!;
      final ImageTile? tile = await _createTileAtPosition(
        left!,
        top!,
        nodesInTile,
        arrowsInTile,
      );
      tile != null ? tiles.add(tile) : null;
    }

    return tiles;
  }

  ImageTile? getTileById(List<ImageTile> tiles, String id) {
    return tiles.firstWhereOrNull((tile) => tile.id == id);
  }

  // Генерация ID тайла на основе мировых координат
  String _generateTileId(double left, double top) {
    return '${left.toInt()}:${top.toInt()}';
  }

  // Создание тайла в указанной позиции
  Future<ImageTile?> _createTileAtPosition(
    double left,
    double top,
    List<TableNode?> nodesInTile,
    List<Arrow?> arrowsInTile,
  ) async {
    // Всегда создаем тайл фиксированного размера, кратного 1024
    final tileWorldSize = EditorConfig.tileSize.toDouble();
    final tileBounds = Rect.fromLTRB(
      left,
      top,
      left + tileWorldSize,
      top + tileWorldSize,
    );

    // ID тайла в формате 'left:top' (мировые координаты)
    final tileId = _generateTileId(left, top);

    return _createUpdatedTileWithContent(
      tileBounds,
      tileId,
      nodesInTile,
      arrowsInTile,
    );
  }

  // Получение узлов для тайла (исключая выделенные)
  List<TableNode?> _getNodesForTile(ImageTile tile) {
    return NodeManager.nodeRecurcive(
      state.nodes,
      (node) => tile.nodes.contains(node.id),
    );
  }

  // Получение связей для тайла (исключая выделенные)
  List<Arrow?> _getArrowsForTile(ImageTile tile) {
    return state.arrows
        .where((arrow) => tile.arrows.contains(arrow.id))
        .toList();
  }

  // Создание тайлов в grid сетке
  Future<List<ImageTile>> _createTilesInGrid(
    int startX,
    int startY,
    int width,
    int height,
    List<TableNode> allNodes,
    List<Arrow> allArrows,
  ) async {
    final List<ImageTile> tiles = [];
    final tileWorldSize = EditorConfig.tileSize.toDouble();

    for (int y = startY; y < startY + height; y++) {
      for (int x = startX; x < startX + width; x++) {
        final left = x * tileWorldSize;
        final top = y * tileWorldSize;
        final tile = await _createTileAtPosition(
          left,
          top,
          allNodes,
          allArrows,
        );
        if (tile != null) {
          tiles.add(tile);
        }
      }
    }

    return tiles;
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

  /// Сортирует узлы так, чтобы swimlane были после своих детей
  List<TableNode?> _sortNodesWithSwimlaneLast(List<TableNode?> nodes) {
    final List<TableNode> nonSwimlaneNodes = [];
    final List<TableNode> swimlaneNodes = [];

    for (final node in nodes) {
      if (node!.qType == 'swimlane') {
        swimlaneNodes.add(node);
      } else {
        nonSwimlaneNodes.add(node);
      }
    }

    // Сначала не-swimlane узлы, потом swimlane
    return [...nonSwimlaneNodes, ...swimlaneNodes];
  }

  /// Удаление детей swimlane из тайлов
  Future<void> removeSwimlaneChildrenFromTiles(
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

  /// Удаление выделенного узла из тайлов
  Future<void> removeSelectedNodeFromTiles(TableNode node) async {
    final Set<ImageTile> tilesToUpdate = {};
    final Set<String?> arrowIdsConnectedToNode = {};

    Set<String> nodeIds = {node.id};

    /// Находим все связи этого узла
    for (final arrow in state.arrows) {
      if (arrow.source == node.id || arrow.target == node.id) {
        arrowIdsConnectedToNode.add(arrow.id);
        state.arrowsSelected.add(arrow);
      }
      if (node.children != null && node.children!.isNotEmpty) {
        for (final n in node.children!) {
          if (arrow.source == n.id || arrow.target == n.id) {
            arrowIdsConnectedToNode.add(arrow.id);
            state.arrowsSelected.add(arrow);
          }
        }
      }
    }

    /// Находим и добавляем для удаления id вложенных в группу узлов
    if (node.qType == 'group' &&
        node.children != null &&
        node.children!.isNotEmpty) {
      for (final child in node.children!) {
        nodeIds.add(child.id);
      }
    }

    /// Находим все тайлы содержащие этот узел, удаляем узел и его связи
    for (final tile in state.imageTiles) {
      if (nodeIds.any((id) => tile.nodes.contains(id))) {
        // удаляем узел из списка узлов в тайле
        tile.nodes.removeAll(nodeIds);
        tile.arrows.removeAll(arrowIdsConnectedToNode);
        tilesToUpdate.add(tile);
      }
    }

    /// Находим все тайлы содержащие связи этого узла и удаляем связи
    for (final tile in state.imageTiles) {
      if (arrowIdsConnectedToNode.any(
        (arrowId) => tile.arrows.contains(arrowId),
      )) {
        tile.arrows.removeAll(arrowIdsConnectedToNode);
        tilesToUpdate.add(tile);
      }
    }

    // Обновляем ВСЕ тайлы, из которых удаляли узлы ИЛИ стрелки
    print('Тайлы для обновления: $tilesToUpdate');
    for (final tile in tilesToUpdate) {
      await updateTileWithAllContent(tile);
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

  // ignore: unused_element
  TableNode? _findParentExpandedSwimlaneInNode(
    TableNode parent,
    TableNode targetNode,
  ) {
    if (parent.children != null) {
      for (final child in parent.children!) {
        if (child.id == targetNode.id) {
          if (parent.qType == 'swimlane' && !(parent.isCollapsed ?? false)) {
            return parent; // Нашли родительский развернутый swimlane
          }
        }

        // Рекурсивно проверяем вложенные узлы
        TableNode? result = _findParentExpandedSwimlaneInNode(
          child,
          targetNode,
        );
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

  // Обновление тайла по id
  Future<void> _restoreTile(String tileId, ImageTile tile) async {
    final tileIndex = _findTileIndexById(tileId);
    if (tileIndex == null) return;

    try {
      state.imageTiles[tileIndex] = tile;

      onStateUpdate();
    } catch (e) {}
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

      onStateUpdate();
    } catch (e) {}
  }

  // Добавление узла в тайлы (после перемещения)
  Future<void> addNodeToTiles(TableNode node) async {
    // Создаем тайлы только там где есть узлы или стрелки
    final tiles = await _createTilesForContent(
      state.nodesSelected.toList(),
      state.arrowsSelected.toList(),
    );

    // Обновляем все тайлы, в которые добавили стрелки
    for (final tile in tiles) {
      await updateTileWithAllContent(tile);
    }

    onStateUpdate();
  }

  // Создание обновленного тайла с узлами и стрелками
  Future<ImageTile?> _createUpdatedTileWithContent(
    Rect tileBounds,
    String tileId,
    List<TableNode?> nodesInTile,
    List<Arrow?> arrowsInTile,
  ) async {
    try {
      // Фиксированный размер изображения
      final int tileImageSize = EditorConfig.tileSize;
      final double scale = 1.0;

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

      if (nodesInTile.isNotEmpty) {
        // ВАЖНО: Сортируем узлы так, чтобы swimlane были после своих детей
        final sortedNodes = _sortNodesWithSwimlaneLast(nodesInTile);
        _nodeRenderer.drawRootNodesToTile(
          canvas: canvas,
          nodes: sortedNodes,
          tileBounds: tileBounds,
          delta: state.delta,
        );
      }

      // Рисуем стрелки, если они есть (используем ArrowTilePainter)
      if (arrowsInTile.isNotEmpty) {
        final arrowTilePainter = ArrowTilePainter(
          arrows: arrowsInTile,
          arrowManager: arrowManager,
        );
        arrowTilePainter.drawArrowsInTile(
          canvas: canvas,
          tileBounds: tileBounds,
          baseOffset: state.delta,
        );
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(tileImageSize, tileImageSize);
      picture.dispose();

      // Возвращаем тайл вместе с данными для последующего обновления маппингов
      return ImageTile(
        image: image,
        bounds: tileBounds,
        scale: scale,
        id: tileId,
        nodes: nodesInTile.map((node) => node?.id).toSet(),
        arrows: arrowsInTile.map((arrow) => arrow?.id).toSet(),
      );
    } catch (e) {
      print('Ошибка создания обновленного тайла: $e');
      return null;
    }
  }

  // Пересоздаем тайлы с выбранными узлами, их опонентами и связями
  Future<void> updateTilesAfterNodeChange() async {
    Set<TableNode?> nodes = {...state.nodesSelected};
    Set<Arrow?> arrows = {...state.arrowsSelected};

    // for (final arrow in arrows) {
    //   final node = state.nodes.firstWhereOrNull(
    //     (n) => n.id == arrow!.source || n.id == arrow.target,
    //   );
    //   nodes.add(node);
    // }

    // for (final tileId in state.imageTilesChanged) {
    //   final tile = getTileById(state.imageTiles, tileId);
    //   nodes.addAll(_getNodesForTile(tile!));
    //   arrows.addAll(_getArrowsForTile(tile));
    // }

    await createTiledImage(state.nodes, state.arrows, isUpdate: false);

    state.imageTilesChanged.clear();

    // Уведомляем об изменении
    onStateUpdate();
  }

  /// Обновление тайла со ВСЕМИ узлами и стрелками
  Future<void> updateTileWithAllContent(ImageTile tile) async {
    try {
      final tileId = tile.id;
      final bounds = tile.bounds;

      print('Update tile: $tileId');

      state.imageTilesChanged.add(tileId);

      // Получаем ВСЕ узлы для этого тайла из state.nodes
      final nodesInTile = _getNodesForTile(tile);

      // Получаем ВСЕ стрелки для этого тайла из state.arrows
      final arrowsInTile = _getArrowsForTile(tile);

      // tile.image.dispose();

      // Перерисовываем тайл со ВСЕМИ узлами и стрелками
      final newTile = await _createUpdatedTileWithContent(
        bounds,
        tileId,
        nodesInTile,
        arrowsInTile,
      );
      if (newTile != null) {
        await _restoreTile(tileId, newTile);
      } else if (nodesInTile.isEmpty && arrowsInTile.isEmpty) {
        // Если тайл пустой, удаляем его
        await _removeTile(tileId);
      }
    } catch (e) {
      print('Ошибка обновления тайла ${tile.id}: $e');
    }
  }

  Future<void> createFallbackTiles() async {
    try {
      _disposeTiles();

      // Создаем 4 начальных тайла
      final tiles = await _createTilesInGrid(0, 0, 2, 2, [], []);

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
    state.nodeBoundsCache.clear();
  }

  void dispose() {
    _disposeTiles();
  }
}
