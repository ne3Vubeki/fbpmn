import 'dart:ui';

class LayoutContextSnapshot {
  final Rect bounds;
  final Rect sourceBounds;
  final double occupancyRatio;
  final double freeAreaRatio;
  final double localNodeDensity;
  final double contextWidth;
  final double contextHeight;

  const LayoutContextSnapshot({
    required this.bounds,
    required this.sourceBounds,
    this.occupancyRatio = 0,
    this.freeAreaRatio = 0,
    this.localNodeDensity = 0,
    this.contextWidth = 0,
    this.contextHeight = 0,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'left': bounds.left,
      'top': bounds.top,
      'right': bounds.right,
      'bottom': bounds.bottom,
      'sourceLeft': sourceBounds.left,
      'sourceTop': sourceBounds.top,
      'sourceRight': sourceBounds.right,
      'sourceBottom': sourceBounds.bottom,
      'occupancyRatio': occupancyRatio,
      'freeAreaRatio': freeAreaRatio,
      'localNodeDensity': localNodeDensity,
      'contextWidth': contextWidth,
      'contextHeight': contextHeight,
    };
  }

  factory LayoutContextSnapshot.fromJson(Map<String, dynamic> json) {
    final bounds = Rect.fromLTRB(
      (json['left'] as num).toDouble(),
      (json['top'] as num).toDouble(),
      (json['right'] as num).toDouble(),
      (json['bottom'] as num).toDouble(),
    );
    return LayoutContextSnapshot(
      bounds: bounds,
      sourceBounds: Rect.fromLTRB(
        (json['sourceLeft'] as num).toDouble(),
        (json['sourceTop'] as num).toDouble(),
        (json['sourceRight'] as num).toDouble(),
        (json['sourceBottom'] as num).toDouble(),
      ),
      occupancyRatio: (json['occupancyRatio'] as num).toDouble(),
      freeAreaRatio: (json['freeAreaRatio'] as num).toDouble(),
      localNodeDensity: (json['localNodeDensity'] as num).toDouble(),
      contextWidth: (json['contextWidth'] as num).toDouble(),
      contextHeight: (json['contextHeight'] as num).toDouble(),
    );
  }
}
