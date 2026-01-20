// Модель табличного узла
import 'package:flutter/material.dart';

import 'node.dart';

class TableNode extends Node {
  final String? groupId;
  final Map<String, dynamic> objectData;
  final List<Map<String, dynamic>> attributes;
  final List<TableNode>? children;
  final String qType;
  final String style;
  final Color borderColor;
  final Color backgroundColor;
  final bool? isCollapsed;

  TableNode({
    required super.id,
    required super.position,
    required super.size,
    required super.text,
    required this.objectData,
    required this.attributes,
    required this.qType,
    required this.style,
    required this.borderColor,
    required this.backgroundColor,
    super.isSelected,
    super.aPosition,
    super.parent,
    super.connections,
    this.groupId,
    this.children,
    this.isCollapsed,
  });

  factory TableNode.fromJson(Map<String, dynamic> object, [String? parent]) {
    final id = object['id'] as String;
    final geometry = object['geometry'] as Map<String, dynamic>;
    final style = object['style'] as String? ?? '';
    final attributes = (object['attributes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final children = (object['children'] as List<dynamic>? ?? [])
        .map<TableNode>((object) => TableNode.fromJson(object, id))
        .toList();

    // Извлекаем свойство collapsed
    final isCollapsed = object['collapsed'] == '1';

    final x = (geometry['x'] as num).toDouble();
    final y = (geometry['y'] as num).toDouble();
    final width = (geometry['width'] as num).toDouble();
    final height = (geometry['height'] as num).toDouble();

    // Функция parseColor остается без изменений
    Color parseColor(String styleStr, String property) {
      try {
        final regex = RegExp('$property=([^;]+)');
        final match = regex.firstMatch(styleStr);
        if (match != null) {
          final colorStr = match.group(1);
          if (colorStr == '0' || colorStr == 'none') {
            return Colors.transparent;
          }
          if (colorStr!.startsWith('#')) {
            return Color(
              int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
            );
          }
        }
      } catch (e) {}
      return Colors.black;
    }

    final node = TableNode(
      id: id,
      groupId: object['groupId'] as String?,
      position: Offset(x, y),
      size: Size(width, height),
      text: object['label'] as String? ?? '',
      objectData: object,
      attributes: attributes,
      children: children,
      qType: object['qType'] ?? 'None',
      style: style,
      borderColor: parseColor(style, 'fillColor'),
      backgroundColor: parseColor(style, 'fillColor'),
      isCollapsed: isCollapsed,
    );
    
    // Если это вложенный узел, добавляем parent родителя
    if(parent != null) {
      node.parent = parent;
    }
    return node;
  }

  // Метод для инициализации абсолютных позиций после создания узла
  void initializeAbsolutePositions(Offset parentPosition) {
    calculateAbsolutePositions(parentPosition);
  }

  TableNode copyWithTable({
    Offset? position,
    String? text,
    bool? isSelected,
    Map<String, dynamic>? objectData,
    bool? isCollapsed,
  }) {
    return TableNode(
      id: id,
      groupId: groupId,
      position: position ?? this.position,
      size: size,
      text: text ?? this.text,
      objectData: objectData ?? this.objectData,
      attributes: attributes,
      children: children,
      qType: qType,
      style: style,
      borderColor: borderColor,
      backgroundColor: backgroundColor,
      isSelected: isSelected ?? this.isSelected,
      isCollapsed: isCollapsed ?? this.isCollapsed, // Копируем состояние
      aPosition: aPosition, // Сохраняем абсолютную позицию
    );
  }

  // Добавляем метод для переключения состояния collapsed
  TableNode toggleCollapsed() {
    return copyWithTable(isCollapsed: !(isCollapsed ?? false));
  }

  // Метод для вычисления абсолютных позиций рекурсивно
  void calculateAbsolutePositions([Offset parentPosition = Offset.zero]) {
    // Абсолютная позиция текущего узла - это позиция родителя + собственная позиция
    aPosition = parentPosition + position;
    
    // Если есть дети, вычисляем их абсолютные позиции
    if (children != null) {
      for (final child in children!) {
        child.calculateAbsolutePositions(aPosition!);
      }
    }
  }
}
