import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../models/image_tile.dart';

class CanvasThumbnail extends StatefulWidget {
  final double canvasWidth;
  final double canvasHeight;
  final Offset canvasOffset;
  final double panelWidth;
  final Offset delta;
  final Size viewportSize;
  final double scale;
  final Map<String, ImageTile> imageTiles;
  final Function(Offset)?
  onThumbnailClick; // Новый callback для кликов по миниатюре
  final VoidCallback? onInteractionStart; // Callback при начале взаимодействия с миниатюрой

  const CanvasThumbnail({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.canvasOffset,
    required this.panelWidth,
    required this.delta,
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
        widget.canvasWidth != oldWidget.canvasWidth ||
        widget.canvasHeight != oldWidget.canvasHeight ||
        widget.delta != oldWidget.delta;

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
      final double safeCanvasWidth = widget.canvasWidth > 0 ? widget.canvasWidth : 1;
      final double safeCanvasHeight = widget.canvasHeight > 0 ? widget.canvasHeight : 1;

      // Ширина миниатюры всегда = panelWidth
      final double thumbnailWidth = widget.panelWidth;

      // Высота рассчитывается пропорционально размерам холста
      final double aspectRatio = safeCanvasWidth / safeCanvasHeight;
      final double thumbnailHeight = thumbnailWidth / aspectRatio;

      // Масштаб для миниатюры (отношение ширины миниатюры к ширине холста)
      final double thumbnailScale = thumbnailWidth / safeCanvasWidth;

      // Сохраняем расчетные значения для использования в build()
      _thumbnailScale = thumbnailScale;
      _thumbnailWidth = thumbnailWidth;
      _thumbnailHeight = thumbnailHeight;

      // Создаем PictureRecorder для миниатюры
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Применяем масштаб миниатюры
      canvas.scale(thumbnailScale, thumbnailScale);

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
        thumbnailWidth.toInt().clamp(1, 1000000),
        thumbnailHeight.toInt().clamp(1, 1000000),
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
    final bool clickedInVisibleArea =
        localPosition.dx >= _clampedVisibleLeft &&
        localPosition.dx <= _clampedVisibleLeft + _clampedVisibleWidth &&
        localPosition.dy >= _clampedVisibleTop &&
        localPosition.dy <= _clampedVisibleTop + _clampedVisibleHeight;

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

    final double maxRectLeft = (_thumbnailWidth - _clampedVisibleWidth) < 0
        ? 0
        : (_thumbnailWidth - _clampedVisibleWidth);
    final double maxRectTop = (_thumbnailHeight - _clampedVisibleHeight) < 0
        ? 0
        : (_thumbnailHeight - _clampedVisibleHeight);

    // Новая позиция прямоугольника в миниатюре
    final double newRectLeft = (_dragStartRectPosition.dx + mouseDelta.dx)
        .clamp(0, maxRectLeft);
    final double newRectTop = (_dragStartRectPosition.dy + mouseDelta.dy).clamp(0, maxRectTop);

    // Обновляем позицию прямоугольника
    _clampedVisibleLeft = newRectLeft;
    _clampedVisibleTop = newRectTop;

    // Преобразуем позицию прямоугольника в миниатюре в мировые координаты
    // Позиция прямоугольника в мировых координатах = позиция в миниатюре / масштаб миниатюры
    final double visibleWorldLeft = newRectLeft / _thumbnailScale;
    final double visibleWorldTop = newRectTop / _thumbnailScale;

    // Преобразуем мировые координаты видимой области в canvasOffset
    // Формула: canvasOffset.dx = -visibleWorldLeft * scale
    final double newCanvasOffsetX = -visibleWorldLeft * widget.scale;
    final double newCanvasOffsetY = -visibleWorldTop * widget.scale;

    // Вычисляем новый canvasOffset
    final Offset newCanvasOffset = Offset(newCanvasOffsetX, newCanvasOffsetY);

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

    // Преобразуем координаты клика из миниатюры в мировые координаты
    final double worldX = localPosition.dx / _thumbnailScale;
    final double worldY = localPosition.dy / _thumbnailScale;

    // Центрируем viewport на этой точке
    // Центр viewport должен быть в точке (worldX, worldY)
    // visibleWorldLeft = worldX - (viewportWidth / 2 / scale)
    final double newVisibleWorldLeft =
        worldX - (widget.viewportSize.width / widget.scale / 2);
    final double newVisibleWorldTop =
        worldY - (widget.viewportSize.height / widget.scale / 2);

    // Ограничиваем мировые координаты границами холста
    final double maxWorldLeft =
        widget.canvasWidth - (widget.viewportSize.width / widget.scale);
    final double maxWorldTop =
        widget.canvasHeight - (widget.viewportSize.height / widget.scale);

    final double safeMaxWorldLeft = maxWorldLeft < 0 ? 0 : maxWorldLeft;
    final double safeMaxWorldTop = maxWorldTop < 0 ? 0 : maxWorldTop;

    final double clampedWorldLeft = newVisibleWorldLeft.clamp(0, safeMaxWorldLeft);
    final double clampedWorldTop = newVisibleWorldTop.clamp(0, safeMaxWorldTop);

    // Преобразуем в canvasOffset
    final double newCanvasOffsetX = -clampedWorldLeft * widget.scale;
    final double newCanvasOffsetY = -clampedWorldTop * widget.scale;

    // Вызываем callback
    if (widget.onThumbnailClick != null) {
      widget.onThumbnailClick!(Offset(newCanvasOffsetX, newCanvasOffsetY));
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
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Используем расчетные размеры из _createThumbnail()
    final double thumbnailWidth = _thumbnailWidth;
    final double thumbnailHeight = _thumbnailHeight;
    final double thumbnailScale = _thumbnailScale;

    // КОРРЕКТНЫЙ РАСЧЕТ видимой области
    // Видимая область на основном холсте (в мировых координатах)
    final double visibleWorldWidth = widget.viewportSize.width / widget.scale;
    final double visibleWorldHeight = widget.viewportSize.height / widget.scale;

    // Позиция видимой области в мировых координатах
    // offset - это смещение холста относительно viewport
    // Формула: visibleWorldLeft = -offset.dx / scale
    final double visibleWorldLeft = -widget.canvasOffset.dx / widget.scale;
    final double visibleWorldTop = -widget.canvasOffset.dy / widget.scale;

    // Переводим в координаты миниатюры
    final double visibleLeft = visibleWorldLeft * thumbnailScale;
    final double visibleTop = visibleWorldTop * thumbnailScale;
    final double visibleWidth = visibleWorldWidth * thumbnailScale;
    final double visibleHeight = visibleWorldHeight * thumbnailScale;

    final double clampedVisibleWidth = visibleWidth.clamp(0, thumbnailWidth);
    final double clampedVisibleHeight = visibleHeight.clamp(0, thumbnailHeight);
    final double maxVisibleLeft = (thumbnailWidth - clampedVisibleWidth) < 0
        ? 0
        : (thumbnailWidth - clampedVisibleWidth);
    final double maxVisibleTop = (thumbnailHeight - clampedVisibleHeight) < 0
        ? 0
        : (thumbnailHeight - clampedVisibleHeight);

    // Ограничиваем координаты видимой области границами миниатюры
    _clampedVisibleLeft = visibleLeft.clamp(0, maxVisibleLeft);
    _clampedVisibleTop = visibleTop.clamp(0, maxVisibleTop);
    _clampedVisibleWidth = clampedVisibleWidth;
    _clampedVisibleHeight = clampedVisibleHeight;

    return GestureDetector(
      onPanStart: (details) => _handleDragStart(details.localPosition),
      onPanUpdate: (details) => _handleDragUpdate(details.localPosition),
      onPanEnd: (details) => _handleDragEnd(),
      onPanCancel: () => _handleDragEnd(),
      onTapDown: (details) => _handleTap(details.localPosition),
      child: Container(
        width: thumbnailWidth,
        height: thumbnailHeight,
        decoration: BoxDecoration(
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
