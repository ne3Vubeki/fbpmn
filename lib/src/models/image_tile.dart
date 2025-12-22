import 'dart:ui';

class ImageTile {
  final Image image;
  final Rect bounds; // Границы тайла в мировых координатах
  final double scale; // Масштаб тайла
  
  ImageTile({
    required this.image,
    required this.bounds,
    required this.scale,
  });
}