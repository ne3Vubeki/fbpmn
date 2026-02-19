import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/cola_layout_service.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/wasmapi/app.model.dart';

import '../editor_state.dart';
import '../services/input_handler.dart';
import '../services/tile_manager.dart';
import '../services/zoom_manager.dart';

class EventManager {
  final EditorState state;
  final InputHandler inputHandler;
  final TileManager tileManager;
  final ArrowManager arrowManager;
  final NodeManager nodeManager;
  final ScrollHandler scrollHandler;
  final ColaLayoutService colaLayoutService;
  final ZoomManager zoomManager;
  final EventApp? appEvent;

  Stream? get eventStream => appEvent?.stream;

  EventManager({
    required this.state,
    required this.inputHandler,
    required this.tileManager,
    required this.arrowManager,
    required this.nodeManager,
    required this.scrollHandler,
    required this.colaLayoutService,
    required this.zoomManager,
    required this.appEvent,
  }) {
    eventStream?.listen((event) {
      switcher(event.getActionDart(), event.getDataDart());
    });
  }

  switcher(String action, Map<String, dynamic>? data) async {
    switch (action) {
      case 'run_cola':
        await colaLayoutService.runAutoLayout();
        appEvent?.emitToJs(action: 'finish_cola');
        break;
      case 'thunbnail_on':
        zoomManager.onThumbnail();
        break;
      case 'thunbnail_off':
        zoomManager.offThumbnail();
        break;
      case 'snap_on':
        state.snapEnabled = true;
        break;
      case 'snap_off':
        state.snapEnabled = false;
        break;
      case 'tiles_border_on':
        zoomManager.onTileBorders();
        break;
      case 'tiles_border_off':
        zoomManager.offTileBorders();
        break;
      case 'perfomance_on':
        zoomManager.onPerformance();
        break;
      case 'perfomance_off':
        zoomManager.offPerformance();
        break;
      case 'curves_on':
        zoomManager.onCurves();
        break;
      case 'curves_off':
        zoomManager.offCurves();
        break;
    }
  }
}
