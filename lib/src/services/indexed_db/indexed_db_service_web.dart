import 'dart:html' as html;

import 'indexed_db_models.dart';
import 'indexed_db_service_base.dart';

class WebIndexedDbService implements IndexedDbService {
  dynamic _database;
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

    final factory = html.window.indexedDB;
    if (factory == null) {
      throw UnsupportedError('IndexedDB is not supported in this browser.');
    }

    _database = await factory.open(
      definition.name,
      version: definition.version,
      onUpgradeNeeded: (event) {
        final target = event.target as dynamic;
        final database = target.result;
        final transaction = target.transaction;
        for (final storeDefinition in definition.stores) {
          final storeExists = database.objectStoreNames.contains(storeDefinition.name);
          final store = storeExists
              ? transaction.objectStore(storeDefinition.name)
              : database.createObjectStore(
                  storeDefinition.name,
                  keyPath: storeDefinition.keyPath,
                  autoIncrement: storeDefinition.autoIncrement,
                );

          for (final indexDefinition in storeDefinition.indices) {
            final indexExists = store.indexNames.contains(indexDefinition.name);
            if (indexExists) {
              continue;
            }
            store.createIndex(
              indexDefinition.name,
              indexDefinition.keyPath,
              unique: indexDefinition.unique,
              multiEntry: indexDefinition.multiEntry,
            );
          }
        }
      },
    );
    _definition = definition;
  }

  @override
  Future<void> close() async {
    _database?.close();
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

    final factory = html.window.indexedDB;
    if (factory == null) {
      throw UnsupportedError('IndexedDB is not supported in this browser.');
    }

    await factory.deleteDatabase(definition.name);
  }

  @override
  Future<void> put({required String storeName, required value, key}) async {
    final database = _requireDatabase();
    final transaction = database.transaction(storeName, 'readwrite');
    final store = transaction.objectStore(storeName);
    if (key == null) {
      await store.put(value);
    } else {
      await store.put(value, key);
    }
    await transaction.completed;
  }

  @override
  Future<void> putAll({required String storeName, required List<dynamic> values}) async {
    if (values.isEmpty) {
      return;
    }

    final database = _requireDatabase();
    final transaction = database.transaction(storeName, 'readwrite');
    final store = transaction.objectStore(storeName);
    for (final value in values) {
      await store.put(value);
    }
    await transaction.completed;
  }

  @override
  Future<dynamic> get({required String storeName, required key}) async {
    final database = _requireDatabase();
    final transaction = database.transaction(storeName, 'readonly');
    final store = transaction.objectStore(storeName);
    final result = await store.getObject(key);
    await transaction.completed;
    return result;
  }

  @override
  Future<List<dynamic>> getAll({required String storeName}) async {
    final database = _requireDatabase();
    final transaction = database.transaction(storeName, 'readonly');
    final store = transaction.objectStore(storeName);
    final cursorValues = <dynamic>[];
    await for (final cursor in store.openCursor(autoAdvance: true)) {
      cursorValues.add(cursor.value);
    }
    await transaction.completed;
    return cursorValues;
  }

  @override
  Future<void> delete({required String storeName, required key}) async {
    final database = _requireDatabase();
    final transaction = database.transaction(storeName, 'readwrite');
    final store = transaction.objectStore(storeName);
    await store.delete(key);
    await transaction.completed;
  }

  @override
  Future<void> clearStore({required String storeName}) async {
    final database = _requireDatabase();
    final transaction = database.transaction(storeName, 'readwrite');
    final store = transaction.objectStore(storeName);
    await store.clear();
    await transaction.completed;
  }

  @override
  Future<int> count({required String storeName}) async {
    final database = _requireDatabase();
    final transaction = database.transaction(storeName, 'readonly');
    final store = transaction.objectStore(storeName);
    final result = await store.count();
    await transaction.completed;
    return result;
  }

  dynamic _requireDatabase() {
    final database = _database;
    if (database == null) {
      throw StateError('IndexedDB database is not open.');
    }
    return database;
  }
}

IndexedDbService createIndexedDbServiceImpl() => WebIndexedDbService();
