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
import '../painters/arrow_painter.dart';
import '../utils/node_renderer.dart';
import '../utils/editor_config.dart';
import '../utils/utils.dart';
import 'arrow_manager.dart';
import 'manager.dart';

class TileManager extends Manager {
  final EditorState state;
  final ArrowManager arrowManager;

  final NodeRenderer _nodeRenderer = NodeRenderer();

  TileManager({required this.state, required this.arrowManager});

  /// Получает ID узлов, связанных с выделенными узлами (на другом конце связей)
  /// Для group: подсвечивается родитель и вложенные узлы
  /// Для swimlane: если раскрыт - только родитель, если свернут - родитель и вложенные
  Set<String> getConnectedNodeIds(Set<TableNode?> selectedNodes) {
    final Set<String> connectedIds = {};
    final Set<String> selectedIds = {};

    // Собираем ID всех выделенных узлов (включая вложенные)
    for (final node in selectedNodes) {
      if (node == null) continue;
      selectedIds.add(node.id);
      if (node.children != null) {
        for (final child in node.children!) {
          selectedIds.add(child.id);
        }
      }
    }

    // Находим все связи, связанные с выделенными узлами
    final arrows = arrowManager.getArrowsForNodes(selectedNodes.toList());

    for (final arrow in arrows) {
      if (arrow == null) continue;

      // Если source выделен, добавляем target
      if (selectedIds.contains(arrow.source)) {
        _addConnectedNodeWithRules(arrow.target, connectedIds, selectedIds);
      }
      // Если target выделен, добавляем source
      if (selectedIds.contains(arrow.target)) {
        _addConnectedNodeWithRules(arrow.source, connectedIds, selectedIds);
      }
    }

    return connectedIds;
  }

  /// Добавляет узел в список подсвеченных с учетом правил для group/swimlane
  void _addConnectedNodeWithRules(String nodeId, Set<String> connectedIds, Set<String> selectedIds) {
    // Не добавляем, если узел уже выделен
    if (selectedIds.contains(nodeId)) return;

    // Находим узел по ID
    final node = _findNodeById(nodeId);
    if (node == null) return;

    // Проверяем, является ли узел вложенным
    final parentNode = _findParentNode(nodeId);

    if (parentNode != null) {
      // Узел вложенный
      if (parentNode.qType == 'group') {
        // Для group: закрашиваем родителя и вложенный узел
        connectedIds.add(parentNode.id);
        connectedIds.add(nodeId);
      } else if (parentNode.qType == 'swimlane') {
        // Для swimlane: если раскрыт - только родитель, если свернут - родитель и вложенные
        if (parentNode.isCollapsed == true) {
          // Свернут - закрашиваем родителя и вложенные узлы по отдельности
          connectedIds.add(parentNode.id);
          connectedIds.add(nodeId);
        } else {
          // Раскрыт - закрашиваем только родителя
          connectedIds.add(parentNode.id);
        }
      }
    } else {
      // Узел корневой
      if (node.qType == 'group') {
        // Для group: закрашиваем родителя и вложенные узлы
        connectedIds.add(nodeId);
        if (node.children != null) {
          for (final child in node.children!) {
            connectedIds.add(child.id);
          }
        }
      } else if (node.qType == 'swimlane') {
        // Для swimlane: если раскрыт - только родитель, если свернут - родитель и вложенные
        connectedIds.add(nodeId);
        if (node.isCollapsed == true && node.children != null) {
          for (final child in node.children!) {
            connectedIds.add(child.id);
          }
        }
      } else {
        // Обычный узел
        connectedIds.add(nodeId);
      }
    }
  }

  /// Находит узел по ID во всей иерархии
  TableNode? _findNodeById(String nodeId) {
    TableNode? findRecursive(List<TableNode> nodes) {
      for (final node in nodes) {
        if (node.id == nodeId) return node;
        if (node.children != null && node.children!.isNotEmpty) {
          final found = findRecursive(node.children!);
          if (found != null) return found;
        }
      }
      return null;
    }
    return findRecursive(state.nodes);
  }

  /// Находит родительский узел для указанного ID
  TableNode? _findParentNode(String nodeId) {
    TableNode? findParentRecursive(List<TableNode> nodes, TableNode? parent) {
      for (final node in nodes) {
        if (node.id == nodeId) return parent;
        if (node.children != null && node.children!.isNotEmpty) {
          final found = findParentRecursive(node.children!, node);
          if (found != null) return found;
        }
      }
      return null;
    }
    return findParentRecursive(state.nodes, null);
  }

  /// Обновляет список подсвеченных узлов на основе текущего выделения
  void updateHighlightedNodes() {
    state.highlightedNodeIds.clear();
    if (state.nodesSelected.isNotEmpty) {
      state.highlightedNodeIds.addAll(getConnectedNodeIds(state.nodesSelected));
    }
  }

  Future<void> createTiledImage(List<TableNode?> nodes, List<Arrow?> arrows, {bool isUpdate = false}) async {
    try {
      // Очищаем старые данные только при полном пересоздании
      if (!isUpdate) {
        await _disposeTiles();
      }

      if (nodes.isEmpty) {
        // Если узлов нет, создаем несколько пустых тайлов для начала
        await _createInitialTiles();
        return;
      }

      // Создаем тайлы только там где есть узлы или стрелки
      final tiles = await _createTilesForContent(nodes, arrows);

      if (isUpdate) {
        // Собираем ID новых тайлов
        final newTileIds = tiles.map((t) => t.id).toSet();

        // Удаляем старые тайлы, которых нет в новом списке
        final tilesToRemove = state.imageTiles.where((t) => !newTileIds.contains(t.id)).toList();
        for (final oldTile in tilesToRemove) {
          try {
            oldTile.image.dispose();
          } catch (e) {
            print('Warning: Error disposing removed tile: $e');
          }
        }

        // Создаем новый список тайлов
        final updatedTiles = <ImageTile>[];
        
        // Обновляем существующие и добавляем новые тайлы
        for (final tile in tiles) {
          final existingIndex = state.imageTiles.indexWhere((t) => t.id == tile.id);
          if (existingIndex >= 0) {
            // Тайл существует - dispose старого и добавляем новый
            try {
              state.imageTiles[existingIndex].image.dispose();
            } catch (e) {
              print('Warning: Error disposing old tile in update: $e');
            }
          }
          updatedTiles.add(tile);
        }
        
        // Заменяем список целиком для корректного отслеживания изменений
        state.imageTiles = updatedTiles;
      } else {
        state.imageTiles = tiles;
      }
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
  Future<List<ImageTile>> _createTilesForContent(List<TableNode?> allNodes, List<Arrow?> allArrows) async {
    final Map<String, List<TableNode?>> mapNodesInTile = {}; // узлы для создаваемых тайлов
    final Map<String, List<Arrow?>> mapArrowsInTile = {}; // связи для создаваемых тайлов
    final createdTiles = <String>[];

    // Удаляем все коннекты из выбранных узлов для повторного расчета
    for (var node in allNodes) {
      node?.connections?.removeAll();
    }

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

    Future<void> createTiles({required double left, required double top, TableNode? node, Arrow? arrow}) async {
      final tileId = _generateTileId(left, top);
      if (!createdTiles.contains(tileId)) {
        createdTiles.add(tileId);
      }
      if (mapNodesInTile[tileId] == null) {
        // Создаем маптайл в этой позиции
        mapNodesInTile[tileId] = node != null ? [node] : <TableNode>[];
      } else {
        node != null && !mapNodesInTile[tileId]!.contains(node) ? mapNodesInTile[tileId]!.add(node) : null;
      }
      if (mapArrowsInTile[tileId] == null) {
        // Создаем маптайл в этой позиции
        mapArrowsInTile[tileId] = arrow != null ? [arrow] : <Arrow>[];
      } else {
        arrow != null && !mapArrowsInTile[tileId]!.contains(arrow) ? mapArrowsInTile[tileId]!.add(arrow) : null;
      }
    }

    collectAllNodes(allNodes);

    // Для каждого узла (включая вложенные) создаем тайлы в нужных позициях
    for (final node in allNodesIncludingChildren) {
      // Получаем абсолютную позицию узла
      final nodePosition = node.aPosition ?? (state.delta + node.position);
      final nodeRect = Utils.calculateNodeRect(node: node, position: nodePosition);

      await _tilesIntersectingRect(
        nodeRect,
        callback: ({required double left, required double top}) async {
          await createTiles(top: top, left: left, node: node);
        },
      );
    }

    // Теперь обрабатываем стрелки - для каждой стрелки, которая пересекает тайлы, убедимся, что тайлы созданы
    for (final arrow in allArrows) {
      final Arrow arrowCopy = arrow!;

      /// Перенаправляем связи скрытых узлов на узел родителя
      for (final n in allNodesIncludingChildren) {
        if (n.children != null && n.children!.isNotEmpty) {
          final children = n.children;
          for (final child in children!) {
            if (n.isCollapsed == true) {
              if (arrowCopy.source == child.id) {
                arrowCopy.sourceCache = arrowCopy.source;
                arrowCopy.source = n.id;
              }
              if (arrowCopy.target == child.id) {
                arrowCopy.targetCache = arrowCopy.target;
                arrowCopy.target = n.id;
              }
              if (arrowCopy.source == arrowCopy.target) {
                break;
              }
            } else {
              if (arrowCopy.sourceCache == child.id) {
                arrowCopy.source = arrowCopy.sourceCache!;
                arrowCopy.sourceCache = null;
              }
              if (arrowCopy.targetCache == child.id) {
                arrowCopy.target = arrowCopy.targetCache!;
                arrowCopy.targetCache = null;
              }
            }
          }
        }
      }

      // не отображаем замкнутую стрелку
      if (arrowCopy.source == arrowCopy.target) {
        continue;
      }

      // Получаем полный путь стрелки
      final arrowPathResult = arrowManager
          .getArrowPathInTile(arrowCopy, state.delta, isTiles: true, isNotCalculate: true);
      final coordinates = arrowPathResult.coordinates;
      final arrowPaths = arrowPathResult.paths;
      final tileWorldSize = EditorConfig.tileSize.toDouble();

      if (coordinates.isNotEmpty) {
        if (!state.useCurves) {
          for (int ind = 0; ind < coordinates.length - 1; ind++) {
            final coordStart = coordinates[ind];
            final coordEnd = coordinates[ind + 1];

            /// Вертикальный отрезок связи
            if (coordStart.dx == coordEnd.dx) {
              final gridYStart = (math.min(coordStart.dy, coordEnd.dy) / tileWorldSize).floor();
              final gridYEnd = (math.max(coordStart.dy, coordEnd.dy) / tileWorldSize).ceil();
              final gridX = (coordStart.dx / tileWorldSize).floor();
              for (int gridY = gridYStart; gridY < gridYEnd; gridY++) {
                final left = gridX * tileWorldSize;
                final top = gridY * tileWorldSize;
                await createTiles(top: top, left: left, arrow: arrow);
              }
            }
            /// Горизонтальный отрезок связи
            else {
              final gridXStart = (math.min(coordStart.dx, coordEnd.dx) / tileWorldSize).floor();
              final gridXEnd = (math.max(coordStart.dx, coordEnd.dx) / tileWorldSize).ceil();
              final gridY = (coordStart.dy / tileWorldSize).floor();
              for (int gridX = gridXStart; gridX < gridXEnd; gridX++) {
                final left = gridX * tileWorldSize;
                final top = gridY * tileWorldSize;
                await createTiles(top: top, left: left, arrow: arrow);
              }
            }
          }
        } else {
          // Для кривых связей используем Path.getBounds() + проверку пересечения
          final path = arrowPaths.path;
          
          // Получаем bounding box пути
          final pathBounds = path.getBounds();
          
          // Определяем диапазон тайлов, которые могут пересекаться с путём
          final gridXStart = (pathBounds.left / tileWorldSize).floor();
          final gridXEnd = (pathBounds.right / tileWorldSize).ceil();
          final gridYStart = (pathBounds.top / tileWorldSize).floor();
          final gridYEnd = (pathBounds.bottom / tileWorldSize).ceil();
          
          // Для каждого тайла в bounding box проверяем пересечение с путём
          for (int gridY = gridYStart; gridY < gridYEnd; gridY++) {
            for (int gridX = gridXStart; gridX < gridXEnd; gridX++) {
              final tileLeft = gridX * tileWorldSize;
              final tileTop = gridY * tileWorldSize;
              final tileRect = Rect.fromLTWH(tileLeft, tileTop, tileWorldSize, tileWorldSize);
              
              // Проверяем пересечение пути с тайлом через Path.combine
              final tilePath = Path()..addRect(tileRect);
              final intersection = Path.combine(PathOperation.intersect, path, tilePath);
              
              // Если пересечение не пустое, добавляем тайл
              if (intersection.getBounds().width > 0 && intersection.getBounds().height > 0) {
                await createTiles(top: tileTop, left: tileLeft, arrow: arrow);
              }
            }
          }
        }
      }
    }

    final List<ImageTile> tiles = [];

    /// Создание тайлов рассчитанным узлам и связям
    for (final tileId in createdTiles) {
      // print('Create tile $tileId ----------');
      final tilePos = tileId.split(':');
      final left = double.tryParse(tilePos.first);
      final top = double.tryParse(tilePos.last);
      final List<TableNode?> nodesInTile = mapNodesInTile[tileId]!;
      final List<Arrow?> arrowsInTile = mapArrowsInTile[tileId]!;
      final ImageTile? tile = await _createTileAtPosition(left!, top!, nodesInTile, arrowsInTile);
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
    final tileBounds = Rect.fromLTRB(left, top, left + tileWorldSize, top + tileWorldSize);

    // ID тайла в формате 'left:top' (мировые координаты)
    final tileId = _generateTileId(left, top);

    return _createUpdatedTileWithContent(tileBounds, tileId, nodesInTile, arrowsInTile);
  }

  // Получение узлов для тайла (исключая выделенные)
  List<TableNode?> _getNodesForTile(ImageTile tile) {
    return NodeManager.whereAllNodes(state.nodes, (node) => tile.nodes.contains(node.id));
  }

  // Получение связей для тайла (исключая выделенные)
  List<Arrow?> _getArrowsForTile(ImageTile tile) {
    return state.arrows.where((arrow) => tile.arrows.contains(arrow.id)).toList();
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
        final tile = await _createTileAtPosition(left, top, allNodes, allArrows);
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
    return [...swimlaneNodes, ...nonSwimlaneNodes];
  }

  /// Удаление детей swimlane из тайлов
  Future<void> removeSwimlaneChildrenFromTiles(TableNode swimlaneNode, Set<int> tilesToUpdate) async {
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
    final arrowsSelected = arrowManager.getArrowsForNodes([node]);
    arrowIdsConnectedToNode.addAll(arrowsSelected.map((arrow) => arrow!.id));
    state.arrowsSelected.addAll(arrowsSelected);

    /// Находим и добавляем для удаления id вложенных в группу узлов
    if ((node.qType == 'group' || node.qType == 'swimlane') && node.children != null && node.children!.isNotEmpty) {
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
      if (arrowIdsConnectedToNode.any((arrowId) => tile.arrows.contains(arrowId))) {
        tile.arrows.removeAll(arrowIdsConnectedToNode);
        tilesToUpdate.add(tile);
      }
    }

    // Обновляем ВСЕ тайлы, из которых удаляли узлы ИЛИ стрелки
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
      final nodeRect = Utils.calculateNodeRect(node: node, position: nodePosition);

      if (nodeRect.overlaps(tile.bounds)) {
        tileIndices.add(i);
      }
    }

    return tileIndices;
  }

  // ignore: unused_element
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
      try {
        tile.image.dispose();
      } catch (e) {
        // Игнорируем ошибки disposal, которые могут возникнуть из-за WebGL контекста
        print('Warning: Error disposing tile image: $e');
      }

      // Удаляем тайл из списка
      state.imageTiles.removeAt(tileIndex);

      onStateUpdate();
    } catch (e) {}
  }

  // Добавление узла в тайлы (после перемещения)
  Future<void> addNodeToTiles(TableNode node) async {
    // Создаем тайлы только там где есть узлы или стрелки
    final tiles = await _createTilesForContent(state.nodesSelected.toList(), state.arrowsSelected.toList());

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
          highlightedNodeIds: state.highlightedNodeIds,
        );
      }

      // Рисуем стрелки, если они есть (используем ArrowTilePainter)
      if (arrowsInTile.isNotEmpty) {
        final arrowsPainter = ArrowsPainter(arrows: arrowsInTile, arrowManager: arrowManager);
        arrowsPainter.drawArrowsInTile(canvas: canvas, baseOffset: state.delta, scale: scale);
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
    // state.isLoading = true;
    // onStateUpdate();
    // await Future.delayed(const Duration(milliseconds: 100));

    await createTiledImage(state.nodes, state.arrows, isUpdate: true);

    state.imageTilesChanged.clear();

    // Уведомляем об изменении
    // state.isLoading = false;
    onStateUpdate();
  }

  /// Обновление тайла со ВСЕМИ узлами и стрелками
  Future<void> updateTileWithAllContent(ImageTile tile) async {
    try {
      final tileId = tile.id;
      final bounds = tile.bounds;

      state.imageTilesChanged.add(tileId);

      // Получаем ВСЕ узлы для этого тайла из state.nodes
      final nodesInTile = _getNodesForTile(tile);

      // Получаем ВСЕ стрелки для этого тайла из state.arrows
      final arrowsInTile = _getArrowsForTile(tile);

      // Перерисовываем тайл со ВСЕМИ узлами и стрелками
      final newTile = await _createUpdatedTileWithContent(bounds, tileId, nodesInTile, arrowsInTile);
      if (newTile != null) {
        // Находим и dispose старый тайл перед заменой
        final tileIndex = _findTileIndexById(tileId);
        if (tileIndex != null) {
          try {
            state.imageTiles[tileIndex].image.dispose();
          } catch (e) {
            // Игнорируем ошибки disposal
          }
          state.imageTiles[tileIndex] = newTile;
          onStateUpdate();
        }
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
      await _disposeTiles();

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

  /// Получает список тайлов, которые пересекает прямоугольник, заданный начальными и конечными координатами
  /// [start] - начальная точка прямоугольника (левый верхний угол)
  /// [end] - конечная точка прямоугольника (правый нижний угол)
  /// Возвращает список тайлов, которые пересекаются с прямоугольником
  List<ImageTile> getTilesIntersectingRect(Offset start, Offset end) {
    final intersectingTiles = <ImageTile>[];

    // Создаем прямоугольник из начальных и конечных координат
    final rect = Rect.fromPoints(start, end);

    _tilesIntersectingRect(
      rect,
      callback: ({required double left, required double top}) {
        final tileId = _generateTileId(left, top);

        // Ищем тайл с таким ID в существующих тайлах
        final tile = getTileById(state.imageTiles, tileId);
        if (tile != null) {
          intersectingTiles.add(tile);
        }
      },
    );

    return intersectingTiles;
  }

  Future<void> _tilesIntersectingRect(Rect rect, {Function? callback}) async {
    // Получаем границы прямоугольника
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;

    // Размер тайла в мировых координатах
    final tileWorldSize = EditorConfig.tileSize.toDouble();

    // Рассчитываем grid позиции, которые пересекает прямоугольник
    final gridXStart = (left / tileWorldSize).floor();
    final gridYStart = (top / tileWorldSize).floor();
    final gridXEnd = (right / tileWorldSize).ceil();
    final gridYEnd = (bottom / tileWorldSize).ceil();

    // Проходим по всем grid позициям в пределах прямоугольника
    for (int gridY = gridYStart; gridY < gridYEnd; gridY++) {
      for (int gridX = gridXStart; gridX < gridXEnd; gridX++) {
        final left = gridX * tileWorldSize;
        final top = gridY * tileWorldSize;
        if (callback != null) {
          await callback(left: left, top: top);
        }
      }
    }
  }

  /// Публичный метод для очистки всех тайлов
  void disposeTiles() {
    _disposeTiles();
  }

  Future<void> _disposeTiles() async {
    for (final tile in state.imageTiles) {
      try {
        tile.image.dispose();
      } catch (e) {
        // Игнорируем ошибки disposal, которые могут возникнуть из-за WebGL контекста
        // (например, если изображение уже было освобождено)
      }
    }
    state.imageTiles.clear();
    
    // Принудительная очистка памяти WASM после массового dispose
    await Future.microtask(() {});
  }

  @override
  void dispose() {
    super.dispose();
    _disposeTiles();
  }
}
