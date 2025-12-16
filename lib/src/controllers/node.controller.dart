import 'dart:ui';

import 'package:get/get.dart';

class Node extends GetxController {
  final String id;
  final Rx<Offset> _position;
  final Size size;
  final RxString text;
  final RxBool _isSelected;

  Node({
    required this.id,
    required Offset position,
    this.size = const Size(100, 60),
    String text = 'Node',
    bool isSelected = false,
  })  : _position = position.obs,
        text = text.obs,
        _isSelected = isSelected.obs;

  Offset get position => _position.value;
  set position(Offset newPosition) => _position.value = newPosition;

  bool get isSelected => _isSelected.value;
  set isSelected(bool selected) => _isSelected.value = selected;

  Node copyWith({Offset? position, String? text, bool? isSelected}) {
    return Node(
      id: id,
      position: position ?? this.position,
      text: text ?? this.text.value,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  void onClose() {
    _position.close();
    text.close();
    _isSelected.close();
    super.onClose();
  }
}
