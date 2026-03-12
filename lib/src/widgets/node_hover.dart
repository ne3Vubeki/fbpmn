import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../models/table.node.dart';

class NodeHover extends StatelessWidget {
  final EditorState state;
  final TableNode? node;
  final Offset? worldPosition;

  const NodeHover({
    super.key,
    required this.state,
    required this.node,
    required this.worldPosition,
  });

  @override
  Widget build(BuildContext context) {
    if (node == null || worldPosition == null) {
      return Container();
    }

    final currentNode = node!;
    final screenTopLeft = Offset(
      worldPosition!.dx * state.scale + state.offset.dx,
      worldPosition!.dy * state.scale + state.offset.dy,
    );
    final nodeSize = Size(currentNode.size.width * state.scale, currentNode.size.height * state.scale);
    final hasAttributes = currentNode.attributes.isNotEmpty;
    final isEnum = currentNode.qType == 'enum';
    final isGroup = currentNode.qType == 'group';
    final isBo = currentNode.qType == 'bo';
    final borderRadius = !isGroup && !isEnum && isBo && hasAttributes
        ? BorderRadius.circular(8 * state.scale)
        : BorderRadius.zero;

    return Positioned(
      left: screenTopLeft.dx,
      top: screenTopLeft.dy,
      child: IgnorePointer(
        child: Container(
          width: nodeSize.width,
          height: nodeSize.height,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }
}
