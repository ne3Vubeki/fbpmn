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
    final screenRect = Offset.zero & size;

    final tilePaint = Paint()
      ..color = Colors.red.withOpacity(0.01)
      ..style = PaintingStyle.fill;

    final tileBorderPaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = false;

    for (final entry in state.imageTiles.entries) {
      final tile = entry.value;
      final rect = Rect.fromLTWH(
        tile.bounds.left * scale + offset.dx,
        tile.bounds.top * scale + offset.dy,
        tile.bounds.width * scale,
        tile.bounds.height * scale,
      );

      if (!rect.overlaps(screenRect)) {
        continue;
      }

      canvas.drawRect(rect, tilePaint);
      canvas.drawRect(rect, tileBorderPaint);

      final double padding = 6 * scale;
      final double idFontSize = 20 * scale;
      final double countFontSize = 20 * scale;
      final double availableWidth = rect.width - padding * 2;

      // Отображаем id тайла
      final idTextPainter = TextPainter(
        text: TextSpan(
          text: tile.id,
          style: TextStyle(
            color: Colors.red,
            fontSize: idFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: availableWidth > 0 ? availableWidth : 0);
      final double idTextHeight = idTextPainter.height;

      if (availableWidth > 0 && rect.height > idTextHeight + padding * 2) {
        idTextPainter.paint(
          canvas,
          Offset(rect.left + padding, rect.top + padding),
        );
      }
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
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: availableWidth > 0 ? availableWidth : 0);

      if (availableWidth > 0 && rect.height > idTextHeight + countTextPainter.height + padding * 3) {
        countTextPainter.paint(
          canvas,
          Offset(
            rect.left + padding,
            rect.top + padding + idTextHeight + padding / 2,
          ),
        );
      }
      countTextPainter.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant TileBorderPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.state.offset != state.offset ||
        oldDelegate.state.imageTiles.length != state.imageTiles.length ||
        !oldDelegate.isNodeDragging ||
        !isNodeDragging;
  }
}
