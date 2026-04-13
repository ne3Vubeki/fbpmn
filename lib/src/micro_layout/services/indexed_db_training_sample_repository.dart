import 'package:fbpmn/src/micro_layout/models/layout_training_sample.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_snapshot.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_snapshot_metadata.dart';
import 'package:fbpmn/src/micro_layout/models/micro_layout_weights.dart';
import 'package:fbpmn/src/micro_layout/services/candidate_feature_extractor.dart';
import 'package:fbpmn/src/micro_layout/services/training_sample_repository.dart';
import 'package:fbpmn/src/services/indexed_db/indexed_db_app_definition.dart';
import 'package:fbpmn/src/services/indexed_db/indexed_db_service.dart';

class IndexedDbTrainingSampleRepository implements TrainingSampleRepository {
  static const String _weightsRecordId = 'current';
  static const String _metadataRecordId = 'current';

  final IndexedDbService indexedDbService;
  Future<void>? _opening;
  int _sampleRecordSequence = 0;

  IndexedDbTrainingSampleRepository({required this.indexedDbService});

  factory IndexedDbTrainingSampleRepository.createDefault() {
    return IndexedDbTrainingSampleRepository(
      indexedDbService: createIndexedDbService(),
    );
  }

  Future<void> open() {
    return _ensureOpen(forceReopen: true);
  }

  Future<void> _ensureOpen({bool forceReopen = false}) async {
    if (!forceReopen && indexedDbService.isOpen) {
      return;
    }

    final existingOpening = _opening;
    if (existingOpening != null) {
      return existingOpening;
    }

    final opening = () async {
      if (forceReopen && indexedDbService.isOpen) {
        await indexedDbService.close();
      }
      await indexedDbService.open(IndexedDbAppDefinition.database);
    }();

    _opening = opening;
    try {
      await opening;
    } finally {
      if (identical(_opening, opening)) {
        _opening = null;
      }
    }
  }

  bool _shouldReopen(Object error) {
    if (error is StateError) {
      return true;
    }
    final message = error.toString().toLowerCase();
    return message.contains('database is not open') ||
        message.contains('not found') ||
        message.contains('no such store') ||
        message.contains('versionchange') ||
        message.contains('not a known object store') ||
        message.contains('connection is closing');
  }

  Future<T> _withDatabase<T>(Future<T> Function() action) async {
    await _ensureOpen();
    try {
      return await action();
    } catch (error) {
      if (!_shouldReopen(error)) {
        rethrow;
      }
      await _ensureOpen(forceReopen: true);
      return action();
    }
  }

  @override
  Future<void> clearSamples() async {
    await _withDatabase(() => indexedDbService.clearStore(storeName: IndexedDbAppStores.microLayoutSamples));
  }

  @override
  Future<void> clear() async {
    await _withDatabase(() async {
      await indexedDbService.clearStore(storeName: IndexedDbAppStores.microLayoutSamples);
      await indexedDbService.clearStore(storeName: IndexedDbAppStores.microLayoutWeights);
      await indexedDbService.clearStore(storeName: IndexedDbAppStores.microLayoutMetadata);
    });
  }

  @override
  Future<MicroLayoutSnapshot> exportSnapshot({
    required String buildVersion,
    required String modelVersion,
    String schemaVersion = '1',
  }) async {
    final samples = await getSamples();
    final weights = await getWeights();

    final metadata = MicroLayoutSnapshotMetadata(
      schemaVersion: schemaVersion,
      modelVersion: modelVersion,
      buildVersion: buildVersion,
      datasetSchemaTag: 'neural_polish_v6',
      featureCount: CandidateFeatureExtractor.featureCount,
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
    final records = await _withDatabase(() => indexedDbService.getAll(storeName: IndexedDbAppStores.microLayoutSamples));
    return records
        .map((record) => _mapSampleRecord(record))
        .map(LayoutTrainingSample.fromJson)
        .toList(growable: false);
  }

  @override
  Future<MicroLayoutSnapshotMetadata?> getSnapshotMetadata() async {
    final record = await _withDatabase(
      () => indexedDbService.get(
        storeName: IndexedDbAppStores.microLayoutMetadata,
        key: _metadataRecordId,
      ),
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
    final record = await _withDatabase(
      () => indexedDbService.get(
        storeName: IndexedDbAppStores.microLayoutWeights,
        key: _weightsRecordId,
      ),
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
    if (!mergeSamples) {
      await _withDatabase(() => indexedDbService.clearStore(storeName: IndexedDbAppStores.microLayoutSamples));
    }

    await saveSamples(snapshot.samples);

    if (replaceWeights && snapshot.weights != null) {
      await saveWeights(snapshot.weights!);
    }

    await _saveMetadata(snapshot.metadata);
  }

  @override
  Future<void> saveSample(LayoutTrainingSample sample) async {
    await _withDatabase(
      () => indexedDbService.put(
        storeName: IndexedDbAppStores.microLayoutSamples,
        value: _buildSampleRecord(sample),
      ),
    );
  }

  @override
  Future<void> saveSamples(List<LayoutTrainingSample> samples) async {
    if (samples.isEmpty) {
      return;
    }

    await _withDatabase(
      () => indexedDbService.putAll(
        storeName: IndexedDbAppStores.microLayoutSamples,
        values: samples.map(_buildSampleRecord).toList(growable: false),
      ),
    );
  }

  @override
  Future<void> saveWeights(MicroLayoutWeights weights) async {
    final json = weights.toJson();
    json['id'] = _weightsRecordId;
    await _withDatabase(
      () => indexedDbService.put(
        storeName: IndexedDbAppStores.microLayoutWeights,
        value: json,
      ),
    );
  }

  Future<void> _saveMetadata(MicroLayoutSnapshotMetadata metadata) async {
    final json = metadata.toJson();
    json['id'] = _metadataRecordId;
    await _withDatabase(
      () => indexedDbService.put(
        storeName: IndexedDbAppStores.microLayoutMetadata,
        value: json,
      ),
    );
  }

  Map<String, dynamic> _mapRecord(dynamic record) {
    return Map<String, dynamic>.from(record as Map);
  }

  Map<String, dynamic> _mapSampleRecord(dynamic record) {
    final json = _mapRecord(record);
    json.remove('id');
    return json;
  }

  Map<String, dynamic> _buildSampleRecord(LayoutTrainingSample sample) {
    final json = sample.toJson();
    json['id'] = _nextSampleRecordId();
    return json;
  }

  String _nextSampleRecordId() {
    final timestampMicros = DateTime.now().microsecondsSinceEpoch;
    final sequence = _sampleRecordSequence++;
    return 'sample_${timestampMicros}_$sequence';
  }
}
