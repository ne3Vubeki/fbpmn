import 'package:fbpmn/src/services/node_manager.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';

class NodeHover extends StatefulWidget {
  final EditorState state;
  final NodeManager nodeManager;

  const NodeHover({super.key, required this.state, required this.nodeManager});

  @override
  State<NodeHover> createState() => _NodeHoverState();
}

class _NodeHoverState extends State<NodeHover> {
  @override
  void initState() {
    super.initState();
    widget.nodeManager.setOnStateUpdate('NodeHover', () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.hoveredNode == null) {
      return Container();
    }

    final currentNode = widget.state.hoveredNode!;
    final screenTopLeft = Offset(
      widget.state.hoveredNode!.aPosition!.dx * widget.state.scale + widget.state.offset.dx,
      widget.state.hoveredNode!.aPosition!.dy * widget.state.scale + widget.state.offset.dy,
    );
    final nodeSize = Size(currentNode.size.width * widget.state.scale, currentNode.size.height * widget.state.scale);
    final hasAttributes = currentNode.attributes.isNotEmpty;
    final isEnum = currentNode.qType == 'enum';
    final isGroup = currentNode.qType == 'group';
    final isBo = currentNode.qType == 'bo';
    final borderRadius = !isGroup && !isEnum && isBo && hasAttributes
        ? BorderRadius.circular(8 * widget.state.scale)
        : BorderRadius.zero;

    return Positioned(
      left: screenTopLeft.dx,
      top: screenTopLeft.dy,
      child: MouseRegion(
        // Меняем курсор на руку при наведении на подсветку
        cursor: SystemMouseCursors.click, // или SystemMouseCursors.grab
        child: Container(
          width: nodeSize.width,
          height: nodeSize.height,
          decoration: BoxDecoration(color: Colors.yellowAccent.withValues(alpha: 0.2), borderRadius: borderRadius),
        ),
      ),
    );
  }
}
