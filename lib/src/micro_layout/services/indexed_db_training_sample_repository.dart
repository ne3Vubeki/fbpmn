import 'package:fbpmn/src/micro_layout/models/layout_training_sample.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_snapshot.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_snapshot_metadata.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_weights.dart';
import 'package:fbpmn/src/micro_layout/services/training_sample_repository.dart';
import 'package:fbpmn/src/services/indexed_db/indexed_db_app_definition.dart';
import 'package:fbpmn/src/services/indexed_db/indexed_db_service.dart';

class IndexedDbTrainingSampleRepository implements TrainingSampleRepository {
  static const String _weightsRecordId = 'current';
  static const String _metadataRecordId = 'current';

  final IndexedDbService indexedDbService;

  IndexedDbTrainingSampleRepository({required this.indexedDbService});

  factory IndexedDbTrainingSampleRepository.createDefault() {
    return IndexedDbTrainingSampleRepository(
      indexedDbService: createIndexedDbService(),
    );
  }

  Future<void> open() {
    return indexedDbService.open(IndexedDbAppDefinition.database);
  }

  @override
  Future<void> clear() async {
    await open();
    await indexedDbService.clearStore(storeName: IndexedDbAppStores.microLayoutSamples);
    await indexedDbService.clearStore(storeName: IndexedDbAppStores.microLayoutWeights);
    await indexedDbService.clearStore(storeName: IndexedDbAppStores.microLayoutMetadata);
  }

  @override
  Future<MicroLayoutSnapshot> exportSnapshot({
    required String buildVersion,
    required String modelVersion,
    String schemaVersion = '1',
  }) async {
    await open();
    final samples = await getSamples();
    final weights = await getWeights();

    final metadata = MicroLayoutSnapshotMetadata(
      schemaVersion: schemaVersion,
      modelVersion: modelVersion,
      buildVersion: buildVersion,
      exportedAt: DateTime.now(),
      sampleCount: samples.length,
      hasWeights: weights != null,
    );

    await _saveMetadata(metadata);

    return MicroLayoutSnapshot(
      metadata: metadata,
      samples: samples,
      weights: weights,
    );
  }

  @override
  Future<List<LayoutTrainingSample>> getAcceptedSamples() async {
    final samples = await getSamples();
    return samples.where((sample) => sample.accepted).toList(growable: false);
  }

  @override
  Future<List<LayoutTrainingSample>> getSamples() async {
    await open();
    final records = await indexedDbService.getAll(storeName: IndexedDbAppStores.microLayoutSamples);
    return records
        .map((record) => _mapRecord(record))
        .map(LayoutTrainingSample.fromJson)
        .toList(growable: false);
  }

  @override
  Future<MicroLayoutSnapshotMetadata?> getSnapshotMetadata() async {
    await open();
    final record = await indexedDbService.get(
      storeName: IndexedDbAppStores.microLayoutMetadata,
      key: _metadataRecordId,
    );
    if (record == null) {
      return null;
    }
    final json = _mapRecord(record);
    json.remove('id');
    return MicroLayoutSnapshotMetadata.fromJson(json);
  }

  @override
  Future<MicroLayoutWeights?> getWeights() async {
    await open();
    final record = await indexedDbService.get(
      storeName: IndexedDbAppStores.microLayoutWeights,
      key: _weightsRecordId,
    );
    if (record == null) {
      return null;
    }
    final json = _mapRecord(record);
    json.remove('id');
    return MicroLayoutWeights.fromJson(json);
  }

  @override
  Future<void> importSnapshot(
    MicroLayoutSnapshot snapshot, {
    bool mergeSamples = true,
    bool replaceWeights = true,
  }) async {
    await open();

    if (!mergeSamples) {
      await indexedDbService.clearStore(storeName: IndexedDbAppStores.microLayoutSamples);
    }

    await saveSamples(snapshot.samples);

    if (replaceWeights && snapshot.weights != null) {
      await saveWeights(snapshot.weights!);
    }

    await _saveMetadata(snapshot.metadata);
  }

  @override
  Future<void> saveSample(LayoutTrainingSample sample) async {
    await open();
    await indexedDbService.put(
      storeName: IndexedDbAppStores.microLayoutSamples,
      value: sample.toJson(),
    );
  }

  @override
  Future<void> saveSamples(List<LayoutTrainingSample> samples) async {
    if (samples.isEmpty) {
      return;
    }

    await open();
    await indexedDbService.putAll(
      storeName: IndexedDbAppStores.microLayoutSamples,
      values: samples.map((sample) => sample.toJson()).toList(growable: false),
    );
  }

  @override
  Future<void> saveWeights(MicroLayoutWeights weights) async {
    await open();
    final json = weights.toJson();
    json['id'] = _weightsRecordId;
    await indexedDbService.put(
      storeName: IndexedDbAppStores.microLayoutWeights,
      value: json,
    );
  }

  Future<void> _saveMetadata(MicroLayoutSnapshotMetadata metadata) async {
    final json = metadata.toJson();
    json['id'] = _metadataRecordId;
    await indexedDbService.put(
      storeName: IndexedDbAppStores.microLayoutMetadata,
      value: json,
    );
  }

  Map<String, dynamic> _mapRecord(dynamic record) {
    return Map<String, dynamic>.from(record as Map);
  }
}
