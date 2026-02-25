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
      if (event == null) return;

      final dynamic rawAction = event.getActionDart();
      if (rawAction == null) return;

      final String action = rawAction.toString();
      final dynamic rawData = event.getDataDart();
      final Map<String, dynamic>? data = rawData is Map<String, dynamic> ? rawData : null;

      switcher(action, data);
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
      case 'configuration_editor_changed':
        if (data != null) {
          state.setConfig(data);
          for (final entry in data.entries) {
            switch (entry.key) {
              case 'snapEnabled':
                state.snapEnabled = entry.value;
                break;
              case 'showTileBorders':
                entry.value == true ? zoomManager.onTileBorders() : zoomManager.offTileBorders();
                break;
              case 'useCurves':
                entry.value == true ? zoomManager.onCurves() : zoomManager.offCurves();
                break;
              case 'showPerformance':
                entry.value == true ? zoomManager.onPerformance() : zoomManager.offPerformance();
                break;
              case 'showThumbnail':
                entry.value == true ? zoomManager.onThumbnail() : zoomManager.offThumbnail();
                break;
            }
          }
        }
        break;
    }
  }
}
