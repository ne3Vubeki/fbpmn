import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../services/node_manager.dart';

class ScrollHandler {
  final EditorState state;
  final NodeManager? nodeManager;
  final VoidCallback onStateUpdate;

  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController verticalScrollController = ScrollController();

  final double canvasSizeMultiplier = 3.0;

  // Для перетаскивания скроллбаров
  bool _isHorizontalDragging = false;
  bool _isVerticalDragging = false;
  Offset _horizontalDragStart = Offset.zero;
  Offset _verticalDragStart = Offset.zero;
  double _horizontalDragStartOffset = 0.0;
  double _verticalDragStartOffset = 0.0;

  ScrollHandler({
    required this.state,
    this.nodeManager,
    required this.onStateUpdate,
  }) {
    horizontalScrollController.addListener(_onHorizontalScroll);
    verticalScrollController.addListener(_onVerticalScroll);
  }

  /// Размер холста с учетом масштаба
  Size _calculateCanvasSize() {
    return Size(
      state.viewportSize.width * canvasSizeMultiplier * state.scale,
      state.viewportSize.height * canvasSizeMultiplier * state.scale,
    );
  }

  void centerCanvas() {
    final Size canvasSize = _calculateCanvasSize();

    // Центрируем холст в видимой области
    state.offset = Offset(
      (state.viewportSize.width - canvasSize.width) / 2,
      (state.viewportSize.height - canvasSize.height) / 2,
    );

    // Корректируем offset, чтобы не выходить за границы
    _constrainCurrentOffset();

    // Обновляем позицию выделенного узла
    if (state.isNodeOnTopLayer) {
      nodeManager?.onOffsetChanged();
    }

    updateScrollControllers();
    state.isInitialized = true;
    onStateUpdate();
  }

  void resetZoom() {
    state.scale = 1.0;
    centerCanvas();
    onStateUpdate();
  }

  /// Ограничивает текущий offset границами
  void _constrainCurrentOffset() {
    final Size canvasSize = _calculateCanvasSize();

    double constrainedX = state.offset.dx;
    double constrainedY = state.offset.dy;

    // Максимальные смещения
    final double maxRight = 0; // Нельзя двигать вправо за левую границу
    final double maxLeft =
        state.viewportSize.width - canvasSize.width; // Максимум влево

    final double maxBottom = 0; // Нельзя двигать вниз за верхнюю границу
    final double maxTop =
        state.viewportSize.height - canvasSize.height; // Максимум вверх

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

    state.offset = Offset(constrainedX, constrainedY);
  }

  void updateScrollControllers() {
    final Size canvasSize = _calculateCanvasSize();

    // Максимальная прокрутка
    final double horizontalMaxScroll = _max(
      0,
      canvasSize.width - state.viewportSize.width,
    );
    final double verticalMaxScroll = _max(
      0,
      canvasSize.height - state.viewportSize.height,
    );

    // Текущая позиция в координатах скроллбара
    final double horizontalPosition = _clamp(
      -state.offset.dx,
      0,
      horizontalMaxScroll,
    );
    final double verticalPosition = _clamp(
      -state.offset.dy,
      0,
      verticalMaxScroll,
    );

    // Обновляем скроллбары
    if (horizontalScrollController.hasClients) {
      horizontalScrollController.jumpTo(horizontalPosition);
    }

    if (verticalScrollController.hasClients) {
      verticalScrollController.jumpTo(verticalPosition);
    }
  }

  /// Вызывается при изменении размера viewport
  void handleViewportResize(Size newViewportSize) {
    state.viewportSize = newViewportSize;

    // Корректируем текущий offset под новый размер viewport
    _constrainCurrentOffset();

    // Обновляем скроллбары
    updateScrollControllers();

    // Обновляем позицию выделенного узла
    if (state.isNodeOnTopLayer) {
      nodeManager?.onOffsetChanged();
    }

    onStateUpdate();
  }

  void _onHorizontalScroll() {
    if (_isHorizontalDragging) return; // Игнорируем при перетаскивании

    final double scrollPosition = horizontalScrollController.offset;
    final Size canvasSize = _calculateCanvasSize();
    final double maxScroll = _max(
      0,
      canvasSize.width - state.viewportSize.width,
    );

    final double clampedScroll = _clamp(scrollPosition, 0, maxScroll);
    state.offset = Offset(-clampedScroll, state.offset.dy);

    // Обновляем позицию выделенного узла
    if (state.isNodeOnTopLayer) {
      nodeManager?.onOffsetChanged();
    }

    onStateUpdate();
  }

  void _onVerticalScroll() {
    if (_isVerticalDragging) return; // Игнорируем при перетаскивании

    final double scrollPosition = verticalScrollController.offset;
    final Size canvasSize = _calculateCanvasSize();
    final double maxScroll = _max(
      0,
      canvasSize.height - state.viewportSize.height,
    );

    final double clampedScroll = _clamp(scrollPosition, 0, maxScroll);
    state.offset = Offset(state.offset.dx, -clampedScroll);

    // Обновляем позицию выделенного узла
    if (state.isNodeOnTopLayer) {
      nodeManager?.onOffsetChanged();
    }

    onStateUpdate();
  }

  // === МЕТОДЫ ДЛЯ ПЕРЕТАСКИВАНИЯ СКРОЛЛБАРОВ (С УЧЕТОМ МАСШТАБА) ===

  void handleHorizontalScrollbarDragStart(PointerDownEvent details) {
    _isHorizontalDragging = true;
    _horizontalDragStart = details.localPosition;
    _horizontalDragStartOffset = horizontalScrollController.offset;
    onStateUpdate();
  }

void handleHorizontalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!_isHorizontalDragging) return;
    
    final Size canvasSize = _calculateCanvasSize();
    final double maxScroll = _max(0, canvasSize.width - state.viewportSize.width);
    
    if (maxScroll == 0) return;
    
    // Смещение мыши
    final double mouseDelta = details.localPosition.dx - _horizontalDragStart.dx;
    
    // Более точный расчет с учетом canvasSizeMultiplier
    // Размер холста = viewportSize * canvasSizeMultiplier * scale
    // Отношение размера холста к viewport = canvasSizeMultiplier * scale
    final double canvasToViewportRatio = canvasSizeMultiplier * state.scale;
    final double adjustedDelta = mouseDelta * canvasToViewportRatio;
    
    final double newScrollOffset = _clamp(
      _horizontalDragStartOffset + adjustedDelta,
      0,
      maxScroll
    );
    
    if (horizontalScrollController.hasClients) {
      horizontalScrollController.jumpTo(newScrollOffset);
    }
    
    state.offset = Offset(-newScrollOffset, state.offset.dy);
    
    if (state.isNodeOnTopLayer) {
      nodeManager?.onOffsetChanged();
    }
    
    onStateUpdate();
  }

  void handleHorizontalScrollbarDragEnd(PointerUpEvent details) {
    _isHorizontalDragging = false;
    onStateUpdate();
  }

  void handleVerticalScrollbarDragStart(PointerDownEvent details) {
    _isVerticalDragging = true;
    _verticalDragStart = details.localPosition;
    _verticalDragStartOffset = verticalScrollController.offset;
    onStateUpdate();
  }

void handleVerticalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!_isVerticalDragging) return;
    
    final Size canvasSize = _calculateCanvasSize();
    final double maxScroll = _max(0, canvasSize.height - state.viewportSize.height);
    
    if (maxScroll == 0) return;
    
    final double mouseDelta = details.localPosition.dy - _verticalDragStart.dy;
    final double canvasToViewportRatio = canvasSizeMultiplier * state.scale;
    final double adjustedDelta = mouseDelta * canvasToViewportRatio;
    
    final double newScrollOffset = _clamp(
      _verticalDragStartOffset + adjustedDelta,
      0,
      maxScroll
    );
    
    if (verticalScrollController.hasClients) {
      verticalScrollController.jumpTo(newScrollOffset);
    }
    
    state.offset = Offset(state.offset.dx, -newScrollOffset);
    
    if (state.isNodeOnTopLayer) {
      nodeManager?.onOffsetChanged();
    }
    
    onStateUpdate();
  }
  
  void handleVerticalScrollbarDragEnd(PointerUpEvent details) {
    _isVerticalDragging = false;
    onStateUpdate();
  }

  double _max(double a, double b) => a > b ? a : b;

  double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void dispose() {
    horizontalScrollController.dispose();
    verticalScrollController.dispose();
  }
}
