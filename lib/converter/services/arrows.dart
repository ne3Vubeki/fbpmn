import 'package:xml/xml.dart';

class Arrows {
  /// Извлекает связи между объектами из XML документа
  static List<Map<String, dynamic>> extract(XmlElement root) {
    final arrows = <Map<String, dynamic>>[];

    try {
      print('Начало извлечения связей...');

      // 1. Ищем объекты с qType=arrowObject
      final arrowObjects = root
          .findAllElements('object')
          .where((element) => element.getAttribute('qType') == 'arrowObject');
      print('Найдено arrowObject: ${arrowObjects.length}');

      // 2. Ищем объекты с param_q_relationship1="" param_q_relationship2=""
      final relationshipObjects = root
          .findAllElements('object')
          .where(
            (element) =>
                element.getAttribute('param_q_relationship1') != null &&
                element.getAttribute('param_q_relationship2') != null,
          );
      print('Найдено relationship объектов: ${relationshipObjects.length}');

      // 3. Ищем mxCell с edge="1"
      final edgeCells = root
          .findAllElements('mxCell')
          .where(
            (element) =>
                element.getAttribute('edge') == '1' &&
                element.getAttribute('qJrelation') != null,
          );
      print('Найдено edge, qJrelation элементов: ${edgeCells.length}');

      // Обрабатываем все найденные связи
      for (final arrowElement in arrowObjects) {
        try {
          final arrow = _extractArrowObject(arrowElement, root);
          if (arrow.isNotEmpty) {
            arrows.add(arrow);
          }
        } catch (e) {
          print('Ошибка при обработке arrowObject: $e');
        }
      }

      for (final relationshipElement in relationshipObjects) {
        try {
          final arrow = _extractRelationshipObject(relationshipElement, root);
          if (arrow.isNotEmpty) {
            arrows.add(arrow);
          }
        } catch (e) {
          print('Ошибка при обработке relationship: $e');
        }
      }

      for (final edgeElement in edgeCells) {
        try {
          final arrow = _extractEdgeObject(edgeElement, root);
          if (arrow.isNotEmpty) {
            arrows.add(arrow);
          }
        } catch (e) {
          print('Ошибка при обработке edge: $e');
        }
      }

      print('Успешно обработано связей: ${arrows.length}');
    } catch (e) {
      print('Ошибка при извлечении связей: $e');
    }

    return arrows;
  }

  /// Извлекает данные для arrowObject
  static Map<String, dynamic> _extractArrowObject(
    XmlElement arrowElement,
    XmlElement root,
  ) {
    final arrow = <String, dynamic>{};

    final List<String> notIncludeAttrs = [
      'parent',
      'qType',
      'qCompStatus',
      'edge',
    ];

    try {
      for (final attr in arrowElement.attributes) {
        if (attr.value != '') {
          arrow[attr.localName] = attr.value;
        }
      }

      final mxCell = arrowElement.findElements('mxCell').firstOrNull;

      for (final attr in mxCell?.attributes ?? []) {
        if (!notIncludeAttrs.contains(attr.localName) &&
            attr.value != null &&
            attr.value != '') {
          arrow[attr.localName] = attr.value;
        }
      }

      // Извлекаем points
      if (mxCell != null) {
        final points = _extractAllPoints(mxCell);
        if (points.isNotEmpty) {
          arrow['points'] = points;
        }
      }

      final powers = _extractPowerData(root, arrowElement);
      if (powers.isNotEmpty) {
        arrow['powers'] = powers;
      }
    } catch (e) {
      print('Ошибка при извлечении arrowObjects: $e');
    }

    return arrow;
  }

  /// Извлекает данные для relationship объекта
  static Map<String, dynamic> _extractRelationshipObject(
    XmlElement relationshipElement,
    XmlElement root,
  ) {
    final arrow = <String, dynamic>{};
    final List<String> notIncludeAttrs = ['parent', 'edge'];

    try {
      for (final attr in relationshipElement.attributes) {
        if (attr.value != '') {
          arrow[attr.localName] = attr.value;
        }
      }

      arrow['qType'] = 'qRelationship';

      final mxCell = relationshipElement.findElements('mxCell').firstOrNull;

      for (final attr in mxCell?.attributes ?? []) {
        if (!notIncludeAttrs.contains(attr.localName) &&
            attr.value != null &&
            attr.value != '') {
          arrow[attr.localName] = attr.value;
        }
      }

      // Извлекаем points
      if (mxCell != null) {
        final points = _extractAllPoints(mxCell);
        if (points.isNotEmpty) {
          arrow['points'] = points;
        }
      }
    } catch (e) {
      print('Ошибка при извлечении relationships: $e');
    }

    return arrow;
  }

  /// Извлекает данные для edge объекта
  static Map<String, dynamic> _extractEdgeObject(
    XmlElement edgeElement,
    XmlElement root,
  ) {
    final arrow = <String, dynamic>{};
    final List<String> notIncludeAttrs = ['parent', 'edge'];

    try {
      for (final attr in edgeElement.attributes) {
        if (!notIncludeAttrs.contains(attr.localName) && attr.value != '') {
          arrow[attr.localName] = attr.value;
        }
      }

      arrow['qType'] = 'qEdgeToJson';

      // Извлекаем points
      final points = _extractAllPoints(edgeElement);
      if (points.isNotEmpty) {
        arrow['points'] = points;
      }
    } catch (e) {
      print('Ошибка при извлечении edges: $e');
    }

    return arrow;
  }

  /// Извлекает точки из всех элемента
  static List<Map<String, dynamic>> _extractAllPoints(XmlElement element) {
    final points = <Map<String, dynamic>>[];

    try {
      // Ищем Array as="points" внутри geometry
      final geometry = element.findElements('mxGeometry').firstOrNull;
      if (geometry != null) {
        final arrayPoints = geometry.findElements('mxPoint');
        final arrayElements = geometry.findElements('Array');
        points.addAll(_extractPoints(arrayPoints));
        for (final array in arrayElements) {
          if (array.getAttribute('as') == 'points') {
            points.addAll(_extractPoints(array.findElements('mxPoint')));
          }
        }
      }
    } catch (e) {
      print('Ошибка при извлечении точек: $e');
    }

    return points;
  }

  /// Извлекает точки из элемента
  static List<Map<String, dynamic>> _extractPoints(
    Iterable<XmlElement> xmlPoints,
  ) {
    final points = <Map<String, dynamic>>[];

    try {
      for (final point in xmlPoints) {
        final Map<String, dynamic> pointData = {
          'x': double.tryParse(point.getAttribute('x') ?? '0') ?? 0.0,
          'y': double.tryParse(point.getAttribute('y') ?? '0') ?? 0.0,
        };

        // Добавляем as если есть
        final asValue = point.getAttribute('as');
        if (asValue != null && asValue.isNotEmpty) {
          pointData['type'] = asValue;
        }

        points.add(pointData);
      }
    } catch (e) {
      print('Ошибка при извлечении точек: $e');
    }

    return points;
  }

  /// Извлекает данные power элемента
  static List<Map<String, dynamic>> _extractPowerData(
    XmlElement root,
    XmlElement parent,
  ) {
    final powers = <Map<String, dynamic>>[];
    final List<String> notIncludeAttrs = ['parent', 'vertex'];

    final powerElements = root
        .findAllElements('mxCell')
        .where(
          (element) => element.getAttribute('parent') == parent.getAttribute('id')
        );

    try {
      for (final powerElement in powerElements) {
        final power = <String, dynamic>{};

        for (final attr in powerElement.attributes) {
          if (!notIncludeAttrs.contains(attr.localName) && attr.value != '') {
            power[attr.localName] = attr.value;
          }
        }

        final geometry = powerElement.findElements('mxGeometry').firstOrNull;
        if (geometry != null) {
          power['side'] = geometry.getAttribute('x');
        }

        if (power.isNotEmpty) {
          powers.add(power);
        }
      }
    } catch (e) {
      print('Ошибка при извлечении power данных: $e');
    }

    return powers;
  }
}
