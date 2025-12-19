import 'dart:math';
import 'package:flutter/material.dart';

import '../models/table.node.dart';

class HierarchicalGridPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final Offset delta;
  final Size canvasSize;
  final List<TableNode> nodes;

  const HierarchicalGridPainter({
    required this.scale,
    required this.offset,
    required this.canvasSize,
    required this.nodes,
    required this.delta,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Рисуем белый фон холста
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..color = Colors.white,
    );

    // Применяем масштабирование к холсту
    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(offset.dx / scale, offset.dy / scale);

    // Определяем видимую область с учетом смещения и масштаба
    final double visibleLeft = -offset.dx / scale;
    final double visibleTop = -offset.dy / scale;
    final double visibleRight = (size.width - offset.dx) / scale;
    final double visibleBottom = (size.height - offset.dy) / scale;

    // Рисуем иерархическую сетку
    _drawHierarchicalGrid(
      canvas,
      visibleLeft,
      visibleTop,
      visibleRight,
      visibleBottom,
    );

    // Рисуем узлы
    _drawTableNodes(canvas, nodes, delta);

    canvas.restore();
  }

  void _drawNodes(Canvas canvas) {
    for (final node in nodes) {
      final nodeRect = Rect.fromCenter(
        center: node.position,
        width: node.size.width,
        height: node.size.height,
      );

      // Рисуем тело узла
      final paint = Paint()
        ..color = node.isSelected ? Colors.blue.shade200 : Colors.grey.shade300
        ..style = PaintingStyle.fill;

      canvas.drawRect(nodeRect, paint);

      // Рисуем рамку
      final borderPaint = Paint()
        ..color = node.isSelected ? Colors.blue.shade600 : Colors.grey.shade600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(nodeRect, borderPaint);

      // Рисуем текст
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.text,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          node.position.dx - textPainter.width / 2,
          node.position.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawTableNodes(Canvas canvas, List<TableNode> nodes, Offset offset) {
    for (final node in nodes) {
      final TableNode tableNode = node;

      print('Обработка ${tableNode.text}');

      // Применяем сдвиг к позиции узла
      final shiftedPosition = tableNode.position + offset;

      // Используем ширину из geometry ноды - это главная ширина
      final actualWidth = tableNode.size.width;
      final minHeight = _calculateMinHeight(tableNode);

      final actualHeight = max(tableNode.size.height, minHeight);

      // Используем сдвинутую позицию
      final nodeRect = Rect.fromPoints(
        shiftedPosition,
        Offset(
          shiftedPosition.dx + actualWidth,
          shiftedPosition.dy + actualHeight,
        ),
      );

      // Цвета для отрисовки
      final backgroundColor = tableNode.groupId != null
          ? tableNode.backgroundColor
          : Colors.white; // Фон таблицы всегда белый
      final headerBackgroundColor = tableNode.backgroundColor; // Цвет заголовка
      final borderColor = Colors.black;
      final textColorHeader = headerBackgroundColor.computeLuminance() > 0.5
          ? Colors.black
          : Colors.white;

      // Рисуем закругленный прямоугольник для всей таблицы
      final tablePaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill;

      final tableBorderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      if (tableNode.groupId != null) {
        // Рисуем прямой прямоугольник
        canvas.drawRect(nodeRect, tablePaint);
        canvas.drawRect(nodeRect, tableBorderPaint);
      } else {
        // Рисуем закругленный прямоугольник
        final roundedRect = RRect.fromRectAndRadius(
          nodeRect,
          Radius.circular(8),
        );
        canvas.drawRRect(roundedRect, tablePaint);
        canvas.drawRRect(roundedRect, tableBorderPaint);
      }

      // Вычисляем размеры заголовка и ячеек
      final attributes = tableNode.attributes;
      final children = tableNode.children ?? [];

      // Фиксированная высота заголовка = 20
      final headerHeight = 30.0;
      final rowHeight = (nodeRect.height - headerHeight) / attributes.length;

      // Минимальная высота для строк атрибутов
      final minRowHeight = 18.0;
      final actualRowHeight = max(rowHeight, minRowHeight);

      // Рисуем заголовок
      final headerRect = Rect.fromLTWH(
        nodeRect.left + 1,
        nodeRect.top + 1,
        nodeRect.width - 2,
        headerHeight - 2,
      );

      // Фон заголовка - используем переданный цвет
      final headerPaint = Paint()
        ..color = headerBackgroundColor
        ..style = PaintingStyle.fill;

      if (tableNode.groupId != null) {
        // Рисуем заголовок с прямыми верхними углами
        canvas.drawRect(headerRect, headerPaint);
      } else {
        // Рисуем заголовок с закругленными верхними углами
        final headerRoundedRect = RRect.fromRectAndCorners(
          headerRect,
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        );
        canvas.drawRRect(headerRoundedRect, headerPaint);
      }

      // Граница горизонтальная
      final headerBorderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      if (tableNode.groupId == null) {
        // Линия разделения между заголовком и таблицей
        canvas.drawLine(
          Offset(nodeRect.left, nodeRect.top + headerHeight),
          Offset(nodeRect.right, nodeRect.top + headerHeight),
          headerBorderPaint,
        );
      }

      // Текст заголовка с ограничением по ширине
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
      );

      headerTextPainter.layout(
        maxWidth: nodeRect.width - 16,
      ); // Отступы по 8px с каждой стороны
      headerTextPainter.paint(
        canvas,
        Offset(
          nodeRect.left + 8,
          nodeRect.top + (headerHeight - headerTextPainter.height) / 2,
        ),
      );

      // Рисуем строки таблицы с атрибутами
      for (int i = 0; i < attributes.length; i++) {
        final attribute = attributes[i];
        final rowTop = nodeRect.top + headerHeight + actualRowHeight * i;
        final rowBottom = rowTop + actualRowHeight;

        // Разделяем строку на две колонки
        final columnSplit = tableNode.qType == 'enum'
            ? 20
            : nodeRect.width - 20;

        // Рисуем вертикальную границу между колонками
        canvas.drawLine(
          Offset(nodeRect.left + columnSplit, rowTop),
          Offset(nodeRect.left + columnSplit, rowBottom),
          headerBorderPaint,
        );

        // Рисуем горизонтальную границу между строками
        if (i < attributes.length - 1) {
          canvas.drawLine(
            Offset(nodeRect.left, rowBottom),
            Offset(nodeRect.right, rowBottom),
            headerBorderPaint,
          );
        }

        // Текст в левой колонке (label атрибута)
        final leftText = tableNode.qType == 'enum'
            ? attribute['position']
            : attribute['label'];
        if (leftText.isNotEmpty) {
          final leftTextPainter = TextPainter(
            text: TextSpan(
              text: leftText,
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
              ), // Черный текст на белом фоне
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLines: 1,
            ellipsis: '...',
          );
          leftTextPainter.layout(maxWidth: columnSplit - 16);
          leftTextPainter.paint(
            canvas,
            Offset(
              nodeRect.left + 8,
              rowTop + (actualRowHeight - leftTextPainter.height) / 2,
            ),
          );
        }

        // Текст в правой колонке (type атрибута)
        final rightText = tableNode.qType == 'enum' ? attribute['label'] : '';
        if (rightText.isNotEmpty) {
          final rightTextPainter = TextPainter(
            text: TextSpan(
              text: rightText,
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
              ), // Черный текст на белом фоне
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLines: 1,
            ellipsis: '...',
          );
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

      // Рисуем вложенные объекты
      if (children.isNotEmpty) {
      _drawTableNodes(canvas, children, tableNode.position + offset);
      }

      // Если узел выделен, рисуем выделяющую рамку
      if (tableNode.isSelected) {
        final selectionBorderPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        if (tableNode.groupId != null) {
          final selectionRect = Rect.fromLTWH(
            nodeRect.left - 2,
            nodeRect.top - 2,
            nodeRect.width + 4,
            nodeRect.height + 4,
          );
          canvas.drawRect(selectionRect, selectionBorderPaint);
        } else {
          final selectionRRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              nodeRect.left - 2,
              nodeRect.top - 2,
              nodeRect.width + 4,
              nodeRect.height + 4,
            ),
            Radius.circular(10),
          );
          canvas.drawRRect(selectionRRect, selectionBorderPaint);
        }
      }
    }
  }

  double _calculateMinHeight(TableNode node) {
    final headerHeight = 20.0; // Фиксированная высота заголовка
    final minRowHeight = 18.0; // Минимальная высота строки
    final totalRowsHeight = node.attributes.length * minRowHeight;

    return headerHeight + totalRowsHeight;
  }

  void _drawHierarchicalGrid(
    Canvas canvas,
    double visibleLeft,
    double visibleTop,
    double visibleRight,
    double visibleBottom,
  ) {
    // Базовый размер родительского квадрата (в мировых координатах)
    const double baseParentSize = 100.0;

    // Расширяем область отрисовки для плавного появления/исчезновения линий
    final double extendedLeft = visibleLeft - baseParentSize * 4;
    final double extendedTop = visibleTop - baseParentSize * 4;
    final double extendedRight = visibleRight + baseParentSize * 4;
    final double extendedBottom = visibleBottom + baseParentSize * 4;

    // Рисуем уровни сетки от -2 до 5
    for (int level = -2; level <= 5; level++) {
      double levelParentSize = baseParentSize * pow(4, level);
      _drawGridLevel(
        canvas,
        extendedLeft,
        extendedTop,
        extendedRight,
        extendedBottom,
        levelParentSize,
        level,
      );
    }
  }

  void _drawGridLevel(
    Canvas canvas,
    double left,
    double top,
    double right,
    double bottom,
    double parentSize,
    int level,
  ) {
    // Вычисляем прозрачность для текущего уровня
    double alpha = _calculateAlphaForLevel(level);

    // Если прозрачность 0, прекращаем отрисовку этого уровня
    if (alpha < 0.01) return;

    // Родительская сетка (светло-серая) - толщина линии компенсируется масштабом
    final Paint parentGridPaint = Paint()
      ..color = Color(0xFFE0E0E0).withOpacity(alpha)
      ..strokeWidth =
          1.0 / scale; // Компенсируем масштаб для постоянной толщины

    // Размер дочернего квадрата (4x4 внутри родительского)
    final double childSize = parentSize / 4;

    // Рисуем родительскую сетку
    _drawGridLines(
      canvas,
      left,
      top,
      right,
      bottom,
      parentSize,
      parentGridPaint,
    );

    // Рисуем дочернюю сетку (4x4 внутри каждого родительского квадрата)
    if (childSize > 2) {
      // Минимальный размер для отрисовки
      final double childAlpha = alpha * 0.8; // Дочерняя сетка светлее

      if (childAlpha > 0.01) {
        // Дочерняя сетка - толщина линии также компенсируется масштабом
        final Paint childGridPaint = Paint()
          ..color = Color(0xFFF0F0F0).withOpacity(childAlpha)
          ..strokeWidth =
              0.5 / scale; // Компенсируем масштаб для постоянной толщины

        _drawGridLines(
          canvas,
          left,
          top,
          right,
          bottom,
          childSize,
          childGridPaint,
        );
      }
    }
  }

  void _drawGridLines(
    Canvas canvas,
    double left,
    double top,
    double right,
    double bottom,
    double cellSize,
    Paint paint,
  ) {
    // Вертикальные линии
    double startX = (left / cellSize).floor() * cellSize;
    double endX = (right / cellSize).ceil() * cellSize;

    for (double x = startX; x <= endX; x += cellSize) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }

    // Горизонтальные линии
    double startY = (top / cellSize).floor() * cellSize;
    double endY = (bottom / cellSize).ceil() * cellSize;

    for (double y = startY; y <= endY; y += cellSize) {
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  double _calculateAlphaForLevel(int level) {
    // Идеальный масштаб для этого уровня
    // Уровень 0 идеален при scale=1.0, уровень 1 при scale=0.25, уровень -1 при scale=4.0
    double idealScale = 1.0 / pow(4, level);

    // Разница между текущим масштабом и идеальным в логарифмической шкале
    double logDifference = (log(scale) - log(idealScale)).abs();

    // Максимальная разница, при которой сетка еще видна
    double maxLogDifference = 2.0;

    // Вычисляем прозрачность: 1.0 когда scale = idealScale, 0.0 когда logDifference > maxLogDifference
    double alpha =
        (1.0 - (logDifference / maxLogDifference)).clamp(0.0, 1.0) * 0.8;
    return alpha;
  }

  @override
  bool shouldRepaint(covariant HierarchicalGridPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.canvasSize != canvasSize ||
        !_listEquals(oldDelegate.nodes, nodes);
  }

  bool _listEquals(List<TableNode> a, List<TableNode> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].position != b[i].position ||
          a[i].isSelected != b[i].isSelected ||
          a[i].text != b[i].text) {
        return false;
      }
    }
    return true;
  }
}
