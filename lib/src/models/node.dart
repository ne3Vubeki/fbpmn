// Модель узла
import 'dart:ui';

class Node {
  final String id;
  Offset position;
  Size size;
  String text;
  bool isSelected;
  Offset? aPosition;

  Node({
    required this.id,
    required this.position,
    this.size = const Size(100, 60),
    this.text = 'Node',
    this.isSelected = false,
    this.aPosition,
  });

  Node copyWith({Offset? position, String? text, bool? isSelected, Offset? aPosition}) {
    return Node(
      id: id,
      position: position ?? this.position,
      size: size,
      text: text ?? this.text,
      isSelected: isSelected ?? this.isSelected,
      aPosition: aPosition ?? this.aPosition,
    );
  }
}

