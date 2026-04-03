class IndexedDbIndexDefinition {
  final String name;
  final String keyPath;
  final bool unique;
  final bool multiEntry;

  const IndexedDbIndexDefinition({
    required this.name,
    required this.keyPath,
    this.unique = false,
    this.multiEntry = false,
  });
}

class IndexedDbStoreDefinition {
  final String name;
  final String? keyPath;
  final bool autoIncrement;
  final List<IndexedDbIndexDefinition> indices;

  const IndexedDbStoreDefinition({
    required this.name,
    this.keyPath,
    this.autoIncrement = false,
    this.indices = const <IndexedDbIndexDefinition>[],
  });
}

class IndexedDbDatabaseDefinition {
  final String name;
  final int version;
  final List<IndexedDbStoreDefinition> stores;

  const IndexedDbDatabaseDefinition({
    required this.name,
    required this.version,
    required this.stores,
  });
}
