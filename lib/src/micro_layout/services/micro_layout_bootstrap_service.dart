import 'package:fbpmn/src/micro_layout/models/micro_layout_bootstrap_result.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_snapshot.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_snapshot_metadata.dart';
import 'package:fbpmn/src/micro_layout/services/micro_layout_snapshot_codec.dart';
import 'package:fbpmn/src/micro_layout/services/training_sample_repository.dart';

class MicroLayoutBootstrapService {
  final TrainingSampleRepository repository;
  final MicroLayoutSnapshotCodec codec;

  const MicroLayoutBootstrapService({
    required this.repository,
    this.codec = const MicroLayoutSnapshotCodec(),
  });

  Future<MicroLayoutBootstrapResult> bootstrapFromBundledSnapshotJson(
    String source, {
    bool mergeSamples = true,
    bool replaceWeights = true,
  }) async {
    final bundledSnapshot = codec.decode(source);
    return bootstrapFromBundledSnapshot(
      bundledSnapshot,
      mergeSamples: mergeSamples,
      replaceWeights: replaceWeights,
    );
  }

  Future<MicroLayoutBootstrapResult> bootstrapFromBundledSnapshot(
    MicroLayoutSnapshot bundledSnapshot, {
    bool mergeSamples = true,
    bool replaceWeights = true,
  }) async {
    final currentMetadata = await repository.getSnapshotMetadata();
    if (!_shouldImport(currentMetadata, bundledSnapshot.metadata)) {
      return const MicroLayoutBootstrapResult(
        imported: false,
        metadataChanged: false,
        reason: 'bundled_snapshot_is_not_newer',
      );
    }

    await repository.importSnapshot(
      bundledSnapshot,
      mergeSamples: mergeSamples,
      replaceWeights: replaceWeights,
    );

    return const MicroLayoutBootstrapResult(
      imported: true,
      metadataChanged: true,
      reason: 'bundled_snapshot_imported',
    );
  }

  bool _shouldImport(
    MicroLayoutSnapshotMetadata? current,
    MicroLayoutSnapshotMetadata incoming,
  ) {
    if (current == null) {
      return true;
    }

    if (current.schemaVersion != incoming.schemaVersion) {
      return true;
    }

    final modelCompare = current.modelVersion.compareTo(incoming.modelVersion);
    if (modelCompare < 0) {
      return true;
    }

    final buildCompare = current.buildVersion.compareTo(incoming.buildVersion);
    if (buildCompare < 0) {
      return true;
    }

    if (!current.hasWeights && incoming.hasWeights) {
      return true;
    }

    return false;
  }
}
