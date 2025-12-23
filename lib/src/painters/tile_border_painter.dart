import 'package:flutter/material.dart';

import '../models/image_tile.dart';

class TileBorderPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final List<ImageTile> imageTiles;
  final Rect totalBounds;
  
  TileBorderPainter({
    required this.scale,
    required this.offset,
    required this.imageTiles,
    required this.totalBounds,
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
    
   
    for (int i = 0; i < imageTiles.length; i++) {
      final tile = imageTiles[i];
      
      if (tile.bounds.overlaps(visibleRect)) {
        canvas.drawRect(tile.bounds, tileBorderPaint);
        
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${tile.index}',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12 / scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        textPainter.paint(
          canvas,
          Offset(
            tile.bounds.left + 2 / scale,
            tile.bounds.top + 2 / scale,
          ),
        );
        
        final sizeText = '${tile.image.width}x${tile.image.height}';
        final sizeTextPainter = TextPainter(
          text: TextSpan(
            text: sizeText,
            style: TextStyle(
              color: Colors.red.withOpacity(0.8),
              fontSize: 10 / scale,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        sizeTextPainter.paint(
          canvas,
          Offset(
            tile.bounds.right - sizeTextPainter.width - 2 / scale,
            tile.bounds.bottom - sizeTextPainter.height - 2 / scale,
          ),
        );
      }
    }
    
    if (imageTiles.isNotEmpty) {
      final totalBorderPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / scale
        ..isAntiAlias = true;
      
      canvas.drawRect(totalBounds, totalBorderPaint);
      
      final totalText = 'Total bounds: ${totalBounds.width.toStringAsFixed(0)}x${totalBounds.height.toStringAsFixed(0)}';
      final totalTextPainter = TextPainter(
        text: TextSpan(
          text: totalText,
          style: TextStyle(
            color: Colors.red.withOpacity(0.8),
            fontSize: 12 / scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      totalTextPainter.paint(
        canvas,
        Offset(
          totalBounds.left + 5 / scale,
          totalBounds.top + 5 / scale,
        ),
      );
    }
    
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(covariant TileBorderPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.imageTiles.length != imageTiles.length ||
        oldDelegate.totalBounds != totalBounds;
  }
}