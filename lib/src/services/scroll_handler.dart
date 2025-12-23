import 'package:flutter/material.dart';

import '../editor_state.dart';

class ScrollHandler {
  final EditorState state;
  final VoidCallback onStateUpdate;
  
  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController verticalScrollController = ScrollController();
  bool _updatingFromScroll = false;
  
  final double canvasSizeMultiplier = 3.0;
  
  // Для работы с скроллбарами
  bool isHorizontalScrollbarDragging = false;
  bool isVerticalScrollbarDragging = false;
  Offset horizontalScrollbarDragStart = Offset.zero;
  Offset verticalScrollbarDragStart = Offset.zero;
  double horizontalScrollbarStartOffset = 0.0;
  double verticalScrollbarStartOffset = 0.0;
  
  ScrollHandler({
    required this.state,
    required this.onStateUpdate,
  }) {
    horizontalScrollController.addListener(_onHorizontalScroll);
    verticalScrollController.addListener(_onVerticalScroll);
  }
  
  void centerCanvas() {
    state.offset = Offset(
      (state.viewportSize.width - state.viewportSize.width * canvasSizeMultiplier) / 2,
      (state.viewportSize.height - state.viewportSize.height * canvasSizeMultiplier) / 2,
    );
    
    updateScrollControllers();
    state.isInitialized = true;
    onStateUpdate();
  }
  
  void resetZoom() {
    state.scale = 1.0;
    centerCanvas();
    onStateUpdate();
  }
  
  // ОБНОВЛЕНО: Метод теперь публичный и вызывается при любом изменении offset
  void updateScrollControllers() {
    if (_updatingFromScroll) return;
    
    final Size canvasSize = _calculateCanvasSize();
    
    final double horizontalMaxScroll = max(0, canvasSize.width - state.viewportSize.width);
    final double verticalMaxScroll = max(0, canvasSize.height - state.viewportSize.height);
    
    // Рассчитываем позицию скроллбара на основе offset холста
    final double horizontalPosition = _calculateScrollPosition(
      offset: -state.offset.dx,
      maxScroll: horizontalMaxScroll,
    );
    
    final double verticalPosition = _calculateScrollPosition(
      offset: -state.offset.dy,
      maxScroll: verticalMaxScroll,
    );
    
    // Плавное обновление позиции скроллбара
    _updateScrollPosition(
      horizontalPosition,
      verticalPosition,
      horizontalMaxScroll,
      verticalMaxScroll,
    );
  }
  
  // НОВЫЙ: Расчет размера канваса
  Size _calculateCanvasSize() {
    return Size(
      state.viewportSize.width * canvasSizeMultiplier * state.scale,
      state.viewportSize.height * canvasSizeMultiplier * state.scale,
    );
  }
  
  // НОВЫЙ: Расчет позиции скроллбара
  double _calculateScrollPosition({required double offset, required double maxScroll}) {
    if (maxScroll <= 0) return 0;
    return offset.clamp(0, maxScroll).toDouble();
  }
  
  // НОВЫЙ: Обновление позиций скроллбаров
  void _updateScrollPosition(
    double horizontalPosition,
    double verticalPosition,
    double horizontalMaxScroll,
    double verticalMaxScroll,
  ) {
    // Обновляем горизонтальный скроллбар
    if (horizontalMaxScroll > 0) {
      final double normalizedHorizontalPos = horizontalPosition.clamp(0, horizontalMaxScroll).toDouble();
      if (horizontalScrollController.hasClients) {
        horizontalScrollController.jumpTo(normalizedHorizontalPos);
      }
    }
    
    // Обновляем вертикальный скроллбар
    if (verticalMaxScroll > 0) {
      final double normalizedVerticalPos = verticalPosition.clamp(0, verticalMaxScroll).toDouble();
      if (verticalScrollController.hasClients) {
        verticalScrollController.jumpTo(normalizedVerticalPos);
      }
    }
  }
  
  void _onHorizontalScroll() {
    if (_updatingFromScroll) return;
    
    _updatingFromScroll = true;
    
    final Size canvasSize = _calculateCanvasSize();
    final double horizontalMaxScroll = max(0, canvasSize.width - state.viewportSize.width);
    
    // Получаем позицию из скроллбара
    final double scrollbarPosition = horizontalScrollController.offset;
    final double newOffsetX = -scrollbarPosition.clamp(0, horizontalMaxScroll).toDouble();
    
    // Обновляем offset холста
    state.offset = Offset(newOffsetX, state.offset.dy);
    
    _updatingFromScroll = false;
    onStateUpdate();
  }
  
  void _onVerticalScroll() {
    if (_updatingFromScroll) return;
    
    _updatingFromScroll = true;
    
    final Size canvasSize = _calculateCanvasSize();
    final double verticalMaxScroll = max(0, canvasSize.height - state.viewportSize.height);
    
    // Получаем позицию из скроллбара
    final double scrollbarPosition = verticalScrollController.offset;
    final double newOffsetY = -scrollbarPosition.clamp(0, verticalMaxScroll).toDouble();
    
    // Обновляем offset холста
    state.offset = Offset(state.offset.dx, newOffsetY);
    
    _updatingFromScroll = false;
    onStateUpdate();
  }
  
  // Методы для обработки перетаскивания скроллбаров
  void handleHorizontalScrollbarDragStart(PointerDownEvent details) {
    isHorizontalScrollbarDragging = true;
    horizontalScrollbarDragStart = details.localPosition;
    horizontalScrollbarStartOffset = horizontalScrollController.offset;
    onStateUpdate();
  }
  
  void handleHorizontalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!isHorizontalScrollbarDragging) return;
    
    final Size canvasSize = _calculateCanvasSize();
    final double horizontalMaxScroll = max(0, canvasSize.width - state.viewportSize.width);
    if (horizontalMaxScroll == 0) return;
    
    final double viewportToCanvasRatio = canvasSize.width / state.viewportSize.width;
    final double delta = (details.localPosition.dx - horizontalScrollbarDragStart.dx) * viewportToCanvasRatio;
    final double newScrollOffset = (horizontalScrollbarStartOffset + delta).clamp(0, horizontalMaxScroll).toDouble();
    
    _updatingFromScroll = true;
    if (horizontalScrollController.hasClients) {
      horizontalScrollController.jumpTo(newScrollOffset);
    }
    _updatingFromScroll = false;
    
    final double newOffsetX = -newScrollOffset;
    state.offset = Offset(newOffsetX, state.offset.dy);
    onStateUpdate();
  }
  
  void handleHorizontalScrollbarDragEnd(PointerUpEvent details) {
    isHorizontalScrollbarDragging = false;
    onStateUpdate();
  }
  
  void handleVerticalScrollbarDragStart(PointerDownEvent details) {
    isVerticalScrollbarDragging = true;
    verticalScrollbarDragStart = details.localPosition;
    verticalScrollbarStartOffset = verticalScrollController.offset;
    onStateUpdate();
  }
  
  void handleVerticalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!isVerticalScrollbarDragging) return;
    
    final Size canvasSize = _calculateCanvasSize();
    final double verticalMaxScroll = max(0, canvasSize.height - state.viewportSize.height);
    if (verticalMaxScroll == 0) return;
    
    final double viewportToCanvasRatio = canvasSize.height / state.viewportSize.height;
    final double delta = (details.localPosition.dy - verticalScrollbarDragStart.dy) * viewportToCanvasRatio;
    final double newScrollOffset = (verticalScrollbarStartOffset + delta).clamp(0, verticalMaxScroll).toDouble();
    
    _updatingFromScroll = true;
    if (verticalScrollController.hasClients) {
      verticalScrollController.jumpTo(newScrollOffset);
    }
    _updatingFromScroll = false;
    
    final double newOffsetY = -newScrollOffset;
    state.offset = Offset(state.offset.dx, newOffsetY);
    onStateUpdate();
  }
  
  void handleVerticalScrollbarDragEnd(PointerUpEvent details) {
    isVerticalScrollbarDragging = false;
    onStateUpdate();
  }
  
  void dispose() {
    horizontalScrollController.dispose();
    verticalScrollController.dispose();
  }
  
  double max(double a, double b) {
    return a > b ? a : b;
  }
}