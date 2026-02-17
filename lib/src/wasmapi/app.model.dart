import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'action.model.dart';

@JSExport()
class EventApp {
  final StreamController streamController = StreamController.broadcast();

  JSFunction? _callbackJs;
  Function? _callbackDart;
  Stream get stream => streamController.stream;

  EventApp({required String app, required String source, required EventAction event})
    : _app = app,
      _source = source,
      _event = event;

  final String _app;
  final String _source;
  final EventAction _event;

  String getApp() {
    return _app;
  }

  String getSource() {
    return _source;
  }

  JSEventAction getEvent() {
    // Создаем копию события вместо модификации оригинала
    final eventCopy = EventAction(
      action: _event.getActionDart(),
      source: _source, // Используем текущий source
      targets: [_app], // Устанавливаем targets из текущего app
      data: _event.getDataDart(), // Копируем данные
    );

    // Возвращаем обертку для копии
    return createJSInteropWrapper(eventCopy) as JSEventAction;
  }

  emitToDart(JSEventAction data) {
    try {
      // Безопасное получение action
      final String action = _safeGetJSString(data.getActionJS());

      // Безопасное получение source
      final String source = _safeGetJSString(data.getSourceJS());

      // Безопасное получение targets
      final List<String> targets = _safeGetTargets(data.getTargetsJS());

      // Безопасное получение data
      final Map<String, dynamic> eventData = _safeGetData(data.getDataJS());

      final EventAction event = EventAction(
        action: action,
        source: source,
        targets: targets.isNotEmpty ? targets : null,
        data: eventData.isNotEmpty ? eventData : null,
      );

      streamController.sink.add(event);
      if (_callbackDart != null) {
        _callbackDart!(event);
      }

      print('Emit event to Dart on app: ${getApp()} view: ${getSource()} action: $action data: ${event.getDataDart()}');
    } catch (e) {
      print('Error in emitToDart: $e');
    }
  }

  // Вспомогательные методы для безопасного преобразования
  String _safeGetJSString(JSString? jsString) {
    try {
      return jsString?.toDart ?? '';
    } catch (e) {
      print('Error converting JSString: $e');
      return '';
    }
  }

  List<String> _safeGetTargets(JSArray<JSString>? jsArray) {
    final List<String> result = [];
    if (jsArray == null) return result;

    try {
      final dartList = jsArray.toDart;
      for (var item in dartList) {
        try {
          final String value = item.toDart;
          if (value.isNotEmpty) {
            result.add(value);
          }
        } catch (e) {
          print('Error converting target item: $e');
        }
      }
    } catch (e) {
      print('Error converting targets array: $e');
    }

    return result;
  }

  Map<String, dynamic> _safeGetData(JSString? jsData) {
    if (jsData == null) return {};

    try {
      final String jsonStr = jsData.toDart;
      if (jsonStr.isEmpty) return {};

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      print('Error decoding JSON data: $e');
    }

    return {};
  }

  void emitToJs({required String action, List<String>? targets, Map<String, dynamic>? data}) {
    _callbackJs?.callAsFunction(
      null,
      createJSInteropWrapper(EventAction(action: action, targets: targets ?? [_app], data: data, source: _source)),
    );
    print('Emit event to JS on app: ${getApp()} view: ${getSource()} action: $action');
  }

  void addListenerJs(JSFunction fn) {
    _callbackJs = fn;
  }

  void addListenerDart(Function fn) {
    _callbackDart = fn;
  }
}
