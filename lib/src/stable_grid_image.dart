import 'package:fbpmn/src/wasmapi/app.model.dart';
import 'package:fbpmn/src/services/cola_layout_service.dart';
import 'package:fbpmn/src/services/id_manager.dart';
import 'package:flutter/material.dart';

import 'models/table.node.dart';
import 'models/arrow.dart';
import 'services/arrow_manager.dart';
import 'services/input_handler.dart';
import 'services/scroll_handler.dart';
import 'services/tile_manager.dart';
import 'services/node_manager.dart';
import 'services/zoom_manager.dart';
import 'editor_state.dart';
import 'wasmapi/event_manager.dart';
import 'widgets/zoom_container.dart';
import 'widgets/loading_indicator.dart';
import 'widgets/canvas_area.dart';

class StableGridImage extends StatefulWidget {
  final Map<String, dynamic> diagram;
  final EventApp? appEvent;

  const StableGridImage({super.key, required this.diagram, this.appEvent});

  @override
  State<StableGridImage> createState() => _StableGridImageState();
}

class _StableGridImageState extends State<StableGridImage> {
  late EditorState _editorState;
  late InputHandler _inputHandler;
  late ScrollHandler _scrollHandler;
  late TileManager _tileManager;
  late NodeManager _nodeManager;
  late ArrowManager _arrowManager;
  late ColaLayoutService _colaLayoutService;
  late IDManager _idManager;
  late ZoomManager _zoomManager;

  @override
  void initState() {
    super.initState();

    _editorState = EditorState();

    _idManager = IDManager();

    _arrowManager = ArrowManager(state: _editorState);

    _tileManager = TileManager(state: _editorState, arrowManager: _arrowManager);

    _nodeManager = NodeManager(state: _editorState, tileManager: _tileManager, arrowManager: _arrowManager);

    _scrollHandler = ScrollHandler(state: _editorState, nodeManager: _nodeManager);

    _inputHandler = InputHandler(
      state: _editorState,
      nodeManager: _nodeManager,
      scrollHandler: _scrollHandler,
      arrowManager: _arrowManager,
    );

    _colaLayoutService = ColaLayoutService(
      state: _editorState,
      tileManager: _tileManager,
      arrowManager: _arrowManager,
      nodeManager: _nodeManager,
      scrollHandler: _scrollHandler,
    );

    _zoomManager = ZoomManager(
      state: _editorState,
      inputHandler: _inputHandler,
      scrollHandler: _scrollHandler,
      tileManager: _tileManager,
      nodeManager: _nodeManager,
      colaLayoutService: _colaLayoutService,
    );

    EventManager(
      state: _editorState,
      inputHandler: _inputHandler,
      tileManager: _tileManager,
      arrowManager: _arrowManager,
      nodeManager: _nodeManager,
      scrollHandler: _scrollHandler,
      colaLayoutService: _colaLayoutService,
      zoomManager: _zoomManager,
      appEvent: widget.appEvent,
    );

    // Инициализация
    _initEditor();
  }

  Future<void> _initEditor() async {
    final objects = widget.diagram['objects'];
    final arrows = widget.diagram['arrows'];
    final metadata = widget.diagram['metadata'];
    final double dx = (metadata['dx'] as num).toDouble();
    final double dy = (metadata['dy'] as num).toDouble();

    _idManager.initializeFromJson(widget.diagram);

    _editorState.delta = Offset(dx, dy);

    _editorState.isLoading = true;
    _tileManager.onStateUpdate();
    await Future.delayed(const Duration(milliseconds: 100));

    if (objects != null && objects.isNotEmpty) {
      for (final object in objects) {
        _editorState.nodes.add(TableNode.fromJson(object));
      }

      // Вычисляем абсолютные позиции для всех узлов
      for (final node in _editorState.nodes) {
        node.initializeAbsolutePositions(_editorState.delta);
      }

      // Рассчитываем размер холста на основе расположения узлов
      // Этот метод сам обновит абсолютные позиции после коррекции delta
      _scrollHandler.calculateCanvasSizeFromNodes(_editorState.nodes);

      // Загружаем стрелки/связи
      if (arrows != null && arrows.isNotEmpty) {
        for (final arrow in arrows) {
          if (arrow['source'] != null && arrow['target'] != null) {
            _editorState.arrows.add(Arrow.fromJson(arrow));
          }
        }
      }

      await _tileManager.createTiledImage(_editorState.nodes, _editorState.arrows);
    } else {
      await _tileManager.createFallbackTiles();
    }

    _editorState.isLoading = false;
    _tileManager.onStateUpdate();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollHandler.autoFitAndCenterNodes();
    });
  }

  @override
  void dispose() {
    _colaLayoutService.dispose();
    _inputHandler.dispose();
    _scrollHandler.dispose();
    _tileManager.dispose();
    _nodeManager.dispose();
    _zoomManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Основной канвас с скроллбарами
            CanvasArea(
              state: _editorState,
              inputHandler: _inputHandler,
              nodeManager: _nodeManager,
              scrollHandler: _scrollHandler,
              tileManager: _tileManager,
              arrowManager: _arrowManager,
              appEvent: widget.appEvent,
            ),

            // Контейнер с миниатюрой и панелью зума
            Positioned(
              right: 0,
              bottom: 0,
              child: ZoomContainer(
                state: _editorState,
                zoomManager: _zoomManager,
                appEvent: widget.appEvent,
              ),
            ),

            // Индикатор загрузки
            LoadingIndicator(state: _editorState, tileManager: _tileManager),
          ],
        );
      },
    );
  }
}
