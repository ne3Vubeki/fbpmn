import 'dart:convert';
import 'package:xml/xml.dart';

import 'models/arrows.dart';
import 'models/objects.dart';

class DiagramCompiler {
  static String compileXmlToJson(String xmlContent) {
    try {
      final stopwatch = Stopwatch()..start();
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement;
      final objects = BObjects.extract(root);
      final arrows = Arrows.extract(root);
      final metadata = _extractMetadata(
        root,
        objectLength: objects.length,
        arrowLength: arrows.length,
      );

      stopwatch.stop();
      final executionTime = stopwatch.elapsedMicroseconds / 1000.0;

      metadata['time_convert'] = executionTime;

      final result = {
        'metadata': metadata,
        'objects': objects,
        'arrows': arrows,
      };

      return JsonEncoder.withIndent('  ').convert(result);
    } on XmlParserException catch (e) {
      throw Exception('Ошибка парсинга XML: $e');
    } catch (e) {
      throw Exception('Ошибка компиляции XML в JSON: $e');
    }
  }

  static Map<String, dynamic> _extractMetadata(
    XmlElement root, {
    int objectLength = 0,
    int arrowLength = 0,
  }) {
    try {
      return {
        'qAdmin': root.getAttribute('qAdmin'),
        'dx': int.tryParse(root.getAttribute('dx') ?? '0'),
        'dy': int.tryParse(root.getAttribute('dy') ?? '0'),
        'pageWidth':
            int.tryParse(root.getAttribute('pageWidth') ?? '800') ?? 800,
        'pageHeight':
            int.tryParse(root.getAttribute('pageHeight') ?? '1200') ?? 1200,
        'objects': objectLength,
        'arrows': arrowLength,
      };
    } catch (e) {
      return {
        'qAdmin': '0',
        'dx': 0,
        'dy': 0,
        'pageWidth': 800,
        'pageHeight': 1200,
      };
    }
  }
}
