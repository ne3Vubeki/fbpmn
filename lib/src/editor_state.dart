import 'package:flutter/material.dart';

import 'models/image_tile.dart';
import 'models/table.node.dart';
import 'models/arrow.dart';

class EditorState {
  // Масштаб и позиция
  double scale = 1.0;
  Offset offset = Offset.zero;
  Offset delta = Offset.zero;

  // Состояние ввода
  bool isShiftPressed = false;
  bool isPanning = false;
  Offset mousePosition = Offset.zero;

  // Размеры
  Size viewportSize = Size.zero;
  bool isInitialized = false;

  // Узлы
  final List<TableNode> nodes = [];
  final List<TableNode> nodesSelected = [];
  Offset originalNodePosition = Offset.zero;
  bool isNodeDragging = false;
  bool isNodeOnTopLayer = false;
  TableNode? selectedNodeOnTopLayer;

  // Позиция, Размер и Отступы в рамке выделенного узла (для правильной отрисовки рамки)
  Offset selectedNodeOffset = Offset.zero;
  EdgeInsets framePadding = EdgeInsets.all(0);

  // Связи/стрелки
  final List<Arrow> arrows = [];
  final List<Arrow> arrowsSelected = [];

  // Тайлы
  List<ImageTile> imageTiles = [];
  List<String> imageTilesChanged = [];
  bool showTileBorders = true;

  // Загрузка
  bool isLoading = false;

  // Кэши
  final Map<TableNode, Rect> nodeBoundsCache = {};

  // Метод для получения экранных координат из мировых
  Offset worldToScreen(Offset worldPosition) {
    return worldPosition * scale + offset;
  }

  // Метод для получения мировых координат из экранных
  Offset screenToWorld(Offset screenPosition) {
    return (screenPosition - offset) / scale;
  }

  // Метод для получения списка узлов по списку id узлов
  List<TableNode> getNodesByIds(List<String> idNodes) {
    return nodes.where((node) => idNodes.contains(node.id)).toList();
  }

  // Метод для получения списка узлов по списку id узлов
  List<Arrow> getArrowsByIds(List<String> idArrows) {
    return arrows.where((arrow) => idArrows.contains(arrow.id)).toList();
  }
}
