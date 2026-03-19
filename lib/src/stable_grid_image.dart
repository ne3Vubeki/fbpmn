import 'package:fbpmn/src/models/app.model.dart';
import 'package:fbpmn/src/services/cola_layout_service.dart';
import 'package:fbpmn/src/services/shema_manager.dart';
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
import 'services/event_service.dart';
import 'widgets/zoom_container.dart';
import 'widgets/loading_indicator.dart';
import 'widgets/canvas_area.dart';

class StableGridImage extends StatefulWidget {
  final Map<String, dynamic> properties;
  final EventApp? appEvent;

  const StableGridImage({super.key, required this.properties, this.appEvent});

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
  late ZoomManager _zoomManager;
  late ShemaManager _shemaManager;

  bool _isEditorInitializing = false;
  bool _hasPendingReinitialize = false;
  bool _suppressSchemaCallback = false;
  bool _schemaInitialized = false;

  @override
  void initState() {
    super.initState();

    _editorState = EditorState(widget.properties);

    _shemaManager = ShemaManager(state: _editorState);
    _initializeEmptySchemaOnFirstLaunch();

    _arrowManager = ArrowManager(state: _editorState, schemaManager: _shemaManager);

    _tileManager = TileManager(state: _editorState, arrowManager: _arrowManager);

    _nodeManager = NodeManager(state: _editorState, schemaManager: _shemaManager, tileManager: _tileManager, arrowManager: _arrowManager);

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

    EventService(
      state: _editorState,
      inputHandler: _inputHandler,
      tileManager: _tileManager,
      arrowManager: _arrowManager,
      nodeManager: _nodeManager,
      scrollHandler: _scrollHandler,
      colaLayoutService: _colaLayoutService,
      zoomManager: _zoomManager,
      shemaManager: _shemaManager,
      appEvent: widget.appEvent,
    );

    _shemaManager.setOnStateUpdate('StableGridImage', () {
      if (_suppressSchemaCallback) return;
      _reinitializeFromSchema(_shemaManager.schema);
    });

    // Инициализация (запускаем после загрузки схемы)
    _initializeEmptySchemaOnFirstLaunch().then((_) {
      _initEditor();
    });
  }

  Future<void> _initializeEmptySchemaOnFirstLaunch() async {
    if (_schemaInitialized) return;

    _suppressSchemaCallback = true;
    try {
      await _shemaManager.resolveSchema(allowHttpLoad: true, filePath: 'assets/diagram_2.json');
      // _shemaManager.createEmptySchema(apply: true);
      _schemaInitialized = true;
    } finally {
      _suppressSchemaCallback = false;
    }
  }

  /// Даёт UI-потоку время на отрисовку (для анимации LoadingIndicator)
  Future<void> _yieldToUi() => Future<void>.delayed(Duration.zero);

  Future<void> _initEditor() async {
    if (_isEditorInitializing) {
      _hasPendingReinitialize = true;
      return;
    }

    _isEditorInitializing = true;
    _clearEditorData();
    _scrollHandler.resetCanvasSizeToDefault();
    await _zoomManager.resetZoom();
    _editorState.isLoading = true;
    _tileManager.onStateUpdate();
    if (mounted) {
      setState(() {});
    }
    // Даём Flutter отрисовать overlay загрузки до тяжёлой обработки
    await Future<void>.delayed(const Duration(milliseconds: 16));

    try {
      final diagram = await _loadSchema();

      final objects = diagram['objects'] as List<dynamic>? ?? [];
      final arrows = diagram['arrows'] as List<dynamic>? ?? [];
      final metadata = (diagram['metadata'] as Map?) ?? const {};
      final double dx = ((metadata['dx'] as num?) ?? 0).toDouble();
      final double dy = ((metadata['dy'] as num?) ?? 0).toDouble();

      _editorState.delta = Offset(dx, dy);

      if (objects.isNotEmpty) {
        var processedObjects = 0;
        for (final object in objects) {
          if (object is Map<String, dynamic>) {
            _editorState.nodes.add(TableNode.fromJson(object));
          }
          processedObjects++;
          if (processedObjects % 200 == 0) {
            await _yieldToUi();
          }
        }

        // Вычисляем абсолютные позиции для всех узлов
        for (final node in _editorState.nodes) {
          node.initializeAbsolutePositions(_editorState.delta);
        }

        // Рассчитываем размер холста на основе расположения узлов
        // Этот метод сам обновит абсолютные позиции после коррекции delta
        _scrollHandler.calculateCanvasSizeFromNodes(_editorState.nodes);

        // Загружаем стрелки/связи
        if (arrows.isNotEmpty) {
          var processedArrows = 0;
          for (final arrow in arrows) {
            if (arrow is Map<String, dynamic> && arrow['source'] != null && arrow['target'] != null) {
              _editorState.arrows.add(Arrow.fromJson(arrow));
            }
            processedArrows++;
            if (processedArrows % 200 == 0) {
              await _yieldToUi();
            }
          }
        }

        await _tileManager.createTiledImage(_editorState.nodes, _editorState.arrows);
      }
    } catch (e) {
      _shemaManager.resetToDefaultEmptySchema();
      _editorState.delta = Offset.zero;
    } finally {
      _editorState.isLoading = false;
      _tileManager.onStateUpdate();

      if (mounted) {
        setState(() {});
      }

      _isEditorInitializing = false;

      if (_hasPendingReinitialize) {
        _hasPendingReinitialize = false;
        _reinitializeFromSchema(_shemaManager.schema);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollHandler.autoFitAndCenterNodes();
    });
  }

  Future<void> _reinitializeFromSchema(Map<String, dynamic> schema) async {
    if (_isEditorInitializing) {
      _hasPendingReinitialize = true;
      return;
    }

    _suppressSchemaCallback = true;
    try {
      _shemaManager.updateSchema(schema, merge: false);
      _schemaInitialized = true;
    } finally {
      _suppressSchemaCallback = false;
    }

    await _initEditor();
  }

  void _clearEditorData() {
    // Очищаем узлы и их подписки
    for (final node in _editorState.nodes) {
      node.dispose();
    }
    _editorState.nodes.clear();
    _editorState.nodesSelected.clear();
    
    _editorState.arrows.clear();
    _editorState.arrowsSelected.clear();
    _editorState.highlightedNodeIds.clear();
    
    // Важно: вызываем dispose на тайлах через TileManager для освобождения ui.Image
    _tileManager.disposeTiles();
    _editorState.updatedImageTileIds.clear();
    _editorState.snapLines.clear();
  }

  Future<Map<String, dynamic>> _loadSchema() {
    if (_schemaInitialized) {
      return Future.value(_shemaManager.schema);
    }

    final schema = _shemaManager.schema;
    _schemaInitialized = true;
    return Future.value(schema);
  }

  @override
  void dispose() {
    _shemaManager.dispose();
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
                inputHandler: _inputHandler,
                scrollHandler: _scrollHandler,
                tileManager: _tileManager,
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
