// Модель табличного узла
import 'package:flutter/material.dart';

import 'node.dart';

class TableNode extends Node {
  final Map<String, dynamic> objectData;
  final List<Map<String, dynamic>> attributes;
  final String style;
  final Color borderColor;
  final Color backgroundColor;

  TableNode({
    required super.id,
    required super.position,
    required super.size,
    required super.text,
    required this.objectData,
    required this.attributes,
    required this.style,
    required this.borderColor,
    required this.backgroundColor,
    super.isSelected,
  });

  factory TableNode.fromJson(Map<String, dynamic> object) {
    final geometry = object['geometry'] as Map<String, dynamic>;
    final style = object['style'] as String? ?? '';
    final attributes = (object['attributes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    
    final x = (geometry['x'] as num).toDouble();
    final y = (geometry['y'] as num).toDouble();
    final width = (geometry['width'] as num).toDouble();
    final height = (geometry['height'] as num).toDouble();

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
      } catch (e) {
        print('Error parsing $property: $e');
      }
      return Colors.black;
    }

    return TableNode(
      id: object['id'] as String,
      position: Offset(x, y),
      size: Size(width, height),
      text: object['label'] as String? ?? '',
      objectData: object,
      attributes: attributes,
      style: style,
      borderColor: parseColor(style, 'fillColor'),
      backgroundColor: parseColor(style, 'fillColor'),
    );
  }

  TableNode copyWithTable({
    Offset? position,
    String? text,
    bool? isSelected,
    Map<String, dynamic>? objectData,
  }) {
    return TableNode(
      id: id,
      position: position ?? this.position,
      size: size,
      text: text ?? this.text,
      objectData: objectData ?? this.objectData,
      attributes: attributes,
      style: style,
      borderColor: borderColor,
      backgroundColor: backgroundColor,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}