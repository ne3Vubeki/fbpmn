import 'package:fbpmn/src/micro_layout/models/micro_layout_import_result.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_snapshot.dart';
import 'package:fbpmn/src/micro_layout/services/micro_layout_snapshot_codec.dart';
import 'package:fbpmn/src/micro_layout/services/training_sample_repository.dart';

class MicroLayoutSnapshotService {
  final TrainingSampleRepository repository;
  final MicroLayoutSnapshotCodec codec;

  const MicroLayoutSnapshotService({
    required this.repository,
    this.codec = const MicroLayoutSnapshotCodec(),
  });

  Future<MicroLayoutSnapshot> createSnapshot({
    required String buildVersion,
    required String modelVersion,
    String schemaVersion = '1',
  }) {
    return repository.exportSnapshot(
      buildVersion: buildVersion,
      modelVersion: modelVersion,
      schemaVersion: schemaVersion,
    );
  }

  Future<String> exportSnapshotJson({
    required String buildVersion,
    required String modelVersion,
    String schemaVersion = '1',
  }) async {
    final snapshot = await createSnapshot(
      buildVersion: buildVersion,
      modelVersion: modelVersion,
      schemaVersion: schemaVersion,
    );
    return codec.encode(snapshot);
  }

  Future<MicroLayoutImportResult> importSnapshotJson(
    String source, {
    bool mergeSamples = true,
    bool replaceWeights = true,
  }) async {
    final snapshot = codec.decode(source);
    return importSnapshot(
      snapshot,
      mergeSamples: mergeSamples,
      replaceWeights: replaceWeights,
    );
  }

  Future<MicroLayoutImportResult> importSnapshot(
    MicroLayoutSnapshot snapshot, {
    bool mergeSamples = true,
    bool replaceWeights = true,
  }) async {
    await repository.importSnapshot(
      snapshot,
      mergeSamples: mergeSamples,
      replaceWeights: replaceWeights,
    );

    return MicroLayoutImportResult(
      schemaVersion: snapshot.metadata.schemaVersion,
      modelVersion: snapshot.metadata.modelVersion,
      buildVersion: snapshot.metadata.buildVersion,
      importedSampleCount: snapshot.samples.length,
      weightsUpdated: replaceWeights && snapshot.weights != null,
    );
  }
}
