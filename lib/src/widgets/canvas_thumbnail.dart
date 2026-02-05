import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../models/image_tile.dart';
import '../utils/canvas_icons.dart';

class CanvasThumbnail extends StatefulWidget {
  final double canvasWidth;
  final double canvasHeight;
  final Offset canvasOffset;
  final double panelWidth;
  final Offset delta;
  final Size viewportSize;
  final double scale;
  final List<ImageTile> imageTiles;
  final Function(Offset)?
  onThumbnailClick; // Новый callback для кликов по миниатюре

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
  Offset _dragStartPosition = Offset.zero;
  Offset _dragStartRectPosition = Offset.zero;

  double _clampedVisibleLeft = 0;
  double _clampedVisibleTop = 0;
  double _clampedVisibleWidth = 0;
  double _clampedVisibleHeight = 0;

  @override
  void initState() {
    super.initState();
    _createThumbnail();
  }

  @override
  void didUpdateWidget(CanvasThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Проверяем, изменились ли тайлы
    bool tilesChanged = false;
    
    // Если это разные списки по ссылке - точно изменились
    if (!identical(widget.imageTiles, oldWidget.imageTiles)) {
      tilesChanged = true;
    } else if (widget.imageTiles.length != oldWidget.imageTiles.length) {
      // Если длина изменилась - точно изменились
      tilesChanged = true;
    } else {
      // Проверяем содержимое тайлов (id, bounds, image, scale)
      for (int i = 0; i < widget.imageTiles.length; i++) {
        final newTile = widget.imageTiles[i];
        final oldTile = oldWidget.imageTiles[i];

        // Сравниваем по id, bounds, image и scale
        if (newTile.id != oldTile.id ||
            newTile.bounds != oldTile.bounds ||
            !identical(newTile.image, oldTile.image) ||
            newTile.scale != oldTile.scale) {
          tilesChanged = true;
          break;
        }
      }
    }

    // Обновляем миниатюру если изменились тайлы или размер холста
    if (tilesChanged ||
        widget.canvasWidth != oldWidget.canvasWidth ||
        widget.canvasHeight != oldWidget.canvasHeight ||
        widget.delta != oldWidget.delta) {
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
    if (widget.imageTiles.isEmpty) return;

    try {
      // Ширина миниатюры всегда = panelWidth
      final double thumbnailWidth = widget.panelWidth;

      // Высота рассчитывается пропорционально размерам холста
      final double aspectRatio = widget.canvasWidth / widget.canvasHeight;
      final double thumbnailHeight = thumbnailWidth / aspectRatio;

      // Масштаб для миниатюры (отношение ширины миниатюры к ширине холста)
      final double thumbnailScale = thumbnailWidth / widget.canvasWidth;

      // Сохраняем расчетные значения для использования в build()
      _thumbnailScale = thumbnailScale;
      _thumbnailWidth = thumbnailWidth;
      _thumbnailHeight = thumbnailHeight;

      // Создаем PictureRecorder для миниатюры
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Применяем масштаб миниатюры
      canvas.scale(thumbnailScale, thumbnailScale);

      // Рисуем все тайлы с улучшенным качеством
      for (final tile in widget.imageTiles) {
        // Позиция тайла на миниатюре
        final tileRect = tile.bounds;

        // Рисуем тайл с улучшенным качеством
        canvas.drawImageRect(
          tile.image,
          Rect.fromLTWH(
            0,
            0,
            tile.image.width.toDouble(),
            tile.image.height.toDouble(),
          ),
          tileRect,
          Paint()..filterQuality = FilterQuality.high,
        );
      }

      // Завершаем запись и создаем изображение
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        thumbnailWidth.toInt(),
        thumbnailHeight.toInt(),
      );
      picture.dispose();

      if (mounted) {
        setState(() {
          _thumbnailImage = image;
        });
      }
    } catch (e) {}
  }

  // Обработчик начала перетаскивания в миниатюре
  void _handleDragStart(Offset localPosition) {
    if (_thumbnailImage == null) return;

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

    // Новая позиция прямоугольника в миниатюре
    final double newRectLeft = (_dragStartRectPosition.dx + mouseDelta.dx)
        .clamp(0, _thumbnailWidth - _clampedVisibleWidth);
    final double newRectTop = (_dragStartRectPosition.dy + mouseDelta.dy).clamp(
      0,
      _thumbnailHeight - _clampedVisibleHeight,
    );

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

    final double clampedWorldLeft = newVisibleWorldLeft.clamp(0, maxWorldLeft);
    final double clampedWorldTop = newVisibleWorldTop.clamp(0, maxWorldTop);

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

    // Ограничиваем координаты видимой области границами миниатюры
    _clampedVisibleLeft = visibleLeft.clamp(0, thumbnailWidth - visibleWidth);
    _clampedVisibleTop = visibleTop.clamp(0, thumbnailHeight - visibleHeight);
    _clampedVisibleWidth = visibleWidth.clamp(0, thumbnailWidth);
    _clampedVisibleHeight = visibleHeight.clamp(0, thumbnailHeight);

    final double clampedVisibleWidth = visibleWidth.clamp(0, thumbnailWidth);
    final double clampedVisibleHeight = visibleHeight.clamp(0, thumbnailHeight);

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
          color: Colors.white.withOpacity(.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isDragging ? Colors.blue : Colors.grey[400]!,
            width: _isDragging ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Миниатюра холста
            RawImage(
              image: _thumbnailImage,
              width: thumbnailWidth,
              height: thumbnailHeight,
              fit: BoxFit.fill,
            ),

            // Видимая область (прозрачный голубой прямоугольник)
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

            // Информация о видимой области
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${clampedVisibleWidth.toInt()}×${clampedVisibleHeight.toInt()}',
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ),

            // Индикатор перетаскивания
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: CanvasIcon(
                      painter: CanvasIcons.paintOpenWith,
                      size: 24,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
