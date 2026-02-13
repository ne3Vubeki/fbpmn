import 'package:flutter/material.dart';

import 'models/image_tile.dart';
import 'models/snap_line.dart';
import 'models/table.node.dart';
import 'models/arrow.dart';

class EditorState {
  // Масштаб и позиция
  double scale = 1.0;
  Offset offset = Offset.zero;
  Offset delta = Offset.zero;

  // Состояние ввода
  bool isShiftPressed = false;
  bool isCtrlPressed = false;
  bool isPanning = false;
  Offset mousePosition = Offset.zero;

  // Размеры
  Size viewportSize = Size.zero;
  bool isInitialized = false;

  // Узлы
  final List<TableNode> nodes = [];
  final Set<TableNode?> nodesSelected = {};
  bool isNodeOnTopLayer = false;
  Offset originalNodePosition = Offset.zero;
  bool isNodeDragging = false;
  Offset selectedNodeOffset = Offset.zero;
  EdgeInsets framePadding = EdgeInsets.all(0);
  
  // Наведение на строку атрибута
  String? hoveredAttributeNodeId;
  int? hoveredAttributeRowIndex;

  // Snap-линии для прилипания узлов
  List<SnapLine> snapLines = [];
  bool snapEnabled = false; // Включение/выключение snap-прилипания

  // Связи/стрелки
  final List<Arrow> arrows = [];
  final Set<Arrow?> arrowsSelected = {};

  // Подсвеченные узлы (связанные с выделенными)
  final Set<String> highlightedNodeIds = {};

  // Тайлы
  List<ImageTile> imageTiles = [];
  Set<String> imageTilesChanged = {};
  bool showTileBorders = true;

  // Загрузка
  bool isLoading = false;

  // Режим автораскладки (скрывает рамки выделения)
  bool isAutoLayoutMode = false;

  bool useCurves = false;
}
