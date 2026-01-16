import 'dart:ui';

// Класс для хранения тайлов изображения
class ImageTile {
  final Image image;
  final Rect bounds; // Границы тайла в мировых координатах
  final double scale; // Масштаб тайла
  final String id; // id тайла
  List<String> nodes = [];
  List<String> arrows = [];
  
  ImageTile({
    required this.image,
    required this.bounds,
    required this.scale,
    required this.id,
  });
}

