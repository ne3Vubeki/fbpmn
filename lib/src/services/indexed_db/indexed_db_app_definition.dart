import 'indexed_db_models.dart';

class IndexedDbAppStores {
  static const String microLayoutSamples = 'micro_layout_samples';
  static const String microLayoutWeights = 'micro_layout_weights';
  static const String microLayoutMetadata = 'micro_layout_metadata';
  static const String schemaHistory = 'schema_history';
}

class IndexedDbAppDefinition {
  static const IndexedDbDatabaseDefinition database = IndexedDbDatabaseDefinition(
    name: 'fbpmn_local_storage',
    version: 1,
    stores: <IndexedDbStoreDefinition>[
      IndexedDbStoreDefinition(
        name: IndexedDbAppStores.microLayoutSamples,
        keyPath: 'id',
      ),
      IndexedDbStoreDefinition(
        name: IndexedDbAppStores.microLayoutWeights,
        keyPath: 'id',
      ),
      IndexedDbStoreDefinition(
        name: IndexedDbAppStores.microLayoutMetadata,
        keyPath: 'id',
      ),
      IndexedDbStoreDefinition(
        name: IndexedDbAppStores.schemaHistory,
        keyPath: 'id',
      ),
    ],
  );
}
