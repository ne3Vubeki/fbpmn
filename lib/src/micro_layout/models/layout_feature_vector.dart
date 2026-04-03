import 'dart:typed_data';

class LayoutFeatureVector {
  final Float32List values;
  final int schemaVersion;

  LayoutFeatureVector(List<double> values, {this.schemaVersion = 1}) : values = Float32List.fromList(values);

  int get length => values.length;

  List<double> toList() => values.toList(growable: false);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'values': values.toList(growable: false),
    };
  }

  factory LayoutFeatureVector.fromJson(Map<String, dynamic> json) {
    final rawValues = (json['values'] as List<dynamic>? ?? const <dynamic>[])
        .map((value) => (value as num).toDouble())
        .toList(growable: false);

    return LayoutFeatureVector(
      rawValues,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
