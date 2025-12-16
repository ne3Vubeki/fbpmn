import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Node;

import 'node.controller.dart';

class EditorController extends GetxController {
  final RxDouble scale = 1.0.obs;
  final Rx<Offset> offset = Offset.zero.obs;
  final RxBool isShiftPressed = false.obs;

  final FocusNode focusNode = FocusNode();

  final double canvasSizeMultiplier = 3.0;

  final Rx<Offset> mousePosition = Offset.zero.obs;

  final Rx<Offset> panStartOffset = Offset.zero.obs;
  final Rx<Offset> panStartMousePosition = Offset.zero.obs;
  final RxBool isPanning = false.obs;

  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController verticalScrollController = ScrollController();
  final RxBool updatingFromScroll = false.obs;

  final Rx<Size> viewportSize = Size.zero.obs;
  final RxBool isInitialized = false.obs;

  // Для перемещения скроллбаров
  final RxBool isHorizontalScrollbarDragging = false.obs;
  final RxBool isVerticalScrollbarDragging = false.obs;
  final Rx<Offset> horizontalScrollbarDragStart = Offset.zero.obs;
  final Rx<Offset> verticalScrollbarDragStart = Offset.zero.obs;
  final RxDouble horizontalScrollbarStartOffset = 0.0.obs;
  final RxDouble verticalScrollbarStartOffset = 0.0.obs;

  // Для работы с узлами
  final RxList<Node> nodes = <Node>[].obs;
  final Rxn<Node> selectedNode = Rxn<Node>();
  final RxBool isNodeDragging = false.obs;
  final Rx<Offset> nodeDragStart = Offset.zero.obs;
  final Rx<Offset> nodeStartPosition = Offset.zero.obs;
  final Rx<Offset> nodePosition = Offset.zero.obs;

  @override
  void onInit() {
    super.onInit();
    horizontalScrollController.addListener(_onHorizontalScroll);
    verticalScrollController.addListener(_onVerticalScroll);
  }

  void addNodeAt(Offset position) {
    final node = Node(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: position,
      text: 'Node ${nodes.length + 1}',
    );
    nodes.add(node);
  }

  void deleteSelectedNode() {
    if (selectedNode.value != null) {
      final nodeToRemove = selectedNode.value!;
      nodeToRemove.dispose(); // Важно: освобождаем ресурсы
      nodes.remove(nodeToRemove);
      selectedNode.value = null;
    }
  }

  void selectNodeAtPosition(Offset position) {
    final worldPos = (position - offset.value) / scale.value;

    // Снимаем выделение со всех узлов
    for (final node in nodes) {
      node.isSelected = false;
    }
    
    selectedNode.value = null;

    // Ищем узел под курсором (в обратном порядке для приоритета верхних узлов)
    for (int i = nodes.length - 1; i >= 0; i--) {
      final node = nodes[i];
      final nodeRect = Rect.fromCenter(
        center: node.position,
        width: node.size.width,
        height: node.size.height,
      );

      if (nodeRect.contains(worldPos)) {
        node.isSelected = true;
        selectedNode.value = node;
        break;
      }
    }
  }

  void startNodeDrag(Offset position) {
    if (selectedNode.value != null) {
      isNodeDragging.value = true;
      nodeDragStart.value = position;
      nodeStartPosition.value = selectedNode.value!.position;
    }
  }

  void updateNodeDrag(Offset position) {
    if (isNodeDragging.value && selectedNode.value != null) {
      final delta = (position - nodeDragStart.value) / scale.value;
      nodePosition.value = nodeStartPosition.value + delta;
      selectedNode.value!.position = nodePosition.value;
    }
  }

  void endNodeDrag() {
    isNodeDragging.value = false;
  }

  void centerCanvas() {
    offset.value = Offset(
      (viewportSize.value.width - viewportSize.value.width * canvasSizeMultiplier) / 2,
      (viewportSize.value.height - viewportSize.value.height * canvasSizeMultiplier) / 2,
    );

    updateScrollControllers();
    isInitialized.value = true;
  }

  void resetZoom() {
    scale.value = 1.0;
    centerCanvas();
  }

  void updateScrollControllers() {
    if (updatingFromScroll.value) return;

    final Size canvasSize = Size(
      viewportSize.value.width * canvasSizeMultiplier * scale.value,
      viewportSize.value.height * canvasSizeMultiplier * scale.value,
    );

    double horizontalMaxScroll = max(0, canvasSize.width - viewportSize.value.width);
    double verticalMaxScroll = max(0, canvasSize.height - viewportSize.value.height);

    num horizontalPosition = -offset.value.dx.clamp(-horizontalMaxScroll, 0);
    num verticalPosition = -offset.value.dy.clamp(-verticalMaxScroll, 0);

    horizontalScrollController.jumpTo(
      horizontalPosition.clamp(0, horizontalMaxScroll).toDouble(),
    );
    verticalScrollController.jumpTo(
      verticalPosition.clamp(0, verticalMaxScroll).toDouble(),
    );
  }

  void _onHorizontalScroll() {
    if (updatingFromScroll.value) return;

    updatingFromScroll.value = true;

    final Size canvasSize = Size(
      viewportSize.value.width * canvasSizeMultiplier * scale.value,
      viewportSize.value.height * canvasSizeMultiplier * scale.value,
    );

    double horizontalMaxScroll = max(0, canvasSize.width - viewportSize.value.width);
    num newOffsetX = -horizontalScrollController.offset.clamp(
      0,
      horizontalMaxScroll,
    );

    offset.value = Offset(newOffsetX.toDouble(), offset.value.dy);
    updatingFromScroll.value = false;
  }

  void _onVerticalScroll() {
    if (updatingFromScroll.value) return;

    updatingFromScroll.value = true;

    final Size canvasSize = Size(
      viewportSize.value.width * canvasSizeMultiplier * scale.value,
      viewportSize.value.height * canvasSizeMultiplier * scale.value,
    );

    double verticalMaxScroll = max(0, canvasSize.height - viewportSize.value.height);
    num newOffsetY = -verticalScrollController.offset.clamp(
      0,
      verticalMaxScroll,
    );

    offset.value = Offset(offset.value.dx, newOffsetY.toDouble());
    updatingFromScroll.value = false;
  }

  void handleZoom(double delta, Offset localPosition) {
    double oldScale = scale.value;

    double newScale = scale.value * (1 + delta * 0.001);

    // Ограничения зума
    if (newScale < 0.35) {
      newScale = 0.35;
    } else if (newScale > 5.0) {
      newScale = 5.0;
    }

    // Корректировка смещения для фокуса на курсоре
    double zoomFactor = newScale / oldScale;
    Offset mouseInCanvas = (localPosition - offset.value);
    Offset newOffset = localPosition - mouseInCanvas * zoomFactor;

    scale.value = newScale;
    offset.value = _constrainOffset(newOffset);

    updateScrollControllers();
  }

  Offset _constrainOffset(Offset offset) {
    final Size canvasSize = Size(
      viewportSize.value.width * canvasSizeMultiplier * scale.value,
      viewportSize.value.height * canvasSizeMultiplier * scale.value,
    );

    double constrainedX = offset.dx;
    double constrainedY = offset.dy;

    double maxXOffset = viewportSize.value.width - canvasSize.width;
    double maxYOffset = viewportSize.value.height - canvasSize.height;

    if (constrainedX > 0) {
      constrainedX = 0;
    }
    if (constrainedX < maxXOffset) {
      constrainedX = maxXOffset;
    }

    if (constrainedY > 0) {
      constrainedY = 0;
    }
    if (constrainedY < maxYOffset) {
      constrainedY = maxYOffset;
    }

    return Offset(constrainedX, constrainedY);
  }

  // Функция для перемещения холста
  void updatePan(Offset currentMousePosition) {
    if (isPanning.value && isShiftPressed.value) {
      final delta = currentMousePosition - panStartMousePosition.value;
      final newOffset = panStartOffset.value + delta;
      offset.value = _constrainOffset(newOffset);
      updateScrollControllers();
    }
  }

  void handleHorizontalScrollbarDragStart(PointerDownEvent details) {
    isHorizontalScrollbarDragging.value = true;
    horizontalScrollbarDragStart.value = details.localPosition;
    horizontalScrollbarStartOffset.value = horizontalScrollController.offset;
  }

  void handleHorizontalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!isHorizontalScrollbarDragging.value) return;

    final Size canvasSize = Size(
      viewportSize.value.width * canvasSizeMultiplier * scale.value,
      viewportSize.value.height * canvasSizeMultiplier * scale.value,
    );

    double horizontalMaxScroll = max(0, canvasSize.width - viewportSize.value.width);
    if (horizontalMaxScroll == 0) return;

    // Вычисляем соотношение размеров для правильной скорости перемещения
    double viewportToCanvasRatio = canvasSize.width / viewportSize.value.width;

    // Применяем соотношение к перемещению мыши для синхронизации скоростей
    double delta =
        (details.localPosition.dx - horizontalScrollbarDragStart.value.dx) *
        viewportToCanvasRatio;

    double newScrollOffset = (horizontalScrollbarStartOffset.value + delta).clamp(
      0,
      horizontalMaxScroll,
    );

    updatingFromScroll.value = true;
    horizontalScrollController.jumpTo(newScrollOffset);
    updatingFromScroll.value = false;

    double newOffsetX = -newScrollOffset;
    offset.value = Offset(newOffsetX, offset.value.dy);
  }

  void handleHorizontalScrollbarDragEnd(PointerUpEvent details) {
    isHorizontalScrollbarDragging.value = false;
  }

  void handleVerticalScrollbarDragStart(PointerDownEvent details) {
    isVerticalScrollbarDragging.value = true;
    verticalScrollbarDragStart.value = details.localPosition;
    verticalScrollbarStartOffset.value = verticalScrollController.offset;
  }

  void handleVerticalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!isVerticalScrollbarDragging.value) return;

    final Size canvasSize = Size(
      viewportSize.value.width * canvasSizeMultiplier * scale.value,
      viewportSize.value.height * canvasSizeMultiplier * scale.value,
    );

    double verticalMaxScroll = max(0, canvasSize.height - viewportSize.value.height);
    if (verticalMaxScroll == 0) return;

    // Вычисляем соотношение размеров для правильной скорости перемещения
    double viewportToCanvasRatio = canvasSize.height / viewportSize.value.height;

    // Применяем соотношение к перемещению мыши для синхронизации скоростей
    double delta =
        (details.localPosition.dy - verticalScrollbarDragStart.value.dy) *
        viewportToCanvasRatio;

    double newScrollOffset = (verticalScrollbarStartOffset.value + delta).clamp(
      0,
      verticalMaxScroll,
    );

    updatingFromScroll.value = true;
    verticalScrollController.jumpTo(newScrollOffset);
    updatingFromScroll.value = false;

    double newOffsetY = -newScrollOffset;
    offset.value = Offset(offset.value.dx, newOffsetY);
  }

  void handleVerticalScrollbarDragEnd(PointerUpEvent details) {
    isVerticalScrollbarDragging.value = false;
  }

  void setViewportSize(Size size) {
    viewportSize.value = size;
  }

  void setMousePosition(Offset position) {
    mousePosition.value = position;
  }

  void setPanning(bool panning, {Offset? startOffset, Offset? startMousePosition}) {
    isPanning.value = panning;
    if (startOffset != null) panStartOffset.value = startOffset;
    if (startMousePosition != null) panStartMousePosition.value = startMousePosition;
  }

  void setShiftPressed(bool pressed) {
    isShiftPressed.value = pressed;
  }

  @override
  void onClose() {
    // Освобождаем все узлы
    for (final node in nodes) {
      node.dispose();
    }
    focusNode.dispose();
    horizontalScrollController.dispose();
    verticalScrollController.dispose();
    super.onClose();
  }
}