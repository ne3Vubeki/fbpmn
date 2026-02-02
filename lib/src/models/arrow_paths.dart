import 'dart:ui';

class ArrowPaths {
  final Path path;
  final Path? startArrow;
  final Path? endArrow;

  ArrowPaths({
    required this.path,
    this.startArrow,
    this.endArrow,
  });
}