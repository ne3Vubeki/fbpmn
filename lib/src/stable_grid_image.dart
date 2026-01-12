import 'package:flutter/material.dart';

import 'models/table.node.dart';
import 'services/input_handler.dart';
import 'services/scroll_handler.dart';
import 'services/tile_manager.dart';
import 'services/node_manager.dart';
import 'editor_state.dart';
import 'widgets/zoom_container.dart';
import 'widgets/loading_indicator.dart';
import 'widgets/canvas_area.dart';

class StableGridImage extends StatefulWidget {
  final Map diagram;
  const StableGridImage({super.key, required this.diagram});

  @override
  State<StableGridImage> createState() => _StableGridImageState();
}

class _StableGridImageState extends State<StableGridImage> {
  late EditorState _editorState;
  late InputHandler _inputHandler;
  late ScrollHandler _scrollHandler;
  late TileManager _tileManager;
  late NodeManager _nodeManager;

  @override
  void initState() {
    super.initState();

    _editorState = EditorState();

    // Сначала создаем TileManager и NodeManager
    _tileManager = TileManager(
      state: _editorState,
      onStateUpdate: () => setState(() {}),
    );

    _nodeManager = NodeManager(
      state: _editorState,
      tileManager: _tileManager,
      onStateUpdate: () => setState(() {}),
    );

    // Теперь создаем ScrollHandler с передачей NodeManager
    _scrollHandler = ScrollHandler(
      state: _editorState,
      nodeManager: _nodeManager, // Передаем NodeManager
      onStateUpdate: () => setState(() {}),
    );

    _inputHandler = InputHandler(
      state: _editorState,
      nodeManager: _nodeManager,
      scrollHandler: _scrollHandler,
      onStateUpdate: () => setState(() {}),
    );

    // Инициализация
    _initEditor();
  }

  Future<void> _initEditor() async {
    final objects = widget.diagram['objects'];
    final metadata = widget.diagram['metadata'];
    final double dx = (metadata['dx'] as num).toDouble();
    final double dy = (metadata['dy'] as num).toDouble();

    _editorState.delta = Offset(dx, dy);

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

      await _tileManager.createTiledImage(_editorState.nodes);
    } else {
      
      await _tileManager.createFallbackTiles();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollHandler.centerCanvas();
    });
  }

  @override
  void dispose() {
    _inputHandler.dispose();
    _scrollHandler.dispose();
    _tileManager.dispose();
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
            ),

            // Контейнер с миниатюрой и панелью зума
            Positioned(
              right: 0,
              bottom: 0,
              child: ZoomContainer(
                scale: _editorState.scale,
                showTileBorders: _editorState.showTileBorders,
                canvasWidth: _scrollHandler.dynamicCanvasWidth,
                canvasHeight: _scrollHandler.dynamicCanvasHeight,
                canvasOffset: _editorState.offset,
                delta: _editorState.delta, // Передаем delta
                viewportSize: _editorState.viewportSize,
                imageTiles: _editorState.imageTiles,
                onResetZoom: () => _scrollHandler.resetZoom(),
                onToggleTileBorders: () => _inputHandler.toggleTileBorders(),
                onThumbnailClick: (Offset newOffset) {
                  // Обновляем offset в состоянии
                  _editorState.offset = _inputHandler.constrainOffset(newOffset);

                  // Обновляем скроллбары
                  _scrollHandler.updateScrollControllers();

                  // Перерисовываем
                  setState(() {});
                },
              ),
            ),

            // Индикатор загрузки
            if (_editorState.isLoading) const LoadingIndicator(),
          ],
        );
      },
    );
  }
}
