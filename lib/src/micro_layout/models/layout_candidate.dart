import 'dart:ui';

class LayoutCandidate {
  final Offset originPosition;
  final Offset candidatePosition;
  final Size nodeSize;
  final double heuristicScore;

  const LayoutCandidate({
    required this.originPosition,
    required this.candidatePosition,
    required this.nodeSize,
    this.heuristicScore = 0,
  });

  Offset get delta => candidatePosition - originPosition;

  Rect get candidateRect => candidatePosition & nodeSize;

  double get movementDistance => delta.distance;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'originX': originPosition.dx,
      'originY': originPosition.dy,
      'candidateX': candidatePosition.dx,
      'candidateY': candidatePosition.dy,
      'width': nodeSize.width,
      'height': nodeSize.height,
      'heuristicScore': heuristicScore,
    };
  }

  factory LayoutCandidate.fromJson(Map<String, dynamic> json) {
    return LayoutCandidate(
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
      heuristicScore: (json['heuristicScore'] as num?)?.toDouble() ?? 0,
    );
  }
}
