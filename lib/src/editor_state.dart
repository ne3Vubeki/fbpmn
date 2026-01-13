import 'package:flutter/material.dart';

import 'models/image_tile.dart';
import 'models/node.dart';
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
  Node? selectedNode;
  TableNode? selectedNodeOnTopLayer;
  bool isNodeOnTopLayer = false;
  Offset originalNodePosition = Offset.zero;
  bool isNodeDragging = false;

  // Позиция, Размер и Отступы в рамке выделенного узла (для правильной отрисовки рамки)
  Offset selectedNodeOffset = Offset.zero;
  EdgeInsets framePadding = EdgeInsets.all(0);

  // Связи/стрелки
  final List<Arrow> arrows = [];
  
  // Тайлы
  List<ImageTile> imageTiles = [];
  bool showTileBorders = true;
  
  // Загрузка
  bool isLoading = false;
  
  // Кэши
  final Map<TableNode, Rect> nodeBoundsCache = {};
  final Map<int, List<TableNode>> tileToNodes = {};
  final Map<TableNode, Set<int>> nodeToTiles = {};
}