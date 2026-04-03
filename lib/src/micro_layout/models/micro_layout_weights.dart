class MicroLayoutWeights {
  final List<List<List<double>>> kernels;
  final List<List<double>> biases;
  final int inputSize;
  final List<int> hiddenSizes;
  final int outputSize;
  final int version;

  const MicroLayoutWeights({
    required this.kernels,
    required this.biases,
    required this.inputSize,
    required this.hiddenSizes,
    required this.outputSize,
    this.version = 1,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kernels': kernels,
      'biases': biases,
      'inputSize': inputSize,
      'hiddenSizes': hiddenSizes,
      'outputSize': outputSize,
      'version': version,
    };
  }

  factory MicroLayoutWeights.fromJson(Map<String, dynamic> json) {
    return MicroLayoutWeights(
      kernels: (json['kernels'] as List<dynamic>? ?? const <dynamic>[])
          .map((layer) => (layer as List<dynamic>)
              .map((row) => (row as List<dynamic>).map((value) => (value as num).toDouble()).toList(growable: false))
              .toList(growable: false))
          .toList(growable: false),
      biases: (json['biases'] as List<dynamic>? ?? const <dynamic>[])
          .map((layer) => (layer as List<dynamic>).map((value) => (value as num).toDouble()).toList(growable: false))
          .toList(growable: false),
      inputSize: (json['inputSize'] as num).toInt(),
      hiddenSizes: (json['hiddenSizes'] as List<dynamic>? ?? const <dynamic>[]).map((value) => (value as num).toInt()).toList(growable: false),
      outputSize: (json['outputSize'] as num).toInt(),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}
