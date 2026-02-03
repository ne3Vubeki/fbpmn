enum SnapLineType {
  horizontal,
  vertical,
}

class SnapLine {
  final SnapLineType type;
  final double position; // Y для horizontal, X для vertical (в экранных координатах)

  SnapLine({
    required this.type,
    required this.position,
  });
}
