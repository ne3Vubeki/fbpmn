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
  final bool showTileBorders;
  final bool showThumbnail;
  final bool showPerformance;
  final bool snapEnabled;
  final bool useCurves;
  final bool onlyConnectors;
  final bool selectAndHide;

  const ZoomPanel({
    super.key,
    required this.scale,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.panelWidth,
    required this.onResetZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.showTileBorders,
    required this.showThumbnail,
    required this.showPerformance,
    required this.snapEnabled,
    required this.useCurves,
    required this.onlyConnectors,
    required this.selectAndHide,
  });

  @override
  Widget build(BuildContext context) {
    // Форматируем размеры для отображения
    final String widthText = '${(canvasWidth).toInt()}';
    final String heightText = '${(canvasHeight).toInt()}';
    final String sizeText = '$widthText × $heightText';
    final bool canZoomIn = scale < EditorConfig.maxScale;
    final bool canZoomOut = scale > EditorConfig.minScale;
    final List<Widget> enabledSettingsIcons = [
        Tooltip(
          message: 'Границы тайлов',
          child: Icon(Icons.border_outer, color: showTileBorders ? Colors.redAccent : Colors.grey),
        ),
      Tooltip(
          message: 'Окно миниатюры',
          child: Icon(Icons.picture_in_picture_alt_outlined, color: showThumbnail ? Colors.blueAccent : Colors.grey),
        ),
      Tooltip(
          message: 'Метрики',
          child: Icon(Icons.speed_outlined, color: showPerformance ? Colors.orangeAccent : Colors.grey),
        ),
      Tooltip(
          message: 'Прилипание',
          child: Icon(Icons.grid_on, color: snapEnabled ? Colors.green : Colors.grey),
        ),
      Tooltip(
          message: 'Кривые связи',
          child: Icon(Icons.timeline, color: useCurves ? Colors.purple : Colors.grey),
        ),
      Tooltip(
          message: 'Только коннекторы',
          child: Icon(Icons.device_hub, color: onlyConnectors ? Colors.black87 : Colors.grey),
        ),
      Tooltip(
          message: 'Скрывать другие узлы и связи при выделении',
          child: Icon(Icons.visibility_off_outlined, color: selectAndHide ? Colors.teal : Colors.grey),
        ),
    ];

    return Container(
      width: panelWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[400]!, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double gap = constraints.maxWidth < 360 ? 8 : 12;

          return Row(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Tooltip(
                        message: 'Размер холста (ширина × высота)',
                        child: Text(
                          sizeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                    FittedBox(
                      fit: BoxFit.scaleDown,
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
                          IconButton(
                            onPressed: onResetZoom,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                            tooltip: 'Сфокусироваться',
                            icon: const Icon(Icons.zoom_out_map_outlined, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(width: gap),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
                child: IconTheme(
                  data: const IconThemeData(size: 18),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: enabledSettingsIcons,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
