import 'dart:convert';
import 'dart:js_interop';

/// JavaScript interop extension type для EventAction
///
/// Обеспечивает взаимодействие между Dart и JavaScript объектами EventAction
@JS()
@staticInterop
extension type JSEventAction._(JSObject _) implements JSObject {
  /// Создает новый JavaScript EventAction объект
  external JSEventAction();

  /// Получает действие (action) из JavaScript объекта
  external JSString getActionJS();

  /// Получает источник (source) из JavaScript объекта
  external JSString getSourceJS();

  /// Получает массив целей (targets) из JavaScript объекта
  external JSArray<JSString> getTargetsJS();

  /// Получает дополнительные данные (data) из JavaScript объекта
  external JSString? getDataJS();

  external void setActionJS(JSString action);
  external void setSourceJS(JSString source);
  external void setTargetsJS(JSArray<JSString> targets);
  external void setDataJS(JSString? data);
}

/// Dart класс для представления EventAction с поддержкой JavaScript interop
///
/// Содержит информацию о действии, источнике, целях и дополнительных данных.
/// Поддерживает преобразование между Dart и JavaScript форматами.
@JSExport()
class EventAction {
  /// Создает новый экземпляр EventAction
  ///
  /// [action] - тип действия
  /// [source] - источник/приложение действия
  /// [targets] - список целей/приложений действия (опционально)
  /// [data] - дополнительные данные в формате Map (опционально)
  EventAction({required String action, required String source, List<String>? targets, Map<String, dynamic>? data})
    : _action = action,
      _data = data,
      _source = source,
      _targets = targets;

  /// Тип действия
  String _action;

  /// Список целей действия (опционально)
  List<String>? _targets;

  /// Источник/приложение действия
  String _source;

  /// Дополнительные данные в формате Map (опционально)
  Map<String, dynamic>? _data;

  /// Получает действие в формате JavaScript строки
  ///
  /// Возвращает: JSString представление поля _action
  JSString getActionJS() {
    return _action.toJS;
  }

  /// Устанавливает действие из JavaScript строки
  ///
  /// [action] - JavaScript строка с типом действия
  void setActionJS(JSString action) {
    _action = action.toDart;
  }

  /// Получает список целей в формате JavaScript массива строк
  ///
  /// Возвращает: JSArray<JSString> представление поля _targets
  /// Если _targets равно null, возвращает пустой массив
  JSArray<JSString> getTargetsJS() {
    List<JSString> listJsString = _targets?.map((String target) => target.toJS).toList() ?? [];
    return listJsString.toJS;
  }

  /// Устанавливает список целей из JavaScript массива строк
  ///
  /// [targets] - JavaScript массив строк с целями действия
  void setTargetsJS(JSArray<JSString> targets) {
    try {
      final dartList = targets.toDart;
      _targets = dartList
          .map((item) {
            try {
              return item.toDart;
            } catch (e) {
              print('Error converting target in setTargetsJS: $e');
              return '';
            }
          })
          .where((item) => item.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error processing targets array: $e');
      _targets = [];
    }
  }

  /// Получает дополнительные данные в формате JSON строки
  ///
  /// Возвращает: JSString представление поля _data в формате JSON
  /// Если _data равно null, возвращает null
  JSString? getDataJS() {
    try {
      final Map<String, dynamic>? data = getDataDart();
      if (data != null) {
        final String jsonString = jsonEncode(data);
        return jsonString.toJS;
      }
      return null;
    } catch (e) {
      print('Error encoding JSON in getDataJS: $e');
      return null;
    }
  }

  /// Устанавливает дополнительные данные из JSON строки
  ///
  /// [jsonString] - JSON строка с дополнительными данными (может быть пустой)
  void setDataJS(JSString jsonString) {
    try {
      final String jsonStr = jsonString.toDart;
      if (jsonStr.isNotEmpty) {
        final Map<String, dynamic> data = Map.from(jsonDecode(jsonStr) as Map<String, dynamic>);
        setDataDart(data);
      }
    } catch (e) {
      print('Error parsing JSON in setDataJS: $e');
    }
  }

  /// Получает источник в формате JavaScript строки
  ///
  /// Возвращает: JSString представление поля _source
  JSString getSourceJS() {
    return _source.toJS;
  }

  /// Устанавливает источник из JavaScript строки
  ///
  /// [source] - JavaScript строка с источником действия
  void setSourceJS(JSString source) {
    _source = source.toDart;
  }

  /// Получает действие в формате Dart строки
  ///
  /// Возвращает: String значение поля _action
  String getActionDart() {
    return _action;
  }

  /// Устанавливает действие из Dart строки
  ///
  /// [action] - строка с типом действия
  void setActionDart(String action) {
    _action = action;
  }

  /// Получает список целей в формате Dart списка строк
  ///
  /// Возвращает: List<String>? значение поля _targets
  List<String>? getTargetsDart() {
    return _targets;
  }

  /// Устанавливает список целей из Dart списка строк
  ///
  /// [targets] - список строк с целями действия (может быть null)
  void setTargetsDart(List<String>? targets) {
    _targets = targets;
  }

  /// Получает дополнительные данные в формате Dart Map
  ///
  /// Возвращает: Map<String, dynamic>? значение поля _data
  Map<String, dynamic>? getDataDart() {
    return _data;
  }

  /// Устанавливает дополнительные данные из Dart Map
  ///
  /// [data] - Map<String, dynamic> с дополнительными данными (может быть null)
  void setDataDart(Map<String, dynamic>? data) {
    _data = data;
  }

  /// Получает источник в формате Dart строки
  ///
  /// Возвращает: String значение поля _source
  String getSourceDart() {
    return _source;
  }

  /// Устанавливает источник из Dart строки
  ///
  /// [source] - строка с источником действия
  void setSourceDart(String source) {
    _source = source;
  }
}
