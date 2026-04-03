class MicroLayoutBootstrapResult {
  final bool imported;
  final bool metadataChanged;
  final String reason;

  const MicroLayoutBootstrapResult({
    required this.imported,
    required this.metadataChanged,
    required this.reason,
  });
}
