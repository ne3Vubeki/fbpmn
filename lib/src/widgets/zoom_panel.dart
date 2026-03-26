import 'package:flutter/material.dart';
import '../utils/editor_config.dart';

class ZoomPanel extends StatelessWidget {
  final double scale;
  final double canvasWidth;
  final double canvasHeight;
  final double panelWidth;
  final VoidCallback onResetZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const ZoomPanel({
    super.key,
    required this.scale,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.panelWidth,
    required this.onResetZoom,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    // Форматируем размеры для отображения
    final String widthText = '${(canvasWidth).toInt()}';
    final String heightText = '${(canvasHeight).toInt()}';
    final String sizeText = '$widthText × $heightText';
    final bool canZoomIn = scale < EditorConfig.maxScale;
    final bool canZoomOut = scale > EditorConfig.minScale;

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
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
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
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: canZoomIn ? onZoomIn : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Увеличить масштаб',
                    icon: const Icon(Icons.add, size: 18),
                  ),
                  Tooltip(
                    message: 'Текущий масштаб',
                    child: InkWell(
                      onTap: onResetZoom,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          '${(scale * 100).round()}%',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue[800]),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: canZoomOut ? onZoomOut : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Уменьшить масштаб',
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onResetZoom,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Сфокусироваться',
                icon: const Icon(Icons.zoom_out_map_outlined, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
