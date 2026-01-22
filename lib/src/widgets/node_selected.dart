import 'package:fbpmn/src/services/input_handler.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../painters/node_custom_painter.dart';
import '../services/node_manager.dart';

class NodeSelected extends StatefulWidget {
  final EditorState state;
  final NodeManager nodeManager;
  final InputHandler inputHandler;

  const NodeSelected({
    super.key,
    required this.state,
    required this.nodeManager,
    required this.inputHandler,
  });

  @override
  State<NodeSelected> createState() => _NodeSelectedState();
}

class _NodeSelectedState extends State<NodeSelected> {
  // Используем константы из NodeManager
  double get framePadding => NodeManager.framePadding;
  double get frameBorderWidth => NodeManager.frameBorderWidth;
  double get frameTotalOffset => NodeManager.frameTotalOffset;

  @override
  void initState() {
    super.initState();
    widget.nodeManager.setOnStateUpdate('NodeSelected', () {
      if (this.mounted) {
        setState(() {});
      }
    });
    widget.inputHandler.setOnStateUpdate('NodeSelected', () {
      if (this.mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant NodeSelected oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.nodesSelected.isEmpty) return Container();

    final node = widget.state.nodesSelected.first!;
    final hasAttributes = node.attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isNotGroup = node.groupId != null;

    // Размер узла (масштабированный)
    final nodeSize = Size(
      node.size.width * widget.state.scale,
      node.size.height * widget.state.scale,
    );

    return widget.state.isNodeOnTopLayer &&
            widget.state.nodesSelected.isNotEmpty
        ? Positioned(
            left: widget.state.selectedNodeOffset.dx,
            top: widget.state.selectedNodeOffset.dy,
            child: Container(
              padding: widget.state.framePadding,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: frameBorderWidth),
                borderRadius: isNotGroup || isEnum || !hasAttributes
                    ? BorderRadius.zero
                    : BorderRadius.circular(12),
              ),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: nodeSize,
                  painter: NodeCustomPainter(
                    node: node,
                    isSelected: true,
                    targetSize: nodeSize,
                  ),
                ),
              ),
            ),
          )
        : Container();
  }
}
