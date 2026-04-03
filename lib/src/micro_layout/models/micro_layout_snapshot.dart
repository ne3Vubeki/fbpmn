import 'layout_training_sample.dart';
import 'micro_layout_snapshot_metadata.dart';
import 'micro_layout_weights.dart';

class MicroLayoutSnapshot {
  final MicroLayoutSnapshotMetadata metadata;
  final List<LayoutTrainingSample> samples;
  final MicroLayoutWeights? weights;

  const MicroLayoutSnapshot({
    required this.metadata,
    this.samples = const <LayoutTrainingSample>[],
    this.weights,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'metadata': metadata.toJson(),
      'samples': samples.map((sample) => sample.toJson()).toList(growable: false),
      'weights': weights?.toJson(),
    };
  }

  factory MicroLayoutSnapshot.fromJson(Map<String, dynamic> json) {
    return MicroLayoutSnapshot(
      metadata: MicroLayoutSnapshotMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      samples: (json['samples'] as List<dynamic>? ?? const <dynamic>[])
          .map((sample) => LayoutTrainingSample.fromJson(sample as Map<String, dynamic>))
          .toList(growable: false),
      weights: json['weights'] == null ? null : MicroLayoutWeights.fromJson(json['weights'] as Map<String, dynamic>),
    );
  }
}
