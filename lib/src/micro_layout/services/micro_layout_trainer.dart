import 'package:fbpmn/src/micro_layout/models/layout_training_sample.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_training_batch.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_weights.dart';
import 'package:fbpmn/src/micro_layout/services/indexed_db_training_sample_repository.dart';
import 'package:fbpmn/src/micro_layout/services/micro_layout_model.dart';
import 'package:fbpmn/src/micro_layout/services/training_sample_repository.dart';

class MicroLayoutTrainer {
  final TrainingSampleRepository repository;
  final MicroLayoutModel model;

  const MicroLayoutTrainer({
    required this.repository,
    required this.model,
  });

  factory MicroLayoutTrainer.withIndexedDb({
    required MicroLayoutModel model,
  }) {
    return MicroLayoutTrainer(
      repository: IndexedDbTrainingSampleRepository.createDefault(),
      model: model,
    );
  }

  Future<double> train({
    int epochs = 10,
    double learningRate = 0.0005,
    bool acceptedOnly = false,
  }) async {
    final samples = acceptedOnly ? await repository.getAcceptedSamples() : await repository.getSamples();
    if (samples.isEmpty) {
      return 0;
    }

    final batch = _createBatch(samples);
    var lastLoss = 0.0;

    for (var epoch = 0; epoch < epochs; epoch++) {
      lastLoss = model.trainBatch(batch, learningRate: learningRate);
    }

    return lastLoss;
  }

  Future<void> saveWeights({int version = 1}) async {
    final weights = model.exportWeights(version: version);
    await repository.saveWeights(weights);
  }

  Future<MicroLayoutWeights?> loadWeights() {
    return repository.getWeights();
  }

  MicroLayoutTrainingBatch _createBatch(List<LayoutTrainingSample> samples) {
    return MicroLayoutTrainingBatch(
      features: samples.map((sample) => sample.features).toList(growable: false),
      targets: samples.map((sample) => sample.targetScore).toList(growable: false),
    );
  }
}
