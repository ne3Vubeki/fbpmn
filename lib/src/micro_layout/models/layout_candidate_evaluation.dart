import 'layout_candidate.dart';
import 'layout_quality_metrics.dart';

class LayoutCandidateEvaluation {
  final LayoutCandidate candidate;
  final LayoutQualityMetrics metrics;
  final double exactScore;
  final double predictedScore;
  final bool accepted;

  const LayoutCandidateEvaluation({
    required this.candidate,
    required this.metrics,
    required this.exactScore,
    this.predictedScore = 0,
    this.accepted = false,
  });
}
