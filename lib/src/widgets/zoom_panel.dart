import 'package:flutter/material.dart';

class ZoomPanel extends StatelessWidget {
  final double scale;
  final bool showTileBorders;
  final bool showThumbnail;
  final double canvasWidth;
  final double canvasHeight;
  final double panelWidth;
  final VoidCallback onResetZoom;
  final VoidCallback onToggleTileBorders;
  final VoidCallback onToggleThumbnail;

  const ZoomPanel({
    super.key,
    required this.scale,
    required this.showTileBorders,
    required this.showThumbnail,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.panelWidth,
    required this.onResetZoom,
    required this.onToggleTileBorders,
    required this.onToggleThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    // Форматируем размеры для отображения
    final String widthText = '${canvasWidth.toInt()}px';
    final String heightText = '${canvasHeight.toInt()}px';
    final String sizeText = '$widthText × $heightText';

    return Container(
      width: panelWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Левая часть: информация о размерах
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Кнопка скрытия/показа миниатюры
                IconButton(
                  icon: Icon(
                    showThumbnail
                        ? Icons.picture_in_picture_alt
                        : Icons.picture_in_picture,
                    size: 18,
                    color: showThumbnail ? Colors.blue : Colors.grey,
                  ),
                  onPressed: onToggleThumbnail,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  tooltip: showThumbnail
                      ? 'Скрыть миниатюру'
                      : 'Показать миниатюру',
                ),

                const SizedBox(width: 4),

                // Масштаб
                Tooltip(
                  message: 'Текущий масштаб',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
              ],
            ),
          ),

          // Правая часть: кнопки управления
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Кнопка сброса масштаба
              IconButton(
                icon: const Icon(Icons.zoom_out_map, size: 18),
                onPressed: onResetZoom,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Сфокусироваться',
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
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: showTileBorders
                    ? 'Скрыть границы тайлов'
                    : 'Показать границы тайлов',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
