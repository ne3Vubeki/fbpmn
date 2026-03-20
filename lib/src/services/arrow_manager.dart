import 'dart:math';
import 'dart:ui';

import 'package:fbpmn/src/editor_state.dart';
import 'package:fbpmn/src/models/arrow_paths.dart';
import 'package:fbpmn/src/services/event_service.dart';
import 'package:fbpmn/src/services/shema_manager.dart';
import 'package:fbpmn/src/services/tile_manager.dart';
import 'package:fbpmn/src/utils/editor_config.dart';
import 'package:fbpmn/src/utils/utils.dart';
import 'package:flutter/cupertino.dart';

import '../models/attribute.dart';
import '../models/connection.dart';
import '../models/table.node.dart';
import '../models/arrow.dart';
import 'manager.dart';

/// Сервис для управления и расчета соединений стрелок
class ArrowManager extends Manager {
  final EditorState state;
  final ShemaManager schemaManager;

  double get arrowIndent => 12;
  double get createdArrowSourceHandleOffset => 14;
  double get createdArrowSnapDistance => 24;
  double get sizeLimit => 60;
  double get halfSizeLimit => 30;
  double get defaultArrowRadius => 10;
  double get arrowPathRectOffset => 5;
  bool get onlyConnectors => state.onlyConnectors;

  ArrowManager({required this.state, required this.schemaManager});

  Future<void> createArrowFromMap(Map<String, dynamic> arrowMap) async {
    final arrow = Arrow.fromJson(arrowMap);
    state.arrows.add(arrow);
    state.arrowsSelected.add(arrow);
    _syncArrowToSchema(arrowMap, arrow);
    clearStartCreatedArrow();
    EventService.apiStatic('schema_update', {'schema': state.schema});

    onStateUpdate('update_arrows');
  }

  Future<void> confirmDeleteNode(Arrow arrow) async {
    // TODO: добавить обработчик для подтверждения удаления узла
  }

  Future<void> deleteSelectedArrows() async {
    final arrowsToDelete = state.arrowsSelected.whereType<Arrow>().toList();
    if (arrowsToDelete.isEmpty) {
      return;
    }

    final arrowIds = arrowsToDelete.map((arrow) => arrow.id).toList();

    for (final arrow in arrowsToDelete) {
      _removeArrowConnections(arrow);
    }

    state.arrows.removeWhere((arrow) => arrowIds.contains(arrow.id));
    state.arrowsSelected.clear();

    if (state.hoveredArrow != null && arrowIds.contains(state.hoveredArrow!.id)) {
      state.hoveredArrow = null;
    }

    if (state.arrowCreated != null && arrowIds.contains(state.arrowCreated!.id)) {
      clearStartCreatedArrow();
    }

    _removeArrowsFromSchema(arrowIds);

    EventService.apiStatic('schema_update', {'schema': state.schema});

    onStateUpdate();
  }

  void _syncArrowToSchema(Map<String, dynamic> arrowMap, Arrow arrow) {
    final schema = state.schema;
    final arrows = List<dynamic>.from(schema['arrows'] as List<dynamic>? ?? const []);
    final arrowJson = Map<String, dynamic>.from(arrowMap.isNotEmpty ? arrowMap : arrow.toJson());
    final arrowId = arrowJson['id']?.toString() ?? arrow.id;

    final existingIndex = arrows.indexWhere((item) => item is Map && item['id']?.toString() == arrowId);
    if (existingIndex >= 0) {
      arrows[existingIndex] = arrowJson;
    } else {
      arrows.add(arrowJson);
    }

    final metadata = Map<String, dynamic>.from(schema['metadata'] as Map<String, dynamic>? ?? const {});
    metadata['arrows'] = arrows.length;

    schema['arrows'] = arrows;
    schema['metadata'] = metadata;
    state.schema = Map<String, dynamic>.from(schema);
  }

  void _removeArrowsFromSchema(List<String> arrowIds) {
    final schema = state.schema;
    final arrows = List<dynamic>.from(schema['arrows'] as List<dynamic>? ?? const []);

    arrows.removeWhere((item) => item is Map && arrowIds.contains(item['id']?.toString()));

    final metadata = Map<String, dynamic>.from(schema['metadata'] as Map<String, dynamic>? ?? const {});
    metadata['arrows'] = arrows.length;

    schema['arrows'] = arrows;
    schema['metadata'] = metadata;
    state.schema = Map<String, dynamic>.from(schema);
  }

  void _removeArrowConnections(Arrow arrow) {
    final sourceNodeAndAttr = _getNodeFromArrow(arrow.source);
    sourceNodeAndAttr.attribute?.connections?.remove(arrow.id);
    sourceNodeAndAttr.node?.connections?.remove(arrow.id);

    if (arrow.target.isNotEmpty) {
      final targetNodeAndAttr = _getNodeFromArrow(arrow.target);
      targetNodeAndAttr.attribute?.connections?.remove(arrow.id);
      targetNodeAndAttr.node?.connections?.remove(arrow.id);
    }
  }

  Future<void> confirmCreateArrow(Arrow arrow) async {
    EventService.apiStatic('confirm_create_arrow', {'arrow': arrow.toJson()});
  }

  Future<void> startCreateArrowFromMap(Map<String, dynamic> arrowMap, String startSide) async {
    final sourceId = (arrowMap['source'] as String?) ?? '';
    if (sourceId.isEmpty) {
      return;
    }

    state.arrowCreated = Arrow(id: '', qType: '', source: sourceId, target: '', style: '');
    state.arrowCreatedStartSide = '${{'l': 'left', 't': 'top', 'r': 'right', 'b': 'bottom'}[startSide]!}:';
    onStateUpdate();
  }

  void clearStartCreatedArrow() {
    final arrow = state.arrowCreated;
    if (arrow == null) {
      return;
    }

    final sourceNodeAndAttr = _getNodeFromArrow(arrow.source);
    sourceNodeAndAttr.attribute?.connections?.remove(arrow.id);
    sourceNodeAndAttr.node?.connections?.remove(arrow.id);

    if (arrow.target.isNotEmpty) {
      final targetNodeAndAttr = _getNodeFromArrow(arrow.target);
      targetNodeAndAttr.attribute?.connections?.remove(arrow.id);
      targetNodeAndAttr.node?.connections?.remove(arrow.id);
    }

    state.arrowCreated = null;
    state.arrowCreatedStartSide = null;
    onStateUpdate();
  }

  void updateCreatedArrowTargetSnap(Offset screenPosition) {
    final arrow = state.arrowCreated;
    if (arrow == null) {
      state.mousePosition = screenPosition;
      return;
    }

    final snapTarget = _findClosestCreatedArrowSnapTarget(screenPosition, arrow);
    state.mousePosition = snapTarget?.screenPosition ?? screenPosition;
    arrow.target = snapTarget?.targetId ?? '';
    arrow.sides = snapTarget != null
        ? '${state.arrowCreatedStartSide}${snapTarget.targetSide}'
        : state.arrowCreatedStartSide;
    onStateUpdate('ArrowCreated');
  }

  selectAllArrows() {
    final arrowsSelected = getArrowsForNodes(state.nodesSelected.toList()).toSet();
    state.arrowsSelected.addAll(arrowsSelected);
    onStateUpdate();
  }

  /// Пересчитывает координаты всех выбранных стрелок
  /// Используется при динамическом изменении позиций узлов (например, Cola layout)
  void recalculateSelectedArrows() {
    for (final arrow in state.arrowsSelected) {
      if (arrow == null) continue;
      // Пересчитываем путь стрелки с текущими позициями узлов
      getArrowPathInTile(arrow, state.delta);
    }
  }

  ({Arrow arrow, Rect rect})? findArrowAtWorldPosition(Offset worldPos, TileManager tileManager) {
    final tile = tileManager.getTileAtWorldPosition(worldPos);
    if (tile == null) {
      return null;
    }

    for (final arrowId in tile.arrows) {
      if (arrowId == null) continue;

      Arrow? arrow;
      for (final item in state.arrows) {
        if (item.id == arrowId) {
          arrow = item;
          break;
        }
      }
      if (arrow == null) continue;

      final rects = arrow.rects;
      if (rects == null || rects.isEmpty) continue;

      for (final rect in rects) {
        if (rect.contains(worldPos)) {
          return (arrow: arrow, rect: rect);
        }
      }
    }

    return null;
  }

  void onHover(Offset localPosition, TileManager tileManager) {
    final worldPos = Utils.screenToWorld(localPosition, state);
    final foundArrow = findArrowAtWorldPosition(worldPos, tileManager);
    final selectedArrow = state.arrowsSelected.isNotEmpty ? state.arrowsSelected.first : null;
    final nextHoveredArrow = foundArrow?.arrow;

    if (nextHoveredArrow?.id == selectedArrow?.id) {
      if (state.hoveredArrow != null) {
        state.hoveredArrow = null;
        onStateUpdate();
      }
      return;
    }

    if (state.hoveredArrow?.id != nextHoveredArrow?.id) {
      state.hoveredArrow = nextHoveredArrow;
      onStateUpdate();
    }
  }

  void clearHoveredArrow() {
    if (state.hoveredArrow != null) {
      state.hoveredArrow = null;
      onStateUpdate();
    }
  }

  /// Расчет точек соединения для определения стороны
  /// по расположению узлов относительно друг друга
  ({Offset? end, Offset? start, String? sides}) calculateConnectionPoints({
    required Arrow arrow,
    required Rect sourceRect,
    Rect? targetRect,
    Offset? targetPoint,
    required TableNode sourceNode,
    TableNode? targetNode,
    Attribute? sourceAttribute,
    Attribute? targetAttribute,
  }) {
    /// Одно из свойств должно быть заполнено всегда
    assert(targetRect != null || targetPoint != null);

    final pointRect = const Offset(0, 0);
    targetRect = targetRect ?? Rect.fromPoints(targetPoint! - pointRect, targetPoint + pointRect);

    // Определяем центральные точки узлов
    final sourceCenter = sourceRect.center;
    final targetCenter = targetRect.center;

    // Определяем стороны и размеры узлов
    final sourceTop = sourceRect.top;
    final sourceBottom = sourceRect.bottom;
    final sourceLeft = sourceRect.left;
    final sourceRight = sourceRect.right;

    final targetTop = targetRect.top;
    final targetBottom = targetRect.bottom;
    final targetLeft = targetRect.left;
    final targetRight = targetRect.right;

    // Вычисляем расстояния между центрами узлов
    final cx = targetCenter.dx - sourceCenter.dx;
    final cy = targetCenter.dy - sourceCenter.dy;

    // Истино для Source узла
    final isLeftSide60 = sourceRight <= targetLeft - 60;
    final isTopSide60 = sourceBottom <= targetTop - 60;
    final isRightSide60 = sourceLeft >= targetRight + 60;
    final isBottomSide60 = sourceTop >= targetBottom + 60;

    // Истино для Source узла
    final isLeftCenter60 = sourceCenter.dx <= targetLeft - 60;
    final isTopCenter60 = sourceCenter.dy <= targetTop - 60;
    final isRightCenter60 = sourceCenter.dx >= targetRight + 60;
    final isBottomCenter60 = sourceCenter.dy >= targetBottom + 60;

    // Source находится сторонами за пределами 60px зоны Target
    if (isLeftSide60 || isTopSide60 || isRightSide60 || isBottomSide60) {
      if (isLeftSide60 && isTopSide60) {
        return _getSidePosition(
          'left60|top60',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isRightSide60 && isTopSide60) {
        return _getSidePosition(
          'right60|top60',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isLeftSide60 && isBottomSide60) {
        return _getSidePosition(
          'left60|bottom60',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isRightSide60 && isBottomSide60) {
        return _getSidePosition(
          'right60|bottom60',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isLeftSide60) {
        return _getSidePosition(
          'left60',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isTopSide60) {
        return _getSidePosition(
          'top60',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isRightSide60) {
        return _getSidePosition(
          'right60',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isBottomSide60) {
        return _getSidePosition(
          'bottom60',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      }
    } else
    // Source находится центром за пределами 60px зоны Target
    if (isLeftCenter60 || isTopCenter60 || isRightCenter60 || isBottomCenter60) {
      if (isLeftCenter60 && isTopCenter60) {
        return _getSidePosition(
          'leftC|topC',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isRightCenter60 && isTopCenter60) {
        return _getSidePosition(
          'rightC|topC',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isLeftCenter60 && isBottomCenter60) {
        return _getSidePosition(
          'leftC|bottomC',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isRightCenter60 && isBottomCenter60) {
        return _getSidePosition(
          'rightC|bottomC',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isLeftCenter60 && cy > 0) {
        return _getSidePosition(
          'leftC|top',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isRightCenter60 && cy > 0) {
        return _getSidePosition(
          'rightC|top',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isLeftCenter60 && cy <= 0) {
        return _getSidePosition(
          'leftC|bottom',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isRightCenter60 && cy <= 0) {
        return _getSidePosition(
          'rightC|bottom',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isTopCenter60 && cx > 0) {
        return _getSidePosition(
          'left|topC',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isBottomCenter60 && cx > 0) {
        return _getSidePosition(
          'left|bottomC',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isTopCenter60 && cx <= 0) {
        return _getSidePosition(
          'right|topC',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (isBottomCenter60 && cx <= 0) {
        return _getSidePosition(
          'right|bottomC',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      }
    } else {
      // Source находится центром внутри 60px зоны Target, положение от центра Target
      if (cx > 0 && cy > 0) {
        return _getSidePosition(
          'left|top',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (cx > 0 && cy <= 0) {
        return _getSidePosition(
          'left|bottom',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (cx <= 0 && cy > 0) {
        return _getSidePosition(
          'right|top',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      } else if (cx <= 0 && cy <= 0) {
        return _getSidePosition(
          'right|bottom',
          sourceRect,
          targetRect,
          sourceNode,
          targetNode,
          sourceAttribute,
          targetAttribute,
          arrow,
        );
      }
    }

    return _getSidePosition(
      'error',
      sourceRect,
      targetRect,
      sourceNode,
      targetNode,
      sourceAttribute,
      targetAttribute,
      arrow,
    );
  }

  /// Расчет координат точек соединения
  ({Offset? start, Offset? end, String? sides}) _getSidePosition(
    String position,
    Rect sourceRect,
    Rect targetRect,
    TableNode sourceNode,
    TableNode? targetNode,
    Attribute? sourceAttribute,
    Attribute? targetAttribute,
    Arrow arrow,
  ) {
    String sides = '';

    try {
      final sourceHeightHeader = sourceNode.heightHeader ?? EditorConfig.minHeaderHeight;
      final targetHeightHeader = targetNode?.heightHeader ?? EditorConfig.minHeaderHeight;

      Offset sourceCenter = Offset(
        sourceRect.center.dx,
        sourceRect.top + sourceHeightHeader / 2 - EditorConfig.arrowSelectedWidth / 2,
      );
      Offset targetCenter = Offset(
        targetRect.center.dx,
        targetRect.top + targetHeightHeader / 2 - EditorConfig.arrowSelectedWidth / 2,
      );

      final cx = targetRect.center.dx - sourceRect.center.dx;
      final cy = targetRect.center.dy - sourceRect.center.dy;

      final sourceWidth = sourceRect.width;
      final sourceHeight = sourceHeightHeader;

      // Определяем стороны узлов
      final sourceTop = sourceRect.top;
      final sourceBottom = sourceRect.bottom;
      final sourceLeft = sourceRect.left;
      final sourceRight = sourceRect.right;

      final targetTop = targetRect.top;
      final targetBottom = targetRect.bottom;
      final targetLeft = targetRect.left;
      final targetRight = targetRect.right;

      final isSourceAttribute = sourceAttribute != null;
      final isTargetAttribute = targetAttribute != null;

      String getSidesForNodeAndAttribute({
        required String ifNode,
        required String ifAttrST,
        required String ifAttrS,
        required String ifAttrT,
        String? ifArrow,
      }) {
        if (isSourceAttribute && isTargetAttribute) {
          final startConnections = sourceAttribute.connections;
          final endConnections = targetAttribute.connections;

          startConnections?.remove(arrow.id);
          endConnections?.remove(arrow.id);

          final matrixSides = ifAttrST.split('|');
          final sidesList = matrixSides[0].split(':');
          final countSides =
              '${startConnections?.get(sidesList[0])?.length ?? 0}:${endConnections?.get(sidesList[1])?.length ?? 0}';
          switch (countSides) {
            case '0:0':
              ifNode = matrixSides[0];
            case '1:0':
              ifNode = matrixSides[1];
            case '0:1':
              ifNode = matrixSides[2];
            case '1:1':
              ifNode = matrixSides[3];
          }
          print('(${sourceAttribute.text})--->(${targetAttribute.text}) ... $countSides Sides: $ifNode');
          final connectSideList = ifNode.split(':');
          startConnections?.add(connectSideList[0], arrow.id);
          endConnections?.add(connectSideList[1], arrow.id);
          return ifNode;
        }

        if (isSourceAttribute) {
          final startConnections = sourceAttribute.connections;

          startConnections?.remove(arrow.id);

          if (targetNode != null) {
            final matrixSides = ifAttrS.split('|');
            final sidesList = matrixSides[0].split(':');

            final countSide = startConnections?.get(sidesList[0])?.length ?? 0;

            switch (countSide) {
              case 0:
                ifNode = matrixSides[0];
              case 1:
                ifNode = matrixSides[1];
            }
            print('(${sourceAttribute.text})--->(Node}) ... $countSide: Sides: $ifNode');
          } else {
            final startSide = cx < 0 ? 'left' : 'right';
            final endSide = state.arrowCreated?.sides?.split(':')[1];
            final countSide = startConnections?.get(startSide)?.length ?? 0;
            if (state.arrowCreated?.sides == null || endSide == '') {
              ifNode = countSide == 0
                  ? {'left': 'left:right', 'right': 'right:left'}[startSide]!
                  : {'right': 'left:right', 'left': 'right:left'}[startSide]!;
            } else {
              ifNode = state.arrowCreated!.sides!;
            }
            print('(${sourceAttribute.text})--->(Arrow}) ... $countSide: Sides: $ifNode EndSide: $endSide');
          }
          final connectSideList = ifNode.split(':');
          startConnections?.add(connectSideList[0], arrow.id);
          return ifNode;
        }

        if (isTargetAttribute) {
          final endConnections = targetAttribute.connections;

          endConnections?.remove(arrow.id);

          final matrixSides = ifAttrT.split('|');
          final sidesList = matrixSides[0].split(':');

          final countSide = endConnections?.get(sidesList[1])?.length ?? 0;

          switch (countSide) {
            case 0:
              ifNode = matrixSides[0];
            case 1:
              ifNode = matrixSides[1];
          }
          print('(Node)--->(${targetAttribute.text}) ... :$countSide Sides: $ifNode');
          final connectSideList = ifNode.split(':');
          endConnections?.add(connectSideList[1], arrow.id);
          return ifNode;
        }
        if (targetNode == null) {
          final sides = ifNode.split(':');
          final startSide = sides[0];
          String? endSide = state.arrowCreated?.sides?.split(':')[1];
          if (state.arrowCreated?.sides != null && endSide != '') {
            endSide = (startSide == 'left' || startSide == 'right') && (endSide == 'top' || endSide == 'bottom')
                ? '$endSide:3'
                : endSide;
            ifNode = sides.length == 3 ? '$startSide:$endSide:${sides[2]}' : '$startSide:$endSide';
          }
          print('(Node)--->(Arrow) ... ifNode: $ifNode CreateArrowSides: ${state.arrowCreated?.sides}');
          return ifNode;
        } else {
          return ifNode;
        }
      }

      Offset startConnectionPoint = Offset.zero;
      Offset endConnectionPoint = Offset.zero;

      if (isSourceAttribute || isTargetAttribute) {
        print('=======================================================================');
      }

      if (isSourceAttribute) {
        print('Source ${sourceAttribute.text} position: $position');
      }
      if (isTargetAttribute) {
        print('Target ${targetAttribute.text} position: $position');
      }
      switch (position) {
        case 'left60':
          sides = getSidesForNodeAndAttribute(
            ifNode: 'right:left',
            ifAttrST: 'right:left|left:left:4|right:right:4|left:right',
            ifAttrS: 'left:left|right:right',
            ifAttrT: '${cy < 0 ? 'bottom:right:3' : 'top:right:3'}|right:left',
          );
          break;
        case 'right60':
          sides = getSidesForNodeAndAttribute(
            ifNode: 'left:right',
            ifAttrST: 'left:right|right:right:4|left:left:4|right:left',
            ifAttrS: 'right:right|left:left',
            ifAttrT: '${cy < 0 ? 'bottom:left:3' : 'top:left:3'}|right:right',
          );
          break;
        case 'top60':
          sides = getSidesForNodeAndAttribute(
            ifNode: 'bottom:top',
            ifAttrST: 'left:left|left:left|right:right|left:left',
            ifAttrS: 'right:right|left:left',
            ifAttrT: '${cx < 0 ? 'right:right' : 'left:left'}|left:left',
          );
          break;
        case 'bottom60':
          sides = getSidesForNodeAndAttribute(
            ifNode: 'top:bottom',
            ifAttrST: 'left:left|left:left|right:right|left:left',
            ifAttrS: 'right:right|left:left',
            ifAttrT: '${cx < 0 ? 'left:left' : 'right:right'}|left:left',
          );
          break;
        case 'left60|top60':
          sides = getSidesForNodeAndAttribute(
            ifNode: sourceWidth < sourceHeight ? 'right:top' : 'bottom:left',
            ifAttrST: 'right:left|left:left|right:right|left:left',
            ifAttrS: 'right:top|left:left',
            ifAttrT: 'bottom:left|right:right',
          );
          break;
        case 'right60|top60':
          sides = getSidesForNodeAndAttribute(
            ifNode: sourceWidth < sourceHeight ? 'left:top' : 'bottom:right',
            ifAttrST: 'left:right|right:right|left:left|right:left',
            ifAttrS: 'left:top|right:right',
            ifAttrT: 'bottom:right|left:left',
          );
          break;
        case 'left60|bottom60':
          sides = getSidesForNodeAndAttribute(
            ifNode: sourceWidth < sourceHeight ? 'right:bottom' : 'top:left',
            ifAttrST: 'right:left|left:left|right:right|left:right',
            ifAttrS: 'right:bottom|left:left',
            ifAttrT: 'top:left|right:right',
          );
          break;
        case 'right60|bottom60':
          sides = getSidesForNodeAndAttribute(
            ifNode: sourceWidth < sourceHeight ? 'left:bottom' : 'top:right',
            ifAttrST: 'left:right|right:right|left:left|right:left',
            ifAttrS: 'right:top|left:top:3',
            ifAttrT: 'top:right|left:left',
          );
          break;
        case 'leftC|topC':
        case 'leftC|bottomC':
          if (sourceWidth < sourceHeight) {
            if (sourceRight <= targetCenter.dx - halfSizeLimit) {
              sides = position == 'leftC|topC' ? 'right:top' : 'right:bottom';
            } else if (sourceBottom <= targetCenter.dy - halfSizeLimit) {
              sides = position == 'leftC|topC' ? 'bottom:left' : 'top:left';
            } else {
              sides = 'right:right';
            }
          } else {
            if (sourceBottom <= targetCenter.dy - halfSizeLimit) {
              sides = position == 'leftC|topC' ? 'bottom:left' : 'top:left';
            } else if (sourceRight <= targetCenter.dx - halfSizeLimit) {
              sides = position == 'leftC|topC' ? 'right:top' : 'right:bottom';
            } else {
              sides = 'bottom:bottom';
            }
          }
          sides = getSidesForNodeAndAttribute(
            ifNode: sides,
            ifAttrST: 'left:left:right:left:4|left:right:4|right:right',
            ifAttrS: position == 'leftC|topC' ? 'right:top|left:right:4' : 'right:bottom|left:right:4',
            ifAttrT: position == 'leftC|topC' ? 'top:right:3|left:left' : 'bottom:right:3|left:left',
          );
          break;
        case 'rightC|topC':
        case 'rightC|bottomC':
          if (sourceWidth < sourceHeight) {
            if (sourceLeft > targetCenter.dx + halfSizeLimit) {
              sides = position == 'rightC|topC' ? 'left:top' : 'left:bottom';
            } else if (sourceBottom <= targetCenter.dy - halfSizeLimit) {
              sides = position == 'rightC|topC' ? 'bottom:right' : 'top:right';
            } else {
              sides = 'left:left';
            }
          } else {
            if (sourceBottom <= targetCenter.dy - halfSizeLimit) {
              sides = position == 'rightC|topC' ? 'bottom:right' : 'top:right';
            } else if (sourceLeft > targetCenter.dx - halfSizeLimit) {
              sides = position == 'rightC|topC' ? 'left:top' : 'left:bottom';
            } else {
              sides = 'bottom:bottom';
            }
          }
          sides = getSidesForNodeAndAttribute(
            ifNode: sides,
            ifAttrST: 'right:right|left:right:4|right:left:4|left:left',
            ifAttrS: position == 'rightC|topC' ? 'left:top|right:left:4' : 'left:bottom|right:left:4',
            ifAttrT: position == 'rightC|topC' ? 'top:left:3|right:right' : 'bottom:left:3|right:right',
          );
          break;
        case 'leftC|top':
          sides = getSidesForNodeAndAttribute(
            ifNode: sourceBottom <= targetCenter.dy - halfSizeLimit ? 'bottom:left' : 'bottom:bottom',
            ifAttrST: 'left:right:4|right:right|left:left|right:left:4',
            ifAttrS: 'left:bottom:3|right:right',
            ifAttrT: 'top:right:3|top:left:3',
          );
          break;
        case 'rightC|top':
          sides = getSidesForNodeAndAttribute(
            ifNode: sourceBottom <= targetCenter.dy - halfSizeLimit ? 'bottom:right' : 'bottom:bottom',
            ifAttrST: 'right:left:4|left:left:4|right:right:4|left:right:4',
            ifAttrS: 'right:bottom:3|left:left',
            ifAttrT: 'top:left:3|top:right:3',
          );
          break;
        case 'leftC|bottom':
          sides = getSidesForNodeAndAttribute(
            ifNode: sourceTop > targetCenter.dy + halfSizeLimit ? 'top:left' : 'top:top',
            ifAttrST: 'left:right:4|right:right|left:left|right:left:4',
            ifAttrS: 'left:top:3|right:right',
            ifAttrT: 'top:right:3|bottom:left:3',
          );
          break;
        case 'rightC|bottom':
          sides = getSidesForNodeAndAttribute(
            ifNode: sourceTop > targetCenter.dy + halfSizeLimit ? 'top:right' : 'top:top',
            ifAttrST: 'right:left:4|left:left:4|right:right:4|left:right:4',
            ifAttrS: 'right:top:3|left:left',
            ifAttrT: 'bottom:left:3|bottom:right:3',
          );
          break;
        case 'left|topC':
          sides = getSidesForNodeAndAttribute(
            ifNode: 'left:left',
            ifAttrST: 'left:right:4|right:right|left:left|right:left:4',
            ifAttrS: 'left:bottom:3|right:bottom:3',
            ifAttrT: 'top:right:3|top:left:3',
          );
          break;
        case 'left|bottomC':
          sides = getSidesForNodeAndAttribute(
            ifNode: 'left:left',
            ifAttrST: 'left:right:4|right:right|left:left|right:left:4',
            ifAttrS: 'left:top:3|right:top:3',
            ifAttrT: 'bottom:right:3|bottom:left:3',
          );
          break;
        case 'right|topC':
          sides = getSidesForNodeAndAttribute(
            ifNode: 'right:right',
            ifAttrST: 'right:left:4|left:left|right:right|left:right:4',
            ifAttrS: 'right:bottom:3|left:bottom:3',
            ifAttrT: 'top:left:3|top:right:3',
          );
          break;
        case 'right|bottomC':
          sides = getSidesForNodeAndAttribute(
            ifNode: 'right:right',
            ifAttrST: 'right:left:4|left:left|right:right|left:right:4',
            ifAttrS: 'right:top:3|left:top:3',
            ifAttrT: 'bottom:left:3|bottom:right:3',
          );
          break;
        case 'left|top':
          if (sourceTop < targetTop) {
            sides = 'top:right:3';
          } else if (sourceBottom > targetBottom) {
            sides = 'bottom:right:3';
          } else if (sourceLeft < targetLeft) {
            sides = 'left:top:3';
          } else {
            sides = 'left:top:3';
          }
          sides = getSidesForNodeAndAttribute(
            ifNode: sides,
            ifAttrST: 'left:right:4|right:right|left:left|right:left:4',
            ifAttrS: 'left:bottom:3|right:bottom:3',
            ifAttrT: 'top:right:3|top:left:3',
          );
          break;
        case 'right|top':
          if (sourceTop < targetTop) {
            sides = 'top:left:3';
          } else if (sourceBottom > targetBottom) {
            sides = 'bottom:left:3';
          } else if (sourceRight > targetRight) {
            sides = 'right:top:3';
          } else {
            sides = 'right:top:3';
          }
          sides = getSidesForNodeAndAttribute(
            ifNode: sides,
            ifAttrST: 'right:left:4|left:left|right:right|left:right:4',
            ifAttrS: 'right:bottom:3|left:bottom:3',
            ifAttrT: 'top:left:3|top:right:3',
          );
          break;
        case 'left|bottom':
          if (sourceBottom > targetBottom) {
            sides = 'bottom:right:3';
          } else if (sourceTop < targetTop) {
            sides = 'top:right:3';
          } else if (sourceLeft < targetLeft) {
            sides = 'left:bottom:3';
          } else {
            sides = 'left:bottom:3';
          }
          sides = getSidesForNodeAndAttribute(
            ifNode: sides,
            ifAttrST: 'left:right:4|right:right:4|left:left:4|right:left:4',
            ifAttrS: 'left:top:3|right:top:3',
            ifAttrT: 'bottom:right:3|bottom:left:3',
          );
          break;
        case 'right|bottom':
          if (sourceBottom > targetBottom) {
            sides = 'bottom:left:3';
          } else if (sourceTop < targetTop) {
            sides = 'top:left:3';
          } else if (sourceRight > targetRight) {
            sides = 'right:bottom:3';
          } else {
            sides = 'right:bottom:3';
          }
          sides = getSidesForNodeAndAttribute(
            ifNode: sides,
            ifAttrST: 'right:left:4|left:left|right:right|left:right:4',
            ifAttrS: 'right:top:3|left:top:3',
            ifAttrT: 'bottom:left:3|bottom:right:3',
          );
          break;
        default:
          sides = 'error';
          break;
      }

      if (isSourceAttribute) {
        print('Source ${sourceAttribute.text} postsides: $sides');
      }
      if (isTargetAttribute) {
        print('Target ${targetAttribute.text} postsides: $sides');
      }

      final sidesNodesList = sides.split(':');

      String sidesNodes = sidesNodesList.take(2).join(':');

      double startDeltaPos = 0;
      double endDeltaPos = 0;
      final sourceArrowIndent = !isSourceAttribute && targetNode == null ? createdArrowSourceHandleOffset : arrowIndent;
      final targetArrowIndent = !isTargetAttribute && targetNode != null ? arrowIndent : 0.0;
      Connection? startConnection;
      Connection? endConnection;

      if (!isSourceAttribute) {
        /// Создание стартового коннекта для узла
        final startConnections = sourceNode.connections;
        startConnection = startConnections?.add(sidesNodesList[0], arrow.id);
        startDeltaPos = startConnections?.getSideDelta(sidesNodesList[0], startConnection!) ?? 0;
      } else {
        sourceCenter = Offset(
          sourceCenter.dx,
          sourceTop + (targetNode == null ? 0 : sourceAttribute.position.dy) + sourceAttribute.size.height / 2,
        );
      }

      if (!isTargetAttribute && targetNode != null) {
        /// Создание конечного коннекта для узла
        final endConnections = targetNode.connections;
        endConnection = endConnections?.add(sidesNodesList[1], arrow.id);
        endDeltaPos = endConnections?.getSideDelta(sidesNodesList[1], endConnection!) ?? 0;
      } else if (isTargetAttribute) {
        targetCenter = Offset(
          targetCenter.dx,
          targetTop + targetAttribute.position.dy + targetAttribute.size.height / 2,
        );
      } else {
        targetCenter = targetRect.center;
      }

      switch (sidesNodes) {
        case 'right:top':
          startConnectionPoint = Offset(
            sourceRight + (!isSourceAttribute ? sourceArrowIndent : 0),
            sourceCenter.dy + startDeltaPos,
          );
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetTop - targetArrowIndent);
          break;
        case 'right:bottom':
          startConnectionPoint = Offset(
            sourceRight + (!isSourceAttribute ? sourceArrowIndent : 0),
            sourceCenter.dy + startDeltaPos,
          );
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetBottom + targetArrowIndent);
          break;
        case 'right:left':
          startConnectionPoint = Offset(
            sourceRight + (!isSourceAttribute ? sourceArrowIndent : 0),
            sourceCenter.dy + startDeltaPos,
          );
          endConnectionPoint = Offset(targetLeft - targetArrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'right:right':
          startConnectionPoint = Offset(
            sourceRight + (!isSourceAttribute ? sourceArrowIndent : 0),
            sourceCenter.dy + startDeltaPos,
          );
          endConnectionPoint = Offset(targetRight + targetArrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'left:top':
          startConnectionPoint = Offset(
            sourceLeft - (!isSourceAttribute ? sourceArrowIndent : 0),
            sourceCenter.dy + startDeltaPos,
          );
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetTop - targetArrowIndent);
          break;
        case 'left:bottom':
          startConnectionPoint = Offset(
            sourceLeft - (!isSourceAttribute ? sourceArrowIndent : 0),
            sourceCenter.dy + startDeltaPos,
          );
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetBottom + targetArrowIndent);
          break;
        case 'left:right':
          startConnectionPoint = Offset(
            sourceLeft - (!isSourceAttribute ? sourceArrowIndent : 0),
            sourceCenter.dy + startDeltaPos,
          );
          endConnectionPoint = Offset(targetRight + targetArrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'left:left':
          startConnectionPoint = Offset(
            sourceLeft - (!isSourceAttribute ? sourceArrowIndent : 0),
            sourceCenter.dy + startDeltaPos,
          );
          endConnectionPoint = Offset(targetLeft - targetArrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'top:bottom':
          startConnectionPoint = Offset(
            sourceCenter.dx + startDeltaPos,
            sourceTop - (!isSourceAttribute ? sourceArrowIndent : 0),
          );
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetBottom + targetArrowIndent);
          break;
        case 'top:right':
          startConnectionPoint = Offset(
            sourceCenter.dx + startDeltaPos,
            sourceTop - (!isSourceAttribute ? sourceArrowIndent : 0),
          );
          endConnectionPoint = Offset(targetRight + targetArrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'top:left':
          startConnectionPoint = Offset(
            sourceCenter.dx + startDeltaPos,
            sourceTop - (!isSourceAttribute ? sourceArrowIndent : 0),
          );
          endConnectionPoint = Offset(targetLeft - targetArrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'top:top':
          startConnectionPoint = Offset(
            sourceCenter.dx + startDeltaPos,
            sourceTop - (!isSourceAttribute ? sourceArrowIndent : 0),
          );
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetTop - targetArrowIndent);
          break;
        case 'bottom:top':
          startConnectionPoint = Offset(
            sourceCenter.dx + startDeltaPos,
            sourceBottom + (!isSourceAttribute ? sourceArrowIndent : 0),
          );
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetTop - targetArrowIndent);
          break;
        case 'bottom:right':
          startConnectionPoint = Offset(
            sourceCenter.dx + startDeltaPos,
            sourceBottom + (!isSourceAttribute ? sourceArrowIndent : 0),
          );
          endConnectionPoint = Offset(targetRight + targetArrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'bottom:left':
          startConnectionPoint = Offset(
            sourceCenter.dx + startDeltaPos,
            sourceBottom + (!isSourceAttribute ? sourceArrowIndent : 0),
          );
          endConnectionPoint = Offset(targetLeft - targetArrowIndent, targetCenter.dy + endDeltaPos);
          break;
        case 'bottom:bottom':
          startConnectionPoint = Offset(
            sourceCenter.dx + startDeltaPos,
            sourceBottom + (!isSourceAttribute ? sourceArrowIndent : 0),
          );
          endConnectionPoint = Offset(targetCenter.dx + endDeltaPos, targetBottom + targetArrowIndent);
          break;
      }

      // startConnection!.pos = startConnectionPoint;
      // endConnection!.pos = endConnectionPoint;

      return (start: startConnectionPoint, end: endConnectionPoint, sides: sides);
    } catch (e) {
      print('ERROR [_getSidePosition]: $e');
    }
    return (start: Offset.zero, end: Offset.zero, sides: sides);
  }

  /// Получить полный путь стрелки для отрисовки в тайлах
  ({ArrowPaths paths, List<Offset> coordinates}) getArrowPathInTile(
    Arrow arrow,
    Offset baseOffset, {
    bool isNotCalculate = false,
    bool isTiles = false,
  }) {
    // Находим эффективные узлы
    final sourceNodeAndAttr = _getNodeFromArrow(arrow.source);
    final targetNodeAndAttr = _getNodeFromArrow(arrow.target);

    final sourceNode = sourceNodeAndAttr.node;
    final targetNode = targetNodeAndAttr.node;

    final sourceAttr = sourceNodeAndAttr.attribute;
    final targetAttr = targetNodeAndAttr.attribute;

    if (sourceNode == null || targetNode == null) {
      return (paths: ArrowPaths(path: Path()), coordinates: []);
    }

    // Получаем абсолютные позиции
    final sourceAbsolutePos = sourceNode.aPosition ?? (sourceNode.position + baseOffset);
    final targetAbsolutePos = targetNode.aPosition ?? (targetNode.position + baseOffset);

    // Создаем Rect для узлов
    final sourceRect = Rect.fromPoints(
      sourceAbsolutePos,
      Offset(sourceAbsolutePos.dx + sourceNode.size.width, sourceAbsolutePos.dy + sourceNode.size.height),
    );

    final targetRect = Rect.fromPoints(
      targetAbsolutePos,
      Offset(targetAbsolutePos.dx + targetNode.size.width, targetAbsolutePos.dy + targetNode.size.height),
    );

    // Вычисляем точки соединения
    final baseConnectionPoints = calculateConnectionPoints(
      arrow: arrow,
      sourceRect: sourceRect,
      targetRect: targetRect,
      sourceNode: sourceNode,
      targetNode: targetNode,
      sourceAttribute: sourceAttr,
      targetAttribute: targetAttr,
    );

    arrow.aPositionSource = baseConnectionPoints.start!;
    arrow.aPositionTarget = baseConnectionPoints.end!;

    if (baseConnectionPoints.start == null || baseConnectionPoints.end == null) {
      return (paths: ArrowPaths(path: Path()), coordinates: []);
    }

    // Создаем простой ортогональный путь без проверок пересечений
    final basePath = _createSimpleOrthogonalPath(
      arrow: arrow,
      start: baseConnectionPoints.start!,
      end: baseConnectionPoints.end!,
      sourceRect: sourceRect,
      targetRect: targetRect,
      sides: baseConnectionPoints.sides!,
      isTiles: isTiles,
    );

    arrow.paths = basePath.paths;
    arrow.rects = basePath.rects;
    arrow.coordinates = basePath.coordinates;
    arrow.sides = baseConnectionPoints.sides;

    return (paths: basePath.paths, coordinates: basePath.coordinates);
  }

  /// Получает путь стрелки с учетом выбранных узлов и текущего масштаба
  ({ArrowPaths paths, List<Offset> coordinates}) getArrowPathWithSelectedNodes(Arrow arrow, Rect arrowsRect) {
    // Создаем простой ортогональный путь в мировых координатах
    final basePath = getArrowPathInTile(arrow, state.delta);

    // Преобразуем путь и координаты в экранные координаты
    return _convertPathToScreenCoordinates(arrow, basePath, arrowsRect);
  }

  ({ArrowPaths paths, List<Offset> coordinates}) getCreatedArrowPath() {
    final arrow = state.arrowCreated;
    if (arrow == null) {
      return (paths: ArrowPaths(path: Path()), coordinates: []);
    }

    final sourceNodeAndAttr = _getNodeFromArrow(arrow.source);
    final sourceNode = sourceNodeAndAttr.node;
    if (sourceNode == null) {
      return (paths: ArrowPaths(path: Path()), coordinates: []);
    }

    final sourceAbsolutePos = sourceNode.aPosition ?? (sourceNode.position + state.delta);
    final targetWorld = Utils.screenToWorld(state.mousePosition, state);
    final sourceRect = Rect.fromLTWH(
      sourceNodeAndAttr.attribute == null
          ? sourceAbsolutePos.dx
          : sourceAbsolutePos.dx + sourceNodeAndAttr.attribute!.position.dx,
      sourceNodeAndAttr.attribute == null
          ? sourceAbsolutePos.dy
          : sourceAbsolutePos.dy + sourceNodeAndAttr.attribute!.position.dy,
      sourceNodeAndAttr.attribute == null ? sourceNode.size.width : sourceNodeAndAttr.attribute!.size.width,
      sourceNodeAndAttr.attribute == null ? sourceNode.size.height : sourceNodeAndAttr.attribute!.size.height,
    );
    final targetRect = Rect.fromPoints(targetWorld, targetWorld);

    final baseConnectionPoints = calculateConnectionPoints(
      arrow: arrow,
      sourceRect: sourceRect,
      targetPoint: targetWorld,
      sourceNode: sourceNode,
      sourceAttribute: sourceNodeAndAttr.attribute,
    );

    if (baseConnectionPoints.start == null || baseConnectionPoints.end == null || baseConnectionPoints.sides == null) {
      return (paths: ArrowPaths(path: Path()), coordinates: []);
    }

    final basePath = _createSimpleOrthogonalPath(
      arrow: arrow,
      start: baseConnectionPoints.start!,
      end: baseConnectionPoints.end!,
      sourceRect: sourceRect,
      targetRect: targetRect,
      sides: baseConnectionPoints.sides!,
      isTiles: false,
    );

    arrow.aPositionSource = baseConnectionPoints.start!;
    arrow.aPositionTarget = baseConnectionPoints.end!;
    arrow.coordinates = basePath.coordinates;
    arrow.paths = basePath.paths;
    arrow.rects = basePath.rects;
    arrow.sides = baseConnectionPoints.sides;

    final screenCoordinates = basePath.coordinates.map((point) => Utils.worldToScreen(point, state)).toList();
    String direct = baseConnectionPoints.sides!.split(':')[0];

    final screenPathResult = _createPath(
      arrow,
      screenCoordinates,
      direct: direct,
      isCurves: state.useCurves,
      isTiles: false,
      scale: state.scale,
    );

    return (paths: screenPathResult.paths, coordinates: screenCoordinates);
  }

  /// Преобразует путь из мировых координат в экранные
  ({ArrowPaths paths, List<Offset> coordinates}) _convertPathToScreenCoordinates(
    Arrow arrow,
    ({ArrowPaths paths, List<Offset> coordinates}) worldPath,
    Rect arrowsRect,
  ) {
    final screenCoordinates = <Offset>[];

    // Преобразуем каждую координату
    for (final worldCoord in worldPath.coordinates) {
      final screenCoord = Offset(worldCoord.dx - arrowsRect.left, worldCoord.dy - arrowsRect.top) * state.scale;
      screenCoordinates.add(screenCoord);
    }

    final pathResult = _createPath(
      arrow,
      screenCoordinates,
      scale: state.scale,
      isTiles: false,
      isCurves: state.useCurves,
    );

    arrow.rects = pathResult.rects;

    return (paths: pathResult.paths, coordinates: screenCoordinates);
  }

  /// Создание простого ортогонального пути
  ({ArrowPaths paths, List<Offset> coordinates, List<Rect> rects}) _createSimpleOrthogonalPath({
    required Arrow arrow,
    required Offset start,
    required Offset end,
    required Rect sourceRect,
    required Rect targetRect,
    required String sides,
    required bool isTiles,
  }) {
    List<Offset> coordinates = [];

    // Определяем стороны и размеры узлов
    final sourceTop = sourceRect.top;
    final sourceBottom = sourceRect.bottom;
    final sourceLeft = sourceRect.left;
    final sourceRight = sourceRect.right;

    final targetTop = targetRect.top;
    final targetBottom = targetRect.bottom;
    final targetLeft = targetRect.left;
    final targetRight = targetRect.right;

    coordinates.add(Offset(start.dx, start.dy));

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dx2 = dx.abs() / 2;
    final dy2 = dy.abs() / 2;

    switch (sides) {
      case 'left:right':
        if (dy2 != 0) {
          coordinates.add(Offset(start.dx - dx2, start.dy));
          coordinates.add(Offset(start.dx - dx2, end.dy));
          coordinates.add(Offset(end.dx, end.dy));
        } else {
          coordinates.add(Offset(end.dx, end.dy));
        }
        break;
      case 'right:left':
        if (dy2 != 0) {
          coordinates.add(Offset(start.dx + dx2, start.dy));
          coordinates.add(Offset(start.dx + dx2, end.dy));
          coordinates.add(Offset(end.dx, end.dy));
        } else {
          coordinates.add(Offset(end.dx, end.dy));
        }
        break;
      case 'top:bottom':
        if (dx2 != 0) {
          coordinates.add(Offset(start.dx, start.dy - dy2));
          coordinates.add(Offset(end.dx, start.dy - dy2));
          coordinates.add(Offset(end.dx, end.dy));
        } else {
          coordinates.add(Offset(end.dx, end.dy));
        }
        break;
      case 'bottom:top':
        if (dx2 != 0) {
          coordinates.add(Offset(start.dx, start.dy + dy2));
          coordinates.add(Offset(end.dx, start.dy + dy2));
          coordinates.add(Offset(end.dx, end.dy));
        } else {
          coordinates.add(Offset(end.dx, end.dy));
        }
        break;
      case 'left:top':
      case 'right:top':
      case 'left:bottom':
      case 'right:bottom':
        coordinates.add(Offset(end.dx, start.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:left':
      case 'top:right':
      case 'bottom:left':
      case 'bottom:right':
        coordinates.add(Offset(start.dx, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'left:left':
        final dxMin = dx > 0 ? 0 : dx;
        coordinates.add(Offset(start.dx - 60 + dxMin, start.dy));
        coordinates.add(Offset(start.dx - 60 + dxMin, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:right':
        final dxMin = dx > 0 ? dx : 0;
        coordinates.add(Offset(start.dx + 60 + dxMin, start.dy));
        coordinates.add(Offset(start.dx + 60 + dxMin, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:top':
        final dyMin = dy > 0 ? 0 : dy;
        coordinates.add(Offset(start.dx, start.dy - 60 + dyMin));
        coordinates.add(Offset(end.dx, start.dy - 60 + dyMin));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:bottom':
        final dyMin = dy > 0 ? dy : 0;
        coordinates.add(Offset(start.dx, start.dy + 60 + dyMin));
        coordinates.add(Offset(end.dx, start.dy + 60 + dyMin));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'left:left:3':
        final dyUp = min(sourceTop, targetTop) - 60;
        coordinates.add(Offset(start.dx - 60, start.dy));
        coordinates.add(Offset(start.dx - 60, dyUp));
        coordinates.add(Offset(end.dx, dyUp));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'left:top:3':
        final dyUp = min(sourceTop, targetTop) - 60;
        coordinates.add(Offset(start.dx - 60, start.dy));
        coordinates.add(Offset(start.dx - 60, dyUp));
        coordinates.add(Offset(end.dx, dyUp));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:top:3':
        final dyUp = min(sourceTop, targetTop) - 60;
        coordinates.add(Offset(start.dx + 60, start.dy));
        coordinates.add(Offset(start.dx + 60, dyUp));
        coordinates.add(Offset(end.dx, dyUp));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:right:3':
        final dyUp = min(sourceTop, targetTop) - 60;
        coordinates.add(Offset(start.dx + 60, start.dy));
        coordinates.add(Offset(start.dx + 60, dyUp));
        coordinates.add(Offset(end.dx, dyUp));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'left:bottom:3':
        final dyDown = max(sourceBottom, targetBottom) + 60;
        coordinates.add(Offset(start.dx - 60, start.dy));
        coordinates.add(Offset(start.dx - 60, dyDown));
        coordinates.add(Offset(end.dx, dyDown));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:bottom:3':
        final dyDown = max(sourceBottom, targetBottom) + 60;
        coordinates.add(Offset(start.dx + 60, start.dy));
        coordinates.add(Offset(start.dx + 60, dyDown));
        coordinates.add(Offset(end.dx, dyDown));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:left:3':
        final dyLeft = min(sourceLeft, targetLeft) - 60;
        coordinates.add(Offset(start.dx, start.dy - 60));
        coordinates.add(Offset(dyLeft, start.dy - 60));
        coordinates.add(Offset(dyLeft, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:left:3':
        final dyLeft = min(sourceLeft, targetLeft) - 60;
        coordinates.add(Offset(start.dx, start.dy + 60));
        coordinates.add(Offset(dyLeft, start.dy + 60));
        coordinates.add(Offset(dyLeft, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:right:3':
        final dyRight = max(sourceRight, targetRight) + 60;
        coordinates.add(Offset(start.dx, start.dy - 60));
        coordinates.add(Offset(dyRight, start.dy - 60));
        coordinates.add(Offset(dyRight, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:right:3':
        final dyRight = max(sourceRight, targetRight) + 60;
        coordinates.add(Offset(start.dx, start.dy + 60));
        coordinates.add(Offset(dyRight, start.dy + 60));
        coordinates.add(Offset(dyRight, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'bottom:top:4':
        final dxRight = max(sourceRight, targetRight) + 60;
        coordinates.add(Offset(start.dx, start.dy + 60));
        coordinates.add(Offset(dxRight, start.dy + 60));
        coordinates.add(Offset(dxRight, targetTop - 60));
        coordinates.add(Offset(end.dx, targetTop - 60));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:bottom:4':
        final dxRight = max(sourceRight, targetRight) + 60;
        coordinates.add(Offset(start.dx, start.dy - 60));
        coordinates.add(Offset(dxRight, start.dy - 60));
        coordinates.add(Offset(dxRight, targetBottom + 60));
        coordinates.add(Offset(end.dx, targetBottom + 60));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'top:left:4':
        final dxRight = max(sourceRight, targetRight) + 60;
        coordinates.add(Offset(start.dx, start.dy - 60));
        coordinates.add(Offset(dxRight, start.dy - 60));
        coordinates.add(Offset(dxRight, targetBottom + 60));
        coordinates.add(Offset(end.dx, targetBottom + 60));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'left:right:4':
        final dyDown = max(sourceBottom, targetBottom) + 60;
        coordinates.add(Offset(start.dx - 60, start.dy));
        coordinates.add(Offset(start.dx - 60, dyDown));
        coordinates.add(Offset(end.dx + 60, dyDown));
        coordinates.add(Offset(end.dx + 60, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'left:left:4':
        final dyDown = max(sourceBottom, targetBottom) + 60;
        coordinates.add(Offset(start.dx - 60, start.dy));
        coordinates.add(Offset(start.dx - 60, dyDown));
        coordinates.add(Offset(end.dx - 60, dyDown));
        coordinates.add(Offset(end.dx - 60, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:left:4':
        final dyDown = max(sourceBottom, targetBottom) + 60;
        coordinates.add(Offset(start.dx + 60, start.dy));
        coordinates.add(Offset(start.dx + 60, dyDown));
        coordinates.add(Offset(end.dx - 60, dyDown));
        coordinates.add(Offset(end.dx - 60, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      case 'right:right:4':
        final dyDown = max(sourceBottom, targetBottom) + 60;
        coordinates.add(Offset(start.dx + 60, start.dy));
        coordinates.add(Offset(start.dx + 60, dyDown));
        coordinates.add(Offset(end.dx + 60, dyDown));
        coordinates.add(Offset(end.dx + 60, end.dy));
        coordinates.add(Offset(end.dx, end.dy));
        break;
      default:
        break;
    }

    String direct = sides.split(':')[0];
    final pathResult = _createPath(arrow, coordinates, direct: direct, isCurves: state.useCurves, isTiles: isTiles);

    return (paths: pathResult.paths, coordinates: coordinates, rects: pathResult.rects);
  }

  ({ArrowPaths paths, List<Rect> rects}) _createPath(
    Arrow arrow,
    List<Offset> coordinates, {
    required bool isTiles,
    String? direct,
    double? scale,
    bool isCurves = false,
  }) {
    final path = Path();
    final baseRadius = defaultArrowRadius * (scale ?? 1);
    final rects = <Rect>[];

    if (coordinates.isEmpty) {
      return (paths: ArrowPaths(path: path), rects: rects);
    }

    final dx = coordinates.first.dx - coordinates[1].dx;
    final dy = coordinates.first.dy - coordinates[1].dy;

    if (direct == null) {
      if (dx > 0) {
        direct = 'left';
      } else if (dx < 0) {
        direct = 'right';
      } else if (dy > 0) {
        direct = 'top';
      } else {
        direct = 'bottom';
      }
    }

    final len = coordinates.length;

    path.moveTo(coordinates.first.dx, coordinates.first.dy);

    for (int i = 1; i < len - 1; i++) {
      final previous = coordinates[i - 1]; // предыдущая точка
      final current = coordinates[i]; // текущая точка
      final next = coordinates[i + 1]; // следующая точка
      // Расчет длин текущего и следующего отрезка
      final dxPrev = previous.dx - current.dx;
      final dyPrev = previous.dy - current.dy;
      final dx = current.dx - next.dx;
      final dy = current.dy - next.dy;
      double offsetCurrent = (dxPrev + dyPrev).abs(); // длина текущего отрезка
      double offsetNext = (dx + dy).abs(); // длина следующего отрезка
      double radius = 0.0;
      if (!isCurves) {
        // Находим минимальный отрезок
        final offset = min(offsetNext, offsetCurrent);
        final maxRadius = offset / 2;
        radius = maxRadius > 1 ? baseRadius.clamp(1.0, maxRadius) : 0;
      } else {
        offsetCurrent = (len == 4 || len == 5) && (i == 2 || i == 4) ? offsetCurrent / 2 : offsetCurrent;
        offsetNext = (len == 4 || len == 5) && (i == 1 || i == 3) ? offsetNext / 2 : offsetNext;
        final offset = min(offsetNext, offsetCurrent);
        radius = offset;
      }
      double x1 = current.dx;
      double y1 = current.dy;
      bool clockwise = true;
      Offset endArcPoint;

      if (previous.dy == current.dy) {
        rects.add(Rect.fromLTRB(min(previous.dx, current.dx), previous.dy - arrowPathRectOffset, max(previous.dx, current.dx), previous.dy + arrowPathRectOffset));
      } else if (previous.dx == current.dx) {
        rects.add(Rect.fromLTRB(previous.dx - arrowPathRectOffset, min(previous.dy, current.dy), previous.dx + arrowPathRectOffset, max(previous.dy, current.dy)));
      }

      if (radius == 0) {
        // Добавляем путь до дуги
        path.lineTo(x1, y1);
        continue;
      }

      switch (direct) {
        case 'left':
          x1 = current.dx + radius;
          clockwise = dy > 0;
          break;
        case 'right':
          x1 = current.dx - radius;
          clockwise = dy < 0;
          break;
        case 'top':
          y1 = current.dy + radius;
          clockwise = dx < 0;
          break;
        case 'bottom':
          y1 = current.dy - radius;
          clockwise = dx > 0;
          break;
        default:
          break;
      }

      if (dx > 0) {
        direct = "left";
        endArcPoint = Offset(current.dx - radius, current.dy);
      } else if (dx < 0) {
        direct = "right";
        endArcPoint = Offset(current.dx + radius, current.dy);
      } else if (dy > 0) {
        direct = "top";
        endArcPoint = Offset(current.dx, current.dy - radius);
      } else {
        direct = "bottom";
        endArcPoint = Offset(current.dx, current.dy + radius);
      }

      // Добавляем путь до дуги
      path.lineTo(x1, y1);

      // Добавляем дугу поворота 90 градусов
      path.arcToPoint(endArcPoint, radius: Radius.circular(radius), largeArc: false, clockwise: clockwise);
    }

    // Добавляем линию к последней точке
    if (len > 1) {
      final previous = coordinates[len - 2];
      final current = coordinates.last;
      if (previous.dy == current.dy) {
        rects.add(Rect.fromLTRB(min(previous.dx, current.dx), current.dy - arrowPathRectOffset, max(previous.dx, current.dx), current.dy + arrowPathRectOffset));
      } else if (previous.dx == current.dx) {
        rects.add(Rect.fromLTRB(current.dx - arrowPathRectOffset, min(previous.dy, current.dy), current.dx + arrowPathRectOffset, max(previous.dy, current.dy)));
      }
      path.lineTo(coordinates.last.dx, coordinates.last.dy);
    }

    // Добавляем начальную фигуру для targetArrow
    final startArrow = _addStartArrowHead(arrow, coordinates, direct, isTiles);

    // Добавляем конечную фигуру для sourceArrow
    final endArrow = _addEndArrowHead(arrow, coordinates, direct, isTiles);

    return (
      paths: ArrowPaths(path: path, startArrow: startArrow, endArrow: endArrow),
      rects: rects,
    );
  }

  /// Добавляет фигуру стрелки в начале пути
  Path? _addStartArrowHead(Arrow arrow, List<Offset> coordinates, String? direct, bool isTiles) {
    if (coordinates.length < 2) return null;

    final startPos = coordinates.first;
    final nextPos = coordinates[1];
    final sizeArrow = 8.0 * (isTiles ? 1 : state.scale);

    // Определяем направление от startPos к nextPos
    final direction = Offset(nextPos.dx - startPos.dx, nextPos.dy - startPos.dy);
    final directionLength = sqrt(direction.dx * direction.dx + direction.dy * direction.dy);

    if (directionLength == 0) return null;

    final normalizedDir = Offset(direction.dx / directionLength, direction.dy / directionLength);
    final rotationAngle = atan2(normalizedDir.dy, normalizedDir.dx);

    // Добавляем фигуру в зависимости от targetArrow
    if (arrow.sourceArrow == 'diamondThin' || arrow.sourceArrow == 'diamond') {
      return _addDiamondToPath(
        startPos + normalizedDir * sizeArrow,
        rotationAngle,
        isFilled: arrow.sourceArrow == 'diamondThin',
        isTiles: isTiles,
        size: sizeArrow,
      );
    }
    return null;
  }

  /// Добавляет фигуру стрелки в конце пути
  Path? _addEndArrowHead(Arrow arrow, List<Offset> coordinates, String? direct, bool isTiles) {
    if (coordinates.length < 2) return null;

    final endPos = coordinates.last;
    final prevPos = coordinates[coordinates.length - 2];
    final sizeArrow = 8.0 * (isTiles ? 1 : state.scale);

    // Определяем направление от prevPos к endPos
    final direction = Offset(endPos.dx - prevPos.dx, endPos.dy - prevPos.dy);
    final directionLength = sqrt(direction.dx * direction.dx + direction.dy * direction.dy);

    if (directionLength == 0) return null;

    final normalizedDir = Offset(direction.dx / directionLength, direction.dy / directionLength);
    final rotationAngle = atan2(normalizedDir.dy, normalizedDir.dx);

    // Добавляем фигуру в зависимости от sourceArrow
    if (arrow.targetArrow == 'block') {
      return _addTriangleToPath(endPos - normalizedDir * sizeArrow, rotationAngle, isTiles: isTiles, size: sizeArrow);
    }
    return null;
  }

  /// Добавляет треугольник к пути
  Path _addTriangleToPath(Offset position, double rotationAngle, {required isTiles, double size = 5.0}) {
    final halfSize = size / 2;
    final triangleHeight = size * sqrt(3) / 2; // Высота равностороннего треугольника
    final path = Path();

    // Вершины треугольника (вершина направлена вперед)
    final vertices = [
      Offset(0, -halfSize), // Левая вершина основания
      Offset(0, halfSize), // Правая вершина основания
      Offset(triangleHeight, 0), // Вершина треугольника
    ];

    // Поворачиваем и перемещаем вершины
    final rotatedVertices = vertices.map((vertex) {
      final xRotated = vertex.dx * cos(rotationAngle) - vertex.dy * sin(rotationAngle);
      final yRotated = vertex.dx * sin(rotationAngle) + vertex.dy * cos(rotationAngle);
      return Offset(position.dx + xRotated, position.dy + yRotated);
    }).toList();

    // Добавляем треугольник к пути
    path.moveTo(rotatedVertices[0].dx, rotatedVertices[0].dy);
    path.lineTo(rotatedVertices[1].dx, rotatedVertices[1].dy);
    path.lineTo(rotatedVertices[2].dx, rotatedVertices[2].dy);
    path.close();
    return path;
  }

  /// Добавляет ромб к пути
  Path _addDiamondToPath(
    Offset position,
    double rotationAngle, {
    required isTiles,
    bool isFilled = true,
    double size = 6.0,
  }) {
    final halfSize = size;
    final path = Path();

    // Вершины ромба (длинная диагональ вдоль направления)
    final outerVertices = [
      Offset(0, -halfSize / 2), // Верх
      Offset(halfSize, 0), // Право
      Offset(0, halfSize / 2), // Низ
      Offset(-halfSize, 0), // Лево
    ];

    // Поворачиваем внешние вершины
    final rotatedOuterVertices = outerVertices.map((vertex) {
      final xRotated = vertex.dx * cos(rotationAngle) - vertex.dy * sin(rotationAngle);
      final yRotated = vertex.dx * sin(rotationAngle) + vertex.dy * cos(rotationAngle);
      return Offset(position.dx + xRotated, position.dy + yRotated);
    }).toList();

    // Добавляем внешний ромб
    path.moveTo(rotatedOuterVertices[0].dx, rotatedOuterVertices[0].dy);
    for (int i = 1; i < rotatedOuterVertices.length; i++) {
      path.lineTo(rotatedOuterVertices[i].dx, rotatedOuterVertices[i].dy);
    }
    path.close();
    return path;
  }

  /// Найти эффективный узел
  ({TableNode? node, Attribute? attribute}) _getNodeFromArrow(String nodeId) {
    TableNode? foundNode;
    Attribute? foundAttribute;

    TableNode? findNodeRecursive(List<TableNode> nodeList) {
      for (final node in nodeList) {
        // Сначала проверяем сам узел
        if (node.id == nodeId) {
          return node;
        }

        // Проверяем атрибуты узла
        for (final attr in node.attributes) {
          if (attr.id == nodeId) {
            foundAttribute = attr;
            return node;
          }
        }

        // Рекурсивно ищем в детях
        if (node.children != null) {
          final found = findNodeRecursive(node.children!);
          if (found != null) return found;
        }
      }
      return null;
    }

    // Ищем в основном списке узлов
    foundNode = findNodeRecursive(state.nodes);

    // Если не найден — ищем среди выделенных узлов (они удалены из state.nodes)
    if (foundNode == null && state.nodesSelected.isNotEmpty) {
      for (final selected in state.nodesSelected) {
        if (selected == null) continue;

        if (selected.id == nodeId) {
          foundNode = selected;
          break;
        }

        // Проверяем атрибуты выделенного узла
        for (final attr in selected.attributes) {
          if (attr.id == nodeId) {
            foundAttribute = attr;
            foundNode = selected;
            break;
          }
        }

        if (foundNode != null) break;

        // Ищем в детях выделенного узла
        if (selected.children != null) {
          final found = findNodeRecursive(selected.children!);
          if (found != null) {
            foundNode = found;
            break;
          }
        }
      }
    }

    if (foundNode == null) return (node: null, attribute: null);

    // Проверка на свернутые swimlane
    if (foundNode.parent != null) {
      final parent = _getNodeFromArrow(foundNode.parent!).node;
      if (parent != null && parent.qType == 'swimlane' && (parent.isCollapsed ?? false)) {
        return (node: parent, attribute: null);
      }
    }

    return (node: foundNode, attribute: foundAttribute);
  }

  ({String targetId, Offset screenPosition, String targetSide})? _findClosestCreatedArrowSnapTarget(
    Offset screenPosition,
    Arrow arrow,
  ) {
    final candidates = <({String targetId, Offset screenPosition, String targetSide, double distance})>[];
    final scale = state.scale;
    final snapDistance = createdArrowSnapDistance * scale;
    final currentArrowId = arrow.id;
    final sourceId = arrow.source;
    final sourceNodeId = _getNodeFromArrow(sourceId).node?.id;

    void addCandidate(String targetId, Offset candidateScreenPosition, String targetSide) {
      if (targetId == sourceId) {
        return;
      }

      final distance = (candidateScreenPosition - screenPosition).distance;
      if (distance > snapDistance) {
        return;
      }

      candidates.add((
        targetId: targetId,
        screenPosition: candidateScreenPosition,
        targetSide: targetSide,
        distance: distance,
      ));
    }

    bool hasOccupiedConnections(Attribute attribute, String side) {
      final sideConnections = attribute.connections?.get(side);
      if (sideConnections == null || sideConnections.isEmpty) {
        return false;
      }

      for (final connection in sideConnections) {
        if (connection == null) {
          continue;
        }
        if (connection.id == currentArrowId) {
          continue;
        }
        return true;
      }

      return false;
    }

    TableNode? findNodeById(String nodeId, List<TableNode> nodes) {
      for (final node in nodes) {
        if (node.id == nodeId) {
          return node;
        }

        final children = node.children;
        if (children != null && children.isNotEmpty) {
          final found = findNodeById(nodeId, children);
          if (found != null) {
            return found;
          }
        }
      }

      return null;
    }

    bool isSnapDisabledForNode(TableNode node) {
      if (node.qType == 'group' && node.children != null && node.children!.isNotEmpty) {
        return true;
      }

      if (node.qType == 'swimlane' && (node.parent == null || (node.isCollapsed ?? false))) {
        return true;
      }

      String? parentId = node.parent;
      while (parentId != null) {
        final parentNode =
            findNodeById(parentId, state.nodes) ??
            findNodeById(parentId, state.nodesSelected.whereType<TableNode>().toList());
        if (parentNode == null) {
          break;
        }
        if (parentNode.qType == 'swimlane' && (parentNode.isCollapsed ?? false)) {
          return true;
        }
        parentId = parentNode.parent;
      }

      return false;
    }

    void collectNodeCandidates(List<TableNode> nodes) {
      for (final node in nodes) {
        if (isSnapDisabledForNode(node)) {
          if (node.children != null && node.children!.isNotEmpty) {
            collectNodeCandidates(node.children!);
          }
          continue;
        }

        if (node.id == sourceNodeId) {
          if (node.children != null && node.children!.isNotEmpty) {
            collectNodeCandidates(node.children!);
          }
          continue;
        }

        final nodeWorldPos = node.aPosition ?? (node.position + state.delta);
        final nodeScreenTopLeft = Utils.worldToScreen(nodeWorldPos, state);
        final nodeWidth = node.size.width * scale;
        final nodeHeight = node.size.height * scale;
        final headerHeight = (node.heightHeader ?? EditorConfig.minHeaderHeight) * scale;
        final groupOffsetX = node.qType == 'group' && node.children != null && node.children!.isNotEmpty
            ? node.children!.first.position.dx * scale
            : 0.0;
        final groupOffsetY = node.qType == 'group' && node.children != null && node.children!.isNotEmpty
            ? node.children!.first.position.dy * scale
            : 0.0;
        final nodeConnectorOffset = createdArrowSourceHandleOffset * scale;

        addCandidate(
          node.id,
          Offset(nodeScreenTopLeft.dx + nodeWidth / 2, nodeScreenTopLeft.dy - nodeConnectorOffset + groupOffsetY),
          'top',
        );
        addCandidate(
          node.id,
          Offset(
            nodeScreenTopLeft.dx + nodeWidth / 2,
            nodeScreenTopLeft.dy + nodeHeight + nodeConnectorOffset - groupOffsetY,
          ),
          'bottom',
        );
        addCandidate(
          node.id,
          Offset(
            nodeScreenTopLeft.dx - nodeConnectorOffset + groupOffsetX,
            nodeScreenTopLeft.dy + groupOffsetY + headerHeight / 2,
          ),
          'left',
        );
        addCandidate(
          node.id,
          Offset(
            nodeScreenTopLeft.dx + nodeWidth + nodeConnectorOffset - groupOffsetX,
            nodeScreenTopLeft.dy + groupOffsetY + headerHeight / 2,
          ),
          'right',
        );

        if (node.qType != 'enum' && node.qType != 'swimlane') {
          for (final attribute in node.attributes) {
            final attributeCenterY = nodeScreenTopLeft.dy + (attribute.position.dy + attribute.size.height / 2) * scale;
            final leftOccupied = hasOccupiedConnections(attribute, 'left');
            final rightOccupied = hasOccupiedConnections(attribute, 'right');

            if (!leftOccupied) {
              addCandidate(attribute.id, Offset(nodeScreenTopLeft.dx, attributeCenterY), 'left');
            }

            if (!rightOccupied) {
              addCandidate(attribute.id, Offset(nodeScreenTopLeft.dx + nodeWidth, attributeCenterY), 'right');
            }
          }
        }

        if (node.children != null && node.children!.isNotEmpty) {
          collectNodeCandidates(node.children!);
        }
      }
    }

    collectNodeCandidates(state.nodes);
    if (state.nodesSelected.isNotEmpty) {
      collectNodeCandidates(state.nodesSelected.whereType<TableNode>().toList());
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    final closest = candidates.first;
    return (targetId: closest.targetId, screenPosition: closest.screenPosition, targetSide: closest.targetSide);
  }

  /// Находит все связи, связанные с указанными узлами
  /// [nodes] - список узлов, для которых нужно найти связанные стрелки
  /// Возвращает список всех стрелок, где источник или цель находится в списке узлов
  List<Arrow?> getArrowsForNodes(List<TableNode?> nodes) {
    // Создаем Set для хранения уникальных ID узлов
    final Set<String> nodeIds = {};
    final Set<String> attributeIds = {};

    // Добавляем ID всех узлов из списка
    for (final node in nodes) {
      nodeIds.add(node!.id);

      // Добавляем ID всех атрибутов узла
      for (final attr in node.attributes) {
        attributeIds.add(attr.id);
      }

      // Также добавляем ID всех вложенных узлов, если они есть
      if (node.children != null && node.children!.isNotEmpty) {
        void addChildrenIds(TableNode parentNode) {
          for (final child in parentNode.children!) {
            nodeIds.add(child.id);
            // Добавляем ID всех атрибутов узла
            for (final attr in node.attributes) {
              attributeIds.add(attr.id);
            }
            if (child.children != null && child.children!.isNotEmpty) {
              addChildrenIds(child);
            }
          }
        }

        addChildrenIds(node);
      }
    }

    // Создаем Set для хранения уникальных стрелок
    final Set<Arrow?> arrowsSet = {};

    // Проходим по всем стрелкам в state.arrows
    for (final arrow in state.arrows) {
      // Проверяем, связана ли стрелка с любым из узлов в списке
      if (nodeIds.contains(arrow.source) ||
          nodeIds.contains(arrow.target) ||
          attributeIds.contains(arrow.source) ||
          attributeIds.contains(arrow.target)) {
        arrowsSet.add(arrow);
      }
    }

    // Преобразуем Set в List и возвращаем
    return arrowsSet.toList();
  }
}
