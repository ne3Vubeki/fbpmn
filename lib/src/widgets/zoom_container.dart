import 'package:flutter/material.dart';

import '../models/image_tile.dart';
import 'canvas_thumbnail.dart';
import 'zoom_panel.dart';

class ZoomContainer extends StatefulWidget {
  final double scale;
  final bool showTileBorders;
  final double canvasWidth;
  final double canvasHeight;
  final Offset canvasOffset;
  final Size viewportSize;
  final List<ImageTile> imageTiles;
  final VoidCallback onResetZoom;
  final VoidCallback onToggleTileBorders;
  
  const ZoomContainer({
    super.key,
    required this.scale,
    required this.showTileBorders,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.canvasOffset,
    required this.viewportSize,
    required this.imageTiles,
    required this.onResetZoom,
    required this.onToggleTileBorders,
  });
  
  @override
  State<ZoomContainer> createState() => _ZoomContainerState();
}

class _ZoomContainerState extends State<ZoomContainer> {
  bool _showThumbnail = true;
  
  void _toggleThumbnail() {
    setState(() {
      _showThumbnail = !_showThumbnail;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Ширина контейнера (равна ширине миниатюры или минимальная ширина панели)
    const double thumbnailWidth = 300;
    const double minPanelWidth = 200;
    final double containerWidth = _showThumbnail ? thumbnailWidth : minPanelWidth;
    
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
              canvasWidth: widget.canvasWidth,
              canvasHeight: widget.canvasHeight,
              canvasOffset: widget.canvasOffset,
              viewportSize: widget.viewportSize,
              scale: widget.scale,
              imageTiles: widget.imageTiles,
            ),
            const SizedBox(height: 8),
          ],
          
          // Панель управления зумом (ширина равна ширине контейнера)
          ZoomPanel(
            scale: widget.scale,
            showTileBorders: widget.showTileBorders,
            showThumbnail: _showThumbnail,
            canvasWidth: widget.canvasWidth,
            canvasHeight: widget.canvasHeight,
            panelWidth: containerWidth,
            onResetZoom: widget.onResetZoom,
            onToggleTileBorders: widget.onToggleTileBorders,
            onToggleThumbnail: _toggleThumbnail,
          ),
        ],
      ),
    );
  }
}