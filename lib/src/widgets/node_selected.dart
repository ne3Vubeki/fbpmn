import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/input_handler.dart';
import 'package:fbpmn/src/utils/utils.dart';
import 'package:fbpmn/src/widgets/state_widget.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/table.node.dart';
import '../painters/node_custom_painter.dart';
import '../services/node_manager.dart';

class NodeSelected extends StatefulWidget {
  final EditorState state;
  final NodeManager nodeManager;
  final ArrowManager arrowManager;
  final InputHandler inputHandler;

  const NodeSelected({
    super.key,
    required this.state,
    required this.nodeManager,
    required this.arrowManager,
    required this.inputHandler,
  });

  @override
  State<NodeSelected> createState() => _NodeSelectedState();
}

class _NodeSelectedState extends State<NodeSelected> with StateWidget<NodeSelected> {
  // Используем константы из NodeManager
  double get framePadding => widget.nodeManager.framePadding;
  double get frameBorderWidth => widget.nodeManager.frameBorderWidth;
  double get frameTotalOffset => widget.nodeManager.frameTotalOffset;

  @override
  void initState() {
    super.initState();
    widget.nodeManager.setOnStateUpdate('NodeSelected', () {
      timeoutSetState();
    });
    // widget.inputHandler.setOnStateUpdate('NodeSelected', () {
    //   timeoutSetState();
    // });
  }

  @override
  void didUpdateWidget(covariant NodeSelected oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.nodesSelected.isEmpty) return Container();

    final allNodes = widget.state.nodesSelected.toList();
    final isMultiSelect = allNodes.length > 1;

    if (isMultiSelect) {
      return _buildMultiSelect(allNodes);
    } else {
      return _buildSingleSelect(allNodes.first!);
    }
  }

  /// Режим 1: Единичное выделение — один узел
  Widget _buildSingleSelect(TableNode node) {
    final hasAttributes = node.attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isGroup = node.qType == 'group';
    final scale = widget.state.scale;

    // Размер узла (масштабированный)
    final nodeSize = Size(node.size.width * scale, node.size.height * scale);

    final borderColor = Colors.transparent;

    return Positioned(
      left: widget.state.selectedNodeOffset.dx,
      top: widget.state.selectedNodeOffset.dy,
      child: Container(
        padding: widget.state.framePadding,
        decoration: BoxDecoration(
          border: Border.all(
            color: borderColor,
            width: frameBorderWidth,
          ),
          borderRadius: isGroup || isEnum || !hasAttributes
              ? BorderRadius.zero
              : BorderRadius.circular(12 * scale),
        ),
        child: RepaintBoundary(
          child: CustomPaint(
            size: nodeSize,
            painter: NodeCustomPainter(
              node: node,
              targetSize: nodeSize,
              simplifiedMode: widget.state.isAutoLayoutMode,
            ),
          ),
        ),
      ),
    );
  }

  /// Режим 2: Множественное выделение — несколько узлов
  Widget _buildMultiSelect(List<TableNode?> allNodes) {
    // Вычисляем bounding box всех узлов в мировых координатах
    final result = Utils.getNodesWorldBounds(allNodes, widget.state.delta);
    if (result == null) return Container();

    final validNodes = result.validNodes;
    final worldBounds = result.worldBounds;

    // Экранные координаты bounding box
    final screenTopLeft = Utils.worldToScreen(worldBounds.topLeft, widget.state);
    final screenBottomRight = Utils.worldToScreen(worldBounds.bottomRight, widget.state);

    // Размер области (масштабированный)
    final nodeSize = Size(
      screenBottomRight.dx - screenTopLeft.dx,
      screenBottomRight.dy - screenTopLeft.dy,
    );

    // В режиме автораскладки скрываем рамку
    final showBorder = !widget.state.isAutoLayoutMode;

    return Positioned(
      left: screenTopLeft.dx - frameTotalOffset,
      top: screenTopLeft.dy - frameTotalOffset,
      child: Container(
        padding: EdgeInsets.all(framePadding),
        decoration: showBorder
            ? BoxDecoration(
                border: Border.all(
                  color: Colors.blue,
                  width: frameBorderWidth,
                ),
              )
            : null,
        child: RepaintBoundary(
          child: CustomPaint(
            size: nodeSize,
            painter: NodeCustomPainter(
              nodes: validNodes,
              targetSize: nodeSize,
              worldBounds: worldBounds,
              simplifiedMode: widget.state.isAutoLayoutMode,
              nodeManager: widget.nodeManager,
            ),
          ),
        ),
      ),
    );
  }
}
