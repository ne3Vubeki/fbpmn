class MicroLayoutSnapshotMetadata {
  final String schemaVersion;
  final String modelVersion;
  final String buildVersion;
  final String datasetSchemaTag;
  final int featureCount;
  final DateTime exportedAt;
  final int sampleCount;
  final bool hasWeights;

  const MicroLayoutSnapshotMetadata({
    required this.schemaVersion,
    required this.modelVersion,
    required this.buildVersion,
    required this.datasetSchemaTag,
    required this.featureCount,
    required this.exportedAt,
    required this.sampleCount,
    required this.hasWeights,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'modelVersion': modelVersion,
      'buildVersion': buildVersion,
      'datasetSchemaTag': datasetSchemaTag,
      'featureCount': featureCount,
      'exportedAt': exportedAt.toIso8601String(),
      'sampleCount': sampleCount,
      'hasWeights': hasWeights,
    };
  }

  factory MicroLayoutSnapshotMetadata.fromJson(Map<String, dynamic> json) {
    return MicroLayoutSnapshotMetadata(
      schemaVersion: json['schemaVersion'] as String? ?? '1',
      modelVersion: json['modelVersion'] as String? ?? '0',
      buildVersion: json['buildVersion'] as String? ?? 'unknown',
      datasetSchemaTag: json['datasetSchemaTag'] as String? ?? 'neural_polish_v6',
      featureCount: (json['featureCount'] as num?)?.toInt() ?? 0,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      hasWeights: json['hasWeights'] as bool? ?? false,
    );
  }
}
