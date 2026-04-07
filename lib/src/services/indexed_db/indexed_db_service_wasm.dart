import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

import 'indexed_db_models.dart';
import 'indexed_db_service_base.dart';

class WasmIndexedDbService implements IndexedDbService {
  Database? _database;
  IndexedDbDatabaseDefinition? _definition;

  @override
  bool get isOpen => _database != null;

  @override
  Future<void> open(IndexedDbDatabaseDefinition definition) async {
    if (_database != null &&
        _definition?.name == definition.name &&
        _definition?.version == definition.version) {
      return;
    }

    await close();
    final factory = databaseFactoryWeb;
    _database = await factory.openDatabase(definition.name);
    _definition = definition;
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
    _definition = null;
  }

  @override
  Future<void> deleteDatabase() async {
    final definition = _definition;
    await close();
    if (definition == null) {
      return;
    }
    await databaseFactoryWeb.deleteDatabase(definition.name);
  }

  @override
  Future<void> put({required String storeName, required value, key}) async {
    final store = _recordStore(storeName);
    final resolvedKey = key ?? _resolveInlineKey(storeName: storeName, value: value);
    if (resolvedKey == null) {
      throw StateError('Unable to resolve key for store $storeName.');
    }
    await store.record(resolvedKey).put(_requireDatabase(), value);
  }

  @override
  Future<void> putAll({required String storeName, required List<dynamic> values}) async {
    if (values.isEmpty) {
      return;
    }

    final database = _requireDatabase();
    final store = _recordStore(storeName);
    await database.transaction((transaction) async {
      for (final value in values) {
        final resolvedKey = _resolveInlineKey(storeName: storeName, value: value);
        if (resolvedKey == null) {
          throw StateError('Unable to resolve key for store $storeName.');
        }
        await store.record(resolvedKey).put(transaction, value);
      }
    });
  }

  @override
  Future<dynamic> get({required String storeName, required key}) async {
    return _recordStore(storeName).record(key).get(_requireDatabase());
  }

  @override
  Future<List<dynamic>> getAll({required String storeName}) async {
    final snapshots = await _recordStore(storeName).find(_requireDatabase());
    return snapshots.map((snapshot) => snapshot.value).toList(growable: false);
  }

  @override
  Future<void> delete({required String storeName, required key}) async {
    await _recordStore(storeName).record(key).delete(_requireDatabase());
  }

  @override
  Future<void> clearStore({required String storeName}) async {
    await _recordStore(storeName).delete(_requireDatabase());
  }

  @override
  Future<int> count({required String storeName}) async {
    final count = await _recordStore(storeName).count(_requireDatabase());
    return count;
  }

  Database _requireDatabase() {
    final database = _database;
    if (database == null) {
      throw StateError('IndexedDB database is not open.');
    }
    return database;
  }

  StoreRef<String, Map<String, Object?>> _recordStore(String storeName) {
    return stringMapStoreFactory.store(storeName);
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

    return value[keyPath]?.toString();
  }
}

IndexedDbService createIndexedDbServiceImpl() => WasmIndexedDbService();
