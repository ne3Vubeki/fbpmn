import 'layout_feature_vector.dart';

class MicroLayoutTrainingBatch {
  final List<LayoutFeatureVector> features;
  final List<double> targets;

  const MicroLayoutTrainingBatch({
    required this.features,
    required this.targets,
  }) : assert(features.length == targets.length, 'features and targets must have equal length');

  bool get isEmpty => features.isEmpty;

  int get length => features.length;
}
