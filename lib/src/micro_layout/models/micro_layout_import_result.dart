class MicroLayoutImportResult {
  final String schemaVersion;
  final String modelVersion;
  final String buildVersion;
  final int importedSampleCount;
  final bool weightsUpdated;

  const MicroLayoutImportResult({
    required this.schemaVersion,
    required this.modelVersion,
    required this.buildVersion,
    required this.importedSampleCount,
    required this.weightsUpdated,
  });
}
