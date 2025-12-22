import 'package:flutter/material.dart';

class NodeVectorData {
  final String id;
  final Rect bounds;
  final Color backgroundColor;
  final Color headerBackgroundColor;
  final String headerText;
  final Color headerTextColor;
  final Rect headerRect;
  final bool isGroup;
  final List<dynamic> attributes;
  final String qType;
  final double actualRowHeight;
  final double headerHeight;
  final bool isSelected;
  final Offset position;
  List<NodeVectorData>? children;

  NodeVectorData({
    required this.id,
    required this.bounds,
    required this.backgroundColor,
    required this.headerBackgroundColor,
    required this.headerText,
    required this.headerTextColor,
    required this.headerRect,
    required this.isGroup,
    required this.attributes,
    required this.qType,
    required this.actualRowHeight,
    required this.headerHeight,
    required this.isSelected,
    required this.position,
    this.children,
  });

  // Проверка видимости
  bool isVisible(Rect visibleRect) {
    return bounds.overlaps(visibleRect);
  }

 // Упрощенная отрисовка для очень маленького зума
  bool shouldDrawSimplified(double scale) {
    return scale < 0.15; // Более низкий порог
  }

  // Нужно ли рисовать текст
  bool shouldDrawText(double scale) {
    return scale > 0.2; // Более низкий порог
  }

  // Нужно ли рисовать детали ячеек
  bool shouldDrawCellDetails(double scale) {
    return scale > 0.3; // Более низкий порог
  }
}