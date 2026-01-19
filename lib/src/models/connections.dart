import 'package:fbpmn/src/models/connection.dart';

class Connections {
  List<Connection?> top;
  List<Connection?> right;
  List<Connection?> bottom;
  List<Connection?> left;

  Connections({
    this.top = const [],
    this.right = const [],
    this.bottom = const [],
    this.left = const [],
  });
}