import 'package:flutter/material.dart';

import '../editor_state.dart';

class TileBorderPainter extends CustomPainter {
  final EditorState state;
  final bool isNodeDragging;

  double get scale => state.scale;
  Offset get offset => state.offset;

  TileBorderPainter({required this.state, required this.isNodeDragging});

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

    final tilePaint = Paint()
      ..color = Colors.red.withOpacity(0.01)
      ..style = PaintingStyle.fill;

    final double safeScale = scale > 0 ? scale : 1.0;

    final tileBorderPaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / safeScale
      ..isAntiAlias = true;

    for (final tile in state.imageTiles) {
      if (tile.bounds.overlaps(visibleRect)) {
        canvas.drawRect(tile.bounds, tilePaint);
        canvas.drawRect(tile.bounds, tileBorderPaint);

        final double idFontSize = (12 / safeScale).clamp(1.0, 200.0);
        final double countFontSize = (10 / safeScale).clamp(1.0, 200.0);

        // Отображаем id тайла
        final idTextPainter = TextPainter(
          text: TextSpan(
            text: '${tile.id}',
            style: TextStyle(
              color: Colors.red,
              fontSize: idFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        idTextPainter.paint(
          canvas,
          Offset(tile.bounds.left + 2 / safeScale, tile.bounds.top + 2 / safeScale),
        );
        idTextPainter.dispose();

        // Отображаем количество узлов в тайле
        final countText =
            'узлов: ${tile.nodes.length}, связей: ${tile.arrows.length}';

        final countTextPainter = TextPainter(
          text: TextSpan(
            text: countText,
            style: TextStyle(
              color: Colors.blue.withOpacity(0.8),
              fontSize: countFontSize,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        countTextPainter.paint(
          canvas,
          Offset(
            tile.bounds.right - countTextPainter.width - 2 / safeScale,
            tile.bounds.top + 2 / safeScale,
          ),
        );
        countTextPainter.dispose();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TileBorderPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.state.imageTiles.length != state.imageTiles.length ||
        !oldDelegate.isNodeDragging ||
        !isNodeDragging;
  }
}
