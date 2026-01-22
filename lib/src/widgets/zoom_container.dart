import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/image_tile.dart';
import '../services/input_handler.dart';
import '../services/scroll_handler.dart';
import '../services/tile_manager.dart';
import 'canvas_thumbnail.dart';
import 'zoom_panel.dart';

class ZoomContainer extends StatefulWidget {
  final EditorState state;
  final InputHandler inputHandler;
  final ScrollHandler scrollHandler;
  final TileManager tileManager;

  const ZoomContainer({
    super.key,
    required this.state,
    required this.scrollHandler,
    required this.inputHandler,
    required this.tileManager,
  });

  @override
  State<ZoomContainer> createState() => _ZoomContainerState();
}

class _ZoomContainerState extends State<ZoomContainer> {
  bool _showThumbnail = true;

  double get scale => widget.state.scale;
  bool get showTileBorders => widget.state.showTileBorders;
  double get canvasWidth => widget.scrollHandler.dynamicCanvasWidth;
  double get canvasHeight => widget.scrollHandler.dynamicCanvasHeight;
  Offset get canvasOffset => widget.state.offset;
  Offset get delta => widget.state.delta;
  Size get viewportSize => widget.state.viewportSize;
  List<ImageTile> get imageTiles => widget.state.imageTiles;

  VoidCallback onResetZoom() => widget.scrollHandler.resetZoom;
  
  VoidCallback onToggleTileBorders() => widget.inputHandler.toggleTileBorders;

  @override
  void initState() {
    super.initState();
    widget.inputHandler.setOnStateUpdate('ZoomContainer', () {
      if (this.mounted) {
        setState(() {});
      }
    });
    widget.scrollHandler.setOnStateUpdate('ZoomContainer', () {
      if (this.mounted) {
        setState(() {});
      }
    });
    widget.tileManager.setOnStateUpdate('ZoomContainer', () {
      if (this.mounted) {
        setState(() {});
      }
    });
  }
  
  void onThumbnailClick(Offset newOffset) {
    // Обновляем offset в состоянии
    widget.state.offset = widget.inputHandler.constrainOffset(newOffset);
    // Обновляем скроллбары
    widget.scrollHandler.updateScrollControllers();
    // Перерисовываем
    setState(() {});
  }


  void _toggleThumbnail() {
    setState(() {
      _showThumbnail = !_showThumbnail;
    });
  }

  void _handleThumbnailClick(Offset newCanvasOffset) {
      onThumbnailClick(newCanvasOffset);
  }

  @override
  Widget build(BuildContext context) {
    // Ширина контейнера (равна ширине миниатюры или минимальная ширина панели)
    final double containerWidth = 300;

    return Container(
      margin: const EdgeInsets.only(right: 20, bottom: 20),
      width: containerWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Миниатюра холста (отображается если включена)
          if (_showThumbnail) ...[
            CanvasThumbnail(
              canvasWidth: canvasWidth,
              canvasHeight: canvasHeight,
              canvasOffset: canvasOffset,
              panelWidth: containerWidth,
              delta: delta, // Передаем delta
              viewportSize: viewportSize,
              scale: scale,
              imageTiles: imageTiles,
              onThumbnailClick: _handleThumbnailClick,
            ),
            const SizedBox(height: 8),
          ],

          // Панель управления зумом (ширина равна ширине контейнера)
          ZoomPanel(
            scale: scale,
            showTileBorders: showTileBorders,
            showThumbnail: _showThumbnail,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            panelWidth: containerWidth,
            onResetZoom: onResetZoom,
            onToggleTileBorders: onToggleTileBorders,
            onToggleThumbnail: _toggleThumbnail,
          ),
        ],
      ),
    );
  }
}
