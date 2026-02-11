import 'dart:async';
import 'dart:js_interop';

import 'action.model.dart';

@JSExport()
class EventApp {
  final StreamController streamController = StreamController.broadcast();

  JSFunction? _callbackJs;
  Function? _callbackDart;
  Stream get stream => streamController.stream;

  EventApp({required String app, required String source})
    : _app = app,
      _source = source;

  final String _app;
  final String _source;

  String getApp() {
    return _app;
  }

  String getSource() {
    return _source;
  }

  emitToDart(JSEventAction data) {
    final EventAction event = EventAction(
      action: data.getActionJS().toDart,
      source: data.getSourceJS().toDart,
      targets: data.getTargetsJS().toDart.map((item) => item.toDart).toList(),
      data: data.getDataJS()?.dartify() as Map,
    );
    streamController.sink.add(event);
    if (_callbackDart != null) {
      _callbackDart!(event);
    }
    print(
      'Emit event to Dart on app: ${getApp()} view: ${getSource()} action: ${event.getActionDart()}',
    );
  }

  void emitToJs({
    required String action,
    List<String>? targets,
    Map<String, dynamic>? data,
  }) {
    _callbackJs?.callAsFunction(
      null,
      createJSInteropWrapper(
        EventAction(
          action: action,
          targets: targets,
          data: data,
          source: _source,
        ),
      ),
    );
    print(
      'Emit event to JS on app: ${getApp()} view: ${getSource()} action: $action',
    );
  }

  void addListenerJs(JSFunction fn) {
    _callbackJs = fn;
  }

  void addListenerDart(Function fn) {
    _callbackDart = fn;
  }
}
