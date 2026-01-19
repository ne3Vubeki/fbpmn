import 'dart:ui';

// Класс для хранения тайлов изображения
class ImageTile {
  final Image image;
  final Rect bounds; // Границы тайла в мировых координатах
  final double scale; // Масштаб тайла
  final String id; // id тайла
  Set<String?> nodes; // Список id узлов в тайле
  Set<String?> arrows; // Список id связей в тайле
  
  ImageTile({
    required this.image,
    required this.bounds,
    required this.scale,
    required this.id,
    this.nodes = const {},
    this.arrows = const {},
  });
}

