class Styles {

    static Map<String, dynamic> extract(
    String styleString, {
    List<String> addStyleKeys = const [],
    bool isAll = false,
  }) {
    final style = <String, dynamic>{};
    final List<String> styleKeys = ['shape', 'fillColor', 'align'];

    styleKeys.addAll(addStyleKeys);

    try {
      final parts = styleString.split(';');
      for (final part in parts) {
        if (part.trim().isEmpty) continue;

        final keyValue = part.split('=');
        final key = keyValue[0].trim();
        if (keyValue.length == 2 && (isAll || styleKeys.contains(key))) {
          style[key] = keyValue[1].trim();
        }
      }
    } catch (e) {
      // Возвращаем пустой стиль при ошибке парсинга
      print('Ошибка парсинга стиля: $e для строки: $styleString');
    }

    return style;
  }

}