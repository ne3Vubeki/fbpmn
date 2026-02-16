/// Сервис для генерации сквозных ID.
/// ID представляет собой строку из 13 цифр.
class IDManager {
  static final IDManager _instance = IDManager._internal();
  factory IDManager() => _instance;
  IDManager._internal();

  /// Текущий максимальный ID
  BigInt _currentMaxId = BigInt.zero;

  /// Геттер для текущего максимального ID
  BigInt get currentMaxId => _currentMaxId;

  /// Регулярное выражение для проверки валидного ID (только 13 цифр)
  static final RegExp _validIdPattern = RegExp(r'^\d{13}$');

  /// Проверяет, является ли строка валидным 13-значным числовым ID
  bool isValidId(String id) {
    return _validIdPattern.hasMatch(id);
  }

  /// Обрабатывает JSON данные схемы и находит максимальный ID.
  /// Возвращает найденный максимальный ID или null, если валидных ID не найдено.
  BigInt? parseJsonAndFindMaxId(Map<String, dynamic> json) {
    BigInt? maxId;

    void processId(String? id) {
      if (id == null) return;
      if (!isValidId(id)) return;

      final parsedId = BigInt.tryParse(id);
      if (parsedId != null) {
        if (maxId == null || parsedId > maxId!) {
          maxId = parsedId;
        }
      }
    }

    // Обработка объектов
    final objects = json['objects'] as List<dynamic>?;
    if (objects != null) {
      for (final obj in objects) {
        if (obj is Map<String, dynamic>) {
          processId(obj['id'] as String?);

          // Обработка атрибутов объекта
          final attributes = obj['attributes'] as List<dynamic>?;
          if (attributes != null) {
            for (final attr in attributes) {
              if (attr is Map<String, dynamic>) {
                // Атрибуты имеют составные ID (например, "1768315075754_startDate")
                // Извлекаем базовый ID
                final attrId = attr['id'] as String?;
                if (attrId != null) {
                  final baseId = attrId.split('_').first;
                  processId(baseId);
                }

                // Проверяем user_object
                final userObject = attr['user_object'] as Map<String, dynamic>?;
                if (userObject != null) {
                  final userObjId = userObject['id'] as String?;
                  if (userObjId != null) {
                    final baseId = userObjId.split('_').first;
                    processId(baseId);
                  }
                }
              }
            }
          }
        }
      }
    }

    // Обработка стрелок
    final arrows = json['arrows'] as List<dynamic>?;
    if (arrows != null) {
      for (final arrow in arrows) {
        if (arrow is Map<String, dynamic>) {
          processId(arrow['id'] as String?);

          // Обработка powers стрелок
          final powers = arrow['powers'] as List<dynamic>?;
          if (powers != null) {
            for (final power in powers) {
              if (power is Map<String, dynamic>) {
                processId(power['id'] as String?);
              }
            }
          }
        }
      }
    }

    return maxId;
  }

  /// Инициализирует менеджер на основе JSON данных схемы.
  /// Если схема новая (нет валидных ID), начинает с 0.
  void initializeFromJson(Map<String, dynamic> json) {
    final maxId = parseJsonAndFindMaxId(json);
    _currentMaxId = maxId ?? BigInt.zero;
  }

  /// Сбрасывает состояние для новой схемы
  void reset() {
    _currentMaxId = BigInt.zero;
  }

  /// Генерирует следующий ID и обновляет состояние.
  /// Возвращает строку из 13 цифр.
  String generateNextId() {
    _currentMaxId += BigInt.one;
    return _formatId(_currentMaxId);
  }

  /// Форматирует BigInt в строку из 13 цифр с ведущими нулями
  String _formatId(BigInt id) {
    return id.toString().padLeft(13, '0');
  }

  /// Устанавливает максимальный ID вручную (для тестирования или восстановления)
  void setMaxId(BigInt id) {
    _currentMaxId = id;
  }

  /// Возвращает текущий максимальный ID в виде отформатированной строки
  String getCurrentMaxIdFormatted() {
    return _formatId(_currentMaxId);
  }
}
