import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../models/image_tile.dart';

class CanvasThumbnail extends StatefulWidget {
  final double canvasWidth;
  final double canvasHeight;
  final Offset canvasOffset;
  final Size viewportSize;
  final double scale;
  final List<ImageTile> imageTiles;
  
  const CanvasThumbnail({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.canvasOffset,
    required this.viewportSize,
    required this.scale,
    required this.imageTiles,
  });
  
  @override
  State<CanvasThumbnail> createState() => _CanvasThumbnailState();
}

class _CanvasThumbnailState extends State<CanvasThumbnail> {
  ui.Image? _thumbnailImage;
  
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
        widget.canvasHeight != oldWidget.canvasHeight) {
      _createThumbnail();
    }
  }
  
  Future<void> _createThumbnail() async {
    if (widget.imageTiles.isEmpty) return;
    
    try {
      // Максимальный размер миниатюры
      const double maxThumbnailSize = 300;
      
      // Рассчитываем масштаб для миниатюры
      final double scaleX = maxThumbnailSize / widget.canvasWidth;
      final double scaleY = maxThumbnailSize / widget.canvasHeight;
      final double thumbnailScale = scaleX < scaleY ? scaleX : scaleY;
      
      // Размеры миниатюры с сохранением пропорций
      final double thumbnailWidth = widget.canvasWidth * thumbnailScale;
      final double thumbnailHeight = widget.canvasHeight * thumbnailScale;
      
      // Создаем PictureRecorder для миниатюры с увеличенным разрешением для лучшего качества
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Увеличиваем разрешение в 2 раза для лучшего качества, затем масштабируем
      final double qualityScale = 2.0;
      canvas.scale(thumbnailScale * qualityScale, thumbnailScale * qualityScale);
      
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
          Paint()..filterQuality = FilterQuality.medium, // Улучшенное качество
        );
      }
      
      // Завершаем запись и создаем изображение с уменьшением масштаба
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (thumbnailWidth * qualityScale).toInt(),
        (thumbnailHeight * qualityScale).toInt(),
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
    
    // Рассчитываем размеры миниатюры с сохранением пропорций
    const double maxThumbnailWidth = 300;
    final double aspectRatio = widget.canvasWidth / widget.canvasHeight;
    final double thumbnailWidth = maxThumbnailWidth;
    final double thumbnailHeight = thumbnailWidth / aspectRatio;
    
    // Масштаб для миниатюры
    final double thumbnailScale = thumbnailWidth / widget.canvasWidth;
    
    // КОРРЕКТНЫЙ РАСЧЕТ видимой области с учетом масштаба
    // Видимая область на основном холсте (в мировых координатах)
    final double visibleWorldWidth = widget.viewportSize.width / widget.scale;
    final double visibleWorldHeight = widget.viewportSize.height / widget.scale;
    
    // Позиция видимой области в мировых координатах
    final double visibleWorldLeft = -widget.canvasOffset.dx / widget.scale;
    final double visibleWorldTop = -widget.canvasOffset.dy / widget.scale;
    
    // Переводим в координаты миниатюры
    final double visibleLeft = visibleWorldLeft * thumbnailScale;
    final double visibleTop = visibleWorldTop * thumbnailScale;
    final double visibleWidth = visibleWorldWidth * thumbnailScale;
    final double visibleHeight = visibleWorldHeight * thumbnailScale;
    
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
          // Миниатюра холста (готовое изображение с улучшенным качеством)
          Transform.scale(
            scale: 0.5, // Компенсируем увеличенное разрешение
            child: RawImage(
              image: _thumbnailImage,
              width: thumbnailWidth * 2,
              height: thumbnailHeight * 2,
              fit: BoxFit.fill,
            ),
          ),
          
          // Видимая область (прозрачный голубой прямоугольник)
          Positioned(
            left: visibleLeft.clamp(0, thumbnailWidth - visibleWidth),
            top: visibleTop.clamp(0, thumbnailHeight - visibleHeight),
            child: Container(
              width: visibleWidth.clamp(0, thumbnailWidth),
              height: visibleHeight.clamp(0, thumbnailHeight),
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
                '${visibleWidth.toInt()}×${visibleHeight.toInt()}',
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