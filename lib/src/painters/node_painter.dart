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
    // Проверяем, является ли узел раскрытым swimlane
    final isExpandedSwimlane =
        currentNode.qType == 'swimlane' && !(currentNode.isCollapsed ?? false);

    if (isExpandedSwimlane) {
      // Для раскрытого swimlane сначала рисуем детей
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

    // Для обычных узлов (не swimlane) рисуем детей после родителя
    if (!isExpandedSwimlane &&
        currentNode.children != null &&
        currentNode.children!.isNotEmpty) {
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
    required Offset parentAbsolutePosition,
    required Rect visibleBounds,
    required bool forTile,
    Map<TableNode, Rect>? nodeBoundsCache,
  }) {
    // Проверяем, является ли узел swimlane
    final isSwimlane = currentNode.qType == 'swimlane';
    final isCollapsed = currentNode.isCollapsed ?? false;

    // Для swimlane в раскрытом состоянии меняем порядок отрисовки
    if (isSwimlane && !isCollapsed) {
      _drawSwimlaneWithChildrenOnTop(
        canvas: canvas,
        swimlaneNode: currentNode,
        parentAbsolutePosition: parentAbsolutePosition,
        visibleBounds: visibleBounds,
        forTile: forTile,
        nodeBoundsCache: nodeBoundsCache,
      );
      return;
    }

    // Оригинальная логика для остальных узлов...
    final isCollapsedSwimlane = isSwimlane && isCollapsed;

    // Если узел свернут, не рисуем его детей
    if (isCollapsedSwimlane) {
      // Рассчитываем абсолютную позицию текущего узла
      final nodeAbsolutePosition =
          currentNode.position + parentAbsolutePosition;

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
        return; // Не рисуем свернутый узел, если он не виден
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
      return; // Выходим, не рисуем детей
    }

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

    // Рисуем детей (если узел не свернут)
    _drawChildren(
      canvas: canvas,
      parentNode: currentNode,
      parentAbsolutePosition: nodeAbsolutePosition,
      visibleBounds: visibleBounds,
      forTile: forTile,
      nodeBoundsCache: nodeBoundsCache,
    );
  }

  /// Новый метод для отрисовки swimlane с детьми под родителем
  void _drawSwimlaneWithChildrenOnTop({
    required Canvas canvas,
    required TableNode swimlaneNode,
    required Offset parentAbsolutePosition,
    required Rect visibleBounds,
    required bool forTile,
    Map<TableNode, Rect>? nodeBoundsCache,
  }) {
    // Рассчитываем абсолютную позицию swimlane
    final swimlaneAbsolutePosition =
        swimlaneNode.position + parentAbsolutePosition;

    // Создаем Rect swimlane в мировых координатах
    final swimlaneWorldRect = Rect.fromPoints(
      swimlaneAbsolutePosition,
      Offset(
        swimlaneAbsolutePosition.dx + swimlaneNode.size.width,
        swimlaneAbsolutePosition.dy + swimlaneNode.size.height,
      ),
    );

    // Сохраняем в кэш
    if (nodeBoundsCache != null) {
      nodeBoundsCache[swimlaneNode] = swimlaneWorldRect;
    }

    // Сначала рисуем детей (они будут под родителем)
    if (swimlaneNode.children != null && swimlaneNode.children!.isNotEmpty) {
      for (final child in swimlaneNode.children!) {
        _drawNodeRecursive(
          canvas: canvas,
          currentNode: child,
          parentAbsolutePosition: swimlaneAbsolutePosition,
          visibleBounds: visibleBounds,
          forTile: forTile,
          nodeBoundsCache: nodeBoundsCache,
        );
      }
    }

    // Проверяем видимость родителя
    if (!swimlaneWorldRect.overlaps(visibleBounds.inflate(10.0))) {
      return;
    }

    canvas.save();

    // Затем рисуем родителя (он будет поверх детей)
    if (forTile) {
      // Для тайла: рисуем в мировых координатах
      _drawSingleNode(
        canvas: canvas,
        node: swimlaneNode,
        nodeRect: swimlaneWorldRect,
        forTile: true,
      );
    } else {
      // Для виджета: преобразуем координаты
      final scaleX = swimlaneWorldRect.width / swimlaneNode.size.width;
      final scaleY = swimlaneWorldRect.height / swimlaneNode.size.height;

      canvas.scale(scaleX, scaleY);

      final nodeLocalRect = Rect.fromLTWH(
        0,
        0,
        swimlaneNode.size.width,
        swimlaneNode.size.height,
      );

      _drawSingleNode(
        canvas: canvas,
        node: swimlaneNode,
        nodeRect: nodeLocalRect,
        forTile: false,
      );
    }

    canvas.restore();
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
    // Проверяем, является ли родитель свернутым swimlane
    final isParentCollapsedSwimlane =
        parentNode.qType == 'swimlane' && (parentNode.isCollapsed ?? false);

    if (isParentCollapsedSwimlane) {
      return; // Не рисуем детей свернутого swimlane
    }

    // Проверяем, является ли родитель раскрытым swimlane
    final isParentExpandedSwimlane =
        parentNode.qType == 'swimlane' && !(parentNode.isCollapsed ?? false);

    // Для раскрытого swimlane дети уже были нарисованы в _drawSwimlaneWithChildrenOnTop
    if (isParentExpandedSwimlane) {
      return;
    }

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
    // Проверяем, является ли узел swimlane
    final isSwimlane = node.qType == 'swimlane';
    final isCollapsed = node.isCollapsed ?? false;

    // Для swimlane в свернутом состоянии
    if (isSwimlane && isCollapsed) {
      _drawCollapsedSwimlane(canvas, node, nodeRect);
      return;
    }

    // Для swimlane в раскрытом состоянии
    if (isSwimlane && !isCollapsed) {
      // Добавляем тень под swimlane
      _drawSwimlaneShadow(canvas, nodeRect);

      // Белый фон для всего узла
      final backgroundPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;

      canvas.drawRect(nodeRect, backgroundPaint);

      // Белый фон для заголовка
      final headerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;

      final headerHeight = EditorConfig.headerHeight;
      final headerRect = Rect.fromLTWH(
        nodeRect.left + 1,
        nodeRect.top + 1,
        nodeRect.width - 2,
        headerHeight - 2,
      );

      canvas.drawRect(headerRect, headerPaint);

      // Черная рамка без радиусов
      final scaleX = nodeRect.width / node.size.width;
      final scaleY = nodeRect.height / node.size.height;
      final lineWidth = 1.0 / math.min(scaleX, scaleY);

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
  void _drawCollapsedSwimlane(Canvas canvas, TableNode node, Rect nodeRect) {
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
    _drawSwimlaneHeader(canvas, node, nodeRect, isCollapsed: true);
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

    // Определяем, свернут ли swimlane
    final isActuallyCollapsed =
        node.qType == 'swimlane' && (node.isCollapsed ?? false);
    final actualHeaderHeight = isActuallyCollapsed
        ? nodeRect.height
        : headerHeight;

    // Рисуем иконку
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

  /// Метод для отрисовки тени swimlane в раскрытом состоянии
  void _drawSwimlaneShadow(Canvas canvas, Rect nodeRect) {
    // Создаем Paint для тени
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4)
      ..isAntiAlias = true;

    // Создаем немного увеличенный прямоугольник для тени
    final shadowRect = Rect.fromLTRB(
      nodeRect.left - 2,
      nodeRect.top - 2,
      nodeRect.right + 2,
      nodeRect.bottom + 2,
    );

    // Рисуем тень
    canvas.drawRect(shadowRect, shadowPaint);

    // Создаем вторую, более мягкую тень
    final softShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.05)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8)
      ..isAntiAlias = true;

    final softShadowRect = Rect.fromLTRB(
      nodeRect.left - 4,
      nodeRect.top - 4,
      nodeRect.right + 4,
      nodeRect.bottom + 4,
    );

    canvas.drawRect(softShadowRect, softShadowPaint);
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
