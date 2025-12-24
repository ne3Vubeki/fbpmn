import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../services/node_manager.dart';
import '../services/scroll_handler.dart';

class InputHandler {
  final EditorState state;
  final NodeManager nodeManager;
  final ScrollHandler scrollHandler;
  final VoidCallback onStateUpdate;

  final FocusNode _focusNode = FocusNode();

  Offset _panStartOffset = Offset.zero;
  Offset _panStartMousePosition = Offset.zero;
  bool _isDirectNodeDrag = false; // Флаг для прямого перетаскивания узла

  InputHandler({
    required this.state,
    required this.nodeManager,
    required this.scrollHandler,
    required this.onStateUpdate,
  });

  void handleKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      state.isShiftPressed = event is KeyDownEvent || event is KeyRepeatEvent;
      onStateUpdate();
    }

    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.delete:
          nodeManager.deleteSelectedNode();
          break;
        case LogicalKeyboardKey.keyB:
          toggleTileBorders();
          break;
        case LogicalKeyboardKey.escape:
          nodeManager.handleEmptyAreaClick();
          break;
      }
    }
  }

  void toggleTileBorders() {
    state.showTileBorders = !state.showTileBorders;
    onStateUpdate();
  }

  void handleZoom(double delta, Offset localPosition) {
    final oldScale = state.scale;

    double newScale = state.scale * (1 + delta * 0.001);

    if (newScale < 0.35) {
      newScale = 0.35;
    } else if (newScale > 5.0) {
      newScale = 5.0;
    }

    final double zoomFactor = newScale / oldScale;
    final Offset mouseInCanvas = (localPosition - state.offset);
    final Offset newOffset = localPosition - mouseInCanvas * zoomFactor;

    state.scale = newScale;
    state.offset = _constrainOffset(newOffset);

    // ВАЖНОЕ ИСПРАВЛЕНИЕ: Корректируем позицию выделенного узла при изменении масштаба
    if (oldScale != newScale) {
      nodeManager.onScaleChanged();
    }

    scrollHandler.updateScrollControllers();
    onStateUpdate();
  }

  void handlePanStart(Offset position) {
    _isDirectNodeDrag = false;

    if (state.isShiftPressed) {
      state.isPanning = true;
      _panStartOffset = state.offset;
      _panStartMousePosition = position;
      onStateUpdate();
    } else {
      bool clickedOnSelectedNode = false;
      if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
        final node = state.selectedNodeOnTopLayer!;
        final scaledWidth = node.size.width * state.scale;
        final scaledHeight = node.size.height * state.scale;

        // Рамка окружает узел с фиксированным отступом
        final double frameOffset = NodeManager.frameTotalOffset;
        final nodeScreenRect = Rect.fromLTWH(
          state.selectedNodeOffset.dx,
          state.selectedNodeOffset.dy,
          scaledWidth + frameOffset * 2,
          scaledHeight + frameOffset * 2,
        );

        clickedOnSelectedNode = nodeScreenRect.contains(position);
      }

      if (clickedOnSelectedNode) {
        _isDirectNodeDrag = true;
        nodeManager.startNodeDrag(position);
      } else {
        nodeManager.selectNodeAtPosition(position, immediateDrag: true);
      }
    }

    _focusNode.requestFocus();
  }

  void handlePanUpdate(Offset position, Offset delta) {
    state.mousePosition = position;

    if (state.isPanning && state.isShiftPressed) {
      // Панорамирование
      final Offset deltaMove = position - _panStartMousePosition;
      final Offset newOffset = _panStartOffset + deltaMove;

      state.offset = _constrainOffset(newOffset);

      // ВАЖНОЕ ИСПРАВЛЕНИЕ: Обновляем позицию выделенного узла при панорамировании
      if (state.isNodeOnTopLayer) {
        nodeManager.onOffsetChanged();
      }

      scrollHandler.updateScrollControllers();
      onStateUpdate();
    } else if (state.isNodeDragging || _isDirectNodeDrag) {
      // Перетаскивание узла (как через выделение, так и прямое)
      nodeManager.updateNodeDrag(position);
    }
  }

  void handlePanEnd() {
    if (state.isPanning) {
      state.isPanning = false;
    }

    // Завершаем перетаскивание узла, если оно было
    if (state.isNodeDragging) {
      nodeManager.endNodeDrag();
    }

    _isDirectNodeDrag = false;
    onStateUpdate();
  }

  void handlePanCancel() {
    if (state.isPanning) {
      state.isPanning = false;
    }

    // Отменяем перетаскивание узла, если оно было
    if (state.isNodeDragging) {
      nodeManager.endNodeDrag();
    }

    _isDirectNodeDrag = false;
    onStateUpdate();
  }

  Offset _constrainOffset(Offset offset) {
    final Size canvasSize = Size(
      state.viewportSize.width *
          scrollHandler.canvasSizeMultiplier *
          state.scale,
      state.viewportSize.height *
          scrollHandler.canvasSizeMultiplier *
          state.scale,
    );

    double constrainedX = offset.dx;
    double constrainedY = offset.dy;

    final double maxX = state.viewportSize.width - canvasSize.width;
    final double maxY = state.viewportSize.height - canvasSize.height;

    // Простое ограничение
    if (constrainedX > 0) constrainedX = 0;
    if (constrainedX < maxX) constrainedX = maxX;
    if (constrainedY > 0) constrainedY = 0;
    if (constrainedY < maxY) constrainedY = maxY;

    return Offset(constrainedX, constrainedY);
  }

  FocusNode get focusNode => _focusNode;

  void dispose() {
    _focusNode.dispose();
  }
}
