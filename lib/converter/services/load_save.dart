import 'dart:io';

class LoadSave {
  /// Загружает XML содержимое из файла и возвращает как строку
  static Future<String> loadXmlFromFile(String filePath) async {
    try {
      final file = File(filePath);

      // Проверяем существование файла
      if (!await file.exists()) {
        throw Exception('Файл $filePath не найден');
      }

      // Читаем содержимое файла
      return await file.readAsString();
    } catch (e) {
      throw Exception('Не удалось загрузить XML из файла $filePath: $e');
    }
  }

  /// Сохраняет JSON строку в файл
  static Future<void> saveJsonToFile(String jsonString, String fileName) async {
    try {
      final file = File(fileName);

      // Создаем директорию, если она не существует
      final directory = file.parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      await file.writeAsString(jsonString);
    } catch (e) {
      throw Exception('Не удалось сохранить файл $fileName: $e');
    }
  }
}