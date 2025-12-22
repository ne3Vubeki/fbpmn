import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/image_tile.dart';
import 'models/node.dart';
import 'models/table.node.dart';
import 'widgets/hierarchical_grid_painter.dart';

class StableGridImage extends StatefulWidget {
  final Map diagram;
  const StableGridImage({super.key, required this.diagram});

  @override
  State<StableGridImage> createState() => _StableGridImageState();
}

class _StableGridImageState extends State<StableGridImage> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _isShiftPressed = false;

  final FocusNode _focusNode = FocusNode();

  final double _canvasSizeMultiplier = 3.0;

  Offset _mousePosition = Offset.zero;

  Offset _panStartOffset = Offset.zero;
  Offset _panStartMousePosition = Offset.zero;
  bool _isPanning = false;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  bool _updatingFromScroll = false;

  Size _viewportSize = Size.zero;
  bool _isInitialized = false;

  // Для перемещения скроллбаров
  bool _isHorizontalScrollbarDragging = false;
  bool _isVerticalScrollbarDragging = false;
  Offset _horizontalScrollbarDragStart = Offset.zero;
  Offset _verticalScrollbarDragStart = Offset.zero;
  double _horizontalScrollbarStartOffset = 0.0;
  double _verticalScrollbarStartOffset = 0.0;

  // Для работы с узлами
  final List<TableNode> _nodes = [];
  Offset _delta = Offset.zero;
  Node? _selectedNode;
  bool _isNodeDragging = false;
  Offset _nodeDragStart = Offset.zero;
  Offset _nodeStartPosition = Offset.zero;

  // Тайловое изображение
  List<ImageTile> _imageTiles = [];
  Rect _totalBounds = Rect.zero;
  double _tileScale = 2.0; // Масштаб для высокого качества (Retina)
  
  // Размер тайла (в пикселях после масштабирования)
  static const int _tileSize = 1024;
  
  // Кэш для расчета границ узлов
  final Map<TableNode, Rect> _nodeBoundsCache = {};
  
  // Состояние загрузки
  bool _isLoading = false;
  
  // Выделенный узел на отдельном слое
  TableNode? _selectedNodeOnTopLayer;
  Offset _selectedNodeOffset = Offset.zero;
  bool _isNodeOnTopLayer = false;
  
  // Для отслеживания каких тайлов нужно обновить
  final Set<int> _tilesToUpdate = {};
  
  // Отображение границ тайлов
  bool _showTileBorders = true; // Включено по умолчанию

  @override
  void initState() {
    super.initState();

    final objects = widget.diagram['objects'];
    final metadata = widget.diagram['metadata'];
    final double dx = (metadata['dx'] as num).toDouble();
    final double dy = (metadata['dy'] as num).toDouble();

    _delta = Offset(dx, dy);

    if (objects != null && objects.isNotEmpty) {
      for (final object in objects) {
        _nodes.add(TableNode.fromJson(object));
      }
      
      // Создаем тайловое изображение
      _createTiledImage();
    } else {
      print('Нет объектов для отрисовки');
      _createFallbackTiles();
    }

    _horizontalScrollController.addListener(_onHorizontalScroll);
    _verticalScrollController.addListener(_onVerticalScroll);
  }

  // Создание тайлового изображения
  Future<void> _createTiledImage() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      print('Создание тайлового изображения...');
      
      // 1. Рассчитываем общие границы всех узлов
      final bounds = _calculateTotalBounds();
      
      if (bounds == null) {
        await _createFallbackTiles();
        return;
      }
      
      _totalBounds = bounds;
      print('Общие границы: $_totalBounds');
      
      // 2. Разбиваем на тайлы
      final tiles = await _createTilesForBounds(_totalBounds);
      
      // 3. Освобождаем старые тайлы
      _disposeTiles();
      
      // 4. Сохраняем новые тайлы
      _imageTiles = tiles;
      
      print('Создано ${tiles.length} тайлов');
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e, stackTrace) {
      print('Ошибка создания тайлового изображения: $e');
      print('Stack trace: $stackTrace');
      
      await _createFallbackTiles();
    }
  }

  // Расчет общих границ всех узлов
  Rect? _calculateTotalBounds() {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    void calculateBounds(List<TableNode> nodeList, Offset currentOffset) {
      for (final node in nodeList) {
        final shiftedPosition = node.position + currentOffset;
        final nodeRect = _calculateNodeRect(node, shiftedPosition);
        
        // Кэшируем границы узла
        _nodeBoundsCache[node] = nodeRect;
        
        minX = min(minX, nodeRect.left);
        minY = min(minY, nodeRect.top);
        maxX = max(maxX, nodeRect.right);
        maxY = max(maxY, nodeRect.bottom);

        if (node.children != null && node.children!.isNotEmpty) {
          calculateBounds(node.children!, shiftedPosition);
        }
      }
    }

    calculateBounds(_nodes, _delta);

    if (minX == double.infinity || _nodes.isEmpty) {
      return null;
    }

    // Добавляем отступы
    const padding = 100.0;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  // Расчет прямоугольника узла
  Rect _calculateNodeRect(TableNode node, Offset position) {
    final actualWidth = node.size.width;
    final minHeight = _calculateMinHeight(node);
    final actualHeight = max(node.size.height, minHeight);
    
    return Rect.fromPoints(
      position,
      Offset(position.dx + actualWidth, position.dy + actualHeight),
    );
  }

  Future<List<ImageTile>> _createTilesForBounds(Rect bounds) async {
    final List<ImageTile> tiles = [];
    
    // Размер тайла в мировых координатах (с учетом масштаба)
    final double tileWorldSize = _tileSize / _tileScale;
    
    // Определяем количество тайлов по горизонтали и вертикали
    final int tilesX = max(1, (bounds.width / tileWorldSize).ceil());
    final int tilesY = max(1, (bounds.height / tileWorldSize).ceil());
    
    print('Создаем $tilesX x $tilesY тайлов');
    
    // Создаем каждый тайл
    for (int y = 0; y < tilesY; y++) {
      for (int x = 0; x < tilesX; x++) {
        try {
          // Границы тайла в мировых координатах
          final tileWorldLeft = bounds.left + (x * tileWorldSize);
          final tileWorldTop = bounds.top + (y * tileWorldSize);
          final tileWorldRight = min(bounds.right, tileWorldLeft + tileWorldSize);
          final tileWorldBottom = min(bounds.bottom, tileWorldTop + tileWorldSize);
          
          final tileBounds = Rect.fromLTRB(
            tileWorldLeft,
            tileWorldTop,
            tileWorldRight,
            tileWorldBottom,
          );
          
          // Создаем тайл
          final tile = await _createTile(tileBounds, x, y);
          if (tile != null) {
            tiles.add(tile);
          }
          
          // Небольшая пауза для предотвращения перегрузки
          if ((x + y * tilesX) % 2 == 0) {
            await Future.delayed(Duration(milliseconds: 1));
          }
        } catch (e) {
          print('Ошибка создания тайла [$x, $y]: $e');
        }
      }
    }
    
    return tiles;
  }

  // Создание отдельного тайла
  Future<ImageTile?> _createTile(Rect bounds, int tileX, int tileY) async {
    try {
      // Проверяем, есть ли узлы в этом тайле
      final nodesInTile = _getNodesInBounds(bounds);
      if (nodesInTile.isEmpty) {
        return null;
      }
      
      // Размеры изображения тайла
      final double width = bounds.width;
      final double height = bounds.height;
      
      final int tileWidth = max(1, (width * _tileScale).ceil());
      final int tileHeight = max(1, (height * _tileScale).ceil());
      
      // Ограничиваем максимальный размер
      final int finalWidth = min(_tileSize, tileWidth);
      final int finalHeight = min(_tileSize, tileHeight);
      
      if (finalWidth <= 0 || finalHeight <= 0) {
        return null;
      }
      
      // Создаем изображение тайла
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Применяем масштаб для высокого качества
      canvas.scale(_tileScale, _tileScale);
      
      // Смещаем канвас для рисования в правильном месте
      canvas.translate(-bounds.left, -bounds.top);
      
      // Прозрачный фон
      canvas.drawRect(
        bounds,
        Paint()
          ..color = Colors.transparent
          ..blendMode = BlendMode.src,
      );
      
      // Рисуем узлы, которые попадают в границы тайла
      for (final node in nodesInTile) {
        // Пропускаем узел, если он на верхнем слое
        if (_isNodeOnTopLayer && node == _selectedNodeOnTopLayer) {
          continue;
        }
        _drawNodeToTile(canvas, node, bounds);
      }
      
      final picture = recorder.endRecording();
      
      // Создаем изображение
      final image = await picture.toImage(finalWidth, finalHeight);
      picture.dispose();
      
      return ImageTile(
        image: image,
        bounds: bounds,
        scale: _tileScale,
      );
      
    } catch (e) {
      print('Ошибка создания тайла [$tileX, $tileY]: $e');
      return null;
    }
  }

  // Обновление конкретных тайлов
  Future<void> _updateSpecificTiles(Set<int> tileIndices) async {
    if (tileIndices.isEmpty) return;
    
    try {
      for (final index in tileIndices) {
        if (index >= 0 && index < _imageTiles.length) {
          final oldTile = _imageTiles[index];
          final bounds = oldTile.bounds;
          
          // Создаем новый тайл
          final newTile = await _createTile(bounds, index % 10, index ~/ 10);
          
          if (newTile != null) {
            // Освобождаем старое изображение
            oldTile.image.dispose();
            
            // Заменяем тайл
            _imageTiles[index] = newTile;
          }
        }
      }
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Ошибка обновления тайлов: $e');
    }
  }

  // Получаем индексы тайлов, которые пересекаются с узлом
  Set<int> _getTileIndicesForNode(TableNode node, Offset nodePosition) {
    final Set<int> indices = {};
    final nodeRect = _calculateNodeRect(node, nodePosition);
    
    for (int i = 0; i < _imageTiles.length; i++) {
      final tile = _imageTiles[i];
      if (nodeRect.overlaps(tile.bounds)) {
        indices.add(i);
      }
    }
    
    return indices;
  }

  // Получаем узлы, которые пересекаются с границами
  List<TableNode> _getNodesInBounds(Rect bounds) {
    final List<TableNode> nodesInBounds = [];
    final expandedBounds = bounds.inflate(50.0); // Небольшой отступ для безопасности
    
    void checkNode(TableNode node, Offset parentOffset) {
      final shiftedPosition = node.position + parentOffset;
      final nodeRect = _calculateNodeRect(node, shiftedPosition);
      
      if (nodeRect.overlaps(expandedBounds)) {
        nodesInBounds.add(node);
      }
      
      // Проверяем детей
      if (node.children != null && node.children!.isNotEmpty) {
        for (final child in node.children!) {
          checkNode(child, shiftedPosition);
        }
      }
    }
    
    for (final node in _nodes) {
      checkNode(node, _delta);
    }
    
    return nodesInBounds;
  }

  // Рисуем узел в тайл
  void _drawNodeToTile(Canvas canvas, TableNode node, Rect tileBounds) {
    void drawNode(TableNode currentNode, Offset currentOffset) {
      final shiftedPosition = currentNode.position + currentOffset;
      final nodeRect = _calculateNodeRect(currentNode, shiftedPosition);
      
      // Рисуем только если узел хотя бы частично в границах тайла
      if (nodeRect.overlaps(tileBounds.inflate(10.0))) {
        canvas.save();
        _drawStaticNode(canvas, currentNode, nodeRect, shiftedPosition);
        canvas.restore();
      }
      
      // Рисуем детей
      if (currentNode.children != null && currentNode.children!.isNotEmpty) {
        for (final child in currentNode.children!) {
          drawNode(child, shiftedPosition);
        }
      }
    }
    
    drawNode(node, _delta);
  }

  // Fallback для тайлов
  Future<void> _createFallbackTiles() async {
    try {
      print('Создание запасных тайлов...');
      
      _totalBounds = Rect.fromLTRB(0, 0, 2000, 2000);
      
      // Создаем один простой тайл
      final bounds = Rect.fromLTRB(0, 0, 2000, 2000);
      
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Прозрачный фон
      canvas.drawRect(
        bounds,
        Paint()..color = Colors.transparent,
      );
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);
      picture.dispose();
      
      // Освобождаем старые тайлы
      _disposeTiles();
      
      // Создаем один тайл
      _imageTiles = [
        ImageTile(
          image: image,
          bounds: bounds,
          scale: 1.0,
        )
      ];
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('Ошибка создания запасных тайлов: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _disposeTiles() {
    for (final tile in _imageTiles) {
      tile.image.dispose();
    }
    _imageTiles.clear();
    _nodeBoundsCache.clear();
  }

  // Вспомогательный метод для расчета минимальной высоты узла
  double _calculateMinHeight(TableNode node) {
    final headerHeight = 30.0;
    final minRowHeight = 18.0;
    final totalRowsHeight = node.attributes.length * minRowHeight;
    return headerHeight + totalRowsHeight;
  }

  // Отрисовка статичного узла
  void _drawStaticNode(
    Canvas canvas,
    TableNode tableNode,
    Rect nodeRect,
    Offset position,
  ) {
    final backgroundColor = tableNode.groupId != null
        ? tableNode.backgroundColor
        : Colors.white;
    final headerBackgroundColor = tableNode.backgroundColor;
    final borderColor = Colors.black;
    final textColorHeader = headerBackgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    // Рисуем закругленный прямоугольник для всей таблицы
    final tablePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    final tableBorderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (tableNode.groupId != null) {
      canvas.drawRect(nodeRect, tablePaint);
      canvas.drawRect(nodeRect, tableBorderPaint);
    } else {
      final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
      canvas.drawRRect(roundedRect, tablePaint);
      canvas.drawRRect(roundedRect, tableBorderPaint);
    }

    // Вычисляем размеры
    final attributes = tableNode.attributes;
    final headerHeight = 30.0;
    final rowHeight = (nodeRect.height - headerHeight) / attributes.length;
    final minRowHeight = 18.0;
    final actualRowHeight = max(rowHeight, minRowHeight);

    // Рисуем заголовок
    final headerRect = Rect.fromLTWH(
      nodeRect.left + 1,
      nodeRect.top + 1,
      nodeRect.width - 2,
      headerHeight - 2,
    );

    final headerPaint = Paint()
      ..color = headerBackgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (tableNode.groupId != null) {
      canvas.drawRect(headerRect, headerPaint);
    } else {
      final headerRoundedRect = RRect.fromRectAndCorners(
        headerRect,
        topLeft: Radius.circular(8),
        topRight: Radius.circular(8),
      );
      canvas.drawRRect(headerRoundedRect, headerPaint);
    }

    final headerBorderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (tableNode.groupId == null) {
      canvas.drawLine(
        Offset(nodeRect.left, nodeRect.top + headerHeight),
        Offset(nodeRect.right, nodeRect.top + headerHeight),
        headerBorderPaint,
      );
    }

    // Текст заголовка
    final headerTextSpan = TextSpan(
      text: tableNode.text,
      style: TextStyle(
        color: textColorHeader,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );

    final headerTextPainter = TextPainter(
      text: headerTextSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    )..textWidthBasis = TextWidthBasis.longestLine;

    headerTextPainter.layout(maxWidth: nodeRect.width - 16);
    headerTextPainter.paint(
      canvas,
      Offset(
        nodeRect.left + 8,
        nodeRect.top + (headerHeight - headerTextPainter.height) / 2,
      ),
    );

    // Рисуем строки таблицы
    for (int i = 0; i < attributes.length; i++) {
      final attribute = attributes[i];
      final rowTop = nodeRect.top + headerHeight + actualRowHeight * i;
      final rowBottom = rowTop + actualRowHeight;

      final columnSplit = tableNode.qType == 'enum' ? 20 : nodeRect.width - 20;

      // Вертикальная граница
      canvas.drawLine(
        Offset(nodeRect.left + columnSplit, rowTop),
        Offset(nodeRect.left + columnSplit, rowBottom),
        headerBorderPaint,
      );

      // Горизонтальная граница
      if (i < attributes.length - 1) {
        canvas.drawLine(
          Offset(nodeRect.left, rowBottom),
          Offset(nodeRect.right, rowBottom),
          headerBorderPaint,
        );
      }

      // Текст в левой колонке
      final leftText = tableNode.qType == 'enum'
          ? attribute['position']
          : attribute['label'];
      if (leftText.isNotEmpty) {
        final leftTextPainter = TextPainter(
          text: TextSpan(
            text: leftText,
            style: TextStyle(color: Colors.black, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
          ellipsis: '...',
        )..textWidthBasis = TextWidthBasis.parent;
        
        leftTextPainter.layout(maxWidth: columnSplit - 16);
        leftTextPainter.paint(
          canvas,
          Offset(
            nodeRect.left + 8,
            rowTop + (actualRowHeight - leftTextPainter.height) / 2,
          ),
        );
      }

      // Текст в правой колонке
      final rightText = tableNode.qType == 'enum' ? attribute['label'] : '';
      if (rightText.isNotEmpty) {
        final rightTextPainter = TextPainter(
          text: TextSpan(
            text: rightText,
            style: TextStyle(color: Colors.black, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
          ellipsis: '...',
        )..textWidthBasis = TextWidthBasis.parent;
        
        rightTextPainter.layout(maxWidth: nodeRect.width - columnSplit - 16);
        rightTextPainter.paint(
          canvas,
          Offset(
            nodeRect.left + columnSplit + 8,
            rowTop + (actualRowHeight - rightTextPainter.height) / 2,
          ),
        );
      }
    }
  }

  // Выделение узла - перемещение на верхний слой
  void _selectNodeAtPosition(Offset position) {
    final worldPos = (position - _offset) / _scale;
    
    // Если уже есть выделенный узел на верхнем слое, сохраняем его обратно
    if (_isNodeOnTopLayer && _selectedNodeOnTopLayer != null) {
      _saveNodeToTiles();
    }
    
    setState(() {
      // Снимаем выделение со всех узлов
      for (final node in _nodes) {
        node.isSelected = false;
      }
      _selectedNode = null;
      
      // Сбрасываем состояние верхнего слоя
      _isNodeOnTopLayer = false;
      _selectedNodeOnTopLayer = null;

      // Ищем узел под курсором
      for (int i = _nodes.length - 1; i >= 0; i--) {
        final node = _nodes[i];
        final deltaPosition = node.position + _delta;
        final nodeRect = Rect.fromPoints(
          deltaPosition,
          Offset(
            deltaPosition.dx + node.size.width,
            deltaPosition.dy + node.size.height,
          ),
        );

        if (nodeRect.contains(worldPos)) {
          node.isSelected = true;
          _selectedNode = node;
          
          // Перемещаем узел на верхний слой
          _selectedNodeOnTopLayer = node;
          _isNodeOnTopLayer = true;
          _selectedNodeOffset = deltaPosition;
          
          // Удаляем узел из тайлов
          _removeNodeFromTiles(node);
          
          break;
        }
      }
    });
  }

  // Удаление узла из тайлов (асинхронно)
  Future<void> _removeNodeFromTiles(TableNode node) async {
    final nodePosition = node.position + _delta;
    final tileIndices = _getTileIndicesForNode(node, nodePosition);
    
    if (tileIndices.isNotEmpty) {
      // Запускаем обновление тайлов в фоне
      _updateSpecificTiles(tileIndices);
    }
  }

  // Сохранение узла обратно в тайлы (асинхронно)
  Future<void> _saveNodeToTiles() async {
    if (!_isNodeOnTopLayer || _selectedNodeOnTopLayer == null) return;
    
    final nodePosition = _selectedNodeOffset;
    final tileIndices = _getTileIndicesForNode(_selectedNodeOnTopLayer!, nodePosition);
    
    if (tileIndices.isNotEmpty) {
      // Обновляем позицию узла
      _selectedNodeOnTopLayer!.position = nodePosition - _delta;
      
      // Запускаем обновление тайлов в фоне
      _updateSpecificTiles(tileIndices);
    }
    
    setState(() {
      _isNodeOnTopLayer = false;
      _selectedNodeOnTopLayer = null;
    });
  }

  void _deleteSelectedNode() {
    if (_selectedNode != null) {
      setState(() {
        _nodes.removeWhere((node) => node.id == _selectedNode!.id);
        _selectedNode = null;
        _isNodeOnTopLayer = false;
        _selectedNodeOnTopLayer = null;
        // Пересоздаем изображение после удаления узла
        _createTiledImage();
      });
    }
  }

  void _startNodeDrag(Offset position) {
    if (_isNodeOnTopLayer && _selectedNodeOnTopLayer != null) {
      setState(() {
        _isNodeDragging = true;
        _nodeDragStart = position;
        _nodeStartPosition = _selectedNodeOffset;
      });
    }
  }

  void _updateNodeDrag(Offset position) {
    if (_isNodeDragging && _isNodeOnTopLayer && _selectedNodeOnTopLayer != null) {
      setState(() {
        final delta = (position - _nodeDragStart) / _scale;
        _selectedNodeOffset = _nodeStartPosition + delta;
      });
    }
  }

  void _endNodeDrag() {
    setState(() {
      _isNodeDragging = false;
    });
  }

  // Обработка клика на пустую область
  void _handleEmptyAreaClick() {
    if (_isNodeOnTopLayer && _selectedNodeOnTopLayer != null) {
      _saveNodeToTiles();
    }
  }

  // Переключение отображения границ тайлов
  void _toggleTileBorders() {
    setState(() {
      _showTileBorders = !_showTileBorders;
    });
  }

  void _centerCanvas() {
    setState(() {
      _offset = Offset(
        (_viewportSize.width - _viewportSize.width * _canvasSizeMultiplier) / 2,
        (_viewportSize.height - _viewportSize.height * _canvasSizeMultiplier) / 2,
      );

      _updateScrollControllers();
      _isInitialized = true;
    });
  }

  void _resetZoom() {
    setState(() {
      _scale = 1.0;
      _centerCanvas();
    });
  }

  void _updateScrollControllers() {
    if (_updatingFromScroll) return;

    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double horizontalMaxScroll = max(0, canvasSize.width - _viewportSize.width);
    double verticalMaxScroll = max(0, canvasSize.height - _viewportSize.height);

    num horizontalPosition = -_offset.dx.clamp(-horizontalMaxScroll, 0);
    num verticalPosition = -_offset.dy.clamp(-verticalMaxScroll, 0);

    _horizontalScrollController.jumpTo(
      horizontalPosition.clamp(0, horizontalMaxScroll).toDouble(),
    );
    _verticalScrollController.jumpTo(
      verticalPosition.clamp(0, verticalMaxScroll).toDouble(),
    );
  }

  void _onHorizontalScroll() {
    if (_updatingFromScroll) return;

    _updatingFromScroll = true;

    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double horizontalMaxScroll = max(0, canvasSize.width - _viewportSize.width);
    num newOffsetX = -_horizontalScrollController.offset.clamp(
      0,
      horizontalMaxScroll,
    );

    setState(() {
      _offset = Offset(newOffsetX.toDouble(), _offset.dy);
    });

    _updatingFromScroll = false;
  }

  void _onVerticalScroll() {
    if (_updatingFromScroll) return;

    _updatingFromScroll = true;

    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double verticalMaxScroll = max(0, canvasSize.height - _viewportSize.height);
    num newOffsetY = -_verticalScrollController.offset.clamp(
      0,
      verticalMaxScroll,
    );

    setState(() {
      _offset = Offset(_offset.dx, newOffsetY.toDouble());
    });

    _updatingFromScroll = false;
  }

  void _handleZoom(double delta, Offset localPosition) {
    setState(() {
      double oldScale = _scale;

      double newScale = _scale * (1 + delta * 0.001);

      // Ограничения зума
      if (newScale < 0.35) {
        newScale = 0.35;
      } else if (newScale > 5.0) {
        newScale = 5.0;
      }

      // Корректировка смещения для фокуса на курсоре
      double zoomFactor = newScale / oldScale;
      Offset mouseInCanvas = (localPosition - _offset);
      Offset newOffset = localPosition - mouseInCanvas * zoomFactor;

      _scale = newScale;
      _offset = _constrainOffset(newOffset);

      _updateScrollControllers();
    });
  }

  Offset _constrainOffset(Offset offset) {
    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double constrainedX = offset.dx;
    double constrainedY = offset.dy;

    double maxXOffset = _viewportSize.width - canvasSize.width;
    double maxYOffset = _viewportSize.height - canvasSize.height;

    if (constrainedX > 0) {
      constrainedX = 0;
    }
    if (constrainedX < maxXOffset) {
      constrainedX = maxXOffset;
    }

    if (constrainedY > 0) {
      constrainedY = 0;
    }
    if (constrainedY < maxYOffset) {
      constrainedY = maxYOffset;
    }

    return Offset(constrainedX, constrainedY);
  }

  void _handleHorizontalScrollbarDragStart(PointerDownEvent details) {
    setState(() {
      _isHorizontalScrollbarDragging = true;
      _horizontalScrollbarDragStart = details.localPosition;
      _horizontalScrollbarStartOffset = _horizontalScrollController.offset;
    });
  }

  void _handleHorizontalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!_isHorizontalScrollbarDragging) return;

    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double horizontalMaxScroll = max(0, canvasSize.width - _viewportSize.width);
    if (horizontalMaxScroll == 0) return;

    double viewportToCanvasRatio = canvasSize.width / _viewportSize.width;

    double delta =
        (details.localPosition.dx - _horizontalScrollbarDragStart.dx) *
        viewportToCanvasRatio;

    double newScrollOffset = (_horizontalScrollbarStartOffset + delta).clamp(
      0,
      horizontalMaxScroll,
    );

    _updatingFromScroll = true;
    _horizontalScrollController.jumpTo(newScrollOffset);
    _updatingFromScroll = false;

    double newOffsetX = -newScrollOffset;
    setState(() {
      _offset = Offset(newOffsetX, _offset.dy);
    });
  }

  void _handleHorizontalScrollbarDragEnd(PointerUpEvent details) {
    setState(() {
      _isHorizontalScrollbarDragging = false;
    });
  }

  void _handleVerticalScrollbarDragStart(PointerDownEvent details) {
    setState(() {
      _isVerticalScrollbarDragging = true;
      _verticalScrollbarDragStart = details.localPosition;
      _verticalScrollbarStartOffset = _verticalScrollController.offset;
    });
  }

  void _handleVerticalScrollbarDragUpdate(PointerMoveEvent details) {
    if (!_isVerticalScrollbarDragging) return;

    final Size canvasSize = Size(
      _viewportSize.width * _canvasSizeMultiplier * _scale,
      _viewportSize.height * _canvasSizeMultiplier * _scale,
    );

    double verticalMaxScroll = max(0, canvasSize.height - _viewportSize.height);
    if (verticalMaxScroll == 0) return;

    double viewportToCanvasRatio = canvasSize.height / _viewportSize.height;

    double delta =
        (details.localPosition.dy - _verticalScrollbarDragStart.dy) *
        viewportToCanvasRatio;

    double newScrollOffset = (_verticalScrollbarStartOffset + delta).clamp(
      0,
      verticalMaxScroll,
    );

    _updatingFromScroll = true;
    _verticalScrollController.jumpTo(newScrollOffset);
    _updatingFromScroll = false;

    double newOffsetY = -newScrollOffset;
    setState(() {
      _offset = Offset(_offset.dx, newOffsetY);
    });
  }

  void _handleVerticalScrollbarDragEnd(PointerUpEvent details) {
    setState(() {
      _isVerticalScrollbarDragging = false;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    
    // Освобождаем ресурсы тайлов
    _disposeTiles();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (!_isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _centerCanvas();
          });
        }

        final Size baseCanvasSize = Size(
          _viewportSize.width * _canvasSizeMultiplier,
          _viewportSize.height * _canvasSizeMultiplier,
        );

        final Size scaledCanvasSize = Size(
          baseCanvasSize.width * _scale,
          baseCanvasSize.height * _scale,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateScrollControllers();
        });

        return Stack(
          children: [
            // Основной контент
            Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 10,
                        bottom: 10,
                        child: KeyboardListener(
                          focusNode: _focusNode,
                          autofocus: true,
                          onKeyEvent: (KeyEvent event) {
                            if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                                event.logicalKey == LogicalKeyboardKey.shiftRight) {
                              setState(() {
                                _isShiftPressed =
                                    event is KeyDownEvent ||
                                    event is KeyRepeatEvent;
                              });
                            }
                            // Обработка удаления узла
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.delete) {
                              _deleteSelectedNode();
                            }
                            // Переключение отображения границ тайлов по клавише B
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.keyB) {
                              _toggleTileBorders();
                            }
                          },
                          child: MouseRegion(
                            cursor: _isShiftPressed && _isPanning
                                ? SystemMouseCursors.grabbing
                                : _isShiftPressed
                                ? SystemMouseCursors.grab
                                : SystemMouseCursors.basic,
                            onHover: (PointerHoverEvent event) {
                              _mousePosition = event.localPosition;
                            },
                            child: Listener(
                              onPointerSignal: (pointerSignal) {
                                if (pointerSignal is PointerScrollEvent &&
                                    _isShiftPressed) {
                                  _handleZoom(
                                    pointerSignal.scrollDelta.dy,
                                    _mousePosition,
                                  );
                                }
                              },
                              onPointerMove: (PointerMoveEvent event) {
                                _mousePosition = event.localPosition;

                                if (_isPanning && _isShiftPressed) {
                                  setState(() {
                                    Offset delta =
                                        event.localPosition -
                                        _panStartMousePosition;
                                    Offset newOffset = _panStartOffset + delta;

                                    _offset = _constrainOffset(newOffset);

                                    _updateScrollControllers();
                                  });
                                } else if (_isNodeDragging) {
                                  _updateNodeDrag(event.localPosition);
                                }
                              },
                              onPointerDown: (PointerDownEvent event) {
                                if (_isShiftPressed) {
                                  setState(() {
                                    _isPanning = true;
                                    _panStartOffset = _offset;
                                    _panStartMousePosition = event.localPosition;
                                  });
                                } else {
                                  _selectNodeAtPosition(event.localPosition);
                                  _startNodeDrag(event.localPosition);
                                  // Проверяем, был ли клик на пустой области
                                  if (!_isNodeOnTopLayer) {
                                    _handleEmptyAreaClick();
                                  }
                                }
                                _focusNode.requestFocus();
                              },
                              onPointerUp: (PointerUpEvent event) {
                                setState(() {
                                  _isPanning = false;
                                });
                                _endNodeDrag();
                              },
                              onPointerCancel: (PointerCancelEvent event) {
                                setState(() {
                                  _isPanning = false;
                                });
                                _endNodeDrag();
                              },
                              child: ClipRect(
                                child: Stack(
                                  children: [
                                    // Слой с тайлами
                                    CustomPaint(
                                      size: scaledCanvasSize,
                                      painter: HierarchicalGridPainter(
                                        scale: _scale,
                                        offset: _offset,
                                        canvasSize: scaledCanvasSize,
                                        nodes: _nodes,
                                        delta: _delta,
                                        imageTiles: _imageTiles,
                                        totalBounds: _totalBounds,
                                        tileScale: _tileScale,
                                      ),
                                    ),
                                    
                                    // Слой с красными границами тайлов
                                    if (_showTileBorders)
                                      CustomPaint(
                                        size: scaledCanvasSize,
                                        painter: _TileBorderPainter(
                                          scale: _scale,
                                          offset: _offset,
                                          imageTiles: _imageTiles,
                                          totalBounds: _totalBounds,
                                        ),
                                      ),
                                    
                                    // Верхний слой с выделенным узлом
                                    if (_isNodeOnTopLayer && _selectedNodeOnTopLayer != null)
                                      Positioned(
                                        left: _selectedNodeOffset.dx * _scale + _offset.dx,
                                        top: _selectedNodeOffset.dy * _scale + _offset.dy,
                                        child: Transform.scale(
                                          scale: _scale,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.blue,
                                                width: 2.0,
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: CustomPaint(
                                              size: Size(
                                                _selectedNodeOnTopLayer!.size.width,
                                                max(
                                                  _selectedNodeOnTopLayer!.size.height,
                                                  _calculateMinHeight(_selectedNodeOnTopLayer!),
                                                ),
                                              ),
                                              painter: _NodePainter(
                                                node: _selectedNodeOnTopLayer!,
                                                isSelected: true,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Горизонтальный скроллбар
                      Positioned(
                        left: 0,
                        right: 10,
                        bottom: 0,
                        height: 10,
                        child: Listener(
                          onPointerDown: _handleHorizontalScrollbarDragStart,
                          onPointerMove: _handleHorizontalScrollbarDragUpdate,
                          onPointerUp: _handleHorizontalScrollbarDragEnd,
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            trackVisibility: false,
                            thickness: 10,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: SizedBox(
                                width: scaledCanvasSize.width,
                                height: 10,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Вертикальный скроллбар
                      Positioned(
                        top: 0,
                        bottom: 10,
                        right: 0,
                        width: 10,
                        child: Listener(
                          onPointerDown: _handleVerticalScrollbarDragStart,
                          onPointerMove: _handleVerticalScrollbarDragUpdate,
                          onPointerUp: _handleVerticalScrollbarDragEnd,
                          child: Scrollbar(
                            controller: _verticalScrollController,
                            thumbVisibility: true,
                            trackVisibility: false,
                            thickness: 10,
                            child: SingleChildScrollView(
                              controller: _verticalScrollController,
                              physics: const NeverScrollableScrollPhysics(),
                              child: SizedBox(
                                width: 10,
                                height: scaledCanvasSize.height,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Панель зума
                      Positioned(
                        right: 20,
                        bottom: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(_scale * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.zoom_out_map, size: 18),
                                onPressed: _resetZoom,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                tooltip: 'Reset to 100%',
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(
                                  _showTileBorders ? Icons.border_outer : Icons.border_clear,
                                  size: 18,
                                  color: _showTileBorders ? Colors.red : Colors.grey,
                                ),
                                onPressed: _toggleTileBorders,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                tooltip: _showTileBorders ? 'Hide tile borders' : 'Show tile borders',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Индикатор загрузки - только CircularProgressIndicator
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// Кастомный Painter для отрисовки красных границ тайлов
class _TileBorderPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final List<ImageTile> imageTiles;
  final Rect totalBounds;

  _TileBorderPainter({
    required this.scale,
    required this.offset,
    required this.imageTiles,
    required this.totalBounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Применяем трансформации
    canvas.save();
    canvas.scale(scale, scale);
    canvas.translate(offset.dx / scale, offset.dy / scale);

    // Определяем видимую область
    final double visibleLeft = -offset.dx / scale;
    final double visibleTop = -offset.dy / scale;
    final double visibleRight = (size.width - offset.dx) / scale;
    final double visibleBottom = (size.height - offset.dy) / scale;

    final visibleRect = Rect.fromLTRB(
      visibleLeft,
      visibleTop,
      visibleRight,
      visibleBottom,
    );

    // Создаем Paint для красных границ
    final tileBorderPaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / scale
      ..isAntiAlias = true;

    final tileNumberPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Рисуем границы тайлов
    for (int i = 0; i < imageTiles.length; i++) {
      final tile = imageTiles[i];
      
      // Проверяем, виден ли тайл
      if (tile.bounds.overlaps(visibleRect)) {
        // Рисуем красную рамку тайла
        canvas.drawRect(tile.bounds, tileBorderPaint);
        
        // Рисуем номер тайла в левом верхнем углу
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$i',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12 / scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        textPainter.paint(
          canvas,
          Offset(
            tile.bounds.left + 2 / scale,
            tile.bounds.top + 2 / scale,
          ),
        );
        
        // Рисуем размер тайла в правом нижнем углу
        final sizeText = '${tile.image.width}x${tile.image.height}';
        final sizeTextPainter = TextPainter(
          text: TextSpan(
            text: sizeText,
            style: TextStyle(
              color: Colors.red.withOpacity(0.8),
              fontSize: 10 / scale,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        sizeTextPainter.paint(
          canvas,
          Offset(
            tile.bounds.right - sizeTextPainter.width - 2 / scale,
            tile.bounds.bottom - sizeTextPainter.height - 2 / scale,
          ),
        );
      }
    }

    // Рисуем общую границу всех тайлов
    if (imageTiles.isNotEmpty) {
      final totalBorderPaint = Paint()
        ..color = Colors.red.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / scale
        ..isAntiAlias = true;
      
      canvas.drawRect(totalBounds, totalBorderPaint);
      
      // Подпись для общей границы
      final totalText = 'Total bounds: ${totalBounds.width.toStringAsFixed(0)}x${totalBounds.height.toStringAsFixed(0)}';
      final totalTextPainter = TextPainter(
        text: TextSpan(
          text: totalText,
          style: TextStyle(
            color: Colors.red.withOpacity(0.8),
            fontSize: 12 / scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      totalTextPainter.paint(
        canvas,
        Offset(
          totalBounds.left + 5 / scale,
          totalBounds.top + 5 / scale,
        ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TileBorderPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.imageTiles.length != imageTiles.length ||
        oldDelegate.totalBounds != totalBounds;
  }
}

// Кастомный Painter для отрисовки узла на верхнем слое
class _NodePainter extends CustomPainter {
  final TableNode node;
  final bool isSelected;

  _NodePainter({
    required this.node,
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect nodeRect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    final backgroundColor = node.groupId != null
        ? node.backgroundColor
        : Colors.white;
    final headerBackgroundColor = node.backgroundColor;
    final borderColor = isSelected ? Colors.blue : Colors.black;
    final textColorHeader = headerBackgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    // Рисуем закругленный прямоугольник для всей таблицы
    final tablePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    final tableBorderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.0
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (node.groupId != null) {
      canvas.drawRect(nodeRect, tablePaint);
      canvas.drawRect(nodeRect, tableBorderPaint);
    } else {
      final roundedRect = RRect.fromRectAndRadius(nodeRect, Radius.circular(8));
      canvas.drawRRect(roundedRect, tablePaint);
      canvas.drawRRect(roundedRect, tableBorderPaint);
    }

    // Вычисляем размеры
    final attributes = node.attributes;
    final headerHeight = 30.0;
    final rowHeight = (nodeRect.height - headerHeight) / attributes.length;
    final minRowHeight = 18.0;
    final actualRowHeight = max(rowHeight, minRowHeight);

    // Рисуем заголовок
    final headerRect = Rect.fromLTWH(
      nodeRect.left + 1,
      nodeRect.top + 1,
      nodeRect.width - 2,
      headerHeight - 2,
    );

    final headerPaint = Paint()
      ..color = headerBackgroundColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (node.groupId != null) {
      canvas.drawRect(headerRect, headerPaint);
    } else {
      final headerRoundedRect = RRect.fromRectAndCorners(
        headerRect,
        topLeft: Radius.circular(8),
        topRight: Radius.circular(8),
      );
      canvas.drawRRect(headerRoundedRect, headerPaint);
    }

    final headerBorderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.0
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (node.groupId == null) {
      canvas.drawLine(
        Offset(nodeRect.left, nodeRect.top + headerHeight),
        Offset(nodeRect.right, nodeRect.top + headerHeight),
        headerBorderPaint,
      );
    }

    // Текст заголовка
    final headerTextSpan = TextSpan(
      text: node.text,
      style: TextStyle(
        color: textColorHeader,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );

    final headerTextPainter = TextPainter(
      text: headerTextSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    )..textWidthBasis = TextWidthBasis.longestLine;

    headerTextPainter.layout(maxWidth: nodeRect.width - 16);
    headerTextPainter.paint(
      canvas,
      Offset(
        nodeRect.left + 8,
        nodeRect.top + (headerHeight - headerTextPainter.height) / 2,
      ),
    );

    // Рисуем строки таблицы
    for (int i = 0; i < attributes.length; i++) {
      final attribute = attributes[i];
      final rowTop = nodeRect.top + headerHeight + actualRowHeight * i;
      final rowBottom = rowTop + actualRowHeight;

      final columnSplit = node.qType == 'enum' ? 20 : nodeRect.width - 20;

      // Вертикальная граница
      canvas.drawLine(
        Offset(nodeRect.left + columnSplit, rowTop),
        Offset(nodeRect.left + columnSplit, rowBottom),
        headerBorderPaint,
      );

      // Горизонтальная граница
      if (i < attributes.length - 1) {
        canvas.drawLine(
          Offset(nodeRect.left, rowBottom),
          Offset(nodeRect.right, rowBottom),
          headerBorderPaint,
        );
      }

      // Текст в левой колонке
      final leftText = node.qType == 'enum'
          ? attribute['position']
          : attribute['label'];
      if (leftText.isNotEmpty) {
        final leftTextPainter = TextPainter(
          text: TextSpan(
            text: leftText,
            style: TextStyle(color: Colors.black, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
          ellipsis: '...',
        )..textWidthBasis = TextWidthBasis.parent;
        
        leftTextPainter.layout(maxWidth: columnSplit - 16);
        leftTextPainter.paint(
          canvas,
          Offset(
            nodeRect.left + 8,
            rowTop + (actualRowHeight - leftTextPainter.height) / 2,
          ),
        );
      }

      // Текст в правой колонке
      final rightText = node.qType == 'enum' ? attribute['label'] : '';
      if (rightText.isNotEmpty) {
        final rightTextPainter = TextPainter(
          text: TextSpan(
            text: rightText,
            style: TextStyle(color: Colors.black, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
          ellipsis: '...',
        )..textWidthBasis = TextWidthBasis.parent;
        
        rightTextPainter.layout(maxWidth: nodeRect.width - columnSplit - 16);
        rightTextPainter.paint(
          canvas,
          Offset(
            nodeRect.left + columnSplit + 8,
            rowTop + (actualRowHeight - rightTextPainter.height) / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NodePainter oldDelegate) {
    return oldDelegate.node != node || oldDelegate.isSelected != isSelected;
  }
}