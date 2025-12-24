import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/table.node.dart';
import '../services/tile_manager.dart';

class NodeManager {
  final EditorState state;
  final TileManager tileManager;
  final VoidCallback onStateUpdate;

  Offset _nodeDragStart = Offset.zero;
  Offset _nodeStartWorldPosition = Offset.zero;

  // Константы для точных вычислений
  static const double selectionPadding = 4.0; // 4 пикселя отступа рамки
  static const double visualCompensationPixels =
      2.0; // Визуальный сдвиг в пикселях

  NodeManager({
    required this.state,
    required this.tileManager,
    required this.onStateUpdate,
  });

  // Метод для получения экранных координат из мировых
  Offset _worldToScreen(Offset worldPosition) {
    return worldPosition * state.scale + state.offset;
  }

  // Метод для получения мировых координат из экранных
  Offset _screenToWorld(Offset screenPosition) {
    return (screenPosition - state.offset) / state.scale;
  }

  // Корректировка позиции при изменении масштаба
  void onScaleChanged() {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      // Просто пересчитываем экранные координаты на основе мировых
      _updateScreenPosition();
      onStateUpdate();
    }
  }

  // ВАЖНОЕ ИСПРАВЛЕНИЕ: Корректировка позиции при изменении offset (панорамировании/скроллинге)
  void onOffsetChanged() {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      // Просто пересчитываем экранные координаты на основе мировых
      _updateScreenPosition();
      onStateUpdate();
    }
  }

  // Обновление экранной позиции на основе мировых координат
  void _updateScreenPosition() {
    if (state.selectedNodeOnTopLayer == null) return;

    final node = state.selectedNodeOnTopLayer!;

    // Мировые координаты левого верхнего угла узла
    // (не центра, а левого верхнего угла как в тайлах)
    final worldTopLeft = state.originalNodePosition;

    // Экранные координаты левого верхнего угла узла
    final screenTopLeft = _worldToScreen(worldTopLeft);

    // Размер узла с учетом минимальной высоты
    final nodeSize = _calculateNodeSize(node);
    final scaledWidth = nodeSize.width * state.scale;
    final scaledHeight = nodeSize.height * state.scale;

    // ВАЖНОЕ ИСПРАВЛЕНИЕ: используем только selectionPadding
    // Компенсационный сдвиг не нужен, если позиционируем от левого верхнего угла
    final double totalOffsetInScreen = selectionPadding * state.scale;

    // Позиция рамки: смещаем от узла на padding
    state.selectedNodeOffset = Offset(
      screenTopLeft.dx - totalOffsetInScreen,
      screenTopLeft.dy - totalOffsetInScreen,
    );

    print('=== ОБНОВЛЕНИЕ ПОЗИЦИИ ===');
    print('Мировые координаты узла: $worldTopLeft');
    print('Экранные координаты узла: $screenTopLeft');
    print('Размер узла: $nodeSize');
    print('Масштабированный размер: ${scaledWidth}x$scaledHeight');
    print('Offset: $totalOffsetInScreen');
    print('Позиция рамки: ${state.selectedNodeOffset}');
  }

  void selectNodeAtPosition(
    Offset screenPosition, {
    bool immediateDrag = false,
  }) {
    final worldPos = _screenToWorld(screenPosition);

    TableNode? foundNode;

    // Ищем узел под курсором (с учетом иерархии)
    TableNode? findNodeRecursive(List<TableNode> nodes, Offset parentOffset) {
      for (int i = nodes.length - 1; i >= 0; i--) {
        final node = nodes[i];
        final nodeOffset = parentOffset + node.position;
        final nodeRect = Rect.fromLTWH(
          nodeOffset.dx,
          nodeOffset.dy,
          node.size.width,
          node.size.height,
        );

        // ВАЖНОЕ ИСПРАВЛЕНИЕ: если это выделенный узел на верхнем слое,
        // игнорируем его при поиске (так как он визуально перемещен)
        if (state.isNodeOnTopLayer &&
            state.selectedNodeOnTopLayer != null &&
            state.selectedNodeOnTopLayer!.id == node.id) {
          continue; // Пропускаем этот узел
        }

        if (nodeRect.contains(worldPos)) {
          return node;
        }

        // Проверяем детей
        if (node.children != null && node.children!.isNotEmpty) {
          final childNode = findNodeRecursive(node.children!, nodeOffset);
          if (childNode != null) {
            return childNode;
          }
        }
      }
      return null;
    }

    // Ищем узел в корневых узлах
    foundNode = findNodeRecursive(state.nodes, state.delta);

    if (foundNode != null) {
      // Если уже есть выделенный узел на верхнем слое
      if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
        // И если это тот же узел (не должно случиться из-за проверки выше)
        if (state.selectedNodeOnTopLayer!.id == foundNode.id) {
          if (immediateDrag) {
            startNodeDrag(screenPosition);
          }
          return;
        }

        if (immediateDrag) {
          if (state.isNodeDragging) {
            endNodeDrag();
          }

          _saveNodeInBackground(state.selectedNodeOnTopLayer!);
          _selectNodeImmediate(foundNode, screenPosition);
        } else {
          _saveNodeToTiles().then((_) {
            _selectNode(foundNode!);
          });
        }
      } else {
        if (immediateDrag) {
          _selectNodeImmediate(foundNode, screenPosition);
        } else {
          _selectNode(foundNode);
        }
      }
    } else {
      // Клик на пустую область
      handleEmptyAreaClick();
    }
  }

  // Немедленный выбор узла с началом перетаскивания
  void _selectNodeImmediate(TableNode node, Offset screenPosition) {
    // Снимаем выделение со всех узлов
    _deselectAllNodes();

    // Выделяем найденный узел
    node.isSelected = true;
    state.selectedNode = node;

    // ВАЖНО: Сохраняем мировую позицию ЛЕВОГО ВЕРХНЕГО УГЛА узла
    // (а не центра, как было раньше)
    final worldTopLeft = state.delta + node.position;
    state.originalNodePosition = worldTopLeft;

    print('=== ВЫБОР УЗЛА ===');
    print('Позиция узла в данных: ${node.position}');
    print('Дельта: ${state.delta}');
    print('Мировая позиция левого верхнего угла: $worldTopLeft');
    print('Размер узла в данных: ${node.size}');
    print('Расчетный размер узла: ${_calculateNodeSize(node)}');

    // Перемещаем узел на верхний слой
    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;

    // Обновляем экранную позицию
    _updateScreenPosition();

    // Удаляем узел из тайлов (только визуально, не из данных)
    tileManager.removeNodeFromTiles(node);

    // Немедленно начинаем перетаскивание
    startNodeDrag(screenPosition);

    onStateUpdate();
  }

  void _selectNode(TableNode node) {
    // Снимаем выделение со всех узлов
    _deselectAllNodes();

    // Выделяем найденный узел
    node.isSelected = true;
    state.selectedNode = node;

    // Сохраняем мировую позицию ЛЕВОГО ВЕРХНЕГО УГЛА узла
    final worldTopLeft = state.delta + node.position;
    state.originalNodePosition = worldTopLeft;

    // Перемещаем узел на верхний слой
    state.selectedNodeOnTopLayer = node;
    state.isNodeOnTopLayer = true;

    // Обновляем экранную позицию
    _updateScreenPosition();

    // Удаляем узел из тайлов (только визуально, не из данных)
    tileManager.removeNodeFromTiles(node);

    onStateUpdate();
  }

  // Сохранение узла в фоне (асинхронно, без ожидания)
  Future<void> _saveNodeInBackground(TableNode node) async {
    // Мировые координаты левого верхнего угла узла
    final worldTopLeft = state.originalNodePosition;

    // Ограничиваем позицию узла границами тайлов
    final constrainedWorldPosition = _constrainNodePosition(worldTopLeft, node);

    // Вычисляем новую позицию узла относительно дельты
    final newPosition = constrainedWorldPosition - state.delta;

    // Обновляем позицию узла в оригинальных данных
    node.position = newPosition;

    // Добавляем узел обратно в тайлы
    await tileManager.addNodeToTiles(node, constrainedWorldPosition);

    // Снимаем выделение
    node.isSelected = false;
  }

  Future<void> _saveNodeToTiles() async {
    if (!state.isNodeOnTopLayer || state.selectedNodeOnTopLayer == null) {
      return;
    }

    final node = state.selectedNodeOnTopLayer!;

    // Мировые координаты левого верхнего угла узла
    final worldTopLeft = state.originalNodePosition;

    // Ограничиваем позицию узла границами тайлов
    final constrainedWorldPosition = _constrainNodePosition(worldTopLeft, node);

    // Вычисляем новую позицию узла относительно дельты
    final newPosition = constrainedWorldPosition - state.delta;

    // Обновляем позицию узла в оригинальных данных
    node.position = newPosition;

    // Добавляем узел обратно в тайлы
    await tileManager.addNodeToTiles(node, constrainedWorldPosition);

    // Снимаем выделение
    node.isSelected = false;

    // Сбрасываем состояние перетаскивания
    state.isNodeDragging = false;

    // Сбрасываем состояние
    state.isNodeOnTopLayer = false;
    state.selectedNodeOnTopLayer = null;
    state.selectedNode = null;
    state.selectedNodeOffset = Offset.zero;
    state.originalNodePosition = Offset.zero;

    onStateUpdate();
  }

  // ВАЖНОЕ ИСПРАВЛЕНИЕ: ограничение позиции узла границами тайлов
  Offset _constrainNodePosition(Offset worldPosition, TableNode node) {
    if (state.imageTiles.isEmpty) {
      return worldPosition;
    }

    // Получаем общие границы всех тайлов
    final totalBounds = state.totalBounds;

    // Рассчитываем границы узла
    final nodeWidth = node.size.width;
    final nodeHeight = node.size.height;

    // Ограничиваем позицию так, чтобы узел не выходил за границы тайлов
    double constrainedX = worldPosition.dx;
    double constrainedY = worldPosition.dy;

    // Левый край
    if (constrainedX < totalBounds.left) {
      constrainedX = totalBounds.left;
    }

    // Верхний край
    if (constrainedY < totalBounds.top) {
      constrainedY = totalBounds.top;
    }

    // Правый край
    if (constrainedX + nodeWidth > totalBounds.right) {
      constrainedX = totalBounds.right - nodeWidth;
    }

    // Нижний край
    if (constrainedY + nodeHeight > totalBounds.bottom) {
      constrainedY = totalBounds.bottom - nodeHeight;
    }

    // Также ограничиваем минимальные значения
    if (constrainedX < totalBounds.left) {
      constrainedX = totalBounds.left;
    }
    if (constrainedY < totalBounds.top) {
      constrainedY = totalBounds.top;
    }

    final constrained = Offset(constrainedX, constrainedY);

    if (constrained != worldPosition) {
      print('Позиция узла ограничена: $worldPosition -> $constrained');
    }

    return constrained;
  }

  void deleteSelectedNode() {
    if (state.selectedNode != null) {
      print('Удаление узла: ${state.selectedNode!.text}');

      // Если узел на верхнем слое, сначала сохраняем его
      if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
        _saveNodeToTiles().then((_) {
          // После сохранения удаляем узел из данных
          state.nodes.removeWhere((node) => node.id == state.selectedNode!.id);
          state.selectedNode = null;

          // Пересоздаем тайлы без удаленного узла
          tileManager.createTiledImage(state.nodes);
        });
      } else {
        // Удаляем узел из списка
        state.nodes.removeWhere((node) => node.id == state.selectedNode!.id);
        state.selectedNode = null;

        // Пересоздаем тайлы без удаленного узла
        tileManager.createTiledImage(state.nodes);
      }

      onStateUpdate();
    }
  }

  void startNodeDrag(Offset screenPosition) {
    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      _nodeDragStart = screenPosition;
      _nodeStartWorldPosition =
          state.originalNodePosition; // Теперь это левый верхний угол

      state.isNodeDragging = true;
      onStateUpdate();
    }
  }

  void updateNodeDrag(Offset screenPosition) {
    if (state.isNodeDragging &&
        state.isNodeOnTopLayer &&
        state.selectedNodeOnTopLayer != null) {
      final screenDelta = screenPosition - _nodeDragStart;
      final worldDelta = screenDelta / state.scale;

      // Обновляем мировую позицию ЛЕВОГО ВЕРХНЕГО УГЛА
      final newWorldPosition = _nodeStartWorldPosition + worldDelta;
      state.originalNodePosition = newWorldPosition;

      _updateScreenPosition();

      onStateUpdate();
    }
  }

  void endNodeDrag() {
    if (state.isNodeDragging) {
      print('Конец перетаскивания узла');
      state.isNodeDragging = false;
      onStateUpdate();
    }
  }

  void handleEmptyAreaClick() {
    print('Клик на пустую область');

    if (state.isNodeOnTopLayer && state.selectedNodeOnTopLayer != null) {
      // Сохраняем узел обратно в тайлы
      _saveNodeToTiles();
    } else {
      // Просто снимаем выделение
      _deselectAllNodes();
      state.selectedNode = null;
      state.isNodeOnTopLayer = false;
      state.selectedNodeOnTopLayer = null;
      state.selectedNodeOffset = Offset.zero;
      state.originalNodePosition = Offset.zero;
      onStateUpdate();
    }
  }

  void _deselectAllNodes() {
    void deselectRecursive(List<TableNode> nodes) {
      for (final node in nodes) {
        node.isSelected = false;
        if (node.children != null && node.children!.isNotEmpty) {
          deselectRecursive(node.children!);
        }
      }
    }

    deselectRecursive(state.nodes);
  }

  // Единый метод расчета размеров узла (должен совпадать с NodeRenderer)
  Size _calculateNodeSize(TableNode node) {
    final headerHeight = 30.0; // EditorConfig.headerHeight
    final minRowHeight = 18.0; // EditorConfig.minRowHeight

    // Расчет минимальной высоты как в NodeRenderer
    final minHeight = headerHeight + (node.attributes.length * minRowHeight);
    final actualHeight = node.size.height > minHeight
        ? node.size.height
        : minHeight;

    return Size(node.size.width, actualHeight);
  }
}
