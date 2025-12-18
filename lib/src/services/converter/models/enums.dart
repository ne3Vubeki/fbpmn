import 'package:xml/xml.dart';

/// Извлекает атрибуты с типами enumRow, enumPosition, enumValue

class Enums {
  static List<Map<String, dynamic>> extract(
    String enumId,
    List<XmlElement?> enumRows,
    List<XmlElement?> enumPositions,
    List<XmlElement?> enumValues,
  ) {
    final enumItems = <Map<String, dynamic>>[];

    try {
      // Ищем все enumRow элементы, которые принадлежат данному enum объекту
      final rowsForThisEnum = enumRows
          .where((row) => row!.getAttribute('parent') == enumId)
          .toList();

      for (final row in rowsForThisEnum) {
        final rowId = row!.getAttribute('id') ?? 'unknown';

        // Ищем enumPosition для данного row (порядковый номер)
        final positionElement = enumPositions.firstWhere(
          (pos) => pos!.getAttribute('parent') == rowId,
          orElse: () => XmlElement(XmlName('empty')),
        );

        // Ищем enumValue для данного row (значение)
        final valueElement = enumValues.firstWhere(
          (val) => val!.getAttribute('parent') == rowId,
          orElse: () => XmlElement(XmlName('empty')),
        );

        final enumItem = {
          'id': rowId,
          'style': row.getAttribute('style') ?? '',
          'qCompStatus': row.getAttribute('qCompStatus') ?? '',
          'qType': row.getAttribute('qType') ?? '',
          'originalId': row.getAttribute('originalId') ?? '',
          'position': positionElement?.getAttribute('value') ?? '',
          'label': valueElement?.getAttribute('value') ?? '',
          'geometry': _extractGeometry(
            row.findElements('mxGeometry').firstOrNull,
          ),
        };

        enumItems.add(enumItem);
      }

      // Сортируем элементы по позиции (если позиция числовая)
      enumItems.sort((a, b) {
        final posA = int.tryParse(a['position'] ?? '0') ?? 0;
        final posB = int.tryParse(b['position'] ?? '0') ?? 0;
        return posA.compareTo(posB);
      });
    } catch (e) {
      print('Ошибка при извлечении enum атрибутов для $enumId: $e');
    }

    return enumItems;
  }

  /// Извлекает геометрию из mxGeometry элемента
  static Map<String, dynamic>? _extractGeometry(XmlElement? geometryElement) {
    if (geometryElement == null) return null;

    return {
      'x': double.tryParse(geometryElement.getAttribute('x') ?? '0') ?? 0.0,
      'y': double.tryParse(geometryElement.getAttribute('y') ?? '0') ?? 0.0,
      'width':
          double.tryParse(geometryElement.getAttribute('width') ?? '0') ?? 0.0,
      'height':
          double.tryParse(geometryElement.getAttribute('height') ?? '0') ?? 0.0,
    };
  }
}
