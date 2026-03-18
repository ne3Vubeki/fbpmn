import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/models/table.node.dart';
import 'package:fbpmn/src/widgets/state_widget.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../utils/editor_config.dart';

class NodeHover extends StatefulWidget {
  final EditorState state;
  final NodeManager nodeManager;

  const NodeHover({super.key, required this.state, required this.nodeManager});

  @override
  State<NodeHover> createState() => _NodeHoverState();
}

class _NodeHoverState extends State<NodeHover> with StateWidget<NodeHover> {
  final Map<String, bool> isHovered = {};

  TableNode? _findNodeById(String nodeId, List<TableNode> nodes) {
    for (final node in nodes) {
      if (node.id == nodeId) {
        return node;
      }
      final children = node.children;
      if (children != null && children.isNotEmpty) {
        final found = _findNodeById(nodeId, children);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  bool _shouldIgnoreHoverNode(TableNode node) {
    String? parentId = node.parent;
    while (parentId != null) {
      final parentNode = _findNodeById(parentId, widget.state.nodes);
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

  bool _hasCommittedConnections(Set<dynamic>? sideConnections) {
    final createdArrowId = widget.state.arrowCreated?.id;
    if (sideConnections == null || sideConnections.isEmpty) {
      return false;
    }

    for (final connection in sideConnections) {
      if (connection == null) {
        continue;
      }
      if (createdArrowId != null && connection.id == createdArrowId) {
        continue;
      }
      return true;
    }

    return false;
  }

  Widget _buildStaticCircle(double length, double width, bool isFilled) {
    return Container(
      width: length,
      height: length,
      decoration: BoxDecoration(
        color: isFilled ? Colors.blue : Colors.blue.shade50,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: width),
      ),
    );
  }

  Widget _buildPositionedStaticCircle({
    required double centerX,
    required double centerY,
    required double length,
    required double width,
    required bool isFilled,
  }) {
    return Positioned(
      left: centerX - length / 2,
      top: centerY - length / 2,
      child: _buildStaticCircle(length, width, isFilled),
    );
  }

  List<Widget> _buildStaticAttributeCircles({
    required TableNode currentNode,
    required double offset,
    required double frame,
    required double scale,
    required double length,
    required double width,
  }) {
    final children = <Widget>[];
    final nodesToProcess = <TableNode>[];

    if (currentNode.qType == 'group' && currentNode.children != null) {
      for (final child in currentNode.children!) {
        if (child.attributes.isNotEmpty) {
          nodesToProcess.add(child);
        }
      }
    }

    if (currentNode.attributes.isNotEmpty) {
      nodesToProcess.add(currentNode);
    }

    for (final node in nodesToProcess) {
      final nodeOffsetX = node.id == currentNode.id ? 0.0 : node.position.dx * scale;
      final nodeOffsetY = node.id == currentNode.id ? 0.0 : node.position.dy * scale;
      final nodeLeft = frame + offset + nodeOffsetX;
      final nodeRight = nodeLeft + node.size.width * scale;

      for (final attribute in node.attributes) {
        final centerY = offset + frame + nodeOffsetY + (attribute.position.dy + attribute.size.height / 2) * scale;
        final leftFilled = _hasCommittedConnections(attribute.connections?.get('left'));
        final rightFilled = _hasCommittedConnections(attribute.connections?.get('right'));

        children.add(
          _buildPositionedStaticCircle(
            centerX: nodeLeft,
            centerY: centerY,
            length: length,
            width: width,
            isFilled: leftFilled,
          ),
        );
        children.add(
          _buildPositionedStaticCircle(
            centerX: nodeRight,
            centerY: centerY,
            length: length,
            width: width,
            isFilled: rightFilled,
          ),
        );
      }
    }

    return children;
  }

  List<Widget> _buildStaticNodeSideCircles({
    required TableNode currentNode,
    required Size overlaySize,
    required double offset,
    required double frame,
    required double groupOffsetX,
    required double groupOffsetY,
    required double scale,
    required double length,
    required double width,
  }) {
    final headerHeight = (currentNode.heightHeader ?? EditorConfig.minHeaderHeight) * scale;

    return [
      _buildPositionedStaticCircle(
        centerX: overlaySize.width / 2 + width / 4,
        centerY: frame + groupOffsetY,
        length: length,
        width: width,
        isFilled: false,
      ),
      _buildPositionedStaticCircle(
        centerX: overlaySize.width / 2 + width / 4,
        centerY: overlaySize.height - frame - groupOffsetY,
        length: length,
        width: width,
        isFilled: false,
      ),
      _buildPositionedStaticCircle(
        centerX: overlaySize.width - frame - groupOffsetX,
        centerY: frame + groupOffsetY + offset + headerHeight / 2,
        length: length,
        width: width,
        isFilled: false,
      ),
      _buildPositionedStaticCircle(
        centerX: frame + groupOffsetX,
        centerY: frame + groupOffsetY + offset + headerHeight / 2,
        length: length,
        width: width,
        isFilled: false,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    widget.nodeManager.setOnStateUpdate('NodeHover', () {
      timeoutSetState();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.hoveredNode == null) {
      return Container();
    }

    final currentNode = widget.state.hoveredNode!;
    if (_shouldIgnoreHoverNode(currentNode)) {
      return Container();
    }
    final screenTopLeft = Offset(
      widget.state.hoveredNode!.aPosition!.dx * widget.state.scale + widget.state.offset.dx,
      widget.state.hoveredNode!.aPosition!.dy * widget.state.scale + widget.state.offset.dy,
    );
    final nodeSize = Size(currentNode.size.width * widget.state.scale, currentNode.size.height * widget.state.scale);
    final hasAttributes = currentNode.attributes.isNotEmpty;
    final isEnum = currentNode.qType == 'enum';
    final isGroup = currentNode.qType == 'group';
    final isBo = currentNode.qType == 'bo';
    final scale = widget.state.scale;
    final offset = NodeManager.resizeHandleOffset * scale;
    final lengthArrow = NodeManager.arrowHandleWidth * scale;
    final width = widget.nodeManager.widthBorderCircle;
    final frame = widget.nodeManager.frameTotalOffset;
    final hoverPadding = lengthArrow * 3 / 2;
    final borderRadius = !isGroup && !isEnum && isBo && hasAttributes
        ? BorderRadius.circular(8 * scale)
        : BorderRadius.zero;
    final overlaySize = Size(nodeSize.width + offset * 2 + frame * 2, nodeSize.height + offset * 2 + frame * 2);
    final showArrowCreatedHoverWidgets = widget.state.arrowCreated != null;

    double groupOffsetX = 0;
    double groupOffsetY = 0;

    if (isGroup && currentNode.children != null && currentNode.children!.isNotEmpty) {
      final firstChild = currentNode.children!.first;
      groupOffsetX = firstChild.position.dx * scale;
      groupOffsetY = firstChild.position.dy * scale;
    }

    return Positioned(
      left: screenTopLeft.dx - offset - frame - hoverPadding,
      top: screenTopLeft.dy - offset - frame - hoverPadding,
      child: MouseRegion(
        opaque: true,
        cursor: SystemMouseCursors.click,
        onHover: showArrowCreatedHoverWidgets
            ? (_) {
                if (widget.state.hoveredNode?.id != currentNode.id) {
                  widget.state.hoveredNode = currentNode;
                  widget.nodeManager.onStateUpdate();
                }
              }
            : null,
        child: SizedBox(
          width: overlaySize.width + hoverPadding * 2,
          height: overlaySize.height + hoverPadding * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (showArrowCreatedHoverWidgets)
                Positioned(
                  left: hoverPadding + frame,
                  top: hoverPadding + frame,
                  child: Container(
                    width: overlaySize.width - frame * 2,
                    height: overlaySize.height - frame * 2,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: isGroup || isEnum || !hasAttributes
                          ? BorderRadius.zero
                          : BorderRadius.circular(12 * scale),
                    ),
                  ),
                ),
              Positioned(
                left: hoverPadding + offset + frame,
                top: hoverPadding + offset + frame,
                child: Container(
                  width: nodeSize.width,
                  height: nodeSize.height,
                  decoration: BoxDecoration(
                    color: Colors.yellowAccent.withValues(alpha: 0.2),
                    borderRadius: borderRadius,
                  ),
                ),
              ),
              if (showArrowCreatedHoverWidgets) ...[
                if (currentNode.qType != 'swimlane')
                  Positioned(
                    left: hoverPadding,
                    top: hoverPadding,
                    child: SizedBox(
                      width: overlaySize.width,
                      height: overlaySize.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ...(!isEnum && currentNode.qType != 'swimlane')
                              ? _buildStaticAttributeCircles(
                                  currentNode: currentNode,
                                  offset: offset,
                                  frame: frame,
                                  scale: scale,
                                  length: lengthArrow,
                                  width: width,
                                )
                              : [],
                          ..._buildStaticNodeSideCircles(
                            currentNode: currentNode,
                            overlaySize: overlaySize,
                            offset: offset,
                            frame: frame,
                            groupOffsetX: groupOffsetX,
                            groupOffsetY: groupOffsetY,
                            scale: scale,
                            length: lengthArrow,
                            width: width,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
