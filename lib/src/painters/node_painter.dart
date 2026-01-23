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
  }) {
    // Для всех случаев используем единую рекурсивную логику
    _drawNodeRecursive(
      canvas: canvas,
      currentNode: node,
      parentAbsolutePosition: baseOffset,
      visibleBounds: visibleBounds,
      forTile: forTile,
    );
  }

  /// Рекурсивная отрисовка узла и его детей
  void _drawNodeRecursive({
    required Canvas canvas,
    required TableNode currentNode,
    required Offset parentAbsolutePosition,
    required Rect visibleBounds,
    required bool forTile,
  }) {
    // Рассчитываем абсолютную позицию текущего узла
    final nodeAbsolutePosition =
        currentNode.aPosition ??
        (currentNode.position + parentAbsolutePosition);

    // Создаем Rect узла в мировых координатах
    final nodeWorldRect = Rect.fromPoints(
      nodeAbsolutePosition,
      Offset(
        nodeAbsolutePosition.dx + currentNode.size.width,
        nodeAbsolutePosition.dy + currentNode.size.height,
      ),
    );

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
  }

  /// Отрисовка одного узла (без детей)
  void _drawSingleNode({
    required Canvas canvas,
    required TableNode node,
    required Rect nodeRect,
    required bool forTile,
  }) {
    final isSwimlane = node.qType == 'swimlane';
    // Проверяем, является ли узел свернутым
    final isCollapsed = node.isCollapsed ?? false;

    // Для swimlane
    if (node.qType == 'swimlane') {
      _drawSwimlane(canvas, node, nodeRect, isCollapsed: isCollapsed);
      return;
    }

    // Оригинальная логика для остальных узлов...
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

    final attributes = node.attributes;
    final hasAttributes = attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isNotGroup = node.groupId != null;

    // Для swimlane в раскрытом состоянии
    if (isSwimlane && !isCollapsed) {
      // Прозрачный заголовок
      final headerPaint = Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;

      final headerRect = Rect.fromLTWH(
        nodeRect.left + 1,
        nodeRect.top + 1,
        nodeRect.width - 2,
        EditorConfig.headerHeight - 2,
      );

      canvas.drawRect(headerRect, headerPaint);

      // Черная рамка без радиусов
      final borderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..isAntiAlias = true;

      canvas.drawRect(nodeRect, borderPaint);

      // Рисуем иконку и текст заголовка
      _drawSwimlaneHeader(canvas, node, nodeRect, isCollapsed: false);
      return;
    }

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

    if (isNotGroup || isEnum || !hasAttributes) {
      canvas.drawRect(nodeRect, tablePaint);
      canvas.drawRect(nodeRect, tableBorderPaint);
    } else {
      final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
      canvas.drawRRect(roundedRect, tablePaint);
      canvas.drawRRect(roundedRect, tableBorderPaint);
    }

    // Вычисляем размеры
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

    if (isNotGroup || isEnum || !hasAttributes) {
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

    if (!isNotGroup && hasAttributes) {
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

      final columnSplit = isEnum ? 20 : nodeRect.width - 20;

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
      final leftText = isEnum ? attribute['position'] : attribute['label'];
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
      final rightText = isEnum ? attribute['label'] : '';
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

  /// Метод для отрисовки свернутого swimlane
  void _drawSwimlane(
    Canvas canvas,
    TableNode node,
    Rect nodeRect, {
    required bool isCollapsed,
  }) {
    // Рассчитываем толщину линии
    final scaleX = nodeRect.width / node.size.width;
    final scaleY = nodeRect.height / node.size.height;
    final lineWidth = 1.0 / math.min(scaleX, scaleY);

    // Белый фон для всего узла
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawRect(nodeRect, backgroundPaint);

    // Черная рамка без радиусов
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..isAntiAlias = true;

    canvas.drawRect(nodeRect, borderPaint);

    // Белый фон для заголовка (в свернутом состоянии весь узел - это заголовок)
    final headerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawRect(nodeRect, headerPaint);

    // Рисуем иконку и текст заголовка
    _drawSwimlaneHeader(canvas, node, nodeRect, isCollapsed: isCollapsed);
  }

  /// Метод для отрисовки заголовка swimlane с иконкой
  void _drawSwimlaneHeader(
    Canvas canvas,
    TableNode node,
    Rect nodeRect, {
    required bool isCollapsed,
  }) {
    final headerHeight = EditorConfig.headerHeight;
    final iconSize = 16.0;
    final iconMargin = 8.0;
    final textLeftMargin = iconSize + iconMargin * 2;

    // ВАЖНО: Заголовок всегда должен быть вверху, независимо от состояния свернутости
    // Используем фиксированную высоту заголовка
    final actualHeaderHeight = headerHeight;

    // Рисуем иконку - всегда вверху заголовка
    final iconRect = Rect.fromLTWH(
      nodeRect.left + iconMargin,
      nodeRect.top + (actualHeaderHeight - iconSize) / 2,
      iconSize,
      iconSize,
    );

    // Черный квадрат
    final iconBackgroundPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawRect(iconRect, iconBackgroundPaint);

    // Белый крест или минус
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    if (isCollapsed) {
      // Крест (плюс)
      final centerX = iconRect.left + iconSize / 2;
      final centerY = iconRect.top + iconSize / 2;
      final crossSize = iconSize / 3;

      // Горизонтальная линия
      canvas.drawLine(
        Offset(centerX - crossSize, centerY),
        Offset(centerX + crossSize, centerY),
        iconPaint,
      );

      // Вертикальная линия
      canvas.drawLine(
        Offset(centerX, centerY - crossSize),
        Offset(centerX, centerY + crossSize),
        iconPaint,
      );
    } else {
      // Минус
      final centerY = iconRect.top + iconSize / 2;
      final minusSize = iconSize / 3;

      canvas.drawLine(
        Offset(iconRect.left + iconSize / 2 - minusSize, centerY),
        Offset(iconRect.left + iconSize / 2 + minusSize, centerY),
        iconPaint,
      );
    }

    // Текст заголовка
    final textSpan = TextSpan(
      text: node.text,
      style: TextStyle(
        color: Colors.black, // Черный текст на белом фоне
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );

    textPainter.layout(maxWidth: nodeRect.width - textLeftMargin - 8);
    textPainter.paint(
      canvas,
      Offset(
        nodeRect.left + textLeftMargin,
        nodeRect.top + (actualHeaderHeight - textPainter.height) / 2,
      ),
    );
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
