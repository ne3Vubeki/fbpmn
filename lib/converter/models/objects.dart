import 'package:xml/xml.dart';

import 'attributes.dart';
import 'enums.dart';
import 'user_objects.dart';

// import 'styles.dart';

class BObjects {
  static List<Map<String, dynamic>> extract(XmlElement root) {
    final objects = <Map<String, dynamic>>[];
    final List<String> notIncludeAttrs = ['vertex'];

    // Ищем все элементы object в документе, включая вложенные
    final allObjects = root.findAllElements('object');
    final allUserObjects = root.findAllElements('UserObject');
    final allMxCells = root.findAllElements('mxCell').toList();
    print('Найдено элементов object: ${allObjects.length}');

    List<XmlElement?> allGroups = [];
    List<XmlElement?> allRowEnums = [];
    List<XmlElement?> allPosEnums = [];
    List<XmlElement?> allValueEnums = [];

    // Собираем данные из mxCell для дальнейшей обработки
    for (final element in allMxCells) {
      if (element.getAttribute('style') == 'group') {
        allGroups.add(element);
      } else if (element.getAttribute('qType') == 'enumRow') {
        allRowEnums.add(element);
      } else if (element.getAttribute('qType') == 'enumPosition') {
        allPosEnums.add(element);
      } else if (element.getAttribute('qType') == 'enumValue') {
        allValueEnums.add(element);
      }
    }

    print('Найдено элементов group: ${allGroups.length}');
    print('Найдено элементов enumRow: ${allRowEnums.length}');

    try {
      for (final element in allObjects) {
        try {
          Map<String, dynamic> object = {};
          // Сохрняем атрибуты тега object
          final objectId = element.getAttribute('id') ?? '';
          for (final attribute in element.attributes) {
            object[attribute.localName] = attribute.value;
          }

          // Проверяем, что id состоит только из цифр без символов '_'
          if (!RegExp(r'^\d+$').hasMatch(objectId)) {
            print('Пропущен объект с некорректным id: $objectId');
            continue;
          }

          // Ищем вложенный mxCell для geometry и style
          final mxCell = element.findElements('mxCell').firstOrNull;
          final geometry = mxCell?.findElements('mxGeometry').firstOrNull;

          // Проверяем, что qType корректный
          if (mxCell?.getAttribute('qType') == 'arrow') {
            print('Пропущен объект с некорректным qType');
            continue;
          }

          // Проверяем, что принадлежность объекта к связям
          if (mxCell?.getAttribute('source') != null &&
              mxCell?.getAttribute('target') != null) {
            print('Пропущен объект связи');
            continue;
          }

          // Сохраняем атрибуты тега mxCell
          for (final attr in mxCell?.attributes ?? []) {
            if (!notIncludeAttrs.contains(attr.localName) &&
                attr.value != null &&
                attr.value != '') {
              object[attr.localName] = attr.value;
            }
          }

          // Определяем принадлежность к группе
          final isGroup = allGroups.any(
            (group) => group!.getAttribute('id') == object['parent'],
          );
          final isGroupChild = isGroup && object['originalId'] != null;
          if (isGroup && !isGroupChild) {
            object['groupId'] = object['parent'];
          }

          if (object['qType'] != 'enum') {
            // Добавляем attributes в объект
            object['attributes'] = Attributes.extract(
              allObjects,
              allUserObjects,
              objectId,
            );
          } else {
            object['attributes'] = Enums.extract(
              object['id'],
              allRowEnums,
              allPosEnums,
              allValueEnums,
            );
          }

          // Добавляем geometry из вложенного mxCell
          if (geometry != null) {
            object['geometry'] = {
              'x': double.tryParse(geometry.getAttribute('x') ?? '0') ?? 0.0,
              'y': double.tryParse(geometry.getAttribute('y') ?? '0') ?? 0.0,
              'width':
                  double.tryParse(geometry.getAttribute('width') ?? '0') ?? 0.0,
              'height':
                  double.tryParse(geometry.getAttribute('height') ?? '0') ??
                  0.0,
            };
          }

          // Добавляем user_object из UserObject
          final userObject = UserObjects.extract(allUserObjects, objectId);
          if (userObject != null) {
            object['user_object'] = userObject;
          }

          if (isGroupChild) {
            Map<String, dynamic> group = objects.firstWhere(
              (obj) => obj['groupId'] == object['parent'],
            );
            group['children'] = group['children'] ?? [];
            group['children'].add(object);
          } else {
            objects.add(object);
          }
        } catch (e) {
          print('Предупреждение: не удалось обработать объект: $e');
        }
      }

      print('Всего обработано объектов: ${objects.length}');
    } catch (e) {
      print('Ошибка при извлечении объектов: $e');
    }

    objects.addAll(_extractJsonContainers(root));
    return objects;
  }

  /// Извлекает и парсит JSON контейнеры
  /// Ищет элементы с qType=jsonContainer и связанные с ними элементы
  static List<Map<String, dynamic>> _extractJsonContainers(XmlElement root) {
    final jsonContainers = <Map<String, dynamic>>[];
    final List<String> notIncludeAttrs = [
      'id',
      'parent',
      'vertex',
      'deletable',
    ];

    try {
      // Ищем все элементы с qType=jsonContainer
      final containerElements = root
          .findAllElements('mxCell')
          .where((element) => element.getAttribute('qType') == 'jsonContainer');

      print('Найдено JSON контейнеров: ${containerElements.length}');

      for (final containerElement in containerElements) {
        try {
          final containerId = containerElement.getAttribute('id') ?? '';
          final boAttributeId =
              containerElement.getAttribute('qBoAttributeId') ?? '';

          // Ищем связанный элемент с parent = containerId
          final relatedElements = root
              .findAllElements('mxCell')
              .where(
                (element) => element.getAttribute('parent') == containerId,
              );

          Map<String, dynamic> jsonContainer = {
            'id': containerId,
            'qType': 'jsonContainer',
            'qBoAttributeId': boAttributeId,
            'name': containerElement.getAttribute('value'),
            'style': containerElement.getAttribute('style'),
            'geometry': {},
          };

          // Добавляем атрибуты из контейнера
          for (final attribute in containerElement.attributes) {
            final name = attribute.localName;
            final value = attribute.value;
            if (value.isNotEmpty && !notIncludeAttrs.contains(name)) {
              jsonContainer[name] = value;
            }
          }

          // Добавляем geometry из контейнера
          final containerGeometry = containerElement
              .findElements('mxGeometry')
              .firstOrNull;
          if (containerGeometry != null) {
            jsonContainer['geometry'] = {
              'x':
                  double.tryParse(containerGeometry.getAttribute('x') ?? '0') ??
                  0.0,
              'y':
                  double.tryParse(containerGeometry.getAttribute('y') ?? '0') ??
                  0.0,
              'width':
                  double.tryParse(
                    containerGeometry.getAttribute('width') ?? '0',
                  ) ??
                  0.0,
              'height':
                  double.tryParse(
                    containerGeometry.getAttribute('height') ?? '0',
                  ) ??
                  0.0,
            };
          }

          // Ищем связанный элемент с JSON телом
          for (final relatedElement in relatedElements) {
            final relatedQType = relatedElement.getAttribute('qType');
            if (relatedQType == 'jsonBody') {
              // Извлекаем значение JSON из атрибута value
              final jsonValue = relatedElement.getAttribute('value') ?? '';
              jsonContainer['value'] = jsonValue;

              // Пытаемся парсить JSON, если он валидный
              // try {
              //   if (jsonValue.isNotEmpty) {
              //     final parsedJson = jsonDecode(jsonValue);
              //     jsonContainer['parsed'] = parsedJson;
              //   }
              // } catch (e) {
              //   print('Ошибка парсинга JSON для контейнера $containerId: $e');
              // }

              // Добавляем атрибуты из связанного элемента
              for (final attribute in relatedElement.attributes) {
                final name = attribute.localName;
                final value = attribute.value;
                if (value.isNotEmpty &&
                    !notIncludeAttrs.contains(name) &&
                    name != 'value' &&
                    name != 'qType') {
                  jsonContainer[name] = value;
                }
              }

              // Добавляем geometry из связанного элемента
              // final relatedGeometry = relatedElement.findElements('mxGeometry').firstOrNull;
              // if (relatedGeometry != null) {
              //   jsonContainer['relatedGeometry'] = {
              //     'x': double.tryParse(relatedGeometry.getAttribute('x') ?? '0') ?? 0.0,
              //     'y': double.tryParse(relatedGeometry.getAttribute('y') ?? '0') ?? 0.0,
              //     'width': double.tryParse(relatedGeometry.getAttribute('width') ?? '0') ?? 0.0,
              //     'height': double.tryParse(relatedGeometry.getAttribute('height') ?? '0') ?? 0.0,
              //   };
              // }

              break; // Нашли связанный элемент, выходим из цикла
            }
          }

          jsonContainers.add(jsonContainer);
          print(
            'Обработан JSON контейнер: $containerId для атрибута: $boAttributeId',
          );
        } catch (e) {
          print('Ошибка при обработке JSON контейнера: $e');
        }
      }

      print('Всего обработано JSON контейнеров: ${jsonContainers.length}');
    } catch (e) {
      print('Ошибка при извлечении JSON контейнеров: $e');
    }

    return jsonContainers;
  }

}
