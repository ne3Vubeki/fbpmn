import 'package:flutter/material.dart';

import 'models/table.node.dart';
import 'services/input_handler.dart';
import 'services/scroll_handler.dart';
import 'services/tile_manager.dart';
import 'services/node_manager.dart';
import 'editor_state.dart';
import 'widgets/zoom_panel.dart';
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
      
      await _tileManager.createTiledImage(_editorState.nodes);
    } else {
      print('Нет объектов для отрисовки');
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
        _editorState.viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        
        return Stack(
          children: [
            // Основной канвас с скроллбарами
            CanvasArea(
              state: _editorState,
              inputHandler: _inputHandler,
              nodeManager: _nodeManager,
              scrollHandler: _scrollHandler,
            ),
            
            // Панель зума
            Positioned(
              right: 20,
              bottom: 20,
              child: ZoomPanel(
                scale: _editorState.scale,
                showTileBorders: _editorState.showTileBorders,
                onResetZoom: () => _scrollHandler.resetZoom(),
                onToggleTileBorders: () => _inputHandler.toggleTileBorders(),
              ),
            ),
            
            // Индикатор загрузки
            if (_editorState.isLoading)
              const LoadingIndicator(),
          ],
        );
      },
    );
  }
}