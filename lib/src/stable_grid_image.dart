import 'package:flutter/material.dart';

import 'models/table.node.dart';
import 'models/arrow.dart';
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

    _tileManager = TileManager(
      state: _editorState,
    );

    _nodeManager = NodeManager(
      state: _editorState,
      tileManager: _tileManager,
    );

    _scrollHandler = ScrollHandler(
      state: _editorState,
      nodeManager: _nodeManager,
    );

    _inputHandler = InputHandler(
      state: _editorState,
      nodeManager: _nodeManager,
      scrollHandler: _scrollHandler,
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

      // Загружаем стрелки/связи
      if (arrows != null && arrows.isNotEmpty) {
        for (final arrow in arrows) {
          if (arrow['source'] != null && arrow['target'] != null) {
            _editorState.arrows.add(Arrow.fromJson(arrow));
          }
        }
      }

      await _tileManager.createTiledImage(
        _editorState.nodes,
        _editorState.arrows,
      );
    } else {
      await _tileManager.createFallbackTiles();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollHandler.autoFitAndCenterNodes();
    });
  }

  @override
  void dispose() {
    _inputHandler.dispose();
    _scrollHandler.dispose();
    _tileManager.dispose();
    _nodeManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Рисуем редактор!!!!!');
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
            ),

            // Контейнер с миниатюрой и панелью зума
            Positioned(
              right: 0,
              bottom: 0,
              child: ZoomContainer(
                state: _editorState,
                scrollHandler: _scrollHandler,
                inputHandler: _inputHandler,
                tileManager: _tileManager,
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
