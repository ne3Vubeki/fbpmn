import 'package:flutter/material.dart';

class ZoomPanel extends StatelessWidget {
  final double scale;
  final bool showTileBorders;
  final bool showThumbnail;
  final bool showCurves;
  final bool snapEnabled;
  final double canvasWidth;
  final double canvasHeight;
  final double panelWidth;
  final VoidCallback onResetZoom;
  final VoidCallback onToggleTileBorders;
  final VoidCallback onToggleThumbnail;
  final VoidCallback onToggleCurves;
  final VoidCallback onToggleSnap;

  const ZoomPanel({
    super.key,
    required this.scale,
    required this.showTileBorders,
    required this.showThumbnail,
    required this.showCurves,
    required this.snapEnabled,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.panelWidth,
    required this.onResetZoom,
    required this.onToggleTileBorders,
    required this.onToggleThumbnail,
    required this.onToggleCurves,
    required this.onToggleSnap,
  });

  @override
  Widget build(BuildContext context) {
    // Форматируем размеры для отображения
    final String widthText = '${(canvasWidth / 1000).floor().toInt()}K';
    final String heightText = '${(canvasHeight / 1000).floor().toInt()}K';
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
                    showThumbnail ? Icons.picture_in_picture_alt : Icons.picture_in_picture,
                    size: 18,
                    color: showThumbnail ? Colors.blue : Colors.grey,
                  ),
                  onPressed: onToggleThumbnail,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: showThumbnail ? 'Скрыть миниатюру' : 'Показать миниатюру',
                ),

                const SizedBox(width: 4),

                // Информация о размерах холста
                Tooltip(
                  message: 'Размер холста (ширина × высота)',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      sizeText,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Масштаб
                Tooltip(
                  message: 'Текущий масштаб',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      '${(scale * 100).round()}%',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue[800]),
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
              // Кнопка переключения snap-прилипания
              IconButton(
                icon: Icon(
                  snapEnabled ? Icons.grid_on : Icons.grid_off,
                  size: 18,
                  color: snapEnabled ? Colors.green : Colors.grey,
                ),
                onPressed: onToggleSnap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: snapEnabled ? 'Выключить прилипание' : 'Включить прилипание',
              ),

              const SizedBox(width: 4),

              // Кнопка переключения кривые/ортогональные связи
              IconButton(
                icon: Icon(
                  showCurves ? Icons.timeline : Icons.show_chart,
                  size: 18,
                  color: showCurves ? Colors.purple : Colors.grey,
                ),
                onPressed: onToggleCurves,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: showCurves ? 'Ортогональные связи' : 'Кривые связи',
              ),

              const SizedBox(width: 4),

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
                tooltip: showTileBorders ? 'Скрыть границы тайлов' : 'Показать границы тайлов',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
