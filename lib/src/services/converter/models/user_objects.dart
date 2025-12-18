import 'package:xml/xml.dart';

/// Извлекает атрибуты с типами enumRow, enumPosition, enumValue

class UserObjects {
  /// Извлекает данные для user_objects
  static Map<String, dynamic>? extract(
    Iterable<XmlElement> userObjects,
    String parent,
  ) {
    Map<String, dynamic>? userObject;
    final userObjectElement = userObjects.where((element) {
      final mxCell = element.findElements('mxCell').firstOrNull;
      return mxCell?.getAttribute('parent') == parent;
    }).firstOrNull;
    final List<String> notIncludeAttrs = ['parent', 'vertex'];

    try {
      if (userObjectElement != null) {
        userObject = {};
        for (final attr in userObjectElement.attributes) {
          if (attr.value != '') {
            userObject[attr.localName] = attr.value;
          }
        }

        final mxCell = userObjectElement.findElements('mxCell').firstOrNull;
        final geometry = mxCell?.findElements('mxGeometry').firstOrNull;

        for (final attr in mxCell?.attributes ?? []) {
          if (!notIncludeAttrs.contains(attr.localName) &&
              attr.value != null &&
              attr.value != '') {
            userObject[attr.localName] = attr.value;
          }
        }

        // Добавляем geometry из вложенного mxCell
        if (geometry != null) {
          userObject['geometry'] = {
            'x': double.tryParse(geometry.getAttribute('x') ?? '0') ?? 0.0,
            'y': double.tryParse(geometry.getAttribute('y') ?? '0') ?? 0.0,
            'width':
                double.tryParse(geometry.getAttribute('width') ?? '0') ?? 0.0,
            'height':
                double.tryParse(geometry.getAttribute('height') ?? '0') ?? 0.0,
          };
        }
      }
    } catch (e) {
      print('Ошибка при извлечении arrowObjects: $e');
    }

    return userObject;
  }
}
