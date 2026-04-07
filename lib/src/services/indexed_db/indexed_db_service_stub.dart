import 'indexed_db_models.dart';
import 'indexed_db_service_base.dart';

class UnsupportedIndexedDbService implements IndexedDbService {
  final Map<String, Map<dynamic, dynamic>> _stores = <String, Map<dynamic, dynamic>>{};
  IndexedDbDatabaseDefinition? _definition;

  @override
  bool get isOpen => _definition != null;

  @override
  Future<void> clearStore({required String storeName}) async {
    _requireStore(storeName).clear();
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteDatabase() async {
    _stores.clear();
    _definition = null;
  }

  @override
  Future<int> count({required String storeName}) async {
    return _requireStore(storeName).length;
  }

  @override
  Future<void> delete({required String storeName, required key}) async {
    _requireStore(storeName).remove(key);
  }

  @override
  Future<dynamic> get({required String storeName, required key}) async {
    return _requireStore(storeName)[key];
  }

  @override
  Future<List<dynamic>> getAll({required String storeName}) async {
    return _requireStore(storeName).values.toList(growable: false);
  }

  @override
  Future<void> open(IndexedDbDatabaseDefinition definition) async {
    _definition = definition;
    for (final store in definition.stores) {
      _stores.putIfAbsent(store.name, () => <dynamic, dynamic>{});
    }
  }

  @override
  Future<void> putAll({required String storeName, required List<dynamic> values}) async {
    for (final value in values) {
      await put(storeName: storeName, value: value);
    }
  }

  @override
  Future<void> put({required String storeName, required value, key}) async {
    final store = _requireStore(storeName);
    final resolvedKey = key ?? _resolveInlineKey(storeName: storeName, value: value);
    if (resolvedKey == null) {
      throw StateError('Unable to resolve key for in-memory IndexedDB stub store $storeName.');
    }
    store[resolvedKey] = value;
  }

  Map<dynamic, dynamic> _requireStore(String storeName) {
    final definition = _definition;
    if (definition == null) {
      throw StateError('IndexedDB stub database is not open.');
    }

    return _stores.putIfAbsent(storeName, () => <dynamic, dynamic>{});
  }

  dynamic _resolveInlineKey({required String storeName, required dynamic value}) {
    final definition = _definition;
    if (definition == null || value is! Map) {
      return null;
    }

    IndexedDbStoreDefinition? storeDefinition;
    for (final store in definition.stores) {
      if (store.name == storeName) {
        storeDefinition = store;
        break;
      }
    }
    if (storeDefinition == null) {
      return null;
    }

    final keyPath = storeDefinition.keyPath;
    if (keyPath == null || keyPath.isEmpty) {
      return null;
    }

    return value[keyPath];
  }
}

IndexedDbService createIndexedDbServiceImpl() => UnsupportedIndexedDbService();
