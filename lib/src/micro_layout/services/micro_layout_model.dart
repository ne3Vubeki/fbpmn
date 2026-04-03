import 'dart:math';

import 'package:fbpmn/src/micro_layout/models/layout_feature_vector.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_training_batch.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_weights.dart';

class MicroLayoutModel {
  final int inputSize;
  final List<int> hiddenSizes;
  final int outputSize;
  final Random _random;

  late final List<List<List<double>>> _kernels;
  late final List<List<double>> _biases;

  MicroLayoutModel({
    required this.inputSize,
    this.hiddenSizes = const <int>[64, 32],
    this.outputSize = 1,
    Random? random,
  }) : _random = random ?? Random(42) {
    _kernels = <List<List<double>>>[];
    _biases = <List<double>>[];

    final layerSizes = <int>[inputSize, ...hiddenSizes, outputSize];
    for (var layerIndex = 0; layerIndex < layerSizes.length - 1; layerIndex++) {
      final fanIn = layerSizes[layerIndex];
      final fanOut = layerSizes[layerIndex + 1];
      _kernels.add(_createKernel(fanOut: fanOut, fanIn: fanIn));
      _biases.add(List<double>.filled(fanOut, 0));
    }
  }

  MicroLayoutModel.fromWeights(MicroLayoutWeights weights, {Random? random})
      : inputSize = weights.inputSize,
        hiddenSizes = weights.hiddenSizes,
        outputSize = weights.outputSize,
        _random = random ?? Random(42) {
    _kernels = weights.kernels
        .map((layer) => layer.map((row) => List<double>.from(row)).toList(growable: false))
        .toList(growable: false);
    _biases = weights.biases.map((layer) => List<double>.from(layer)).toList(growable: false);
  }

  double predict(LayoutFeatureVector features) {
    final output = _forward(features.toList());
    return output.first;
  }

  List<double> predictAll(List<LayoutFeatureVector> features) {
    return features.map(predict).toList(growable: false);
  }

  double trainBatch(MicroLayoutTrainingBatch batch, {double learningRate = 0.0005}) {
    if (batch.isEmpty) {
      return 0;
    }

    var totalLoss = 0.0;
    for (var sampleIndex = 0; sampleIndex < batch.length; sampleIndex++) {
      final input = batch.features[sampleIndex].toList();
      final target = batch.targets[sampleIndex];
      totalLoss += _trainSample(input, target, learningRate);
    }

    return totalLoss / batch.length;
  }

  MicroLayoutWeights exportWeights({int version = 1}) {
    return MicroLayoutWeights(
      kernels: _kernels
          .map((layer) => layer.map((row) => List<double>.from(row)).toList(growable: false))
          .toList(growable: false),
      biases: _biases.map((layer) => List<double>.from(layer)).toList(growable: false),
      inputSize: inputSize,
      hiddenSizes: hiddenSizes,
      outputSize: outputSize,
      version: version,
    );
  }

  List<List<double>> _forwardWithActivations(List<double> input) {
    final activations = <List<double>>[List<double>.from(input)];
    var current = input;

    for (var layerIndex = 0; layerIndex < _kernels.length; layerIndex++) {
      final isOutputLayer = layerIndex == _kernels.length - 1;
      final next = List<double>.filled(_biases[layerIndex].length, 0);

      for (var outIndex = 0; outIndex < next.length; outIndex++) {
        var sum = _biases[layerIndex][outIndex];
        for (var inIndex = 0; inIndex < current.length; inIndex++) {
          sum += _kernels[layerIndex][outIndex][inIndex] * current[inIndex];
        }
        next[outIndex] = isOutputLayer ? sum : _relu(sum);
      }

      activations.add(next);
      current = next;
    }

    return activations;
  }

  List<double> _forward(List<double> input) {
    return _forwardWithActivations(input).last;
  }

  double _trainSample(List<double> input, double target, double learningRate) {
    final activations = _forwardWithActivations(input);
    final predictions = activations.last;
    final output = predictions.first;
    final error = output - target;
    final loss = error * error;

    var downstreamGradient = <double>[2 * error];

    for (var layerIndex = _kernels.length - 1; layerIndex >= 0; layerIndex--) {
      final layerInput = activations[layerIndex];
      final layerOutput = activations[layerIndex + 1];
      final isOutputLayer = layerIndex == _kernels.length - 1;
      final propagatedGradient = List<double>.filled(layerInput.length, 0);

      for (var outIndex = 0; outIndex < _kernels[layerIndex].length; outIndex++) {
        final activationGradient = isOutputLayer ? downstreamGradient[outIndex] : downstreamGradient[outIndex] * _reluDerivative(layerOutput[outIndex]);

        for (var inIndex = 0; inIndex < _kernels[layerIndex][outIndex].length; inIndex++) {
          propagatedGradient[inIndex] += _kernels[layerIndex][outIndex][inIndex] * activationGradient;
          _kernels[layerIndex][outIndex][inIndex] -= learningRate * activationGradient * layerInput[inIndex];
        }

        _biases[layerIndex][outIndex] -= learningRate * activationGradient;
      }

      downstreamGradient = propagatedGradient;
    }

    return loss;
  }

  List<List<double>> _createKernel({required int fanOut, required int fanIn}) {
    final scale = sqrt(2 / max(1, fanIn));
    return List<List<double>>.generate(
      fanOut,
      (_) => List<double>.generate(
        fanIn,
        (_) => (_random.nextDouble() * 2 - 1) * scale,
        growable: false,
      ),
      growable: false,
    );
  }

  double _relu(double value) => value > 0 ? value : 0;

  double _reluDerivative(double activatedValue) => activatedValue > 0 ? 1 : 0;
}
