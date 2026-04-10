import 'layout_candidate.dart';
import 'layout_context_snapshot.dart';
import 'layout_feature_vector.dart';
import 'layout_quality_metrics.dart';
import 'layout_training_context.dart';

class LayoutTrainingSample {
  final LayoutCandidate candidate;
  final LayoutFeatureVector features;
  final LayoutQualityMetrics metrics;
  final LayoutContextSnapshot contextSnapshot;
  final double targetScore;
  final bool accepted;
  final DateTime createdAt;
  final LayoutTrainingContext? trainingContext;

  const LayoutTrainingSample({
    required this.candidate,
    required this.features,
    required this.metrics,
    required this.contextSnapshot,
    required this.targetScore,
    required this.accepted,
    required this.createdAt,
    this.trainingContext,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'candidate': candidate.toJson(),
      'features': features.toJson(),
      'metrics': metrics.toJson(),
      'snapshot': contextSnapshot.toJson(),
      'targetScore': targetScore,
      'accepted': accepted,
      'createdAt': createdAt.toIso8601String(),
      'trainingContext': trainingContext?.toJson(),
    };
  }

  factory LayoutTrainingSample.fromJson(Map<String, dynamic> json) {
    return LayoutTrainingSample(
      candidate: LayoutCandidate.fromJson(json['candidate'] as Map<String, dynamic>),
      features: LayoutFeatureVector.fromJson(json['features'] as Map<String, dynamic>),
      metrics: LayoutQualityMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      contextSnapshot: LayoutContextSnapshot.fromJson(json['snapshot'] as Map<String, dynamic>),
      targetScore: (json['targetScore'] as num).toDouble(),
      accepted: json['accepted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      trainingContext: json['trainingContext'] == null
          ? null
          : LayoutTrainingContext.fromJson(json['trainingContext'] as Map<String, dynamic>),
    );
  }
}
