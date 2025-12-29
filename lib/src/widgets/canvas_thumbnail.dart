import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../models/image_tile.dart';

class CanvasThumbnail extends StatefulWidget {
  final double canvasWidth;
  final double canvasHeight;
  final Offset canvasOffset;
  final Offset delta;
  final Size viewportSize;
  final double scale;
  final List<ImageTile> imageTiles;
  
  const CanvasThumbnail({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.canvasOffset,
    required this.delta,
    required this.viewportSize,
    required this.scale,
    required this.imageTiles,
  });
  
  @override
  State<CanvasThumbnail> createState() => _CanvasThumbnailState();
}

class _CanvasThumbnailState extends State<CanvasThumbnail> {
  ui.Image? _thumbnailImage;
  double _thumbnailScale = 1.0;
  double _thumbnailWidth = 0;
  double _thumbnailHeight = 0;
  
  @override
  void initState() {
    super.initState();
    _createThumbnail();
  }
  
  @override
  void didUpdateWidget(CanvasThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Обновляем миниатюру если изменились тайлы или размер холста
    if (widget.imageTiles != oldWidget.imageTiles ||
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
      // Максимальный размер миниатюры
      const double maxThumbnailSize = 300;
      
      // Рассчитываем масштаб для миниатюры с сохранением пропорций
      final double scaleX = maxThumbnailSize / widget.canvasWidth;
      final double scaleY = maxThumbnailSize / widget.canvasHeight;
      final double thumbnailScale = scaleX < scaleY ? scaleX : scaleY;
      
      // Размеры миниатюры с сохранением пропорций
      final double thumbnailWidth = widget.canvasWidth * thumbnailScale;
      final double thumbnailHeight = widget.canvasHeight * thumbnailScale;
      
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
          Rect.fromLTWH(0, 0, 
            tile.image.width.toDouble(), 
            tile.image.height.toDouble()),
          tileRect,
          Paint()..filterQuality = FilterQuality.medium,
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
    } catch (e) {
      print('Ошибка создания миниатюры: $e');
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
        width: 300,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
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
    // Тайлы содержат узлы в мировых координатах (уже с delta)
    // Начало координат миниатюры = начало координат холста (0,0)
    // Поэтому преобразование прямое: visibleLeft = visibleWorldLeft * thumbnailScale
    final double visibleLeft = visibleWorldLeft * thumbnailScale;
    final double visibleTop = visibleWorldTop * thumbnailScale;
    final double visibleWidth = visibleWorldWidth * thumbnailScale;
    final double visibleHeight = visibleWorldHeight * thumbnailScale;
    
    // Ограничиваем координаты видимой области границами миниатюры
    final double clampedVisibleLeft = visibleLeft.clamp(0, thumbnailWidth - visibleWidth);
    final double clampedVisibleTop = visibleTop.clamp(0, thumbnailHeight - visibleHeight);
    final double clampedVisibleWidth = visibleWidth.clamp(0, thumbnailWidth);
    final double clampedVisibleHeight = visibleHeight.clamp(0, thumbnailHeight);
    
    // Отладочная информация
    print('=== CanvasThumbnail Debug ===');
    print('Canvas size: ${widget.canvasWidth}x${widget.canvasHeight}');
    print('Thumbnail size: ${thumbnailWidth}x${thumbnailHeight}');
    print('Thumbnail scale: $thumbnailScale');
    print('Main scale: ${widget.scale}');
    print('Canvas offset: (${widget.canvasOffset.dx}, ${widget.canvasOffset.dy})');
    print('Delta: (${widget.delta.dx}, ${widget.delta.dy})');
    print('Viewport size: ${widget.viewportSize.width}x${widget.viewportSize.height}');
    print('Visible world: (${visibleWorldLeft.toStringAsFixed(1)}, ${visibleWorldTop.toStringAsFixed(1)}) '
          '${visibleWorldWidth.toStringAsFixed(1)}x${visibleWorldHeight.toStringAsFixed(1)}');
    print('Visible thumb: (${visibleLeft.toStringAsFixed(1)}, ${visibleTop.toStringAsFixed(1)}) '
          '${visibleWidth.toStringAsFixed(1)}x${visibleHeight.toStringAsFixed(1)}');
    print('Clamped: (${clampedVisibleLeft.toStringAsFixed(1)}, ${clampedVisibleTop.toStringAsFixed(1)}) '
          '${clampedVisibleWidth.toStringAsFixed(1)}x${clampedVisibleHeight.toStringAsFixed(1)}');
    
    return Container(
      width: thumbnailWidth,
      height: thumbnailHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
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
            left: clampedVisibleLeft,
            top: clampedVisibleTop,
            child: Container(
              width: clampedVisibleWidth,
              height: clampedVisibleHeight,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.8),
                  width: 1.5,
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
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}