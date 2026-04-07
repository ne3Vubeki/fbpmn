import 'package:fbpmn/src/micro_layout/models/layout_training_sample.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_snapshot.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_snapshot_metadata.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_weights.dart';

abstract class TrainingSampleRepository {
  Future<void> clearSamples();

  Future<void> saveSample(LayoutTrainingSample sample);

  Future<void> saveSamples(List<LayoutTrainingSample> samples);

  Future<List<LayoutTrainingSample>> getSamples();

  Future<List<LayoutTrainingSample>> getAcceptedSamples();

  Future<void> saveWeights(MicroLayoutWeights weights);

  Future<MicroLayoutWeights?> getWeights();

  Future<MicroLayoutSnapshotMetadata?> getSnapshotMetadata();

  Future<MicroLayoutSnapshot> exportSnapshot({
    required String buildVersion,
    required String modelVersion,
    String schemaVersion = '1',
  });

  Future<void> importSnapshot(
    MicroLayoutSnapshot snapshot, {
    bool mergeSamples = true,
    bool replaceWeights = true,
  });

  Future<void> clear();
}

class InMemoryTrainingSampleRepository implements TrainingSampleRepository {
  final List<LayoutTrainingSample> _samples = <LayoutTrainingSample>[];
  MicroLayoutWeights? _weights;
  MicroLayoutSnapshotMetadata? _metadata;

  bool _containsSample(String sampleId) {
    return _samples.any((sample) => sample.id == sampleId);
  }

  @override
  Future<void> clear() async {
    _samples.clear();
    _weights = null;
    _metadata = null;
  }

  @override
  Future<void> clearSamples() async {
    _samples.clear();
  }

  @override
  Future<List<LayoutTrainingSample>> getAcceptedSamples() async {
    return _samples.where((sample) => sample.accepted).toList(growable: false);
  }

  @override
  Future<List<LayoutTrainingSample>> getSamples() async {
    return List<LayoutTrainingSample>.unmodifiable(_samples);
  }

  @override
  Future<MicroLayoutWeights?> getWeights() async {
    return _weights;
  }

  @override
  Future<MicroLayoutSnapshotMetadata?> getSnapshotMetadata() async {
    return _metadata;
  }

  @override
  Future<MicroLayoutSnapshot> exportSnapshot({
    required String buildVersion,
    required String modelVersion,
    String schemaVersion = '1',
  }) async {
    final samples = await getSamples();
    final weights = await getWeights();

    final metadata = MicroLayoutSnapshotMetadata(
        schemaVersion: schemaVersion,
        modelVersion: modelVersion,
        buildVersion: buildVersion,
        exportedAt: DateTime.now(),
        sampleCount: samples.length,
        hasWeights: weights != null,
      );

    _metadata = metadata;

    return MicroLayoutSnapshot(
      metadata: metadata,
      samples: samples,
      weights: weights,
    );
  }

  @override
  Future<void> importSnapshot(
    MicroLayoutSnapshot snapshot, {
    bool mergeSamples = true,
    bool replaceWeights = true,
  }) async {
    if (!mergeSamples) {
      _samples.clear();
    }

    for (final sample in snapshot.samples) {
      if (!_containsSample(sample.id)) {
        _samples.add(sample);
      }
    }

    if (replaceWeights && snapshot.weights != null) {
      _weights = snapshot.weights;
    }

    _metadata = snapshot.metadata;
  }

  @override
  Future<void> saveSample(LayoutTrainingSample sample) async {
    if (_containsSample(sample.id)) {
      return;
    }
    _samples.add(sample);
  }

  @override
  Future<void> saveSamples(List<LayoutTrainingSample> samples) async {
    for (final sample in samples) {
      if (_containsSample(sample.id)) {
        continue;
      }
      _samples.add(sample);
    }
  }

  @override
  Future<void> saveWeights(MicroLayoutWeights weights) async {
    _weights = weights;
  }
}
