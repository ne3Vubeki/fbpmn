import 'dart:async';

import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/image_tile.dart';
import '../utils/editor_config.dart';
import 'manager.dart';
import 'tile_manager.dart';

/// Контроллер видимых тайлов.
///
/// Отслеживает, какие тайлы попадают в текущий viewport, и управляет
/// их жизненным циклом: запрашивает создание новых тайлов через [TileManager],
/// кэширует вышедшие за экран тайлы в LRU-кэше, удаляет устаревшие.
class ViewportTileController extends Manager {
  final EditorState state;
  final TileManager tileManager;

  /// Максимальное количество тайлов в LRU-кэше (вне viewport).
  static const int _lruMaxSize = 32;

  /// Множество ID тайлов, видимых в текущем кадре.
  Set<String> _visibleTileIds = {};

  /// LRU-кэш тайлов, вышедших за пределы viewport.
  /// Ключ — tile id ('x:y'), значение — тайл.
  final Map<String, ImageTile> _lruCache = {};

  /// Порядок доступа для LRU (последний — самый свежий).
  final List<String> _lruOrder = [];

  /// Флаг: идёт ли сейчас асинхронное создание тайлов.
  bool _isLoadingTiles = false;

  /// Дебаунс-таймер для перерисовки тайлов после завершения зума.
  Timer? _zoomDebounceTimer;

  /// Масштаб, при котором тайлы были последний раз перерисованы.
  double _lastRenderedScale = -1.0;

  /// Порог изменения масштаба, при котором тайлы нужно перерисовать.
  static const double _scaleRedrawThreshold = 0.5;

  ViewportTileController({required this.state, required this.tileManager});

  /// Публичный геттер: список тайлов для отрисовки в текущем кадре.
  /// Фильтрует освобождённые тайлы.
  List<ImageTile> get visibleTiles {
    final result = <ImageTile>[];
    for (final id in _visibleTileIds) {
      // Сначала ищем в основном индексе
      final tile = state.tileIndex[id];
      if (tile != null && !tile.isDisposed) {
        result.add(tile);
        continue;
      }
      // Затем в LRU-кэше
      final cached = _lruCache[id];
      if (cached != null && !cached.isDisposed) {
        result.add(cached);
      }
    }
    return result;
  }

  /// Вызывается при изменении viewport (скролл, зум, изменение размера окна).
  /// [visibleLeft/Top/Right/Bottom] — видимая область в мировых координатах.
  void onViewportChanged({
    required double visibleLeft,
    required double visibleTop,
    required double visibleRight,
    required double visibleBottom,
  }) {
    final newVisibleIds = _computeVisibleTileIds(
      visibleLeft: visibleLeft,
      visibleTop: visibleTop,
      visibleRight: visibleRight,
      visibleBottom: visibleBottom,
    );

    final appeared = newVisibleIds.difference(_visibleTileIds);
    final disappeared = _visibleTileIds.difference(newVisibleIds);

    // Тайлы, вышедшие за viewport — перемещаем в LRU-кэш
    for (final id in disappeared) {
      final tile = state.tileIndex[id];
      if (tile != null) {
        _putToLru(id, tile);
      }
    }

    _visibleTileIds = newVisibleIds;

    // Если появились новые тайлы, которых нет ни в индексе, ни в кэше — создаём
    final missingIds = appeared.where(
      (id) => !state.tileIndex.containsKey(id) && !_lruCache.containsKey(id),
    ).toSet();

    if (missingIds.isNotEmpty && !_isLoadingTiles) {
      _loadMissingTiles(missingIds);
    }

    // Тайлы из LRU, которые снова стали видимы — перемещаем обратно в индекс
    for (final id in appeared) {
      if (_lruCache.containsKey(id) && !state.tileIndex.containsKey(id)) {
        final tile = _lruCache.remove(id)!;
        _lruOrder.remove(id);
        state.tileIndex[id] = tile;
        // Синхронизируем с imageTiles
        if (!state.imageTiles.any((t) => t.id == id)) {
          state.imageTiles.add(tile);
        }
      }
    }

    // Проверяем, нужна ли перерисовка тайлов после значительного изменения масштаба
    _scheduleScaleRedrawIfNeeded();

    onStateUpdate();
  }

  /// Вызывается из TileManager после создания/обновления тайлов.
  /// Синхронизирует tileIndex с imageTiles и очищает устаревшие тайлы из LRU-кэша.
  void syncTileIndex() {
    state.tileIndex.clear();
    for (final tile in state.imageTiles) {
      state.tileIndex[tile.id] = tile;
    }
    
    // Очищаем LRU-кэш от тайлов, которые были обновлены в imageTiles
    // (старые версии тайлов уже освобождены в TileManager)
    final validTileIds = state.imageTiles.map((t) => t.id).toSet();
    final lruIdsToRemove = <String>[];
    for (final id in _lruCache.keys) {
      if (validTileIds.contains(id)) {
        // Тайл с таким ID уже есть в imageTiles - удаляем старую версию из кэша
        lruIdsToRemove.add(id);
      }
    }
    for (final id in lruIdsToRemove) {
      _lruCache.remove(id);
      _lruOrder.remove(id);
    }
  }

  /// Вычисляет множество ID тайлов, попадающих в видимую область.
  Set<String> _computeVisibleTileIds({
    required double visibleLeft,
    required double visibleTop,
    required double visibleRight,
    required double visibleBottom,
  }) {
    final ts = EditorConfig.tileSize.toDouble();
    final tsInt = EditorConfig.tileSize;

    final startX = (visibleLeft / ts).floor() * tsInt;
    final endX   = (visibleRight / ts).ceil()  * tsInt;
    final startY = (visibleTop / ts).floor()   * tsInt;
    final endY   = (visibleBottom / ts).ceil() * tsInt;

    final ids = <String>{};
    for (int x = startX; x < endX; x += tsInt) {
      for (int y = startY; y < endY; y += tsInt) {
        ids.add('$x:$y');
      }
    }
    return ids;
  }

  /// Асинхронно создаёт тайлы для отсутствующих ID.
  Future<void> _loadMissingTiles(Set<String> missingIds) async {
    if (_isLoadingTiles) return;
    _isLoadingTiles = true;
    try {
      for (final id in missingIds) {
        // Проверяем, не появился ли тайл пока мы ждали
        if (state.tileIndex.containsKey(id) || _lruCache.containsKey(id)) continue;

        // Предварительная проверка: есть ли контент в области этого тайла.
        // Если нет — не запускаем дорогой async-рендер.
        if (!_tileAreaHasContent(id)) continue;

        final tile = await tileManager.createTileById(id, state.nodes, state.arrows);
        if (tile != null) {
          state.tileIndex[id] = tile;
          if (!state.imageTiles.any((t) => t.id == id)) {
            state.imageTiles.add(tile);
          }
        }
      }
      onStateUpdate();
    } finally {
      _isLoadingTiles = false;
    }
  }

  /// Быстрая проверка: есть ли хотя бы один узел или стрелка в области тайла.
  /// Используется как дешёвый фильтр перед дорогим async-рендером.
  bool _tileAreaHasContent(String tileId) {
    final parts = tileId.split(':');
    if (parts.length != 2) return false;
    final left = double.tryParse(parts[0]);
    final top  = double.tryParse(parts[1]);
    if (left == null || top == null) return false;

    final ts = EditorConfig.tileSize.toDouble();
    final tileBounds = Rect.fromLTRB(left, top, left + ts, top + ts);

    // Проверяем узлы (включая вложенные)
    bool hasNode = false;
    void checkNodes(List<dynamic> nodes) {
      for (final n in nodes) {
        if (n == null) continue;
        final pos = n.aPosition ?? (state.delta + n.position);
        final rect = Rect.fromLTWH(pos.dx, pos.dy, n.size.width, n.size.height);
        if (rect.overlaps(tileBounds)) {
          hasNode = true;
          return;
        }
        if (n.children != null && n.children!.isNotEmpty) {
          checkNodes(n.children!);
          if (hasNode) return;
        }
      }
    }
    checkNodes(state.nodes);
    if (hasNode) return true;

    // Проверяем стрелки: хотя бы один конец стрелки должен быть в тайле
    // (упрощённая проверка — точная выполняется в createTileById)
    for (final arrow in state.arrows) {
      final sourceNode = _findNodeById(arrow.source);
      final targetNode = _findNodeById(arrow.target);
      if (sourceNode != null) {
        final pos = sourceNode.aPosition ?? (state.delta + sourceNode.position);
        final rect = Rect.fromLTWH(pos.dx, pos.dy, sourceNode.size.width, sourceNode.size.height);
        if (rect.overlaps(tileBounds)) return true;
      }
      if (targetNode != null) {
        final pos = targetNode.aPosition ?? (state.delta + targetNode.position);
        final rect = Rect.fromLTWH(pos.dx, pos.dy, targetNode.size.width, targetNode.size.height);
        if (rect.overlaps(tileBounds)) return true;
      }
    }

    return false;
  }

  /// Ищет узел по id во всей иерархии.
  dynamic _findNodeById(String? id) {
    if (id == null) return null;
    dynamic findIn(List<dynamic> nodes) {
      for (final n in nodes) {
        if (n == null) continue;
        if (n.id == id) return n;
        if (n.children != null && n.children!.isNotEmpty) {
          final found = findIn(n.children!);
          if (found != null) return found;
        }
      }
      return null;
    }
    return findIn(state.nodes);
  }

  /// Помещает тайл в LRU-кэш, вытесняя старые при переполнении.
  void _putToLru(String id, ImageTile tile) {
    if (_lruCache.containsKey(id)) {
      _lruOrder.remove(id);
    }
    _lruCache[id] = tile;
    _lruOrder.add(id);

    // Вытесняем самые старые тайлы при переполнении
    while (_lruOrder.length > _lruMaxSize) {
      final evictId = _lruOrder.removeAt(0);
      final evicted = _lruCache.remove(evictId);
      if (evicted != null) {
        try {
          evicted.dispose();
        } catch (_) {}
      }
    }
  }

  /// Планирует перерисовку тайлов после завершения зума (debounce 250ms).
  void _scheduleScaleRedrawIfNeeded() {
    final scaleDiff = (state.scale - _lastRenderedScale).abs();
    if (_lastRenderedScale < 0 || scaleDiff > _scaleRedrawThreshold) {
      _zoomDebounceTimer?.cancel();
      _zoomDebounceTimer = Timer(const Duration(milliseconds: 250), () async {
        _lastRenderedScale = state.scale;
        // Перерисовываем только видимые тайлы
        await tileManager.updateTilesAfterNodeChange();
        syncTileIndex();
        onStateUpdate();
      });
    }
  }

  /// Полный сброс при пересоздании всех тайлов (например, после загрузки диаграммы).
  void reset() {
    _zoomDebounceTimer?.cancel();
    _visibleTileIds = {};
    _lruOrder.clear();
    for (final tile in _lruCache.values) {
      try {
        tile.dispose();
      } catch (_) {}
    }
    _lruCache.clear();
    _lastRenderedScale = -1.0;
    syncTileIndex();
  }

  @override
  void dispose() {
    _zoomDebounceTimer?.cancel();
    for (final tile in _lruCache.values) {
      try {
        tile.dispose();
      } catch (_) {}
    }
    _lruCache.clear();
    super.dispose();
  }
}
