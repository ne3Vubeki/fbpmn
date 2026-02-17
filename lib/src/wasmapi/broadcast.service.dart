import 'dart:js_interop';
import 'package:web/web.dart';

import 'action.model.dart';
import 'app.model.dart';

class Broadcast {
  final String _app;
  final String _source;
  final HTMLElement? _element;

  Broadcast({required String app, required String source})
    : _app = app,
      _source = source,
      _element = document.querySelector('#q-wasm-container-fbpmn') as HTMLElement?;

  EventApp? register() {
    if (_element == null) {
      return null;
    }
    EventApp data = EventApp(
      app: _app,
      source: _source,
      event: EventAction(action: '', source: '', targets: [], data: null),
    );
    _broadcastAppEvent('qp_register_app_channel', createJSInteropWrapper(data));
    return data;
  }

  EventApp emitAction({EventApp? event}) {
    EventApp data =
        event ??
        EventApp(
          app: _app,
          source: _source,
          event: EventAction(action: '', source: '', targets: [], data: null),
        );
    _broadcastAppEvent('qp_action_app_channel', createJSInteropWrapper(data));
    return data;
  }

  void _broadcastAppEvent(String trek, JSObject data) {
    assert(_element != null, 'Flutter source element cannot be found!');
    final eventDetails = CustomEventInit(detail: data, bubbles: true, composed: true);
    _element!.dispatchEvent(CustomEvent(trek, eventDetails));
  }
}
