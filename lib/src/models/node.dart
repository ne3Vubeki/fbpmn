// Модель узла
import 'dart:ui';

import 'package:fbpmn/src/models/connections.dart';

class Node {
  final String id;
  String? parent;
  Offset position;
  Size size;
  String text;
  bool isSelected;
  Offset? aPosition;
  Connections? connections;

  Node({
    required this.id,
    required this.position,
    this.parent,
    this.size = const Size(100, 60),
    this.text = 'Node',
    this.isSelected = false,
    this.aPosition,
    this.connections,
  }) {
    connections = Connections();
  }

  Node copyWith({ String? parent, Offset? position, String? text, bool? isSelected, Offset? aPosition}) {
    return Node(
      id: id,
      parent: parent,
      position: position ?? this.position,
      size: size,
      text: text ?? this.text,
      isSelected: isSelected ?? this.isSelected,
      aPosition: aPosition ?? this.aPosition,
    );
  }
}

