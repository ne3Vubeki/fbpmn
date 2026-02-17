import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/cola_layout_service.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/wasmapi/app.model.dart';

import '../editor_state.dart';
import '../services/tile_manager.dart';

class EventManager {
  final EditorState state;
  final TileManager tileManager;
  final ArrowManager arrowManager;
  final NodeManager nodeManager;
  final ScrollHandler scrollHandler;
  final ColaLayoutService colaLayoutService;
  final EventApp? appEvent;

  Stream? get eventStream => appEvent?.stream;

  EventManager({
    required this.state,
    required this.tileManager,
    required this.arrowManager,
    required this.nodeManager,
    required this.scrollHandler,
    required this.colaLayoutService,
    required this.appEvent,
  }) {
    eventStream?.listen((event) {
      switcher(event.getActionDart(), event.getDataDart());
    });
  }

  switcher(String action, Map<String, dynamic>? data) async {
    switch(action) {
      case 'run_cola':
        await colaLayoutService.runAutoLayout();
        appEvent?.emitToJs(action: 'finish_cola');
        break;
    }
  }
}
