import 'indexed_db_models.dart';

abstract class IndexedDbService {
  Future<void> open(IndexedDbDatabaseDefinition definition);

  Future<void> close();

  Future<void> deleteDatabase();

  bool get isOpen;

  Future<void> put({
    required String storeName,
    required dynamic value,
    dynamic key,
  });

  Future<void> putAll({
    required String storeName,
    required List<dynamic> values,
  });

  Future<dynamic> get({
    required String storeName,
    required dynamic key,
  });

  Future<List<dynamic>> getAll({required String storeName});

  Future<void> delete({
    required String storeName,
    required dynamic key,
  });

  Future<void> clearStore({required String storeName});

  Future<int> count({required String storeName});
}
