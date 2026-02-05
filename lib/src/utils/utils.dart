import 'dart:ui';

import '../editor_state.dart';

class Utils {
    // Метод для получения экранных координат из мировых
  static Offset worldToScreen(Offset worldPosition, EditorState state) {
    return worldPosition * state.scale + state.offset;
  }

  // Метод для получения мировых координат из экранных
  static Offset screenToWorld(Offset screenPosition, EditorState state) {
    return (screenPosition - state.offset) / state.scale;
  }

}