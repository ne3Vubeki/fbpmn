// Модель табличного узла
import 'dart:async';
import 'package:flutter/material.dart';

import '../utils/editor_config.dart';
import 'attribute.dart';
import 'node.dart';

class TableNode extends Node {
  final Map<String, dynamic> objectData;
  final List<Attribute> attributes;
  final List<TableNode>? children;
  final String qType;
  final String? qCompStatus;
  final String style;
  final Color borderColor;
  final Color backgroundColor;
  final bool? isCollapsed;

  String? tooltip;
  StreamSubscription<void>? _connectionsSubscription;

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
    this.qCompStatus,
    super.isSelected,
    super.isChanged,
    super.aPosition,
    super.parent,
    super.connections,
    this.children,
    this.isCollapsed,
  }) {
    initConnectionsListener();
  }

  factory TableNode.fromJson(Map<String, dynamic> object, [String? parent]) {
    final id = object['id'] as String;
    final geometry = object['geometry'] as Map<String, dynamic>;
    final style = object['style'] as String? ?? '';

    final x = (geometry['x'] as num).toDouble();
    final y = (geometry['y'] as num).toDouble();
    final width = (geometry['width'] as num).toDouble();
    double height = (geometry['height'] as num).toDouble();

    final attributes = (object['attributes'] as List<dynamic>? ?? [])
        .asMap()
        .entries
        .map<Attribute>((entry) {
          final index = entry.key;
          final attr = entry.value;
          final attribute = Attribute.fromJson(attr as Map<String, dynamic>);

          if (attribute.position == Offset.zero && attribute.size == Size.zero) {
            attribute.position = Offset(0, EditorConfig.headerHeight + EditorConfig.minRowHeight * index);
            attribute.size = Size(width, EditorConfig.minRowHeight);
          }

          return attribute;
        })
        .toList();
    final children = (object['children'] as List<dynamic>? ?? [])
        .map<TableNode>((object) => TableNode.fromJson(object, id))
        .toList();
    final tooltip = object['tooltip'] as String?;

    // Извлекаем свойство collapsed
    final isCollapsed = object['collapsed'] == '1';

    if (height < EditorConfig.headerHeight) {
      height = EditorConfig.headerHeight;
    }

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
            return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
          }
        }
      } catch (e) {}
      return Colors.black;
    }

    final node = TableNode(
      id: id,
      position: Offset(x, y),
      size: Size(width, height),
      text: object['label'] as String? ?? '',
      objectData: object,
      attributes: attributes,
      children: children,
      qType: object['qType'] ?? 'None',
      qCompStatus: object['qCompStatus'] as String?,
      style: style,
      borderColor: parseColor(style, 'fillColor'),
      backgroundColor: parseColor(style, 'fillColor'),
      isCollapsed: isCollapsed,
    );

    if (tooltip != null) {
      node.tooltip = tooltip;
    }

    // Если это вложенный узел, добавляем parent родителя
    if (parent != null) {
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

  // Метод для инициализации слушателя изменений коннекторов
  void initConnectionsListener() {
    if (connections != null) {
      _connectionsSubscription = connections!.changesStream.listen((event) {
        isChanged = true;
        // print('connections changed: $event');
      });
    }
  }

  // Метод для отмены подписки и очистки ресурсов
  void dispose() {
    _connectionsSubscription?.cancel();
    _connectionsSubscription = null;
    
    // Рекурсивно очищаем дочерние узлы
    if (children != null) {
      for (final child in children!) {
        child.dispose();
      }
      children!.clear();
    }
    
    // Очищаем атрибуты
    attributes.clear();
    
    // Очищаем и закрываем connections (включая StreamController)
    connections?.dispose();
    connections = null;
  }
}
