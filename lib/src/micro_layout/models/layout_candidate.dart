import 'dart:ui';

class LayoutCandidate {
  final String nodeId;
  final Offset originPosition;
  final Offset candidatePosition;
  final Size nodeSize;
  final String tileId;
  final double heuristicScore;

  const LayoutCandidate({
    required this.nodeId,
    required this.originPosition,
    required this.candidatePosition,
    required this.nodeSize,
    required this.tileId,
    this.heuristicScore = 0,
  });

  Offset get delta => candidatePosition - originPosition;

  Rect get candidateRect => candidatePosition & nodeSize;

  double get movementDistance => delta.distance;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'nodeId': nodeId,
      'originX': originPosition.dx,
      'originY': originPosition.dy,
      'candidateX': candidatePosition.dx,
      'candidateY': candidatePosition.dy,
      'width': nodeSize.width,
      'height': nodeSize.height,
      'tileId': tileId,
      'heuristicScore': heuristicScore,
    };
  }

  factory LayoutCandidate.fromJson(Map<String, dynamic> json) {
    return LayoutCandidate(
      nodeId: json['nodeId'] as String,
      originPosition: Offset(
        (json['originX'] as num).toDouble(),
        (json['originY'] as num).toDouble(),
      ),
      candidatePosition: Offset(
        (json['candidateX'] as num).toDouble(),
        (json['candidateY'] as num).toDouble(),
      ),
      nodeSize: Size(
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      ),
      tileId: json['tileId'] as String,
      heuristicScore: (json['heuristicScore'] as num?)?.toDouble() ?? 0,
    );
  }
}
