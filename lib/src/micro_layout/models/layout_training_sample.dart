import 'layout_candidate.dart';
import 'layout_feature_vector.dart';
import 'layout_quality_metrics.dart';
import 'tile_snapshot.dart';

class LayoutTrainingSample {
  final String id;
  final String nodeId;
  final String tileId;
  final LayoutCandidate candidate;
  final LayoutFeatureVector features;
  final LayoutQualityMetrics metrics;
  final TileSnapshot snapshot;
  final double targetScore;
  final bool accepted;
  final DateTime createdAt;

  const LayoutTrainingSample({
    required this.id,
    required this.nodeId,
    required this.tileId,
    required this.candidate,
    required this.features,
    required this.metrics,
    required this.snapshot,
    required this.targetScore,
    required this.accepted,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'nodeId': nodeId,
      'tileId': tileId,
      'candidate': candidate.toJson(),
      'features': features.toJson(),
      'metrics': metrics.toJson(),
      'snapshot': snapshot.toJson(),
      'targetScore': targetScore,
      'accepted': accepted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LayoutTrainingSample.fromJson(Map<String, dynamic> json) {
    return LayoutTrainingSample(
      id: json['id'] as String,
      nodeId: json['nodeId'] as String,
      tileId: json['tileId'] as String,
      candidate: LayoutCandidate.fromJson(json['candidate'] as Map<String, dynamic>),
      features: LayoutFeatureVector.fromJson(json['features'] as Map<String, dynamic>),
      metrics: LayoutQualityMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      snapshot: TileSnapshot.fromJson(json['snapshot'] as Map<String, dynamic>),
      targetScore: (json['targetScore'] as num).toDouble(),
      accepted: json['accepted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
