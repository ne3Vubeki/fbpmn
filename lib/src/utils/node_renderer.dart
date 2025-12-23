import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/table.node.dart';
import 'editor_config.dart';

class NodeRenderer {
  void drawStaticNode({
    required Canvas canvas,
    required TableNode tableNode,
    required Rect nodeRect,
    required Offset position,
  }) {
    final backgroundColor = tableNode.groupId != null
        ? tableNode.backgroundColor
        : Colors.white;
    final headerBackgroundColor = tableNode.backgroundColor;
    final borderColor = Colors.black;
    final textColorHeader = headerBackgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    // Рисуем закругленный прямоугольник для всей таблицы
    final tablePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    final tableBorderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (tableNode.groupId != null) {
      canvas.drawRect(nodeRect, tablePaint);
      canvas.drawRect(nodeRect, tableBorderPaint);
    } else {
      final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
      canvas.drawRRect(roundedRect, tablePaint);
      canvas.drawRRect(roundedRect, tableBorderPaint);
    }

    final attributes = tableNode.attributes;
    final headerHeight = EditorConfig.headerHeight;
    final rowHeight = (nodeRect.height - headerHeight) / attributes.length;
    final minRowHeight = EditorConfig.minRowHeight;
    final actualRowHeight = math.max(rowHeight, minRowHeight);

    // Рисуем заголовок
    final headerRect = Rect.fromLTWH(
      nodeRect.left + 1,
      nodeRect.top + 1,
      nodeRect.width - 2,
      headerHeight - 2,
    );

    final headerPaint = Paint()
      ..color = headerBackgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (tableNode.groupId != null) {
      canvas.drawRect(headerRect, headerPaint);
    } else {
      final headerRoundedRect = RRect.fromRectAndCorners(
        headerRect,
        topLeft: Radius.circular(8),
        topRight: Radius.circular(8),
      );
      canvas.drawRRect(headerRoundedRect, headerPaint);
    }

    final headerBorderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (tableNode.groupId == null) {
      canvas.drawLine(
        Offset(nodeRect.left, nodeRect.top + headerHeight),
        Offset(nodeRect.right, nodeRect.top + headerHeight),
        headerBorderPaint,
      );
    }

    // Текст заголовка
    final headerTextSpan = TextSpan(
      text: tableNode.text,
      style: TextStyle(
        color: textColorHeader,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );

    final headerTextPainter = TextPainter(
      text: headerTextSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    )..textWidthBasis = TextWidthBasis.longestLine;

    headerTextPainter.layout(maxWidth: nodeRect.width - 16);
    headerTextPainter.paint(
      canvas,
      Offset(
        nodeRect.left + 8,
        nodeRect.top + (headerHeight - headerTextPainter.height) / 2,
      ),
    );

    // Рисуем строки таблицы
    for (int i = 0; i < attributes.length; i++) {
      final attribute = attributes[i];
      final rowTop = nodeRect.top + headerHeight + actualRowHeight * i;
      final rowBottom = rowTop + actualRowHeight;

      final columnSplit = tableNode.qType == 'enum' ? 20 : nodeRect.width - 20;

      // Вертикальная граница
      canvas.drawLine(
        Offset(nodeRect.left + columnSplit, rowTop),
        Offset(nodeRect.left + columnSplit, rowBottom),
        headerBorderPaint,
      );

      // Горизонтальная граница
      if (i < attributes.length - 1) {
        canvas.drawLine(
          Offset(nodeRect.left, rowBottom),
          Offset(nodeRect.right, rowBottom),
          headerBorderPaint,
        );
      }

      // Текст в левой колонке
      final leftText = tableNode.qType == 'enum'
          ? attribute['position']
          : attribute['label'];
      if (leftText.isNotEmpty) {
        final leftTextPainter = TextPainter(
          text: TextSpan(
            text: leftText,
            style: TextStyle(color: Colors.black, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
          ellipsis: '...',
        )..textWidthBasis = TextWidthBasis.parent;
        
        leftTextPainter.layout(maxWidth: columnSplit - 16);
        leftTextPainter.paint(
          canvas,
          Offset(
            nodeRect.left + 8,
            rowTop + (actualRowHeight - leftTextPainter.height) / 2,
          ),
        );
      }

      // Текст в правой колонке
      final rightText = tableNode.qType == 'enum' ? attribute['label'] : '';
      if (rightText.isNotEmpty) {
        final rightTextPainter = TextPainter(
          text: TextSpan(
            text: rightText,
            style: TextStyle(color: Colors.black, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
          ellipsis: '...',
        )..textWidthBasis = TextWidthBasis.parent;
        
        rightTextPainter.layout(maxWidth: nodeRect.width - columnSplit - 16);
        rightTextPainter.paint(
          canvas,
          Offset(
            nodeRect.left + columnSplit + 8,
            rowTop + (actualRowHeight - rightTextPainter.height) / 2,
          ),
        );
      }
    }
  }
  
  void drawNodeToTile({
    required Canvas canvas,
    required TableNode node,
    required Rect tileBounds,
    required Offset delta,
    required Map<TableNode, Rect> cache,
  }) {
    void drawNodeRecursive(TableNode currentNode, Offset currentOffset) {
      final shiftedPosition = currentNode.position + currentOffset;
      final nodeRect = Rect.fromPoints(
        shiftedPosition,
        Offset(
          shiftedPosition.dx + currentNode.size.width,
          shiftedPosition.dy + currentNode.size.height,
        ),
      );
      
      // Кэшируем границы
      cache[currentNode] = nodeRect;
      
      // Рисуем только если узел хотя бы частично в границах тайла
      if (nodeRect.overlaps(tileBounds.inflate(10.0))) {
        canvas.save();
        drawStaticNode(
          canvas: canvas,
          tableNode: currentNode,
          nodeRect: nodeRect,
          position: shiftedPosition,
        );
        canvas.restore();
      }
      
      // Рисуем детей
      if (currentNode.children != null && currentNode.children!.isNotEmpty) {
        for (final child in currentNode.children!) {
          drawNodeRecursive(child, shiftedPosition);
        }
      }
    }
    
    drawNodeRecursive(node, delta);
  }
}