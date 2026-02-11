import 'dart:js_interop';

@JS()
@staticInterop
extension type JSEventAction._(JSObject _) implements JSObject {
  external JSEventAction();
  external JSString getActionJS();
  external JSString getSourceJS();
  external JSArray<JSString> getTargetsJS();
  external JSAny? getDataJS();
}

@JSExport()
class EventAction {
  EventAction({
    required String action,
    required String source,
    List<String>? targets,
    Map? data,
  }) : _action = action,
       _data = data,
       _source = source,
       _targets = targets;

  final String _action;
  final List<String>? _targets;
  final String _source;
  final Map? _data;

  JSString getActionJS() {
    return _action.toJS;
  }

  JSArray<JSString> getTargetsJS() {
    List<JSString> listJsString =
        _targets?.map((String target) => target.toJS).toList() ?? [];
    return listJsString.toJS;
  }

  JSAny? getDataJS() {
    return _data.jsify();
  }

  JSString getSourceJS() {
    return _source.toJS;
  }

  String getActionDart() {
    return _action;
  }

  List<String>? getTargetsDart() {
    return _targets;
  }

  Map? getDataDart() {
    return _data;
  }

  String getSourceDart() {
    return _source;
  }
}
