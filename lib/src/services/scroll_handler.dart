import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/utils/utils.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../editor_state.dart';
import '../models/table.node.dart';
import '../services/node_manager.dart';
import '../utils/editor_config.dart';
import 'manager.dart';

class ScrollHandler extends Manager {
  final EditorState state;
  final NodeManager? nodeManager;
  final ArrowManager? arrowManager;

  static const double tileSize = 1024.0; // Размер тайла

  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController verticalScrollController = ScrollController();

  // Для перетаскивания скроллбаров
  bool _isHorizontalDragging = false;
  bool _isVerticalDragging = false;
  Offset _horizontalDragStart = Offset.zero;
  Offset _verticalDragStart = Offset.zero;
  double _horizontalDragStartOffset = 0.0;
  double _verticalDragStartOffset = 0.0;

  Rect? get schemeBounds => Utils.getNodesWorldBounds(state.nodes, state.delta)?.worldBounds;
  Rect _toSquareBounds(Rect bounds) {
    final double side = math.max(bounds.width, bounds.height);
    return Rect.fromCenter(
      center: bounds.center,
      width: side,
      height: side,
    );
  }

  Rect get navigationBounds {
    final bounds = schemeBounds;
    if (bounds == null) {
      return _toSquareBounds(Rect.fromCenter(
        center: Offset.zero,
        width: EditorConfig.staticCanvasWidth,
        height: EditorConfig.staticCanvasHeight,
      ));
    }
    return _toSquareBounds(bounds.inflate(1000));
  }
  Size get scaledCanvasSize => Size(
    navigationBounds.width * state.scale,
    navigationBounds.height * state.scale,
  );
  Size get scrollContentSize => Size(
    horizontalScrollContentSize,
    verticalScrollContentSize,
  );
  double get horizontalScrollExtent =>
      (scaledCanvasSize.width - state.viewportSize.width).abs();
  double get verticalScrollExtent =>
      (scaledCanvasSize.height - state.viewportSize.height).abs();
  double get horizontalScrollContentSize =>
      state.viewportSize.width + horizontalScrollExtent;
  double get verticalScrollContentSize =>
      state.viewportSize.height + verticalScrollExtent;
  double get visibleWorldWidth => state.viewportSize.width / state.scale;
  double get visibleWorldHeight => state.viewportSize.height / state.scale;
  double get minVisibleLeftWorld => math.min(
    navigationBounds.left,
    navigationBounds.right - visibleWorldWidth,
  );
  double get maxVisibleLeftWorld => math.max(
    navigationBounds.left,
    navigationBounds.right - visibleWorldWidth,
  );
  double get minVisibleTopWorld => math.min(
    navigationBounds.top,
    navigationBounds.bottom - visibleWorldHeight,
  );
  double get maxVisibleTopWorld => math.max(
    navigationBounds.top,
    navigationBounds.bottom - visibleWorldHeight,
  );
  Rect get visibleWorldRect => Rect.fromLTWH(
    (-state.offset.dx / state.scale).clamp(minVisibleLeftWorld, maxVisibleLeftWorld),
    (-state.offset.dy / state.scale).clamp(minVisibleTopWorld, maxVisibleTopWorld),
    visibleWorldWidth,
    visibleWorldHeight,
  );

  // Наличие скроллбаров
  bool get needsHorizontalScrollbar => horizontalScrollExtent > 0.5;
  bool get needsVerticalScrollbar => verticalScrollExtent > 0.5;

  ScrollHandler({required this.state, this.nodeManager, this.arrowManager}) {
    horizontalScrollController.addListener(_onHorizontalScroll);
    verticalScrollController.addListener(_onVerticalScroll);
  }

  /// Сбрасывает динамические размеры холста к дефолтным значениям.
  /// Нужен при переключении на пустую схему, чтобы не сохранялись размеры
  /// предыдущей (большой) схемы.
  void resetCanvasSizeToDefault({bool notify = false}) {
    if (notify) {
      onStateUpdate();
    }
  }

  /// Рассчитывает размер холста на основе расположения узлов
  void calculateCanvasSizeFromNodes(List<TableNode> nodes) {
    if (nodes.isEmpty) {
      return;
    }
  }

  /// Автоматически масштабирует и центрирует узлы в видимой области
  void autoFitAndCenterNodes() {
    if (nodeManager == null || state.nodes.isEmpty) {
      centerCanvas();
      return;
    }

    // Рассчитываем границы всех узлов
    final result = Utils.getNodesWorldBounds(state.nodes, state.delta);
    if (result == null) {
      centerCanvas();
      return;
    }
    final bounds = result.worldBounds;

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
    if (state.nodesIdOnTopLayer.isNotEmpty) {
      nodeManager?.onOffsetChanged();
    }

    updateScrollControllers();
    state.isInitialized = true;
    onStateUpdate();
  }

  void centerCanvas() {
    final Rect bounds = navigationBounds;
    state.offset = Offset(
      state.viewportSize.width / 2 - bounds.center.dx * state.scale,
      state.viewportSize.height / 2 - bounds.center.dy * state.scale,
    );

    // Корректируем offset, чтобы не выходить за границы
    _constrainCurrentOffset();

    // Обновляем позицию выделенного узла
    if (state.nodesIdOnTopLayer.isNotEmpty) {
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
    state.offset = constrainOffset(state.offset);
  }

  Offset constrainOffset(Offset offset) {
    double constrainedX = offset.dx;
    double constrainedY = offset.dy;

    final double visibleLeft = -offset.dx / state.scale;
    final double clampedVisibleLeft = _clamp(
      visibleLeft,
      minVisibleLeftWorld,
      maxVisibleLeftWorld,
    );
    constrainedX = -clampedVisibleLeft * state.scale;

    final double visibleTop = -offset.dy / state.scale;
    final double clampedVisibleTop = _clamp(
      visibleTop,
      minVisibleTopWorld,
      maxVisibleTopWorld,
    );
    constrainedY = -clampedVisibleTop * state.scale;

    return Offset(constrainedX, constrainedY);
  }

  void updateScrollControllers() {
    // Текущая позиция в координатах скроллбара
    final double horizontalPosition = _clamp(
      (-state.offset.dx - minVisibleLeftWorld * state.scale),
      0,
      horizontalScrollExtent,
    );
    final double verticalPosition = _clamp(
      (-state.offset.dy - minVisibleTopWorld * state.scale),
      0,
      verticalScrollExtent,
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
    final Size previousViewportSize = state.viewportSize;
    state.viewportSize = newViewportSize;

    final bool isFirstValidViewport =
        previousViewportSize.width <= 0 || previousViewportSize.height <= 0;

    if (isFirstValidViewport && newViewportSize.width > 0 && newViewportSize.height > 0) {
      if (state.nodes.isNotEmpty) {
        autoFitAndCenterNodes();
      } else {
        centerCanvas();
      }
      return;
    }

    // Корректируем текущий offset под новый размер viewport
    _constrainCurrentOffset();

    // Обновляем скроллбары
    updateScrollControllers();

    // Обновляем позицию выделенного узла
    if (state.nodesIdOnTopLayer.isNotEmpty) {
      nodeManager?.onOffsetChanged();
    }

    onStateUpdate();
  }

  void _onHorizontalScroll() {
    if (_isHorizontalDragging)
      return; // Игнорируем при перетаскивании и программном обновлении

    final double scrollPosition = horizontalScrollController.offset;

    final double clampedScroll = _clamp(scrollPosition, 0, horizontalScrollExtent);
    final double visibleLeft = minVisibleLeftWorld + clampedScroll / state.scale;
    state.offset = Offset(-visibleLeft * state.scale, state.offset.dy);

    // Обновляем позицию выделенного узла
    if (state.nodesIdOnTopLayer.isNotEmpty) {
      nodeManager?.onOffsetChanged();
    }

    onStateUpdate();
  }

  void _onVerticalScroll() {
    if (_isVerticalDragging)
      return; // Игнорируем при перетаскивании и программном обновлении

    final double scrollPosition = verticalScrollController.offset;

    final double clampedScroll = _clamp(scrollPosition, 0, verticalScrollExtent);
    final double visibleTop = minVisibleTopWorld + clampedScroll / state.scale;
    state.offset = Offset(state.offset.dx, -visibleTop * state.scale);

    // Обновляем позицию выделенного узла
    if (state.nodesIdOnTopLayer.isNotEmpty) {
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

    final double maxScroll = horizontalScrollExtent;

    if (maxScroll == 0) return;

    final double mouseDelta =
        details.localPosition.dx - _horizontalDragStart.dx;

    // САМЫЙ ПРОСТОЙ И ТОЧНЫЙ РАСЧЕТ:
    // Если холст в N раз больше viewport, то движение мыши на 1px = движение скроллбара на N px
    final double canvasToViewportWidthRatio =
        horizontalScrollContentSize / state.viewportSize.width;
    final double adjustedDelta = mouseDelta * canvasToViewportWidthRatio;

    final double newScrollOffset = _clamp(
      _horizontalDragStartOffset + adjustedDelta,
      0,
      maxScroll,
    );

    if (horizontalScrollController.hasClients) {
      horizontalScrollController.jumpTo(newScrollOffset);
    }

    final double visibleLeft = minVisibleLeftWorld + newScrollOffset / state.scale;
    state.offset = Offset(-visibleLeft * state.scale, state.offset.dy);

    if (state.nodesIdOnTopLayer.isNotEmpty) {
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

    final double maxScroll = verticalScrollExtent;

    if (maxScroll == 0) return;

    final double mouseDelta = details.localPosition.dy - _verticalDragStart.dy;

    // САМЫЙ ПРОСТОЙ И ТОЧНЫЙ РАСЧЕТ:
    final double canvasToViewportHeightRatio =
        verticalScrollContentSize / state.viewportSize.height;
    final double adjustedDelta = mouseDelta * canvasToViewportHeightRatio;

    final double newScrollOffset = _clamp(
      _verticalDragStartOffset + adjustedDelta,
      0,
      maxScroll,
    );

    if (verticalScrollController.hasClients) {
      verticalScrollController.jumpTo(newScrollOffset);
    }

    final double visibleTop = minVisibleTopWorld + newScrollOffset / state.scale;
    state.offset = Offset(state.offset.dx, -visibleTop * state.scale);

    if (state.nodesIdOnTopLayer.isNotEmpty) {
      nodeManager?.onOffsetChanged();
    }

    onStateUpdate();
  }

  void handleVerticalScrollbarDragEnd(PointerUpEvent details) {
    _isVerticalDragging = false;
    onStateUpdate();
  }

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
