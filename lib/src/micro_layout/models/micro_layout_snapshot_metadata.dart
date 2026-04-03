class MicroLayoutSnapshotMetadata {
  final String schemaVersion;
  final String modelVersion;
  final String buildVersion;
  final DateTime exportedAt;
  final int sampleCount;
  final bool hasWeights;

  const MicroLayoutSnapshotMetadata({
    required this.schemaVersion,
    required this.modelVersion,
    required this.buildVersion,
    required this.exportedAt,
    required this.sampleCount,
    required this.hasWeights,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'modelVersion': modelVersion,
      'buildVersion': buildVersion,
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
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      hasWeights: json['hasWeights'] as bool? ?? false,
    );
  }
}
