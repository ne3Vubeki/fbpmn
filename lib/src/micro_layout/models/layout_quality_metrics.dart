class LayoutQualityMetrics {
  final double edgeCrossings;
  final double nodeOverlaps;
  final double edgeNodeIntersections;
  final double totalIncidentEdgeLength;
  final double movementDistance;
  final double spacingScore;
  final double alignmentScore;

  const LayoutQualityMetrics({
    this.edgeCrossings = 0,
    this.nodeOverlaps = 0,
    this.edgeNodeIntersections = 0,
    this.totalIncidentEdgeLength = 0,
    this.movementDistance = 0,
    this.spacingScore = 0,
    this.alignmentScore = 0,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'edgeCrossings': edgeCrossings,
      'nodeOverlaps': nodeOverlaps,
      'edgeNodeIntersections': edgeNodeIntersections,
      'totalIncidentEdgeLength': totalIncidentEdgeLength,
      'movementDistance': movementDistance,
      'spacingScore': spacingScore,
      'alignmentScore': alignmentScore,
    };
  }

  factory LayoutQualityMetrics.fromJson(Map<String, dynamic> json) {
    return LayoutQualityMetrics(
      edgeCrossings: (json['edgeCrossings'] as num?)?.toDouble() ?? 0,
      nodeOverlaps: (json['nodeOverlaps'] as num?)?.toDouble() ?? 0,
      edgeNodeIntersections: (json['edgeNodeIntersections'] as num?)?.toDouble() ?? 0,
      totalIncidentEdgeLength: (json['totalIncidentEdgeLength'] as num?)?.toDouble() ?? 0,
      movementDistance: (json['movementDistance'] as num?)?.toDouble() ?? 0,
      spacingScore: (json['spacingScore'] as num?)?.toDouble() ?? 0,
      alignmentScore: (json['alignmentScore'] as num?)?.toDouble() ?? 0,
    );
  }
}
