import 'dart:convert';

import 'package:fbpmn/src/utils/editor_config.dart';
import 'package:http/http.dart' as http;

import 'manager.dart';

class ShemaManager extends Manager {
  ShemaManager({Map<String, dynamic>? initialSchema}) {
    if (initialSchema != null) {
      _schema = _normalizeSchema(initialSchema);
    }
  }

  Map<String, dynamic> _schema = _defaultEmptySchema();

  Map<String, dynamic> get schema => _cloneMap(_schema);

  Map<String, dynamic> createEmptySchema({bool apply = true}) {
    final empty = _defaultEmptySchema();
    if (apply) {
      _schema = empty;
      onStateUpdate();
    }
    return _cloneMap(empty);
  }

  String createEmptySchemaString({bool apply = true, bool pretty = true}) {
    final empty = createEmptySchema(apply: apply);
    return _encodeSchema(empty, pretty: pretty);
  }

  Map<String, dynamic> createSchemaFromString(String schemaString, {bool apply = true}) {
    final parsed = decodeSchemaString(schemaString);
    final normalized = _normalizeSchema(parsed);

    if (apply) {
      _schema = normalized;
      onStateUpdate();
    }

    return _cloneMap(normalized);
  }

  void updateSchemaFromString(String schemaString, {bool merge = true}) {
    final parsed = decodeSchemaString(schemaString);
    updateSchema(parsed, merge: merge);
  }

  void updateSchema(Map<String, dynamic> schemaPatch, {bool merge = true}) {
    final normalizedPatch = _normalizeSchema(schemaPatch);

    _schema = merge ? _deepMerge(_schema, normalizedPatch) : normalizedPatch;
    _schema = _normalizeSchema(_schema);
    onStateUpdate();
  }

  String exportSchema({bool pretty = true}) {
    final normalized = _normalizeSchema(_schema);
    return _encodeSchema(normalized, pretty: pretty);
  }

  Map<String, dynamic> decodeSchemaString(String schemaString) {
    final source = schemaString.trim();
    if (source.isEmpty) {
      throw const FormatException('Schema string is empty');
    }

    final dynamic decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Schema must be a JSON object');
    }

    return Map<String, dynamic>.from(decoded);
  }

  String encodeSchemaMap(Map<String, dynamic> schemaMap, {bool pretty = true}) {
    final normalized = _normalizeSchema(schemaMap);
    return _encodeSchema(normalized, pretty: pretty);
  }

  /// Возвращает текущую схему.
  ///
  /// HTTP-загрузка выполняется только если [allowHttpLoad] == true.
  Future<Map<String, dynamic>> resolveSchema({
    bool allowHttpLoad = false,
    String? filePath,
    String fallbackFilePath = 'assets/diagram_3.json',
  }) async {
    if (!allowHttpLoad) {
      return schema;
    }

    final path = (filePath == null || filePath.trim().isEmpty) ? fallbackFilePath : filePath.trim();
    final response = await http.get(Uri.parse(path));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    return createSchemaFromString(response.body, apply: true);
  }

  void resetToDefaultEmptySchema() {
    _schema = _defaultEmptySchema();
    onStateUpdate();
  }

  static Map<String, dynamic> _defaultEmptySchema() {
    return {
      'metadata': {
        'qAdmin': '0',
        'dx': 0.0,
        'dy': 0.0,
        'pageWidth': EditorConfig.staticCanvasWidth,
        'pageHeight': EditorConfig.staticCanvasHeight,
        'objects': 0,
        'arrows': 0,
      },
      'objects': <dynamic>[],
      'arrows': <dynamic>[],
    };
  }

  Map<String, dynamic> _normalizeSchema(Map<String, dynamic> source) {
    final base = _defaultEmptySchema();

    final metadataFromSource = source['metadata'];
    final metadata = Map<String, dynamic>.from(base['metadata'] as Map<String, dynamic>);
    if (metadataFromSource is Map) {
      metadata.addAll(Map<String, dynamic>.from(metadataFromSource));
    }

    final objects = _extractList(source, primary: 'objects', fallback: 'nodes');
    final arrows = _extractList(source, primary: 'arrows', fallback: 'links');

    metadata['objects'] = objects.length;
    metadata['arrows'] = arrows.length;

    final Map<String, dynamic> additional = Map<String, dynamic>.from(source);
    additional.remove('metadata');
    additional.remove('objects');
    additional.remove('arrows');
    additional.remove('nodes');
    additional.remove('links');

    return {
      ..._cloneMap(additional),
      'metadata': _cloneMap(metadata),
      'objects': _cloneList(objects),
      'arrows': _cloneList(arrows),
    };
  }

  List<dynamic> _extractList(Map<String, dynamic> source, {required String primary, required String fallback}) {
    final primaryValue = source[primary];
    if (primaryValue is List) {
      return List<dynamic>.from(primaryValue);
    }

    final fallbackValue = source[fallback];
    if (fallbackValue is List) {
      return List<dynamic>.from(fallbackValue);
    }

    return <dynamic>[];
  }

  String _encodeSchema(Map<String, dynamic> data, {required bool pretty}) {
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(data);
    }
    return jsonEncode(data);
  }

  Map<String, dynamic> _deepMerge(Map<String, dynamic> target, Map<String, dynamic> patch) {
    final merged = _cloneMap(target);

    for (final entry in patch.entries) {
      final currentValue = merged[entry.key];
      final patchValue = entry.value;

      if (currentValue is Map && patchValue is Map) {
        merged[entry.key] = _deepMerge(
          Map<String, dynamic>.from(currentValue),
          Map<String, dynamic>.from(patchValue),
        );
      } else {
        merged[entry.key] = _cloneValue(patchValue);
      }
    }

    return merged;
  }

  Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
    final cloned = <String, dynamic>{};
    for (final entry in source.entries) {
      cloned[entry.key] = _cloneValue(entry.value);
    }
    return cloned;
  }

  List<dynamic> _cloneList(List<dynamic> source) {
    return source.map(_cloneValue).toList(growable: true);
  }

  dynamic _cloneValue(dynamic value) {
    if (value is Map) {
      return _cloneMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return _cloneList(List<dynamic>.from(value));
    }
    return value;
  }
}
