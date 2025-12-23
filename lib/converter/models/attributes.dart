import 'package:xml/xml.dart';

import 'user_objects.dart';

/// Извлекает атрибуты с типами enumRow, enumPosition, enumValue

class Attributes {
  /// Проверяет, является ли элемент атрибутом
  /// Атрибут имеет id в формате: цифры_название_param
  static bool _isAttributeElement(XmlElement element) {
    final id = element.getAttribute('id') ?? '';

    // Проверяем формат: цифры_название_param
    final parts = id.split('_');
    if (parts.length != 3) {
      return false;
    }

    // Первая часть должна быть цифрами
    if (!RegExp(r'^\d+$').hasMatch(parts[0])) {
      return false;
    }

    // Последняя часть должна быть 'param'
    if (parts[2] != 'param') {
      return false;
    }

    return true;
  }

  /// Извлекает атрибуты для указанного объекта BO
  /// Принимает id объекта BO и возвращает список атрибутов
  static List<Map<String, dynamic>> extract(
    Iterable<XmlElement> objects,
    Iterable<XmlElement> userObjects,
    String boId,
  ) {
    final attributes = <Map<String, dynamic>>[];
    final List<String> notIncludeAttrs = ['vertex', 'parent'];

    try {
      // Ищем все элементы object в документе
      final allElements = objects;

      print(
        'Поиск атрибутов для объекта $boId. Всего элементов: ${allElements.length}',
      );

      for (final element in allElements) {
        try {
          final attributeParamId = element.getAttribute('id') ?? '';

          // Проверяем, является ли элемент атрибутом
          if (!_isAttributeElement(element)) {
            continue;
          }

          // Извлекаем id объекта из id атрибута (первая часть до первой '_')
          final attributeBoId = attributeParamId.split('_')[0];

          // Проверяем, принадлежит ли атрибут текущему объекту
          if (attributeBoId != boId) {
            continue;
          }

          // Ищем вложенный mxCell для geometry и style
          final mxCell = element.findElements('mxCell').firstOrNull;

          // Извлекаем все атрибуты элемента для params
          final params = <String, dynamic>{};
          for (final attribute in element.attributes) {
            final name = attribute.name.qualified;
            final value = attribute.value;

            // Пропускаем id и label, так как они будут отдельными полями
            if (name == 'id' || name == 'label') {
              continue;
            }

            params[name] = value;
          }

          // Извлекаем boAttributeTypeId из id атрибута (вторая часть между '_')
          final idParts = attributeParamId.split('_');
          final boAttributeTypeId = idParts.length > 1 ? idParts[1] : '';
          Map<String, dynamic> attribute = {
            'id': '${idParts[0]}_${idParts[1]}',
            'label': element.getAttribute('label') ?? '',
            'boAttributeTypeId': boAttributeTypeId,
            'params': params,
          };

          for (final attr in mxCell?.attributes ?? []) {
            if (!notIncludeAttrs.contains(attr.localName) &&
                attr.value != null &&
                attr.value != '') {
              attribute[attr.localName] = attr.value;
            }
          }

          attribute['user_object'] = UserObjects.extract(
            userObjects,
            '${idParts[0]}_${idParts[1]}',
          );

          attributes.add(attribute);
          print(
            'Найден атрибут: ${idParts[0]}_${idParts[1]} для объекта $boId',
          );
        } catch (e) {
          print(
            'Предупреждение: не удалось обработать потенциальный атрибут: $e',
          );
        }
      }

      print('Найдено атрибутов для объекта $boId: ${attributes.length}');
    } catch (e) {
      print('Ошибка при извлечении атрибутов для объекта $boId: $e');
    }

    return attributes;
  }
}
