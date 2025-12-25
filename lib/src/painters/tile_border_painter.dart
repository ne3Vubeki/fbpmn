import 'package:flutter/material.dart';

import '../editor_state.dart';

class TileBorderPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final EditorState state;
  
  TileBorderPainter({
    required this.scale,
    required this.offset,
    required this.state,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(offset.dx / scale, offset.dy / scale);
    
    final double visibleLeft = -offset.dx / scale;
    final double visibleTop = -offset.dy / scale;
    final double visibleRight = (size.width - offset.dx) / scale;
    final double visibleBottom = (size.height - offset.dy) / scale;
    
    final visibleRect = Rect.fromLTRB(
      visibleLeft,
      visibleTop,
      visibleRight,
      visibleBottom,
    );
    
    final tileBorderPaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / scale
      ..isAntiAlias = true;
    
    for (final tile in state.imageTiles) {
      if (tile.bounds.overlaps(visibleRect)) {
        canvas.drawRect(tile.bounds, tileBorderPaint);
        
        // Отображаем id тайла
        final idTextPainter = TextPainter(
          text: TextSpan(
            text: '${tile.id}',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12 / scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        idTextPainter.paint(
          canvas,
          Offset(
            tile.bounds.left + 2 / scale,
            tile.bounds.top + 2 / scale,
          ),
        );
        
        // Отображаем количество узлов в тайле
        final tileIndex = state.imageTiles.indexOf(tile);
        final nodesCount = state.tileToNodes[tileIndex]?.length ?? 0;
        final countText = 'узлов: $nodesCount';
        
        final countTextPainter = TextPainter(
          text: TextSpan(
            text: countText,
            style: TextStyle(
              color: Colors.blue.withOpacity(0.8),
              fontSize: 10 / scale,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        countTextPainter.paint(
          canvas,
          Offset(
            tile.bounds.right - countTextPainter.width - 2 / scale,
            tile.bounds.top + 2 / scale,
          ),
        );
      }
    }
    
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(covariant TileBorderPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.state.imageTiles.length != state.imageTiles.length;
  }
}