import 'dart:ui';

import 'arrow.dart';
import 'table.node.dart';

// Класс для хранения тайлов изображения
class ImageTile {
  final Image image;
  final Rect bounds; // Границы тайла в мировых координатах
  final double scale; // Масштаб тайла
  final String id; // id тайла
  List<TableNode> nodes = [];
  List<Arrow> arrows = [];
  
  ImageTile({
    required this.image,
    required this.bounds,
    required this.scale,
    required this.id,
  });
}

