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
  
  ScrollHandler({
    required this.state,
    this.nodeManager,
    required this.onStateUpdate,
  }) {
    horizontalScrollController.addListener(_onHorizontalScroll);
    verticalScrollController.addListener(_onVerticalScroll);
  }
  
  void centerCanvas() {
    final Size canvasSize = _calculateCanvasSize();
    
    // Простое центрирование
    state.offset = Offset(
      (state.viewportSize.width - canvasSize.width) / 2,
      (state.viewportSize.height - canvasSize.height) / 2,
    );
    
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
  
  void updateScrollControllers() {
    final Size canvasSize = _calculateCanvasSize();
    
    final double horizontalMaxScroll = _max(0, canvasSize.width - state.viewportSize.width);
    final double verticalMaxScroll = _max(0, canvasSize.height - state.viewportSize.height);
    
    // Рассчитываем позицию скроллбара на основе offset
    final double horizontalPosition = _clamp(-state.offset.dx, 0, horizontalMaxScroll);
    final double verticalPosition = _clamp(-state.offset.dy, 0, verticalMaxScroll);
    
    // Обновляем скроллбары
    if (horizontalScrollController.hasClients) {
      horizontalScrollController.jumpTo(horizontalPosition);
    }
    
    if (verticalScrollController.hasClients) {
      verticalScrollController.jumpTo(verticalPosition);
    }
  }
  
  Size _calculateCanvasSize() {
    return Size(
      state.viewportSize.width * canvasSizeMultiplier * state.scale,
      state.viewportSize.height * canvasSizeMultiplier * state.scale,
    );
  }
  
  void _onHorizontalScroll() {
    final double scrollPosition = horizontalScrollController.offset;
    final Size canvasSize = _calculateCanvasSize();
    final double maxScroll = _max(0, canvasSize.width - state.viewportSize.width);
    
    final double clampedScroll = _clamp(scrollPosition, 0, maxScroll);
    state.offset = Offset(-clampedScroll, state.offset.dy);
    
    // Обновляем позицию выделенного узла
    if (state.isNodeOnTopLayer) {
      nodeManager?.onOffsetChanged();
    }
    
    onStateUpdate();
  }
  
  void _onVerticalScroll() {
    final double scrollPosition = verticalScrollController.offset;
    final Size canvasSize = _calculateCanvasSize();
    final double maxScroll = _max(0, canvasSize.height - state.viewportSize.height);
    
    final double clampedScroll = _clamp(scrollPosition, 0, maxScroll);
    state.offset = Offset(state.offset.dx, -clampedScroll);
    
    // Обновляем позицию выделенного узла
    if (state.isNodeOnTopLayer) {
      nodeManager?.onOffsetChanged();
    }
    
    onStateUpdate();
  }
  
  // Методы для перетаскивания скроллбаров (упрощенные)
  void handleHorizontalScrollbarDragStart(PointerDownEvent details) {
    // Можно оставить пустым для простоты
  }
  
  void handleHorizontalScrollbarDragUpdate(PointerMoveEvent details) {
    // Можно оставить пустым для простоты
  }
  
  void handleHorizontalScrollbarDragEnd(PointerUpEvent details) {
    // Можно оставить пустым для простоты
  }
  
  void handleVerticalScrollbarDragStart(PointerDownEvent details) {
    // Можно оставить пустым для простоты
  }
  
  void handleVerticalScrollbarDragUpdate(PointerMoveEvent details) {
    // Можно оставить пустым для простоты
  }
  
  void handleVerticalScrollbarDragEnd(PointerUpEvent details) {
    // Можно оставить пустым для простоты
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