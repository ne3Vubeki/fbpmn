import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

import '../models/image_tile.dart';

class CanvasThumbnail extends StatefulWidget {
  final Rect navigationBounds;
  final Offset canvasOffset;
  final double panelWidth;
  final Size viewportSize;
  final double scale;
  final Map<String, ImageTile> imageTiles;
  final Function(Offset)?
  onThumbnailClick; // Новый callback для кликов по миниатюре
  final VoidCallback? onInteractionStart; // Callback при начале взаимодействия с миниатюрой

  const CanvasThumbnail({
    super.key,
    required this.navigationBounds,
    required this.canvasOffset,
    required this.panelWidth,
    required this.viewportSize,
    required this.scale,
    required this.imageTiles,
    this.onThumbnailClick, // Добавляем callback
    this.onInteractionStart,
  });

  @override
  State<CanvasThumbnail> createState() => _CanvasThumbnailState();
}

class _CanvasThumbnailState extends State<CanvasThumbnail> {
  ui.Image? _thumbnailImage;
  double _thumbnailScale = 1.0;
  double _thumbnailWidth = 0;
  double _thumbnailHeight = 0;
  bool _isDragging = false;
  bool _isBuildingThumbnail = false;
  bool _pendingThumbnailRebuild = false;
  Offset _dragStartPosition = Offset.zero;
  Offset _dragStartRectPosition = Offset.zero;

  double _clampedVisibleLeft = 0;
  double _clampedVisibleTop = 0;
  double _clampedVisibleWidth = 0;
  double _clampedVisibleHeight = 0;
  int _lastTilesCount = 0;

  double get _canvasWidth => widget.navigationBounds.width;
  double get _canvasHeight => widget.navigationBounds.height;
  double get _canvasLeft => widget.navigationBounds.left;
  double get _canvasTop => widget.navigationBounds.top;
  double get _visibleWorldWidth => widget.viewportSize.width / widget.scale;
  double get _visibleWorldHeight => widget.viewportSize.height / widget.scale;
  double get _viewportThumbnailWidth => _visibleWorldWidth * _thumbnailScale;
  double get _viewportThumbnailHeight => _visibleWorldHeight * _thumbnailScale;
  double get _minVisibleLeftWorld => math.min(
    _canvasLeft,
    widget.navigationBounds.right - _visibleWorldWidth,
  );
  double get _maxVisibleLeftWorld => math.max(
    _canvasLeft,
    widget.navigationBounds.right - _visibleWorldWidth,
  );
  double get _minVisibleTopWorld => math.min(
    _canvasTop,
    widget.navigationBounds.bottom - _visibleWorldHeight,
  );
  double get _maxVisibleTopWorld => math.max(
    _canvasTop,
    widget.navigationBounds.bottom - _visibleWorldHeight,
  );
  double get _visibleRangeWidthWorld => _maxVisibleLeftWorld - _minVisibleLeftWorld;
  double get _visibleRangeHeightWorld => _maxVisibleTopWorld - _minVisibleTopWorld;

  double _worldLeftToThumbnailLeft(double worldLeft) {
    final double trackWidth = _thumbnailWidth - _viewportThumbnailWidth;
    if (trackWidth <= 0 || _visibleRangeWidthWorld <= 0) {
      return (_thumbnailWidth - _viewportThumbnailWidth) / 2;
    }

    final double progress =
        (worldLeft - _minVisibleLeftWorld) / _visibleRangeWidthWorld;
    return trackWidth * progress.clamp(0.0, 1.0);
  }

  double _worldTopToThumbnailTop(double worldTop) {
    final double trackHeight = _thumbnailHeight - _viewportThumbnailHeight;
    if (trackHeight <= 0 || _visibleRangeHeightWorld <= 0) {
      return (_thumbnailHeight - _viewportThumbnailHeight) / 2;
    }

    final double progress =
        (worldTop - _minVisibleTopWorld) / _visibleRangeHeightWorld;
    return trackHeight * progress.clamp(0.0, 1.0);
  }

  double _thumbnailLeftToWorldLeft(double thumbnailLeft) {
    final double trackWidth = _thumbnailWidth - _viewportThumbnailWidth;
    if (trackWidth <= 0 || _visibleRangeWidthWorld <= 0) {
      return _getVisibleWorldRect().left;
    }

    final double progress = (thumbnailLeft / trackWidth).clamp(0.0, 1.0);
    return _minVisibleLeftWorld + _visibleRangeWidthWorld * progress;
  }

  double _thumbnailTopToWorldTop(double thumbnailTop) {
    final double trackHeight = _thumbnailHeight - _viewportThumbnailHeight;
    if (trackHeight <= 0 || _visibleRangeHeightWorld <= 0) {
      return _getVisibleWorldRect().top;
    }

    final double progress = (thumbnailTop / trackHeight).clamp(0.0, 1.0);
    return _minVisibleTopWorld + _visibleRangeHeightWorld * progress;
  }

  bool _isPointInsideVisibleArea(Offset localPosition) {
    return localPosition.dx >= _clampedVisibleLeft &&
        localPosition.dx <= _clampedVisibleLeft + _clampedVisibleWidth &&
        localPosition.dy >= _clampedVisibleTop &&
        localPosition.dy <= _clampedVisibleTop + _clampedVisibleHeight;
  }

  double _thumbnailPositionToWorldX(double thumbnailX) {
    final double safeCanvasWidth = _canvasWidth > 0 ? _canvasWidth : 1;
    final double normalized = (thumbnailX / _thumbnailWidth).clamp(0.0, 1.0);
    return _canvasLeft + normalized * safeCanvasWidth;
  }

  double _thumbnailPositionToWorldY(double thumbnailY) {
    final double safeCanvasHeight = _canvasHeight > 0 ? _canvasHeight : 1;
    final double normalized = (thumbnailY / _thumbnailHeight).clamp(0.0, 1.0);
    return _canvasTop + normalized * safeCanvasHeight;
  }

  ({double left, double top, double width, double height}) _getVisibleWorldRect() {
    final double visibleWorldLeft = (-widget.canvasOffset.dx / widget.scale).clamp(
      _minVisibleLeftWorld,
      _maxVisibleLeftWorld,
    );
    final double visibleWorldTop = (-widget.canvasOffset.dy / widget.scale).clamp(
      _minVisibleTopWorld,
      _maxVisibleTopWorld,
    );

    return (
      left: visibleWorldLeft,
      top: visibleWorldTop,
      width: _visibleWorldWidth,
      height: _visibleWorldHeight,
    );
  }

  Offset _offsetForVisibleWorldRect({required double left, required double top}) {
    final double newCanvasOffsetX = -left * widget.scale;
    final double newCanvasOffsetY = -top * widget.scale;

    return Offset(newCanvasOffsetX, newCanvasOffsetY);
  }

  @override
  void initState() {
    super.initState();
    _createThumbnail();
  }

  @override
  void didUpdateWidget(CanvasThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);

    // imageTiles мутируется на месте (тот же объект Map), поэтому
    // сравниваем по количеству тайлов или изменению размеров холста/delta
    final bool shouldRebuildThumbnail =
        widget.imageTiles.length != _lastTilesCount ||
        widget.navigationBounds != oldWidget.navigationBounds;

    if (shouldRebuildThumbnail) {
      _lastTilesCount = widget.imageTiles.length;
      _createThumbnail();
    }

    // Перерисовываем видимую область при изменении параметров отображения
    if (widget.canvasOffset != oldWidget.canvasOffset ||
        widget.scale != oldWidget.scale ||
        widget.viewportSize != oldWidget.viewportSize) {
      setState(() {});
    }
  }

  Future<void> _createThumbnail() async {
    if (_isBuildingThumbnail) {
      _pendingThumbnailRebuild = true;
      return;
    }

    _isBuildingThumbnail = true;
    _pendingThumbnailRebuild = false;

    try { 
      final double safeCanvasWidth = _canvasWidth > 0 ? _canvasWidth : 1;
      final double safeCanvasHeight = _canvasHeight > 0 ? _canvasHeight : 1;

      // Миниатюра всегда квадратная
      final double thumbnailSize = widget.panelWidth;

      // Масштаб вписывает всю схему в квадратную область
      final double thumbnailScale = math.min(
        thumbnailSize / safeCanvasWidth,
        thumbnailSize / safeCanvasHeight,
      );
      final double contentWidth = safeCanvasWidth * thumbnailScale;
      final double contentHeight = safeCanvasHeight * thumbnailScale;
      final double contentOffsetX = (thumbnailSize - contentWidth) / 2;
      final double contentOffsetY = (thumbnailSize - contentHeight) / 2;

      // Сохраняем расчетные значения для использования в build()
      _thumbnailScale = thumbnailScale;
      _thumbnailWidth = thumbnailSize;
      _thumbnailHeight = thumbnailSize;

      // Создаем PictureRecorder для миниатюры
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Применяем масштаб миниатюры
      canvas.translate(contentOffsetX, contentOffsetY);
      canvas.scale(thumbnailScale, thumbnailScale);
      canvas.translate(-_canvasLeft, -_canvasTop);

      // Делаем снимок списка тайлов ДО первого await,
      // чтобы избежать use-after-free при dispose тайлов в TileManager
      final tilesSnapshot = Map.of(widget.imageTiles);

      // Рисуем все тайлы с улучшенным качеством
      for (final entry in tilesSnapshot.entries) {
        final tile = entry.value;
        // Позиция тайла на миниатюре
        final tileRect = tile.bounds;

        canvas.save();
        canvas.clipRect(tileRect);
        canvas.translate(tile.bounds.left, tile.bounds.top);
        canvas.drawPicture(tile.picture);
        canvas.restore();
      }

      // Завершаем запись и создаем изображение
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        thumbnailSize.toInt().clamp(1, 1000000),
        thumbnailSize.toInt().clamp(1, 1000000),
      );
      picture.dispose();

      if (mounted) {
        setState(() {
          _thumbnailImage?.dispose();
          _thumbnailImage = image;
        });
      } else {
        image.dispose();
      }
    } catch (e) {
      print('CanvasThumbnail._createThumbnail error: $e');
    } finally {
      _isBuildingThumbnail = false;
      if (_pendingThumbnailRebuild && mounted) {
        _createThumbnail();
      }
    }
  }

  // Обработчик начала перетаскивания в миниатюре
  void _handleDragStart(Offset localPosition) {
    if (_thumbnailImage == null) return;

    widget.onInteractionStart?.call();

    // Проверяем, кликнули ли внутри видимой области
    final bool clickedInVisibleArea = _isPointInsideVisibleArea(localPosition);

    if (!clickedInVisibleArea) {
      // Если кликнули вне видимой области, центрируем на этой точке
      _handleTap(localPosition);
      return;
    }

    _isDragging = true;
    _dragStartPosition = localPosition;

    // Сохраняем начальную позицию прямоугольника в миниатюре
    _dragStartRectPosition = Offset(_clampedVisibleLeft, _clampedVisibleTop);

    setState(() {});
  }

  // Обработчик перемещения в миниатюре
  void _handleDragUpdate(Offset localPosition) {
    if (!_isDragging || _thumbnailImage == null) return;

    // Рассчитываем смещение мыши в координатах миниатюры
    final Offset mouseDelta = localPosition - _dragStartPosition;

    final double minRectLeft = math.min(0, _thumbnailWidth - _clampedVisibleWidth);
    final double minRectTop = math.min(0, _thumbnailHeight - _clampedVisibleHeight);
    final double maxRectLeft = math.max(0, _thumbnailWidth - _clampedVisibleWidth);
    final double maxRectTop = math.max(0, _thumbnailHeight - _clampedVisibleHeight);

    // Новая позиция прямоугольника в миниатюре
    final double newRectLeft = (_dragStartRectPosition.dx + mouseDelta.dx)
        .clamp(minRectLeft, maxRectLeft);
    final double newRectTop = (_dragStartRectPosition.dy + mouseDelta.dy).clamp(minRectTop, maxRectTop);

    // Обновляем позицию прямоугольника
    _clampedVisibleLeft = newRectLeft;
    _clampedVisibleTop = newRectTop;

    // Преобразуем позицию прямоугольника в миниатюре в мировые координаты
    final double visibleWorldLeft = _thumbnailLeftToWorldLeft(newRectLeft);
    final double visibleWorldTop = _thumbnailTopToWorldTop(newRectTop);

    final Offset newCanvasOffset = _offsetForVisibleWorldRect(
      left: visibleWorldLeft,
      top: visibleWorldTop,
    );

    // Вызываем callback с новым положением
    if (widget.onThumbnailClick != null) {
      widget.onThumbnailClick!(newCanvasOffset);
    }

    setState(() {});
  }

  // Обработчик окончания перетаскивания
  void _handleDragEnd() {
    _isDragging = false;
    setState(() {});
  }

  // Обработчик клика по миниатюре (без перетаскивания)
  void _handleTap(Offset localPosition) {
    if (_thumbnailImage == null) return;

    if (_isPointInsideVisibleArea(localPosition)) {
      return;
    }

    // Преобразуем координаты клика из миниатюры в мировые координаты
    final double worldX = _thumbnailPositionToWorldX(localPosition.dx);
    final double worldY = _thumbnailPositionToWorldY(localPosition.dy);

    // Центрируем viewport на этой точке
    // Центр viewport должен быть в точке (worldX, worldY)
    // visibleWorldLeft = worldX - (viewportWidth / 2 / scale)
    final visibleRect = _getVisibleWorldRect();
    final double newVisibleWorldLeft = worldX - (visibleRect.width / 2);
    final double newVisibleWorldTop = worldY - (visibleRect.height / 2);

    // Ограничиваем мировые координаты границами холста
    final double clampedWorldLeft = newVisibleWorldLeft.clamp(_minVisibleLeftWorld, _maxVisibleLeftWorld);
    final double clampedWorldTop = newVisibleWorldTop.clamp(_minVisibleTopWorld, _maxVisibleTopWorld);

    // Вызываем callback
    if (widget.onThumbnailClick != null) {
      widget.onThumbnailClick!(
        _offsetForVisibleWorldRect(
          left: clampedWorldLeft,
          top: clampedWorldTop,
        ),
      );
    }
  }

  @override
  void dispose() {
    _thumbnailImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailImage == null) {
      return Container(
        width: widget.panelWidth,
        height: widget.panelWidth,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final double thumbnailWidth = _thumbnailWidth;
    final double thumbnailHeight = _thumbnailHeight;

    final visibleRect = _getVisibleWorldRect();

    // Переводим в координаты миниатюры
    final double visibleLeft = _worldLeftToThumbnailLeft(visibleRect.left);
    final double visibleTop = _worldTopToThumbnailTop(visibleRect.top);
    final double visibleWidth = _viewportThumbnailWidth;
    final double visibleHeight = _viewportThumbnailHeight;

    // Ограничиваем координаты видимой области границами миниатюры
    _clampedVisibleLeft = visibleLeft;
    _clampedVisibleTop = visibleTop;
    _clampedVisibleWidth = visibleWidth;
    _clampedVisibleHeight = visibleHeight;

    return GestureDetector(
      onPanStart: (details) => _handleDragStart(details.localPosition),
      onPanUpdate: (details) => _handleDragUpdate(details.localPosition),
      onPanEnd: (details) => _handleDragEnd(),
      onPanCancel: () => _handleDragEnd(),
      onTapUp: (details) => _handleTap(details.localPosition),
      child: Container(
        width: thumbnailWidth,
        height: thumbnailHeight,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isDragging ? Colors.blue : Colors.grey[400]!,
            width: _isDragging ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(_isDragging ? 2 : 1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Opacity(
                  opacity: 0.7,
                  child: RawImage(
                    image: _thumbnailImage,
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    fit: BoxFit.fill,
                  ),
                ),
                Positioned(
                  left: _clampedVisibleLeft,
                  top: _clampedVisibleTop,
                  child: Container(
                    width: _clampedVisibleWidth,
                    height: _clampedVisibleHeight,
                    decoration: BoxDecoration(
                      color: _isDragging
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.2),
                      border: Border.all(
                        color: _isDragging
                            ? Colors.blue.withOpacity(0.9)
                            : Colors.blue.withOpacity(0.8),
                        width: _isDragging ? 2 : 1.5,
                      ),
                    ),
                  ),
                ),
                if (_isDragging)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withOpacity(0.1),
                      child: const Center(
                        child: Icon(
                          Icons.open_with,
                          size: 24,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
