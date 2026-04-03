import 'indexed_db_models.dart';
import 'indexed_db_service_base.dart';

class UnsupportedIndexedDbService implements IndexedDbService {
  @override
  bool get isOpen => false;

  @override
  Future<void> clearStore({required String storeName}) {
    throw UnsupportedError('IndexedDB is only available on web platform.');
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteDatabase() {
    throw UnsupportedError('IndexedDB is only available on web platform.');
  }

  @override
  Future<int> count({required String storeName}) {
    throw UnsupportedError('IndexedDB is only available on web platform.');
  }

  @override
  Future<void> delete({required String storeName, required key}) {
    throw UnsupportedError('IndexedDB is only available on web platform.');
  }

  @override
  Future<dynamic> get({required String storeName, required key}) {
    throw UnsupportedError('IndexedDB is only available on web platform.');
  }

  @override
  Future<List<dynamic>> getAll({required String storeName}) {
    throw UnsupportedError('IndexedDB is only available on web platform.');
  }

  @override
  Future<void> open(IndexedDbDatabaseDefinition definition) {
    throw UnsupportedError('IndexedDB is only available on web platform.');
  }

  @override
  Future<void> putAll({required String storeName, required List<dynamic> values}) {
    throw UnsupportedError('IndexedDB is only available on web platform.');
  }

  @override
  Future<void> put({required String storeName, required value, key}) {
    throw UnsupportedError('IndexedDB is only available on web platform.');
  }
}

IndexedDbService createIndexedDbServiceImpl() => UnsupportedIndexedDbService();
