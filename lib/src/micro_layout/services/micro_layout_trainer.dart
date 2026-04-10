import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/micro_layout/models/layout_training_sample.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_training_batch.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_weights.dart';
import 'package:fbpmn/src/micro_layout/services/candidate_feature_extractor.dart';
import 'package:fbpmn/src/micro_layout/services/indexed_db_training_sample_repository.dart';
import 'package:fbpmn/src/micro_layout/services/micro_layout_model.dart';
import 'package:fbpmn/src/micro_layout/services/training_sample_repository.dart';
import 'package:fbpmn/src/models/app.model.dart';
import 'package:fbpmn/src/services/tile_manager.dart';

class MicroLayoutTrainingProgress {
  final int currentEpoch;
  final int totalEpochs;
  final double loss;
  final int sampleCount;

  const MicroLayoutTrainingProgress({
    required this.currentEpoch,
    required this.totalEpochs,
    required this.loss,
    required this.sampleCount,
  });

  double get progressPercent {
    if (totalEpochs <= 0) {
      return 0;
    }
    return (currentEpoch / totalEpochs) * 100;
  }
}

class MicroLayoutTrainingResult {
  final int sampleCount;
  final int epochs;
  final double loss;

  const MicroLayoutTrainingResult({
    required this.sampleCount,
    required this.epochs,
    required this.loss,
  });
}

class MicroLayoutTrainer {
  static const int _defaultMicroLayoutInputSize = CandidateFeatureExtractor.featureCount;
  static bool _isTraining = false;

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

  static Future<void> startTrainingProcess({
    required EditorState state,
    required TileManager tileManager,
    required EventApp? appEvent,
    Map<String, dynamic>? data,
  }) async {
    if (_isTraining) {
      appEvent?.emitToJs(
        action: 'error_start_train_micro_layout_model',
        data: <String, dynamic>{
          'message': 'Процесс обучения уже запущен',
        },
      );
      return;
    }

    _isTraining = true;
    final repository = IndexedDbTrainingSampleRepository.createDefault();
    final existingWeights = await repository.getWeights();
    final model = existingWeights != null
        ? MicroLayoutModel.fromWeights(existingWeights)
        : MicroLayoutModel(inputSize: _defaultMicroLayoutInputSize);
    final trainer = MicroLayoutTrainer(repository: repository, model: model);
    final epochs = (data?['epochs'] as num?)?.toInt() ?? 20;
    final learningRate = (data?['learningRate'] as num?)?.toDouble() ?? 0.0005;
    final acceptedOnly = data?['acceptedOnly'] == true;
    final nextVersion = (existingWeights?.version ?? 0) + 1;
    final stopwatch = Stopwatch()..start();

    state.currentLayoutProcess = 'Обучение нейромодели';
    state.currentLayoutProcessProgress = 0;
    state.currentLayoutProcessCanStop = false;
    state.autoLayoutElapsedMilliseconds = 0;
    tileManager.onStateUpdate();

    appEvent?.emitToJs(
      action: 'train_micro_layout_model_started',
      data: <String, dynamic>{
        'epochs': epochs,
        'learningRate': learningRate,
        'acceptedOnly': acceptedOnly,
        'currentVersion': existingWeights?.version,
      },
    );

    try {
      final result = await trainer.train(
        epochs: epochs,
        learningRate: learningRate,
        acceptedOnly: acceptedOnly,
        onProgress: (progress) {
          state.currentLayoutProcessProgress = progress.progressPercent.clamp(0, 100).toDouble();
          state.autoLayoutElapsedMilliseconds = stopwatch.elapsedMilliseconds;
          tileManager.onStateUpdate();
          appEvent?.emitToJs(
            action: 'train_micro_layout_model_progress',
            data: <String, dynamic>{
              'progressPercent': progress.progressPercent,
              'currentEpoch': progress.currentEpoch,
              'totalEpochs': progress.totalEpochs,
              'loss': progress.loss,
              'sampleCount': progress.sampleCount,
            },
          );
        },
      );

      if (result.sampleCount > 0) {
        await trainer.saveWeights(version: nextVersion);
        await trainer.clearSamples();
      }

      state.currentLayoutProcessProgress = 100;
      state.autoLayoutElapsedMilliseconds = stopwatch.elapsedMilliseconds;
      tileManager.onStateUpdate();

      appEvent?.emitToJs(
        action: 'finish_start_train_micro_layout_model',
        data: <String, dynamic>{
          'sampleCount': result.sampleCount,
          'epochs': result.epochs,
          'loss': result.loss,
          'weightsVersion': result.sampleCount > 0 ? nextVersion : existingWeights?.version,
        },
      );
    } catch (error) {
      appEvent?.emitToJs(
        action: 'error_start_train_micro_layout_model',
        data: <String, dynamic>{
          'message': error.toString(),
        },
      );
    } finally {
      _isTraining = false;
      stopwatch.stop();
      state.autoLayoutElapsedMilliseconds = stopwatch.elapsedMilliseconds;
      state.currentLayoutProcess = '';
      state.currentLayoutProcessProgress = null;
      state.currentLayoutProcessCanStop = true;
      tileManager.onStateUpdate();
    }
  }

  Future<MicroLayoutTrainingResult> train({
    int epochs = 10,
    double learningRate = 0.0005,
    bool acceptedOnly = false,
    void Function(MicroLayoutTrainingProgress progress)? onProgress,
  }) async {
    final rawSamples = acceptedOnly ? await repository.getAcceptedSamples() : await repository.getSamples();
    final samples = rawSamples.where(_isSampleValid).toList(growable: false);
    if (samples.isEmpty) {
      return const MicroLayoutTrainingResult(sampleCount: 0, epochs: 0, loss: 0);
    }

    final batch = _createBatch(samples);
    var lastLoss = 0.0;

    for (var epoch = 0; epoch < epochs; epoch++) {
      lastLoss = model.trainBatch(batch, learningRate: learningRate);
      onProgress?.call(
        MicroLayoutTrainingProgress(
          currentEpoch: epoch + 1,
          totalEpochs: epochs,
          loss: lastLoss,
          sampleCount: samples.length,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    return MicroLayoutTrainingResult(
      sampleCount: samples.length,
      epochs: epochs,
      loss: lastLoss,
    );
  }

  Future<void> saveWeights({int version = 1}) async {
    final weights = model.exportWeights(version: version);
    await repository.saveWeights(weights);
  }

  Future<void> clearSamples() {
    return repository.clearSamples();
  }

  Future<MicroLayoutWeights?> loadWeights() {
    return repository.getWeights();
  }

  bool _isSampleValid(LayoutTrainingSample sample) {
    final context = sample.trainingContext;
    if (context == null) {
      return false;
    }

    if (context.schemaVersion < 5) {
      return false;
    }

    if (context.isManualSample) {
      return false;
    }

    if (context.sampleSource != 'auto') {
      return false;
    }

    const allowedDatasetKinds = <String>{
      'auto_immediate',
      'auto_repair_immediate',
      'auto_polish_immediate',
    };

    if (!allowedDatasetKinds.contains(context.datasetKind)) {
      return false;
    }

    if (context.outcomeKind != 'immediate') {
      return false;
    }

    if (!context.isConflictNode) {
      return false;
    }

    if (!sample.targetScore.isFinite) {
      return false;
    }

    final featureValues = sample.features.toList();
    if (featureValues.isEmpty) {
      return false;
    }

    return featureValues.every((value) => value.isFinite);
  }

  MicroLayoutTrainingBatch _createBatch(List<LayoutTrainingSample> samples) {
    return MicroLayoutTrainingBatch(
      features: samples.map((sample) => sample.features).toList(growable: false),
      targets: samples.map((sample) => sample.targetScore).toList(growable: false),
    );
  }
}
