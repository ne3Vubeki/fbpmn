import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
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
import 'arrow_tile_coordinator.dart';

class TileManager {
  final EditorState state;
  final VoidCallback onStateUpdate;

  final BoundsCalculator _boundsCalculator = BoundsCalculator();
  final NodeRenderer _nodeRenderer = NodeRenderer();

  late ArrowTileCoordinator coordinator;

  TileManager({required this.state, required this.onStateUpdate}) {
    // Создаем ArrowTileCoordinator для проверки пересечений
    coordinator = ArrowTileCoordinator(
      arrows: state.arrows,
      nodes: state.nodes,
      nodeBoundsCache: state.nodeBoundsCache,
    );
  }

  Future<void> createTiledImage(
    List<TableNode> nodes,
    List<Arrow> arrows,
  ) async {
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
    final tiles = await _createTilesInGrid(0, 0, 2, 2, [], []);

    state.imageTiles = tiles;

    state.isLoading = false;
    onStateUpdate();
  }

  // Создание тайлов для узлов и стрелок
  Future<List<ImageTile>> _createTilesForContent(
    List<TableNode> allNodes,
    List<Arrow> allArrows,
  ) async {
    final Map<String, List<TableNode?>> mapNodesInTile =
        {}; // узлы для создаваемых тайлов
    final Map<String, List<Arrow?>> mapArrowssInTile =
        {}; // связи для создаваемых тайлов
    final createdTiles = <String>[];

    // Собираем все узлы (включая вложенные) для определения, где создавать тайлы
    final allNodesIncludingChildren = <TableNode>[];

    void collectAllNodes(List<TableNode> nodes) {
      for (final node in nodes) {
        // Пропускаем узлы, которые находятся внутри скрытых swimlane
        if (node.parent != null &&
            _isNodeHiddenInCollapsedSwimlane(node, allNodes)) {
          continue;
        }

        allNodesIncludingChildren.add(node);

        // Если это развернутый swimlane, добавляем детей как независимые узлы
        if (node.qType == 'swimlane' &&
            !(node.isCollapsed ?? false) &&
            node.children != null &&
            node.children!.isNotEmpty) {
          for (final child in node.children!) {
            // Пропускаем детей, если они находятся внутри скрытых swimlane
            if (!_isNodeHiddenInCollapsedSwimlane(child, allNodes)) {
              allNodesIncludingChildren.add(child);
            }
          }
        } else if (node.children != null &&
            node.children!.isNotEmpty &&
            !(node.qType == 'swimlane' && (node.isCollapsed ?? false))) {
          // Для других узлов или свернутых swimlane обрабатываем детей традиционно
          collectAllNodes(node.children!);
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
      // Пропускаем узлы, которые не должны отображаться на тайлах
      // Это включает детей свернутых swimlane, которые не видны
      if (_isNodeHiddenInCollapsedSwimlane(node, allNodes)) {
        continue;
      }

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

    print(allArrows);

    // Теперь обрабатываем стрелки - для каждой стрелки, которая пересекает тайлы, убедимся, что тайлы созданы
    for (final arrow in allArrows) {
      // Проверяем, связаны ли стрелки с узлами в скрытых swimlane
      final effectiveSourceNode = _getEffectiveNodeById(arrow.source, allNodes);
      final effectiveTargetNode = _getEffectiveNodeById(arrow.target, allNodes);

      // Пропускаем стрелки, связанные с узлами в скрытых swimlane
      if ((effectiveSourceNode != null &&
              _isNodeHiddenInCollapsedSwimlane(
                effectiveSourceNode,
                allNodes,
              )) ||
          (effectiveTargetNode != null &&
              _isNodeHiddenInCollapsedSwimlane(
                effectiveTargetNode,
                allNodes,
              ))) {
        continue;
      }

      // Получаем полный путь стрелки
      final coordinates = coordinator
          .getArrowPathForTiles(arrow, state.delta)
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

      // Рисуем стрелки, если они есть (используем новый ArrowTilePainter)
      if (arrowsInTile.isNotEmpty) {
        final arrowTilePainter = ArrowTilePainter(
          arrows: arrowsInTile,
          coordinator: coordinator,
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
      );
    } catch (e) {
      print('Ошибка создания тайла: $e');
      return null;
    }
  }

  // Проверка, является ли узел скрытым внутри свернутого swimlane
  bool _isNodeHiddenInCollapsedSwimlane(
    TableNode node,
    List<TableNode> allNodes,
  ) {
    if (node.parent == null) {
      return false; // У корневого узла нет родителя
    }

    // Найти родительский узел
    TableNode? findParent(List<TableNode> nodes) {
      for (final n in nodes) {
        if (n.id == node.parent) {
          return n;
        }

        if (n.children != null) {
          final result = findParent(n.children!);
          if (result != null) {
            return result;
          }
        }
      }
      return null;
    }

    final parent = findParent(allNodes);
    if (parent != null &&
        parent.qType == 'swimlane' &&
        (parent.isCollapsed ?? false)) {
      return true; // Узел находится внутри свернутого swimlane
    }

    return false;
  }

  // Получить узел по ID
  TableNode? _getEffectiveNodeById(String nodeId, List<TableNode> allNodes) {
    TableNode? findNodeRecursive(List<TableNode> nodeList) {
      for (final node in nodeList) {
        if (node.id == nodeId) {
          return node;
        }
        if (node.children != null) {
          final found = findNodeRecursive(node.children!);
          if (found != null) return found;
        }
      }
      return null;
    }

    return findNodeRecursive(allNodes);
  }

  // Получение узлов для тайла (исключая выделенные)
  List<TableNode> _getNodesForTile(Rect bounds, List<TableNode> allNodes) {
    final List<TableNode> nodesInTile = [];

    void checkNode(
      TableNode node,
      Offset parentOffset,
      bool parentCollapsed, {
      bool isChildOfExpandedSwimlane = false,
    }) {
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
              Offset
                  .zero, // Используем нулевое смещение, т.к. позиция будет браться напрямую
              parentCollapsed, // Дети развернутого swimlane не скрыты из-за родительского состояния
              isChildOfExpandedSwimlane:
                  true, // Отмечаем, что это дети развернутого swimlane
            );
          }
        } else {
          // Для свернутого swimlane или обычных узлов - традиционная логика
          final isCurrentCollapsed =
              node.qType == 'swimlane' && (node.isCollapsed ?? false);

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

  // Фильтрация корневых узлов
  List<TableNode?> _filterRootNodes(List<TableNode?> allNodes) {
    return allNodes.where((node) {
      // Для свернутых swimlane всегда считаем их корневыми
      if (node!.qType == 'swimlane' && (node.isCollapsed ?? false)) {
        return true;
      }

      bool hasParentInList = false;

      for (final potentialParent in allNodes) {
        // Если потенциальный родитель свернут, его дети не считаются
        if (potentialParent!.qType == 'swimlane' &&
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

      // Также находим стрелки, связанные с дочерним узлом
      final arrowsConnectedToChild = state.arrows
          .where(
            (arrow) => arrow.source == child.id || arrow.target == child.id,
          )
          .toList();

      // Для каждой связанной стрелки находим ВСЕ тайлы, через которые она проходит
      for (final arrow in arrowsConnectedToChild) {
        final arrowTiles = _findTilesForArrow(arrow);
        for (final tileIndex in arrowTiles) {
          tilesToUpdate.add(tileIndex);
        }

        // Также очищаем кэши стрелок для конкретной стрелки
        final tileIndices = state.arrowToTiles[arrow] ?? {};
        for (final tileIndex in tileIndices) {
          state.tileToArrows[tileIndex]?.remove(arrow);
        }
        state.arrowToTiles.remove(arrow);
      }
    }
  }

  /// Удаление детей group из тайлов
  Future<void> removeGroupChildrenFromTiles(
    TableNode groupNode,
    Set<int> tilesToUpdate,
  ) async {
    if (groupNode.children == null || groupNode.children!.isEmpty) {
      return;
    }

    // Удаляем всех детей из тайлов
    for (final child in groupNode.children!) {
      final childTileIndices = _findTilesContainingNode(child);
      for (final tileIndex in childTileIndices) {
        if (tileIndex < state.imageTiles.length) {
          tilesToUpdate.add(tileIndex);
        }
      }

      // Также находим стрелки, связанные с дочерним узлом
      final arrowsConnectedToChild = state.arrows
          .where(
            (arrow) => arrow.source == child.id || arrow.target == child.id,
          )
          .toList();

      // Для каждой связанной стрелки находим ВСЕ тайлы, через которые она проходит
      for (final arrow in arrowsConnectedToChild) {
        final arrowTiles = _findTilesForArrow(arrow);
        for (final tileIndex in arrowTiles) {
          tilesToUpdate.add(tileIndex);
        }

        // Также очищаем кэши стрелок для конкретной стрелки
        final tileIndices = state.arrowToTiles[arrow] ?? {};
        for (final tileIndex in tileIndices) {
          state.tileToArrows[tileIndex]?.remove(arrow);
        }
        state.arrowToTiles.remove(arrow);
      }
    }
  }

  // Удаление выделенного узла из тайлов
  Future<void> removeSelectedNodeFromTiles(TableNode node) async {
    final Set<int> tilesToUpdate = {};

    // Сначала находим ВСЕ стрелки, связанные с этим узлом
    final arrowsConnectedToNode = state.arrows
        .where((arrow) => arrow.source == node.id || arrow.target == node.id)
        .toList();

    // Если это закрытый swimlane или группа, добавляем также стрелки, связанные с дочерними узлами
    if ((node.qType == 'swimlane' || node.qType == 'group') &&
        (node.isCollapsed ?? false) &&
        node.children != null) {
      for (final child in node.children!) {
        arrowsConnectedToNode.addAll(
          state.arrows.where(
            (arrow) => arrow.source == child.id || arrow.target == child.id,
          ),
        );
      }
    }

    // Для каждой связанной стрелки находим ВСЕ тайлы, через которые она проходит
    for (final arrow in arrowsConnectedToNode) {
      final arrowTiles = _findTilesForArrow(arrow);
      print('Для связи ${arrow.id}: $arrowTiles');
      for (final tileIndex in arrowTiles) {
        tilesToUpdate.add(tileIndex);
      }

      // Также очищаем кэши стрелок для конкретной стрелки
      final tileIndices = state.arrowToTiles[arrow] ?? {};
      for (final tileIndex in tileIndices) {
        state.tileToArrows[tileIndex]?.remove(arrow);
      }
      state.arrowToTiles.remove(arrow);
    }

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
        await removeSwimlaneChildrenFromTiles(node, tilesToUpdate);
      }
      // Для группы в развернутом состоянии удаляем всех детей
      else if (node.qType == 'group' && !(node.isCollapsed ?? false)) {
        await removeGroupChildrenFromTiles(node, tilesToUpdate);
      }
      // Для закрытого swimlane или группы также обрабатываем дочерние узлы, чтобы удалить стрелки
      else if ((node.qType == 'swimlane' || node.qType == 'group') &&
          (node.isCollapsed ?? false)) {
        await removeSwimlaneChildrenFromTiles(
          node,
          tilesToUpdate,
        ); // используем тот же метод, так как логика одинакова
      }

      // Ищем тайлы, содержащие этот узел
      final tileIndices = _findTilesContainingNode(node);
      for (final tileIndex in tileIndices) {
        if (tileIndex < state.imageTiles.length) {
          tilesToUpdate.add(tileIndex);
        }
      }
    }

    // Обновляем ВСЕ тайлы, из которых удаляли узлы ИЛИ стрелки
    print('Тайлы для обновления: $tilesToUpdate');
    for (final tileIndex in tilesToUpdate) {
      await updateTileWithAllContent(tileIndex);
    }

    // Очищаем кэши стрелок
    _cleanupArrowCachesForNode(node);
  }

  // Очистка кэшей стрелок для удаленного узла
  void _cleanupArrowCachesForNode(TableNode node) {
    // Находим все стрелки, связанные с этим узлом
    final arrowsToRemove = <Arrow>[];
    for (final arrow in state.arrows) {
      if (arrow.source == node.id || arrow.target == node.id) {
        arrowsToRemove.add(arrow);
      }
    }

    // Если это закрытый swimlane или группа, добавляем также стрелки, связанные с дочерними узлами
    if ((node.qType == 'swimlane' || node.qType == 'group') &&
        (node.isCollapsed ?? false) &&
        node.children != null) {
      for (final child in node.children!) {
        for (final arrow in state.arrows) {
          if (arrow.source == child.id || arrow.target == child.id) {
            if (!arrowsToRemove.contains(arrow)) {
              arrowsToRemove.add(arrow);
            }
          }
        }
      }
    }

    // Удаляем эти стрелки из кэшей
    for (final arrow in arrowsToRemove) {
      final tileIndices = state.arrowToTiles[arrow] ?? {};
      for (final tileIndex in tileIndices) {
        state.tileToArrows[tileIndex]?.remove(arrow);
      }
      state.arrowToTiles.remove(arrow);
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
        if (currentNode.qType == 'swimlane' &&
            !(currentNode.isCollapsed ?? false)) {
          if (currentNode.children != null) {
            for (final child in currentNode.children!) {
              if (child.id == node.id) {
                return currentNode; // Нашли родительский развернутый swimlane
              }

              // Рекурсивно проверяем вложенные узлы
              TableNode? nestedParent = _findParentExpandedSwimlaneInNode(
                child,
                node,
              );
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

  /// Добавление стрелок, связанных с узлом обратно в тайлы (после сохранения)
  Future<void> addArrowsForNode(TableNode node, Offset nodePosition) async {
    final Set<int> tilesToUpdate = {};

    // Находим все стрелки, связанные с этим узлом (как источник или цель)
    final arrowsConnectedToNode = state.arrows
        .where((arrow) => arrow.source == node.id || arrow.target == node.id)
        .toList();

    // Для каждой связанной стрелки находим ВСЕ тайлы, через которые она проходит
    for (final arrow in arrowsConnectedToNode) {
      final arrowTiles = _findTilesForArrow(arrow);
      for (final tileIndex in arrowTiles) {
        tilesToUpdate.add(tileIndex);
      }
    }

    // Обновляем все тайлы, в которые добавили стрелки
    for (final tileIndex in tilesToUpdate) {
      await updateTileWithAllContent(tileIndex);
    }

    onStateUpdate();
  }

  // Добавление узла в тайлы (после перемещения)
  Future<void> addNodeToTiles(TableNode node, Offset nodePosition) async {
    final Set<int> tilesToUpdate = {};

    // Для swimlane в развернутом состоянии добавляем всех детей
    if (node.qType == 'swimlane' && !(node.isCollapsed ?? false)) {
      await _addSwimlaneChildrenToTiles(node, nodePosition, tilesToUpdate);
    }
    // Для group в развернутом состоянии добавляем всех детей
    else if (node.qType == 'group' && !(node.isCollapsed ?? false)) {
      await _addGroupChildrenToTiles(node, nodePosition, tilesToUpdate);
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
      await updateTileWithAllContent(tileIndex);
    }

    // Находим все стрелки, связанные с этим узлом
    final arrowsConnectedToNode = state.arrows
        .where((arrow) => arrow.source == node.id || arrow.target == node.id)
        .toList();

    // Для каждой связанной стрелки обновляем ВСЕ тайлы, через которые она проходит
    for (final arrow in arrowsConnectedToNode) {
      final arrowTiles = _findTilesForArrow(arrow);
      for (final tileIndex in arrowTiles) {
        if (!tilesToUpdate.contains(tileIndex)) {
          tilesToUpdate.add(tileIndex);
        }
      }
    }

    // Повторно обновляем все затронутые тайлы
    for (final tileIndex in tilesToUpdate) {
      await updateTileWithAllContent(tileIndex);
    }

    onStateUpdate();
  }

  // Создание обновленного тайла с узлами и стрелками
  Future<ImageTile?> _createUpdatedTileWithContent(
    Rect bounds,
    String tileId,
    List<TableNode> nodes,
    List<Arrow> arrows,
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

      // Рисуем стрелки, если они есть (используем ArrowTilePainter)
      if (arrows.isNotEmpty) {
        final arrowTilePainter = ArrowTilePainter(
          arrows: arrows,
          coordinator: coordinator,
        );
        arrowTilePainter.drawArrowsInTile(
          canvas: canvas,
          tileBounds: bounds,
          baseOffset: state.delta,
        );
      }

      final picture = recorder.endRecording();

      final image = await picture.toImage(tileImageSize, tileImageSize);
      picture.dispose();

      return ImageTile(image: image, bounds: bounds, scale: scale, id: tileId);
    } catch (e) {
      print('Ошибка создания обновленного тайла: $e');
      return null;
    }
  }

  // Найти все тайлы, через которые проходит стрелка
  Set<int> _findTilesForArrow(Arrow arrow) {
    final Set<int> tileIndices = {};

    // Ищем тайлы по стрелке в state.tileToArrows
    state.tileToArrows.forEach((tileIndex, arrows) {
      if (arrows.contains(arrow)) {
        tileIndices.add(tileIndex);
      }
    });

    // Также ищем тайлы, в которых может быть стрелка, но кэш еще не обновлен
    // Проверяем каждый тайл на наличие стрелки с помощью ArrowTileCoordinator
    for (int i = 0; i < state.imageTiles.length; i++) {
      final tile = state.imageTiles[i];

      // Создаем координатор для проверки пересечения
      final coordinator = ArrowTileCoordinator(
        arrows: [arrow],
        nodes: state.nodes,
        nodeBoundsCache: state.nodeBoundsCache,
      );

      if (coordinator.doesArrowIntersectTile(arrow, tile.bounds, state.delta)) {
        tileIndices.add(i);
      }
    }

    return tileIndices;
  }

  /// Добавление детей swimlane в тайлы
  Future<void> _addSwimlaneChildrenToTiles(
    TableNode swimlaneNode,
    Offset parentWorldPosition,
    Set<int> tilesToUpdate,
  ) async {
    // Определяем, является ли swimlane развернутым
    final isExpanded =
        swimlaneNode.qType == 'swimlane' &&
        !(swimlaneNode.isCollapsed ?? false);

    // Добавляем всех детей в тайлы
    for (final child in swimlaneNode.children!) {
      // Пропускаем детей, которые находятся внутри скрытых swimlane
      if (_isNodeHiddenInCollapsedSwimlane(child, state.nodes)) {
        continue;
      }

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

  /// Добавление детей group в тайлы
  Future<void> _addGroupChildrenToTiles(
    TableNode groupNode,
    Offset parentWorldPosition,
    Set<int> tilesToUpdate,
  ) async {
    // Определяем, является ли group развернутым
    final isExpanded =
        groupNode.qType == 'group' && !(groupNode.isCollapsed ?? false);

    // Добавляем всех детей в тайлы
    for (final child in groupNode.children!) {
      // Пропускаем детей, которые находятся внутри скрытых swimlane
      if (_isNodeHiddenInCollapsedSwimlane(child, state.nodes)) {
        continue;
      }

      // Вычисляем мировые координаты ребенка
      // Для развернутой группы используем абсолютную позицию ребенка напрямую
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

      // Создаем новый тайл со ВСЕМИ узлами и стрелками в этой области
      // Используем state.nodes и state.arrows (все узлы и стрелки)
      final tile = await _createTileAtPosition(
        left,
        top,
        state.nodes,
        state.arrows,
      );

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
    await createTiledImage(state.nodes, state.arrows);

    // Уведомляем об изменении
    onStateUpdate();
  }

  /// Обновление тайла со ВСЕМИ узлами и стрелками
  Future<void> updateTileWithAllContent(int tileIndex) async {
    if (tileIndex < 0 || tileIndex >= state.imageTiles.length) {
      return;
    }

    try {
      final oldTile = state.imageTiles[tileIndex];
      final tileId = oldTile.id;
      final bounds = oldTile.bounds;

      print('Update tile: $tileId');

      // Получаем ВСЕ узлы для этого тайла из state.nodes
      final nodesInTile = _getNodesForTile(bounds, state.nodes);

      // Получаем ВСЕ стрелки для этого тайла из state.arrows
      // Важно: учитываем ВСЕ стрелки, а не только те, что связаны с узлами в этом тайле
      final arrowsInTile = state.tileToArrows[tileIndex] ?? [];

      // Очищаем старый кэш для этого тайла
      state.tileToNodes.remove(tileIndex);
      state.tileToArrows.remove(tileIndex);

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

      // Если в тайле есть стрелки, обновляем кэш
      if (arrowsInTile.isNotEmpty) {
        state.tileToArrows[tileIndex] = arrowsInTile;

        // Обновляем кэш arrowToTiles для всех стрелок в тайле
        for (final arrow in arrowsInTile) {
          if (!state.arrowToTiles.containsKey(arrow)) {
            state.arrowToTiles[arrow] = {};
          }
          state.arrowToTiles[arrow]!.add(tileIndex);
        }
      } else {
        // Если стрелок нет, удаляем их из кэша для этого тайла
        state.tileToArrows.remove(tileIndex);
      }

      oldTile.image.dispose();

      // Перерисовываем тайл со ВСЕМИ узлами и стрелками
      final newTile = await _createUpdatedTileWithContent(
        bounds,
        tileId,
        nodesInTile,
        arrowsInTile,
      );
      if (newTile != null) {
        state.imageTiles[tileIndex] = newTile;
      } else if (nodesInTile.isEmpty && arrowsInTile.isEmpty) {
        // Если тайл пустой, удаляем его
        await _removeTile(tileId);
      }

      onStateUpdate();
    } catch (e) {
      print('Ошибка обновления тайла $tileIndex: $e');
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
    state.imageTiles.clear();
    state.nodeBoundsCache.clear();
    state.tileToNodes.clear();
    state.nodeToTiles.clear();
  }

  void dispose() {
    _disposeTiles();
  }
}
