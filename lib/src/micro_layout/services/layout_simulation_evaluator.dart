import 'package:fbpmn/src/micro_layout/models/layout_candidate.dart';
import 'package:fbpmn/src/micro_layout/models/layout_candidate_evaluation.dart';
import 'package:fbpmn/src/micro_layout/models/layout_search_request.dart';

abstract class LayoutSimulationEvaluator {
  Future<LayoutCandidateEvaluation> evaluate({
    required LayoutSearchRequest request,
    required LayoutCandidate candidate,
    double predictedScore = 0,
  });
}
