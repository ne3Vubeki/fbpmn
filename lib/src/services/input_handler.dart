import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/utils/utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../services/node_manager.dart';
import '../services/scroll_handler.dart';
import 'manager.dart';

class InputHandler extends Manager {
  final EditorState state;
  final NodeManager nodeManager;
  final ScrollHandler scrollHandler;
  final ArrowManager arrowManager;

  final FocusNode _focusNode = FocusNode();

  Offset _panStartOffset = Offset.zero;
  Offset _panStartMousePosition = Offset.zero;
  bool _isDirectNodeDrag = false; // Флаг для прямого перетаскивания узла

  InputHandler({
    required this.state,
    required this.nodeManager,
    required this.scrollHandler,
    required this.arrowManager,
  });

  void handleKeyEvent(KeyEvent event) {
    bool stateChanged = false;

    if (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight) {
      final bool newShiftState = event is KeyDownEvent || event is KeyRepeatEvent;
      if (state.isShiftPressed != newShiftState) {
        state.isShiftPressed = newShiftState;
        stateChanged = true;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight) {
      final bool newCtrlState = event is KeyDownEvent || event is KeyRepeatEvent;
      if (state.isCtrlPressed != newCtrlState) {
        state.isCtrlPressed = newCtrlState;
        stateChanged = true;
      }
    }

    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyB:
          toggleTileBorders();
          break;
        case LogicalKeyboardKey.escape:
          nodeManager.handleEmptyAreaClick();
          break;
      }
    }

    // Вызываем onStateUpdate только если состояние модификаторов изменилось
    if (stateChanged) {
      onStateUpdate();
    }
  }

  void toggleTileBorders() {
    state.showTileBorders = !state.showTileBorders;
    onStateUpdate();
  }

  void onTileBorders() {
    state.showTileBorders = true;
    onStateUpdate();
  }

  void offTileBorders() {
    state.showTileBorders = false;
    onStateUpdate();
  }

  void handleZoom(double delta, Offset localPosition) {
    final oldScale = state.scale;

    double newScale = state.scale * (1 + delta * 0.001);

    if (newScale < 0.3) {
      newScale = 0.3;
    } else if (newScale > 2.0) {
      newScale = 2.0;
    }

    final double zoomFactor = newScale / oldScale;
    final Offset mouseInCanvas = (localPosition - state.offset);
    final Offset newOffset = localPosition - mouseInCanvas * zoomFactor;

    state.scale = newScale;
    state.offset = constrainOffset(newOffset);

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

      if (state.counterNodeOnTopLayer > 0 && state.nodesSelected.isNotEmpty) {
        if (state.nodesSelected.length > 1) {
          // Мультивыделение — проверяем клик по общему bounding box
          final result = Utils.getNodesWorldBounds(state.nodesSelected.toList(), state.delta);
          if (result != null) {
            final screenTopLeft = Utils.worldToScreen(result.worldBounds.topLeft, state);
            final screenBottomRight = Utils.worldToScreen(result.worldBounds.bottomRight, state);
            final frameOffset = nodeManager.frameTotalOffset;
            final multiRect = Rect.fromLTRB(
              screenTopLeft.dx - frameOffset,
              screenTopLeft.dy - frameOffset,
              screenBottomRight.dx + frameOffset,
              screenBottomRight.dy + frameOffset,
            );
            clickedOnSelectedNode = multiRect.contains(position);
          }
        } else {
          // Единичное выделение
          final node = state.nodesSelected.first!;
          final scaledWidth = node.size.width * state.scale;
          final scaledHeight = node.size.height * state.scale;

          // Для раскрытого swimlane используем фактические границы рамки выделения,
          // которые включают в себя детей
          if (node.qType == 'swimlane' && !(node.isCollapsed ?? false)) {
            final nodeScreenRect = Rect.fromLTWH(
              state.selectedNodeOffset.dx,
              state.selectedNodeOffset.dy,
              scaledWidth + state.framePadding.left + state.framePadding.right,
              scaledHeight + state.framePadding.top + state.framePadding.bottom,
            );
            clickedOnSelectedNode = nodeScreenRect.contains(position);
          } else {
            final double frameOffset = nodeManager.frameTotalOffset;
            final nodeScreenRect = Rect.fromLTWH(
              state.selectedNodeOffset.dx,
              state.selectedNodeOffset.dy,
              scaledWidth + frameOffset * 2,
              scaledHeight + frameOffset * 2,
            );
            clickedOnSelectedNode = nodeScreenRect.contains(position);
          }
        }
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

      state.offset = constrainOffset(newOffset);

      // ВАЖНОЕ ИСПРАВЛЕНИЕ: Обновляем позицию выделенного узла при панорамировании
      if (state.counterNodeOnTopLayer > 0) {
        nodeManager.onOffsetChanged();
      }

      if (state.counterNodeOnTopLayer > 0) {
        arrowManager.onStateUpdate();
      }

      scrollHandler.updateScrollControllers();
      // Не вызываем onStateUpdate здесь - он будет вызван в scrollHandler.updateScrollControllers()
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
    // Не вызываем onStateUpdate здесь - nodeManager.endNodeDrag() уже вызывает его при необходимости
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
    // Не вызываем onStateUpdate здесь - nodeManager.endNodeDrag() уже вызывает его при необходимости
  }

  Offset constrainOffset(Offset offset) {
    // Используем динамический размер холста из ScrollHandler
    final Size canvasSize = Size(
      scrollHandler.dynamicCanvasWidth * state.scale,
      scrollHandler.dynamicCanvasHeight * state.scale,
    );

    double constrainedX = offset.dx;
    double constrainedY = offset.dy;

    // Максимальные смещения
    final double maxRight = 0;
    final double maxLeft = state.viewportSize.width - canvasSize.width;
    final double maxBottom = 0;
    final double maxTop = state.viewportSize.height - canvasSize.height;

    // Ограничиваем по X
    if (canvasSize.width <= state.viewportSize.width) {
      // Холст меньше viewport - центрируем
      constrainedX = (state.viewportSize.width - canvasSize.width) / 2;
    } else {
      // Холст больше viewport - ограничиваем
      if (constrainedX > maxRight) constrainedX = maxRight;
      if (constrainedX < maxLeft) constrainedX = maxLeft;
    }

    // Ограничиваем по Y
    if (canvasSize.height <= state.viewportSize.height) {
      // Холст меньше viewport - центрируем
      constrainedY = (state.viewportSize.height - canvasSize.height) / 2;
    } else {
      // Холст больше viewport - ограничиваем
      if (constrainedY > maxBottom) constrainedY = maxBottom;
      if (constrainedY < maxTop) constrainedY = maxTop;
    }

    return Offset(constrainedX, constrainedY);
  }

  FocusNode get focusNode => _focusNode;

  @override
  void dispose() {
    super.dispose();
    _focusNode.dispose();
  }
}
