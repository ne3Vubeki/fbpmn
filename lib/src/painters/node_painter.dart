import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/table.node.dart';
import '../utils/canvas_icons.dart';
import '../utils/editor_config.dart';

/// Универсальный класс для отрисовки TableNode в любом контексте
class NodePainter {
  final TableNode node;
  final bool isSelected;
  final bool isHighlighted;

  NodePainter({
    required this.node,
    this.isSelected = false,
    this.isHighlighted = false,
  });

  /// Отрисовка узла с учетом базового отступа (рекурсивно с детьми)
  void paintWithOffset({
    required Canvas canvas,
    required Offset baseOffset,
    required Rect visibleBounds,
    bool forTile = false,
    Set<String>? highlightedNodeIds,
  }) {
    // Для всех случаев используем единую рекурсивную логику
    _drawNodeRecursive(
      canvas: canvas,
      currentNode: node,
      parentAbsolutePosition: baseOffset,
      visibleBounds: visibleBounds,
      forTile: forTile,
      highlightedNodeIds: highlightedNodeIds,
    );
  }

  /// Проверяет, выходит ли содержимое узла за его нижнюю границу
  bool _isContentOverflowing({required TableNode node, required Rect nodeRect}) {
    if (node.qType == 'swimlane') {
      // Для swimlane проверяем состояние свернутости
      final isCollapsed = node.isCollapsed ?? false;
      if (isCollapsed) {
        return false; // Свернутый swimlane не имеет переполнения
      }
      // Для раскрытого swimlane может быть переполнение детей
      return false; // Пока просто возвращаем false
    }

    final attributes = node.attributes;
    if (attributes.isEmpty) return false; // Нет атрибутов - нет переполнения

    final headerHeight = EditorConfig.headerHeight;
    final rowHeight = (nodeRect.height - headerHeight) / attributes.length;
    final minRowHeight = EditorConfig.minRowHeight;
    final actualRowHeight = math.max(rowHeight, minRowHeight);

    // Вычисляем высоту всего содержимого
    final contentHeight = headerHeight + actualRowHeight * attributes.length;

    // Если высота содержимого больше высоты узла - есть переполнение
    return contentHeight > nodeRect.height;
  }

  /// Создает маску для обрезки содержимого (аналог overflow: hidden)
  /// Маска обрезает только внутреннее содержимое, не затрагивая границу
  void _applyClipMask({
    required Canvas canvas,
    required Rect nodeRect,
    required TableNode node,
    double lineWidth = 1.0,
  }) {
    final attributes = node.attributes;
    final hasAttributes = attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isGroup = node.qType == 'group';
    final isSwimlane = node.qType == 'swimlane';

    // Уменьшаем область обрезки на половину толщины линии, чтобы оставить место для границы
    final clipInset = lineWidth;

    if (isSwimlane || isGroup || isEnum || !hasAttributes) {
      // Прямоугольная маска без скруглений
      final clipRect = Rect.fromLTWH(
        nodeRect.left + clipInset,
        nodeRect.top + clipInset,
        nodeRect.width - clipInset * 2,
        nodeRect.height - clipInset * 2,
      );
      canvas.clipRect(clipRect);
    } else {
      // Маска со скругленными углами, но с меньшим радиусом для внутреннего содержимого
      final innerRadius = math.max(0, 8 - clipInset);
      final roundedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          nodeRect.left + clipInset,
          nodeRect.top + clipInset,
          nodeRect.width - clipInset * 2,
          nodeRect.height - clipInset * 2,
        ),
        Radius.circular(innerRadius.toDouble()),
      );
      canvas.clipRRect(roundedRect);
    }
  }

  /// Рисует границу узла (без маски)
  void _drawNodeBorder({
    required Canvas canvas,
    required TableNode node,
    required Rect nodeRect,
    double lineWidth = 1.0,
    bool forTile = false,
    bool isContentOverflowing = false,
  }) {
    final isSwimlane = node.qType == 'swimlane';
    final attributes = node.attributes;
    final hasAttributes = attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isGroup = node.qType == 'group';

    // Основной цвет границы (черный по умолчанию)
    Color borderColor = Colors.black;

    // Если есть переполнение содержимого, используем красный цвет для нижней границы
    if (isContentOverflowing) {
      // Для узлов со скругленными углами рисуем специальным способом
      if (!isSwimlane && !isGroup && !isEnum && hasAttributes) {
        // Сначала рисуем всю границу черным
        final blackBorderPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high;

        final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
        canvas.drawRRect(roundedRect, blackBorderPaint);

        // Затем поверх рисуем нижнюю часть красным
        final redBorderPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high;

        // Вычисляем точки для нижней границы со скруглениями
        final bottomLeft = Offset(nodeRect.left + 8, nodeRect.bottom);
        final bottomRight = Offset(nodeRect.right - 8, nodeRect.bottom);

        // Левая скругленная часть
        canvas.drawArc(
          Rect.fromCircle(center: Offset(nodeRect.left + 8, nodeRect.bottom - 8), radius: 8),
          math.pi * 0.5,
          math.pi * 0.5,
          false,
          redBorderPaint,
        );

        // Прямая часть нижней границы
        canvas.drawLine(bottomLeft, bottomRight, redBorderPaint);

        // Правая скругленная часть
        canvas.drawArc(
          Rect.fromCircle(center: Offset(nodeRect.right - 8, nodeRect.bottom - 8), radius: 8),
          math.pi * 2,
          math.pi * 0.5,
          false,
          redBorderPaint,
        );

        return;
      } else {
        // Для прямоугольных узлов рисуем черную границу, затем красную снизу
        final blackBorderPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high;

        if (isSwimlane || isGroup || isEnum || !hasAttributes) {
          canvas.drawRect(nodeRect, blackBorderPaint);
        } else {
          final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
          canvas.drawRRect(roundedRect, blackBorderPaint);
        }

        // Рисуем красную нижнюю границу
        final redBorderPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high;

        final bottomLeft = Offset(nodeRect.left, nodeRect.bottom);
        final bottomRight = Offset(nodeRect.right, nodeRect.bottom);
        canvas.drawLine(bottomLeft, bottomRight, redBorderPaint);

        return;
      }
    }

    // Если нет переполнения, рисуем обычную границу
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (isSwimlane) {
      canvas.drawRect(nodeRect, borderPaint);
    } else if (isGroup || isEnum || !hasAttributes) {
      canvas.drawRect(nodeRect, borderPaint);
    } else {
      final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
      canvas.drawRRect(roundedRect, borderPaint);
    }
  }

  /// Рисует подсветку связанного узла (прозрачный синий)
  void _drawHighlightOverlay({
    required Canvas canvas,
    required Rect nodeRect,
    required TableNode node,
  }) {
    final isSwimlane = node.qType == 'swimlane';
    final attributes = node.attributes;
    final hasAttributes = attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isGroup = node.qType == 'group';

    final highlightPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (isSwimlane || isGroup || isEnum || !hasAttributes) {
      canvas.drawRect(nodeRect, highlightPaint);
    } else {
      final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
      canvas.drawRRect(roundedRect, highlightPaint);
    }
  }

  /// Рисует фон узла (без маски)
  void _drawNodeBackground({
    required Canvas canvas,
    required TableNode node,
    required Rect nodeRect,
    bool forTile = false,
  }) {
    final isSwimlane = node.qType == 'swimlane';
    final attributes = node.attributes;
    final hasAttributes = attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isGroup = node.qType == 'group';

    // Для swimlane рисуем белый фон
    if (isSwimlane) {
      final backgroundPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.drawRect(nodeRect, backgroundPaint);
      return;
    }

    final backgroundColor = isGroup ? node.backgroundColor : Colors.white;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (isGroup || isEnum || !hasAttributes) {
      canvas.drawRect(nodeRect, backgroundPaint);
    } else {
      final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
      canvas.drawRRect(roundedRect, backgroundPaint);
    }
  }

  /// Рекурсивная отрисовка узла и его детей
  void _drawNodeRecursive({
    required Canvas canvas,
    required TableNode currentNode,
    required Offset parentAbsolutePosition,
    required Rect visibleBounds,
    required bool forTile,
    Set<String>? highlightedNodeIds,
  }) {
    // Рассчитываем абсолютную позицию текущего узла
    final nodeAbsolutePosition = currentNode.aPosition ?? (currentNode.position + parentAbsolutePosition);

    // Создаем Rect узла в мировых координатах
    final nodeWorldRect = Rect.fromPoints(
      nodeAbsolutePosition,
      Offset(nodeAbsolutePosition.dx + currentNode.size.width, nodeAbsolutePosition.dy + currentNode.size.height),
    );

    canvas.save();

    // Применяем полупрозрачность для узла, если qCompStatus == '6'
    if (currentNode.qCompStatus == '6') {
      canvas.saveLayer(nodeWorldRect, Paint()..color = Colors.white.withOpacity(0.5));
    }

    if (forTile) {
      // Для тайла: рисуем в мировых координатах
      final scaleX = 1.0;
      final scaleY = 1.0;
      final lineWidth = 1.0 / math.min(scaleX, scaleY);

      // Проверяем переполнение содержимого
      final isContentOverflowing = _isContentOverflowing(node: currentNode, nodeRect: nodeWorldRect);

      // 1. Сначала рисуем фон и границу (без маски)
      _drawNodeBackground(canvas: canvas, node: currentNode, nodeRect: nodeWorldRect, forTile: true);

      _drawNodeBorder(
        canvas: canvas,
        node: currentNode,
        nodeRect: nodeWorldRect,
        lineWidth: lineWidth,
        forTile: true,
        isContentOverflowing: isContentOverflowing,
      );

      // 2. Теперь применяем маску для внутреннего содержимого
      _applyClipMask(canvas: canvas, nodeRect: nodeWorldRect, node: currentNode, lineWidth: lineWidth);

      // 3. Рисуем внутреннее содержимое (с маской)
      _drawNodeContent(canvas: canvas, node: currentNode, nodeRect: nodeWorldRect, forTile: true);

      // 4. Рисуем иконку треугольника поверх всего (вне маски)
      if (isContentOverflowing) {
        canvas.restore(); // Снимаем маску
        canvas.save(); // Сохраняем для последующего restore

        final iconSize = 20.0;
        final iconX = nodeWorldRect.left + nodeWorldRect.width / 2 - iconSize / 2;
        final iconY = nodeWorldRect.bottom - iconSize / 2 - 4;

        canvas.save();
        canvas.translate(iconX, iconY);
        CanvasIcons.paintWarningTriangle(canvas, Size(iconSize, iconSize));
        canvas.restore();
      }

      // 5. Рисуем подсветку связанных узлов (прозрачный синий)
      final isNodeHighlighted = highlightedNodeIds?.contains(currentNode.id) ?? false;
      if (isNodeHighlighted) {
        _drawHighlightOverlay(canvas: canvas, nodeRect: nodeWorldRect, node: currentNode);
      }
    } else {
      // Для виджета: преобразуем координаты
      final scaleX = nodeWorldRect.width / currentNode.size.width;
      final scaleY = nodeWorldRect.height / currentNode.size.height;

      canvas.scale(scaleX, scaleY);

      final nodeLocalRect = Rect.fromLTWH(0, 0, currentNode.size.width, currentNode.size.height);
      final lineWidth = 1.0 / math.min(scaleX, scaleY);

      // Проверяем переполнение содержимого
      final isContentOverflowing = _isContentOverflowing(node: currentNode, nodeRect: nodeLocalRect);

      // 1. Сначала рисуем фон и границу (без маски)
      _drawNodeBackground(canvas: canvas, node: currentNode, nodeRect: nodeLocalRect, forTile: false);

      _drawNodeBorder(
        canvas: canvas,
        node: currentNode,
        nodeRect: nodeLocalRect,
        lineWidth: lineWidth,
        forTile: false,
        isContentOverflowing: isContentOverflowing,
      );

      // 2. Теперь применяем маску для внутреннего содержимого
      _applyClipMask(canvas: canvas, nodeRect: nodeLocalRect, node: currentNode, lineWidth: lineWidth);

      // 3. Рисуем внутреннее содержимое (с маской)
      _drawNodeContent(canvas: canvas, node: currentNode, nodeRect: nodeLocalRect, forTile: false);

      // 4. Рисуем иконку треугольника поверх всего (вне маски)
      if (isContentOverflowing) {
        canvas.restore(); // Снимаем маску
        canvas.save(); // Сохраняем для последующего restore

        final iconSize = 20.0;
        final iconX = nodeLocalRect.left + nodeLocalRect.width / 2 - iconSize / 2;
        final iconY = nodeLocalRect.bottom - iconSize / 2 - 4;

        canvas.save();
        canvas.translate(iconX, iconY);
        CanvasIcons.paintWarningTriangle(canvas, Size(iconSize, iconSize));
        canvas.restore();
      }
    }

    // Восстанавливаем слой полупрозрачности, если был применен
    if (currentNode.qCompStatus == '6') {
      canvas.restore();
    }

    canvas.restore();
  }

  /// Отрисовка внутреннего содержимого узла (с примененной маской)
  void _drawNodeContent({
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
      _drawSwimlaneContent(canvas, node, nodeRect, isCollapsed: isCollapsed);
      return;
    }

    final attributes = node.attributes;
    final hasAttributes = attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isGroup = node.qType == 'group';

    // Для swimlane в раскрытом состоянии
    if (isSwimlane && !isCollapsed) {
      // Рисуем иконку и текст заголовка
      _drawSwimlaneHeader(canvas, node, nodeRect, isCollapsed: false);
      return;
    }

    // Рисуем заголовок
    final headerBackgroundColor = node.backgroundColor;
    final headerHeight = EditorConfig.headerHeight;
    final headerRect = Rect.fromLTWH(nodeRect.left + 1, nodeRect.top + 1, nodeRect.width - 2, headerHeight - 2);

    final headerPaint = Paint()
      ..color = headerBackgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (isGroup || isEnum || !hasAttributes) {
      canvas.drawRect(headerRect, headerPaint);
    } else {
      final headerRoundedRect = RRect.fromRectAndCorners(
        headerRect,
        topLeft: Radius.circular(8),
        topRight: Radius.circular(8),
      );
      canvas.drawRRect(headerRoundedRect, headerPaint);
    }

    // Рассчитываем толщину линии для внутренних границ
    final scaleX = nodeRect.width / node.size.width;
    final scaleY = nodeRect.height / node.size.height;
    final lineWidth = 1.0 / math.min(scaleX, scaleY);

    final headerBorderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (!isGroup && hasAttributes) {
      canvas.drawLine(
        Offset(nodeRect.left, nodeRect.top + headerHeight),
        Offset(nodeRect.right, nodeRect.top + headerHeight),
        headerBorderPaint,
      );
    }

    // Текст заголовка
    final textColorHeader = headerBackgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final headerTextSpan = TextSpan(
      text: node.text,
      style: TextStyle(color: textColorHeader, fontSize: 12, fontWeight: FontWeight.bold),
    );

    final headerTextPainter = TextPainter(
      text: headerTextSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    )..textWidthBasis = TextWidthBasis.longestLine;

    headerTextPainter.layout(maxWidth: nodeRect.width - 16);

    // Если текст заголовка выходит за границы, он будет автоматически обрезан маской
    headerTextPainter.paint(
      canvas,
      Offset(nodeRect.left + 8, nodeRect.top + (headerHeight - headerTextPainter.height) / 2),
    );

    // Рисуем иконку замка в заголовке, если qCompStatus == '6'
    if (node.qCompStatus == '6') {
      final lockSize = 16.0;
      final lockX = nodeRect.right - lockSize - 2;
      final lockY = nodeRect.top + (headerHeight - lockSize) / 2;

      canvas.save();
      canvas.translate(lockX, lockY);
      CanvasIcons.paintLock(canvas, Size(lockSize, lockSize), Colors.grey.shade600);
      canvas.restore();
    }

    // Рисуем строки таблицы
    final rowHeight = (nodeRect.height - headerHeight) / attributes.length;
    final minRowHeight = EditorConfig.minRowHeight;
    final actualRowHeight = math.max(rowHeight, minRowHeight);

    for (int i = 0; i < attributes.length; i++) {
      final attribute = attributes[i];
      final rowTop = nodeRect.top + headerHeight + actualRowHeight * i;
      final rowBottom = rowTop + actualRowHeight;

      final columnSplit = isEnum ? 20 : nodeRect.width - 40;

      // Вертикальная граница - будет обрезана маской если выходит за границы
      canvas.drawLine(
        Offset(nodeRect.left + columnSplit, rowTop),
        Offset(nodeRect.left + columnSplit, rowBottom),
        headerBorderPaint,
      );

      // Горизонтальная граница - будет обрезана маской если выходит за границы
      if (i < attributes.length - 1) {
        canvas.drawLine(Offset(nodeRect.left, rowBottom), Offset(nodeRect.right, rowBottom), headerBorderPaint);
      }

      // Текст в левой колонке - будет обрезан маской если выходит за границы
      final leftText = isEnum ? (attribute.index ?? '') : attribute.text;
      if (leftText.isNotEmpty) {
        // Применяем полупрозрачность к тексту атрибута, если qCompStatus == '6'
        final textOpacity = attribute.qCompStatus == '6' ? 0.5 : 1.0;
        final leftTextPainter = TextPainter(
          text: TextSpan(
            text: leftText,
            style: TextStyle(color: Colors.black.withOpacity(textOpacity), fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
          ellipsis: '...',
        )..textWidthBasis = TextWidthBasis.parent;

        leftTextPainter.layout(maxWidth: columnSplit - 16);
        leftTextPainter.paint(
          canvas,
          Offset(nodeRect.left + 8, rowTop + (actualRowHeight - leftTextPainter.height) / 2),
        );
      }

      // Текст в правой колонке - будет обрезан маской если выходит за границы
      final rightText = isEnum ? attribute.text : '';
      if (rightText.isNotEmpty) {
        // Применяем полупрозрачность к тексту атрибута, если qCompStatus == '6'
        final textOpacity = attribute.qCompStatus == '6' ? 0.5 : 1.0;
        final rightTextPainter = TextPainter(
          text: TextSpan(
            text: rightText,
            style: TextStyle(color: Colors.black.withOpacity(textOpacity), fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
          ellipsis: '...',
        )..textWidthBasis = TextWidthBasis.parent;

        rightTextPainter.layout(maxWidth: nodeRect.width - columnSplit - 16);
        rightTextPainter.paint(
          canvas,
          Offset(nodeRect.left + columnSplit + 8, rowTop + (actualRowHeight - rightTextPainter.height) / 2),
        );
      }

      // Рисуем иконку замка во второй ячейке, если qCompStatus == '6'
      if (attribute.qCompStatus == '6') {
        final lockSize = 16.0;
        final lockX = nodeRect.right - lockSize - 2;
        final lockY = rowTop + (actualRowHeight - lockSize) / 2;

        canvas.save();
        canvas.translate(lockX, lockY);
        CanvasIcons.paintLock(canvas, Size(lockSize, lockSize), Colors.grey.shade600);
        canvas.restore();
      }
    }
  }

  /// Метод для отрисовки содержимого свернутого swimlane
  void _drawSwimlaneContent(Canvas canvas, TableNode node, Rect nodeRect, {required bool isCollapsed}) {
    // Рисуем заголовок swimlane
    final headerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawRect(nodeRect, headerPaint);

    // Рисуем иконку и текст заголовка
    _drawSwimlaneHeader(canvas, node, nodeRect, isCollapsed: isCollapsed);
  }

  /// Метод для отрисовки заголовка swimlane с иконкой
  void _drawSwimlaneHeader(Canvas canvas, TableNode node, Rect nodeRect, {required bool isCollapsed}) {
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
      canvas.drawLine(Offset(centerX - crossSize, centerY), Offset(centerX + crossSize, centerY), iconPaint);

      // Вертикальная линия
      canvas.drawLine(Offset(centerX, centerY - crossSize), Offset(centerX, centerY + crossSize), iconPaint);
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

    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '...');

    textPainter.layout(maxWidth: nodeRect.width - textLeftMargin - 8);
    textPainter.paint(
      canvas,
      Offset(nodeRect.left + textLeftMargin, nodeRect.top + (actualHeaderHeight - textPainter.height) / 2),
    );
  }

  /// Простая отрисовка одного узла (без детей) - для обратной совместимости
  void paint(Canvas canvas, Rect targetRect, {bool forTile = false}) {
    // Рассчитываем толщину линии
    final scaleX = targetRect.width / node.size.width;
    final scaleY = targetRect.height / node.size.height;
    final lineWidth = 1.0 / math.min(scaleX, scaleY);

    // Проверяем переполнение содержимого
    final isContentOverflowing = _isContentOverflowing(node: node, nodeRect: targetRect);

    canvas.save();

    // 1. Сначала рисуем фон и границу (без маски)
    _drawNodeBackground(canvas: canvas, node: node, nodeRect: targetRect, forTile: forTile);

    _drawNodeBorder(
      canvas: canvas,
      node: node,
      nodeRect: targetRect,
      lineWidth: lineWidth,
      forTile: forTile,
      isContentOverflowing: isContentOverflowing,
    );

    // 2. Теперь применяем маску для внутреннего содержимого
    _applyClipMask(canvas: canvas, nodeRect: targetRect, node: node, lineWidth: lineWidth);

    // 3. Рисуем внутреннее содержимое (с маской)
    _drawNodeContent(canvas: canvas, node: node, nodeRect: targetRect, forTile: forTile);

    // 4. Рисуем иконку треугольника поверх всего (вне маски)
    if (isContentOverflowing) {
      canvas.restore(); // Снимаем маску
      canvas.save(); // Сохраняем для последующего restore

      final iconSize = 20.0;
      final iconX = targetRect.left + targetRect.width / 2 - iconSize / 2;
      final iconY = targetRect.bottom - iconSize / 2 - 4;

      canvas.save();
      canvas.translate(iconX, iconY);
      CanvasIcons.paintWarningTriangle(canvas, Size(iconSize, iconSize));
      canvas.restore();
    }

    canvas.restore();
  }
}
