import 'layout_candidate.dart';
import 'layout_candidate_evaluation.dart';

class LayoutSearchResult {
  final LayoutCandidate? bestCandidate;
  final List<LayoutCandidate> generatedCandidates;
  final List<LayoutCandidateEvaluation> evaluatedCandidates;

  const LayoutSearchResult({
    required this.bestCandidate,
    this.generatedCandidates = const <LayoutCandidate>[],
    this.evaluatedCandidates = const <LayoutCandidateEvaluation>[],
  });

  bool get hasCandidate => bestCandidate != null;
}
