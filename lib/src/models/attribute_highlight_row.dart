class AttributeHighlightRow {
  final dynamic node;
  final int rowIndex;
  final double currentNodeLeft;
  final double currentNodeWidth;
  final double rowTop;
  final double rowBottom;
  final double rowHeightScaled;
  final double leftCircleCenterX;
  final double rightCircleCenterX;
  final double circleCenterY;

  const AttributeHighlightRow({
    required this.node,
    required this.rowIndex,
    required this.currentNodeLeft,
    required this.currentNodeWidth,
    required this.rowTop,
    required this.rowBottom,
    required this.rowHeightScaled,
    required this.leftCircleCenterX,
    required this.rightCircleCenterX,
    required this.circleCenterY,
  });

  double get rowRight => currentNodeLeft + currentNodeWidth;
}
