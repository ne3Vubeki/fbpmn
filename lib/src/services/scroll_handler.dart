import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../editor_state.dart';
import '../models/table.node.dart';
import '../services/node_manager.dart';
import '../utils/bounds_calculator.dart';
import '../utils/editor_config.dart';
import 'manager.dart';

class ScrollHandler extends Manager {
  final EditorState state;
  final NodeManager? nodeManager;

  final BoundsCalculator _boundsCalculator = BoundsCalculator();
  static const double tileSize = 1024.0; // Размер тайла

  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController verticalScrollController = ScrollController();

  // Статичный размер холста (используется по умолчанию)
  static const double staticCanvasWidth = 12288.0;
  static const double staticCanvasHeight = 6144.0;

  // Динамически рассчитанные размеры холста
  double _dynamicCanvasWidth = staticCanvasWidth;
  double _dynamicCanvasHeight = staticCanvasHeight;

  // Для перетаскивания скроллбаров
  bool _isHorizontalDragging = false;
  bool _isVerticalDragging = false;
  Offset _horizontalDragStart = Offset.zero;
  Offset _verticalDragStart = Offset.zero;
  double _horizontalDragStartOffset = 0.0;
  double _verticalDragStartOffset = 0.0;

  // Геттеры для динамических размеров холста
  double get dynamicCanvasWidth => _dynamicCanvasWidth;
  double get dynamicCanvasHeight => _dynamicCanvasHeight;

  ScrollHandler({required this.state, this.nodeManager}) {
    horizontalScrollController.addListener(_onHorizontalScroll);
    verticalScrollController.addListener(_onVerticalScroll);
  }

  /// Рассчитывает размер холста на основе расположения узлов
  void calculateCanvasSizeFromNodes(List<TableNode> nodes) {
    if (nodes.isEmpty) return;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    // Сначала рассчитываем границы узлов с текущим delta
    for (final node in nodes) {
      final nodePosition = state.delta + node.position;
      final nodeRect = _boundsCalculator.calculateNodeRect(
        node: node,
        position: nodePosition,
      );

      minX = math.min(minX, nodeRect.left);
      minY = math.min(minY, nodeRect.top);
      maxX = math.max(maxX, nodeRect.right);
      maxY = math.max(maxY, nodeRect.bottom);
    }

    const double padding = 1000;

    // Рассчитываем необходимые границы холста
    final double requiredLeft = minX - padding;
    final double requiredTop = minY - padding;

    // Корректируем delta так, чтобы requiredLeft был в 0
    // Это сместит все узлы вправо, чтобы они поместились в холст
    final Offset deltaCorrection = Offset(-requiredLeft, -requiredTop);
    state.delta += deltaCorrection;

    // После изменения delta нужно обновить абсолютные позиции всех узлов
    for (final node in nodes) {
      node.calculateAbsolutePositions(state.delta);
    }

    // Теперь пересчитываем границы с новым delta
    minX = double.infinity;
    minY = double.infinity;
    maxX = -double.infinity;
    maxY = -double.infinity;

    for (final node in nodes) {
      final nodePosition = state.delta + node.position;
      final nodeRect = _boundsCalculator.calculateNodeRect(
        node: node,
        position: nodePosition,
      );

      minX = math.min(minX, nodeRect.left);
      minY = math.min(minY, nodeRect.top);
      maxX = math.max(maxX, nodeRect.right);
      maxY = math.max(maxY, nodeRect.bottom);
    }

    // Рассчитываем окончательный размер холста
    final double finalWidth = (maxX - minX) + padding * 2;
    final double finalHeight = (maxY - minY) + padding * 2;

    // Округляем до размера тайла
    final double calculatedWidth = _roundToTileMultiple(finalWidth, tileSize);
    final double calculatedHeight = _roundToTileMultiple(finalHeight, tileSize);

    // Используем бОльший размер: расчетный или статический
    _dynamicCanvasWidth = math.max(calculatedWidth, staticCanvasWidth);
    _dynamicCanvasHeight = math.max(calculatedHeight, staticCanvasHeight);
  }

  /// Округляет значение до ближайшего кратного размеру тайла
  double _roundToTileMultiple(double value, double tileSize) {
    final double tilesCount = (value / tileSize).ceil().toDouble();
    return tilesCount * tileSize;
  }

  /// Размер холста с учетом масштаба (динамические размеры)
  Size _calculateCanvasSize() {
    // Используем динамический размер, но не меньше минимального
    final double width =
        math.max(_dynamicCanvasWidth, staticCanvasWidth) * state.scale;
    final double height =
        math.max(_dynamicCanvasHeight, staticCanvasHeight) * state.scale;

    return Size(width, height);
  }

  /// Автоматически масштабирует и центрирует узлы в видимой области
  void autoFitAndCenterNodes() {
    if (nodeManager == null || state.nodes.isEmpty) {
      centerCanvas();
      return;
    }

    // Рассчитываем границы всех узлов
    final bounds = _calculateNodesBounds(state.nodes);
    if (bounds == null) {
      centerCanvas();
      return;
    }

    // Получаем размеры видимой области
    final viewportWidth = state.viewportSize.width;
    final viewportHeight = state.viewportSize.height;

    if (viewportWidth <= 0 || viewportHeight <= 0) {
      centerCanvas();
      return;
    }

    // Рассчитываем требуемый масштаб для размещения всех узлов в видимой области
    final requiredWidth = bounds.width;
    final requiredHeight = bounds.height;

    // Оставляем небольшой отступ для лучшего восприятия
    final padding = 50.0;

    // Масштаб по ширине и высоте
    final scaleX = (viewportWidth - padding * 2) / requiredWidth;
    final scaleY = (viewportHeight - padding * 2) / requiredHeight;

    // Берем минимальный масштаб, чтобы всё поместилось
    var targetScale = scaleX < scaleY ? scaleX : scaleY;

    // Ограничиваем масштаб в пределах допустимого диапазона
    targetScale = _clamp(
      targetScale,
      EditorConfig.minScale,
      EditorConfig.maxScale,
    );

    // Устанавливаем новый масштаб
    state.scale = targetScale;

    // Центрируем видимую область по центру узлов
    final centerX =
        viewportWidth / 2 - (bounds.left + bounds.width / 2) * targetScale;
    final centerY =
        viewportHeight / 2 - (bounds.top + bounds.height / 2) * targetScale;

    state.offset = Offset(centerX, centerY);

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

  /// Рассчитывает границы всех узлов
  Rect? _calculateNodesBounds(List<TableNode> nodes) {
    if (nodes.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final node in nodes) {
      final nodePosition = state.delta + node.position;
      final nodeRect = _boundsCalculator.calculateNodeRect(
        node: node,
        position: nodePosition,
      );

      minX = math.min(minX, nodeRect.left);
      minY = math.min(minY, nodeRect.top);
      maxX = math.max(maxX, nodeRect.right);
      maxY = math.max(maxY, nodeRect.bottom);
    }

    if (minX == double.infinity ||
        minY == double.infinity ||
        maxX == -double.infinity ||
        maxY == -double.infinity) {
      return null;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
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
    if (_isHorizontalDragging)
      return; // Игнорируем при перетаскивании и программном обновлении

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
    if (_isVerticalDragging)
      return; // Игнорируем при перетаскивании и программном обновлении

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

  // === МЕТОДЫ ДЛЯ ПЕРЕТАСКИВАНИЯ СКРОЛЛБАРОВ ===

  void handleHorizontalScrollbarDragStart(PointerDownEvent details) {
    _isHorizontalDragging = true;
    _horizontalDragStart = details.localPosition;
    _horizontalDragStartOffset = horizontalScrollController.offset;
    onStateUpdate();
  }

  void handleHorizontalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!_isHorizontalDragging) return;

    final Size canvasSize = _calculateCanvasSize();
    final double maxScroll = _max(
      0,
      canvasSize.width - state.viewportSize.width,
    );

    if (maxScroll == 0) return;

    final double mouseDelta =
        details.localPosition.dx - _horizontalDragStart.dx;

    // САМЫЙ ПРОСТОЙ И ТОЧНЫЙ РАСЧЕТ:
    // Если холст в N раз больше viewport, то движение мыши на 1px = движение скроллбара на N px
    final double canvasToViewportWidthRatio =
        canvasSize.width / state.viewportSize.width;
    final double adjustedDelta = mouseDelta * canvasToViewportWidthRatio;

    final double newScrollOffset = _clamp(
      _horizontalDragStartOffset + adjustedDelta,
      0,
      maxScroll,
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
    final double maxScroll = _max(
      0,
      canvasSize.height - state.viewportSize.height,
    );

    if (maxScroll == 0) return;

    final double mouseDelta = details.localPosition.dy - _verticalDragStart.dy;

    // САМЫЙ ПРОСТОЙ И ТОЧНЫЙ РАСЧЕТ:
    final double canvasToViewportHeightRatio =
        canvasSize.height / state.viewportSize.height;
    final double adjustedDelta = mouseDelta * canvasToViewportHeightRatio;

    final double newScrollOffset = _clamp(
      _verticalDragStartOffset + adjustedDelta,
      0,
      maxScroll,
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

  @override
  void dispose() {
    super.dispose();
    horizontalScrollController.dispose();
    verticalScrollController.dispose();
  }
}
