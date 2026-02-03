import 'dart:ui';

class Connection {
  final String id;
  Offset pos;
  int? index;

  Connection({
    required this.id,
    required this.pos,
    this.index,
  });
}