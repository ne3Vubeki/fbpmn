import 'package:flutter/material.dart';

class ZoomPanel extends StatelessWidget {
  final double scale;
  final bool showTileBorders;
  final double canvasWidth;
  final double canvasHeight;
  final VoidCallback onResetZoom;
  final VoidCallback onToggleTileBorders;
  
  const ZoomPanel({
    super.key,
    required this.scale,
    required this.showTileBorders,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onResetZoom,
    required this.onToggleTileBorders,
  });
  
  @override
  Widget build(BuildContext context) {
    // Форматируем размеры для отображения
    final String widthText = '${canvasWidth.toInt()}px';
    final String heightText = '${canvasHeight.toInt()}px';
    final String sizeText = '$widthText × $heightText';
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Информация о размерах холста
          Tooltip(
            message: 'Размер холста (ширина × высота)',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sizeText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Масштаб
          Tooltip(
            message: 'Текущий масштаб',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(scale * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Кнопка сброса масштаба
          IconButton(
            icon: const Icon(Icons.zoom_out_map, size: 18),
            onPressed: onResetZoom,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            tooltip: 'Сбросить масштаб до 100%',
          ),
          
          const SizedBox(width: 4),
          
          // Кнопка отображения границ тайлов
          IconButton(
            icon: Icon(
              showTileBorders ? Icons.border_outer : Icons.border_clear,
              size: 18,
              color: showTileBorders ? Colors.red : Colors.grey,
            ),
            onPressed: onToggleTileBorders,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            tooltip: showTileBorders ? 'Скрыть границы тайлов' : 'Показать границы тайлов',
          ),
        ],
      ),
    );
  }
}