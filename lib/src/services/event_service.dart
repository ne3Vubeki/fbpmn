import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/cola_layout_service.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/services/scroll_handler.dart';
import 'package:fbpmn/src/models/app.model.dart';

import '../editor_state.dart';
import 'input_handler.dart';
import 'shema_manager.dart';
import 'tile_manager.dart';
import 'zoom_manager.dart';

class EventService {
  static EventService? _instance;

  final EditorState state;
  final InputHandler inputHandler;
  final TileManager tileManager;
  final ArrowManager arrowManager;
  final NodeManager nodeManager;
  final ScrollHandler scrollHandler;
  final ColaLayoutService colaLayoutService;
  final ZoomManager zoomManager;
  final ShemaManager shemaManager;
  final EventApp? appEvent;

  Stream? get eventStream => appEvent?.stream;

  EventService({
    required this.state,
    required this.inputHandler,
    required this.tileManager,
    required this.arrowManager,
    required this.nodeManager,
    required this.scrollHandler,
    required this.colaLayoutService,
    required this.zoomManager,
    required this.shemaManager,
    required this.appEvent,
  }) {
    _instance = this;
    eventStream?.listen((event) {
      if (event == null) return;

      final dynamic rawAction = event.getActionDart();
      if (rawAction == null) return;

      final String action = rawAction.toString();
      final dynamic rawData = event.getDataDart();
      final Map<String, dynamic>? data = rawData is Map<String, dynamic> ? rawData : null;

      apiIN(action, data);
    });
  }

  /// Static метод для отправки событий в родительское приложение
  static Future<void> apiStatic(String action, String printMessage, [Map<String, dynamic>? data]) async {
    await _instance?.apiOUT(action, data);
  }

  /// События для обработки в данном приложении
  apiIN(String action, Map<String, dynamic>? data) async {
    switch (action) {
      /// События запуска алгоритмов
      case 'run_occupancy':
      case 'run_cola':
        await colaLayoutService.runAutoLayout();
        appEvent?.emitToJs(action: 'finish_$action');
        break;
      case 'thunbnail_on':
        zoomManager.onThumbnail();
        break;
      case 'thunbnail_off':
        zoomManager.offThumbnail();
        break;
      case 'snap_on':
        zoomManager.onSnap();
        break;
      case 'snap_off':
        zoomManager.offSnap();
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
      case 'only_connectors_on':
        tileManager.onOnlyConnectors();
        break;
      case 'only_connectors_off':
        tileManager.offOnlyConnectors();
        break;
      case 'auto_fit_and_center_schema':
        scrollHandler.autoFitAndCenterNodes();
        break;

      /// События настройки редактора
      case 'configuration_editor_changed':
        if (data != null) {
          final Map<String, dynamic> previousConfig =
              Map<String, dynamic>.from(state.properties['config'] as Map? ?? const {});
          state.setConfig(data);
          for (final entry in data.entries) {
            final previousValue = previousConfig[entry.key];
            final newValue = entry.value;
            if (previousValue == newValue) {
              continue;
            }

            switch (entry.key) {
              case 'snapEnabled':
                zoomManager.setSnapEnabled(newValue == true, forceNotify: true);
                break;
              case 'showTileBorders':
                newValue == true ? zoomManager.onTileBorders() : zoomManager.offTileBorders();
                break;
              case 'useCurves':
                newValue == true ? zoomManager.onCurves() : zoomManager.offCurves();
                break;
              case 'showPerformance':
                newValue == true ? zoomManager.onPerformance() : zoomManager.offPerformance();
                break;
              case 'showThumbnail':
                newValue == true ? zoomManager.onThumbnail() : zoomManager.offThumbnail();
                break;
              case 'onlyConnectors':
                await (newValue == true ? tileManager.onOnlyConnectors() : tileManager.offOnlyConnectors());
                break;
              case 'autoLayoutUseCola':
                state.autoLayoutUseCola = newValue == true;
                break;
              case 'autoLayoutUsePolish':
                state.autoLayoutUsePolish = newValue == true;
                break;
              case 'autoLayoutUseSnapOnRepair':
                state.autoLayoutUseSnapOnRepair = newValue == true;
                break;
              case 'autoLayoutUseSnapOnPolish':
                state.autoLayoutUseSnapOnPolish = newValue == true;
                break;
            }
          }
        }
        break;

      /// События для схемы
      case 'schema_create':
        shemaManager.createEmptySchema();
        appEvent?.emitToJs(action: action, data: {'schema': state.schema});
        break;
      case 'schema_update':
        appEvent?.emitToJs(action: action, data: state.schema);
        break;
      case 'schema_upload':
        if (data != null) {
          shemaManager.createSchemaFromString(data['schema'] as String);
        }
        break;
      case 'schema_url':
        if (data != null) {
          await shemaManager.resolveSchema(allowHttpLoad: true, filePath: data['filePath'] as String);
          appEvent?.emitToJs(action: 'schema_upload', data: shemaManager.schema);
        }
        break;

      /// События для истории
      case 'history_apply':
        if (data != null) {
          shemaManager.createSchemaFromStringWithoutViewportUpdate(data['schema'] as String);
        }
        break;

      /// События для узлов
      case 'node_create':
        if (data != null) {
          final payload = data['node'];
          if (payload is Map<String, dynamic>) {
            await nodeManager.createNodeFromMap(payload);
          }
        }
        break;
      case 'node_delete':
        if (data != null) {
          final nodeId = data['nodeId'];
          if (nodeId is String && state.nodesSelected.any((node) => node?.id == nodeId)) {
            await nodeManager.deleteSelectedNode();
          }
        }
        break;

      /// События для стрелок
      case 'arrow_create':
        if (data != null) {
          final payload = data['arrow'];
          if (payload is Map<String, dynamic>) {
            await arrowManager.createArrowFromMap(payload);
          }
        }
        break;
      case 'arrow_config':
        if (data != null) {
          final payload = data['arrow'];
          if (payload is Map<String, dynamic>) {
            await arrowManager.configArrowFromMap(payload, tileManager);
          }
        }
        break;
      case 'arrow_delete':
        if (data != null) {
          final arrowId = data['arrowId'];
          if (arrowId is String && state.arrowsSelected.any((node) => node?.id == arrowId)) {
            await arrowManager.deleteSelectedArrows(tileManager);
          }
        }
        break;

      /// Подтверждающие события
      case 'confirm_create_arrow':
      case 'confirm_config_arrow':
      case 'confirm_delete_arrow':
      case 'confirm_delete_node':
        appEvent?.emitToJs(action: action, data: data);
        break;
    }
  }

  /// События для отправки в родительское приложение
  apiOUT(String action, Map<String, dynamic>? data) async {
    switch (action) {
      // Событие обновления схемы для родительского приложения
      case 'schema_update':
        appEvent?.emitToJs(action: action, data: state.schema);
        break;

      /// Подтверждающие события
      case 'confirm_create_arrow':
      case 'confirm_config_arrow':
      case 'confirm_delete_arrow':
      case 'confirm_delete_node':
        appEvent?.emitToJs(action: action, data: data);
        break;
    }
  }
}
