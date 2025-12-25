import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/table.node.dart';
import '../utils/editor_config.dart';

/// Универсальный класс для отрисовки TableNode в любом контексте
class NodePainter {
  final TableNode node;
  final bool isSelected;

  NodePainter({required this.node, this.isSelected = false});

  /// Отрисовка узла с учетом базового отступа (рекурсивно с детьми)
  void paintWithOffset({
    required Canvas canvas,
    required Offset baseOffset,
    required Rect visibleBounds,
    bool forTile = false,
    Map<TableNode, Rect>? nodeBoundsCache,
  }) {
    // Для виджета (верхнего слоя) используем особую логику
    if (!forTile) {
      _drawNodeForWidget(
        canvas: canvas,
        currentNode: node,
        parentAbsolutePosition: baseOffset,
        visibleBounds: visibleBounds,
        nodeBoundsCache: nodeBoundsCache,
      );
    } else {
      // Для тайлов - обычная логика
      _drawNodeRecursive(
        canvas: canvas,
        currentNode: node,
        parentAbsolutePosition: baseOffset,
        visibleBounds: visibleBounds,
        forTile: true,
        nodeBoundsCache: nodeBoundsCache,
      );
    }
  }

  /// Отрисовка узла для виджета (с масштабированием детей)
  void _drawNodeForWidget({
    required Canvas canvas,
    required TableNode currentNode,
    required Offset parentAbsolutePosition,
    required Rect visibleBounds,
    Map<TableNode, Rect>? nodeBoundsCache,
  }) {
    // Рисуем текущий узел (для виджета координаты локальные)
    _drawSingleNode(
      canvas: canvas,
      node: currentNode,
      nodeRect: Rect.fromLTWH(
        0,
        0,
        currentNode.size.width,
        currentNode.size.height,
      ),
      forTile: false,
    );

    // Затем рисуем детей, если они есть
    if (currentNode.children != null && currentNode.children!.isNotEmpty) {
      for (final child in currentNode.children!) {
        canvas.save();

        // Позиция ребенка относительно родителя
        final childLocalRect = Rect.fromLTWH(
          child.position.dx,
          child.position.dy,
          child.size.width,
          child.size.height,
        );

        // Рисуем ребенка
        _drawSingleNode(
          canvas: canvas,
          node: child,
          nodeRect: childLocalRect,
          forTile: false,
        );

        canvas.restore();
      }
    }
  }

  /// Рекурсивная отрисовка узла и его детей
  void _drawNodeRecursive({
    required Canvas canvas,
    required TableNode currentNode,
    required Offset parentAbsolutePosition, // Абсолютная позиция родителя
    required Rect visibleBounds,
    required bool forTile,
    Map<TableNode, Rect>? nodeBoundsCache,
  }) {
    // Рассчитываем абсолютную позицию текущего узла
    final nodeAbsolutePosition = currentNode.position + parentAbsolutePosition;

    // Создаем Rect узла в мировых координатах
    final nodeWorldRect = Rect.fromPoints(
      nodeAbsolutePosition,
      Offset(
        nodeAbsolutePosition.dx + currentNode.size.width,
        nodeAbsolutePosition.dy + currentNode.size.height,
      ),
    );

    // Сохраняем в кэш
    if (nodeBoundsCache != null) {
      nodeBoundsCache[currentNode] = nodeWorldRect;
    }

    // Проверяем видимость
    if (!nodeWorldRect.overlaps(visibleBounds.inflate(10.0))) {
      // Даже если узел не виден, проверяем его детей
      _drawChildren(
        canvas: canvas,
        parentNode: currentNode,
        parentAbsolutePosition: nodeAbsolutePosition,
        visibleBounds: visibleBounds,
        forTile: forTile,
        nodeBoundsCache: nodeBoundsCache,
      );
      return;
    }

    canvas.save();

    if (forTile) {
      // Для тайла: рисуем в мировых координатах
      _drawSingleNode(
        canvas: canvas,
        node: currentNode,
        nodeRect: nodeWorldRect,
        forTile: true,
      );
    } else {
      // Для виджета: преобразуем координаты
      final scaleX = nodeWorldRect.width / currentNode.size.width;
      final scaleY = nodeWorldRect.height / currentNode.size.height;

      canvas.scale(scaleX, scaleY);

      final nodeLocalRect = Rect.fromLTWH(
        0,
        0,
        currentNode.size.width,
        currentNode.size.height,
      );

      _drawSingleNode(
        canvas: canvas,
        node: currentNode,
        nodeRect: nodeLocalRect,
        forTile: false,
      );
    }

    canvas.restore();

    // Рисуем детей
    _drawChildren(
      canvas: canvas,
      parentNode: currentNode,
      parentAbsolutePosition: nodeAbsolutePosition,
      visibleBounds: visibleBounds,
      forTile: forTile,
      nodeBoundsCache: nodeBoundsCache,
    );
  }

  /// Отрисовка дочерних узлов
  void _drawChildren({
    required Canvas canvas,
    required TableNode parentNode,
    required Offset parentAbsolutePosition,
    required Rect visibleBounds,
    required bool forTile,
    Map<TableNode, Rect>? nodeBoundsCache,
  }) {
    if (parentNode.children == null || parentNode.children!.isEmpty) {
      return;
    }

    for (final child in parentNode.children!) {
      _drawNodeRecursive(
        canvas: canvas,
        currentNode: child,
        parentAbsolutePosition: parentAbsolutePosition,
        visibleBounds: visibleBounds,
        forTile: forTile,
        nodeBoundsCache: nodeBoundsCache,
      );
    }
  }

  /// Отрисовка одного узла (без детей)
  void _drawSingleNode({
    required Canvas canvas,
    required TableNode node,
    required Rect nodeRect,
    required bool forTile,
  }) {
    final backgroundColor = node.groupId != null
        ? node.backgroundColor
        : Colors.white;
    final headerBackgroundColor = node.backgroundColor;
    final borderColor = Colors.black;
    final textColorHeader = headerBackgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    // Рассчитываем толщину линии
    final scaleX = nodeRect.width / node.size.width;
    final scaleY = nodeRect.height / node.size.height;
    final lineWidth = 1.0 / math.min(scaleX, scaleY);

    // Рисуем закругленный прямоугольник для всей таблицы
    final tablePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    final tableBorderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (node.groupId != null) {
      canvas.drawRect(nodeRect, tablePaint);
      canvas.drawRect(nodeRect, tableBorderPaint);
    } else {
      final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
      canvas.drawRRect(roundedRect, tablePaint);
      canvas.drawRRect(roundedRect, tableBorderPaint);
    }

    // Вычисляем размеры
    final attributes = node.attributes;
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

    if (node.groupId != null) {
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
      ..strokeWidth = lineWidth
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (node.groupId == null) {
      canvas.drawLine(
        Offset(nodeRect.left, nodeRect.top + headerHeight),
        Offset(nodeRect.right, nodeRect.top + headerHeight),
        headerBorderPaint,
      );
    }

    // Текст заголовка
    final headerTextSpan = TextSpan(
      text: node.text,
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

      final columnSplit = node.qType == 'enum' ? 20 : nodeRect.width - 20;

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
      final leftText = node.qType == 'enum'
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
      final rightText = node.qType == 'enum' ? attribute['label'] : '';
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

  /// Простая отрисовка одного узла (без детей) - для обратной совместимости
  void paint(Canvas canvas, Rect targetRect, {bool forTile = false}) {
    _drawSingleNode(
      canvas: canvas,
      node: node,
      nodeRect: targetRect,
      forTile: forTile,
    );
  }
}