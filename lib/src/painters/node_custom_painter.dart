import 'package:flutter/material.dart';
import '../models/table.node.dart';
import 'node_painter.dart' as node_painter_lib;

/// Адаптер для использования NodePainter как CustomPainter
class NodeCustomPainter extends CustomPainter {
  final TableNode node;
  final bool isSelected;
  final Size targetSize;
  final double scale; // Масштаб всего виджета
  
  NodeCustomPainter({
    required this.node,
    required this.isSelected,
    required this.targetSize,
    required this.scale,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Рассчитываем масштаб для содержимого узла
    final contentScaleX = targetSize.width / node.size.width;
    final contentScaleY = targetSize.height / node.size.height;
    
    // 2. Рисуем основной узел
    final painter = node_painter_lib.NodePainter(node: node);
    
    canvas.save();
    canvas.scale(contentScaleX, contentScaleY);
    
    final rect = Rect.fromLTWH(0, 0, node.size.width, node.size.height);
    painter.paint(canvas, rect, forTile: false);
    
    canvas.restore();
    
    // 3. Рисуем детей, если они есть
    if (node.children != null && node.children!.isNotEmpty) {
      for (final child in node.children!) {
        canvas.save();
        
        // Позиция ребенка относительно родителя (уже масштабированная под contentScale)
        final childLeft = child.position.dx * contentScaleX;
        final childTop = child.position.dy * contentScaleY;
        
        canvas.translate(childLeft, childTop);
        
        // Размеры ребенка (масштабированные под contentScale)
        final childWidth = child.size.width * contentScaleX;
        final childHeight = child.size.height * contentScaleY;
        
        // Создаем отдельный painter для ребенка
        final childPainter = node_painter_lib.NodePainter(node: child);
        
        // Масштабируем canvas для ребенка
        final childContentScaleX = childWidth / child.size.width;
        final childContentScaleY = childHeight / child.size.height;
        
        canvas.scale(childContentScaleX, childContentScaleY);
        
        // Рисуем ребенка
        final childRect = Rect.fromLTWH(0, 0, child.size.width, child.size.height);
        childPainter.paint(canvas, childRect, forTile: false);
        
        canvas.restore();
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant NodeCustomPainter oldDelegate) {
    return oldDelegate.node != node ||
           oldDelegate.isSelected != isSelected ||
           oldDelegate.targetSize != targetSize ||
           oldDelegate.scale != scale;
  }
}