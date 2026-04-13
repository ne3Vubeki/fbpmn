import 'dart:math';

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
  final double validationLoss;
  final int sampleCount;

  const MicroLayoutTrainingProgress({
    required this.currentEpoch,
    required this.totalEpochs,
    required this.loss,
    this.validationLoss = 0,
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
              'validationLoss': progress.validationLoss,
              'sampleCount': progress.sampleCount,
            },
          );
        },
      );

      if (result.sampleCount > 0) {
        await trainer.saveWeights(version: nextVersion);
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
    final allRawSamples = acceptedOnly ? await repository.getAcceptedSamples() : await repository.getSamples();
    final validSamples = allRawSamples.where(_isSampleValid).toList(growable: false);
    const maxRetainedSamples = 5000;
    final samples = validSamples.length > maxRetainedSamples
        ? validSamples.sublist(validSamples.length - maxRetainedSamples)
        : validSamples;
    if (samples.isEmpty) {
      return const MicroLayoutTrainingResult(sampleCount: 0, epochs: 0, loss: 0);
    }

    final rng = Random(42);
    final valCount = max(1, (samples.length * 0.1).round());
    final allIndices = List<int>.generate(samples.length, (i) => i);
    allIndices.shuffle(rng);
    final valIndices = allIndices.sublist(0, valCount).toSet();
    final trainSamples = <LayoutTrainingSample>[];
    final valSamples = <LayoutTrainingSample>[];
    for (var i = 0; i < samples.length; i++) {
      if (valIndices.contains(i)) {
        valSamples.add(samples[i]);
      } else {
        trainSamples.add(samples[i]);
      }
    }

    final trainBatch = _createWeightedBatch(trainSamples);
    final valBatch = _createBatch(valSamples);
    var lastLoss = 0.0;
    var lastValLoss = 0.0;
    var bestValLoss = double.infinity;
    var earlyStopCounter = 0;
    const earlyStopPatience = 3;
    var actualEpochs = 0;

    for (var epoch = 0; epoch < epochs; epoch++) {
      final progress01 = epoch / max(1, epochs - 1);
      final cosineDecay = 0.5 * (1.0 + cos(pi * progress01));
      final epochLR = learningRate * (0.1 + 0.9 * cosineDecay);

      final shuffledTrainBatch = _shuffleBatch(trainBatch, rng);
      lastLoss = model.trainBatch(shuffledTrainBatch, learningRate: epochLR);
      lastValLoss = model.computeBatchLoss(valBatch);
      actualEpochs = epoch + 1;

      onProgress?.call(
        MicroLayoutTrainingProgress(
          currentEpoch: epoch + 1,
          totalEpochs: epochs,
          loss: lastLoss,
          validationLoss: lastValLoss,
          sampleCount: trainSamples.length,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      if (lastValLoss < bestValLoss) {
        bestValLoss = lastValLoss;
        earlyStopCounter = 0;
      } else {
        earlyStopCounter++;
        if (earlyStopCounter >= earlyStopPatience) {
          break;
        }
      }
    }

    return MicroLayoutTrainingResult(
      sampleCount: trainSamples.length,
      epochs: actualEpochs,
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

    if (context.schemaVersion < 6) {
      return false;
    }

    const allowedSampleSources = <String>{
      'auto',
      'manual',
    };

    if (!allowedSampleSources.contains(context.sampleSource)) {
      return false;
    }

    const allowedDatasetKinds = <String>{
      'auto_immediate',
      'auto_repair_immediate',
      'auto_polish_immediate',
      'manual_immediate',
      'manual_deferred',
    };

    if (!allowedDatasetKinds.contains(context.datasetKind)) {
      return false;
    }

    const allowedOutcomeKinds = <String>{
      'immediate',
      'deferred',
    };

    if (!allowedOutcomeKinds.contains(context.outcomeKind)) {
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

  MicroLayoutTrainingBatch _createWeightedBatch(List<LayoutTrainingSample> samples) {
    return MicroLayoutTrainingBatch(
      features: samples.map((sample) => sample.features).toList(growable: false),
      targets: samples.map((sample) => sample.targetScore).toList(growable: false),
      weights: samples.map(_computeSampleWeight).toList(growable: false),
    );
  }

  double _computeSampleWeight(LayoutTrainingSample sample) {
    final ctx = sample.trainingContext;
    if (ctx == null) return 1.0;
    if (ctx.isManualSample) return 2.0;
    if (!sample.accepted) return 0.5;
    return 1.0;
  }

  MicroLayoutTrainingBatch _shuffleBatch(MicroLayoutTrainingBatch batch, Random rng) {
    final indices = List<int>.generate(batch.length, (i) => i);
    indices.shuffle(rng);
    return MicroLayoutTrainingBatch(
      features: indices.map((i) => batch.features[i]).toList(growable: false),
      targets: indices.map((i) => batch.targets[i]).toList(growable: false),
      weights: batch.weights != null
          ? indices.map((i) => batch.weights![i]).toList(growable: false)
          : null,
    );
  }
}
