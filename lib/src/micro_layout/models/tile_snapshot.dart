import 'dart:ui';

class TileSnapshot {
  final String tileId;
  final Rect bounds;
  final List<String> nodeIds;
  final List<String> arrowIds;
  final double occupancyRatio;
  final double freeAreaRatio;
  final double localNodeDensity;

  const TileSnapshot({
    required this.tileId,
    required this.bounds,
    this.nodeIds = const <String>[],
    this.arrowIds = const <String>[],
    this.occupancyRatio = 0,
    this.freeAreaRatio = 0,
    this.localNodeDensity = 0,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tileId': tileId,
      'left': bounds.left,
      'top': bounds.top,
      'right': bounds.right,
      'bottom': bounds.bottom,
      'nodeIds': nodeIds,
      'arrowIds': arrowIds,
      'occupancyRatio': occupancyRatio,
      'freeAreaRatio': freeAreaRatio,
      'localNodeDensity': localNodeDensity,
    };
  }

  factory TileSnapshot.fromJson(Map<String, dynamic> json) {
    return TileSnapshot(
      tileId: json['tileId'] as String,
      bounds: Rect.fromLTRB(
        (json['left'] as num).toDouble(),
        (json['top'] as num).toDouble(),
        (json['right'] as num).toDouble(),
        (json['bottom'] as num).toDouble(),
      ),
      nodeIds: (json['nodeIds'] as List<dynamic>? ?? const <dynamic>[]).map((value) => value.toString()).toList(growable: false),
      arrowIds: (json['arrowIds'] as List<dynamic>? ?? const <dynamic>[]).map((value) => value.toString()).toList(growable: false),
      occupancyRatio: (json['occupancyRatio'] as num?)?.toDouble() ?? 0,
      freeAreaRatio: (json['freeAreaRatio'] as num?)?.toDouble() ?? 0,
      localNodeDensity: (json['localNodeDensity'] as num?)?.toDouble() ?? 0,
    );
  }
}
