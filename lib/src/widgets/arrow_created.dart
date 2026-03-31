import 'dart:math' as math;

import 'package:fbpmn/src/painters/arrow_painter.dart';
import 'package:fbpmn/src/models/attribute.dart';
import 'package:fbpmn/src/models/table.node.dart';
import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/widgets/state_widget.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';

class ArrowCreated extends StatefulWidget {
  final EditorState state;
  final ArrowManager arrowManager;

  const ArrowCreated({super.key, required this.state, required this.arrowManager});

  @override
  State<ArrowCreated> createState() => _ArrowCreatedState();
}

class _ArrowCreatedState extends State<ArrowCreated> with StateWidget<ArrowCreated> {
  bool _isTargetHovered = false;

  @override
  void initState() {
    super.initState();
    widget.arrowManager.setOnStateUpdate('ArrowCreated', (path) {
      if (path == null || path == 'ArrowCreated') timeoutSetState();
    });
  }

  ({TableNode? node, Attribute? attribute}) _findTargetById(String targetId) {
    TableNode? foundNode;
    Attribute? foundAttribute;

    TableNode? findRecursive(List<TableNode> nodes) {
      for (final node in nodes) {
        if (node.id == targetId) {
          return node;
        }

        for (final attribute in node.attributes) {
          if (attribute.id == targetId) {
            foundAttribute = attribute;
            return node;
          }
        }

        if (node.children != null) {
          final found = findRecursive(node.children!);
          if (found != null) {
            return found;
          }
        }
      }
      return null;
    }

    foundNode = findRecursive(widget.state.nodes);

    if (foundNode == null && widget.state.nodesSelected.isNotEmpty) {
      foundNode = findRecursive(widget.state.nodesSelected.whereType<TableNode>().toList());
    }

    return (node: foundNode, attribute: foundAttribute);
  }

  Offset _resolveWorldPosition(TableNode node) {
    if (node.aPosition != null) {
      return node.aPosition!;
    }

    final parentId = node.parent;
    if (parentId == null) {
      return node.position + widget.state.delta;
    }

    final parentNode = NodeManager.getNodeById(widget.state.nodes, parentId);
    if (parentNode == null) {
      return node.position + widget.state.delta;
    }

    return _resolveWorldPosition(parentNode) + node.position;
  }

  String _getTargetDirectionFromPosition(String targetId, Offset targetPoint) {
    final targetSide = widget.state.arrowCreated?.sides?.split(':').skip(1).firstWhere(
      (side) => side.isNotEmpty,
      orElse: () => '',
    );
    if (targetSide != null && targetSide.isNotEmpty) {
      return {
            'left': 'r',
            'right': 'l',
            'top': 'b',
            'bottom': 't',
          }[targetSide] ??
          'l';
    }

    final targetData = _findTargetById(targetId);
    final targetNode = targetData.node;
    if (targetNode == null) {
      return 'l';
    }

    final targetWorldPosition = _resolveWorldPosition(targetNode);
    final targetAttribute = targetData.attribute;
    final targetRect = Rect.fromLTWH(
      targetAttribute == null ? targetWorldPosition.dx : targetWorldPosition.dx + targetAttribute.position.dx,
      targetAttribute == null ? targetWorldPosition.dy : targetWorldPosition.dy + targetAttribute.position.dy,
      targetAttribute == null ? targetNode.size.width : targetAttribute.size.width,
      targetAttribute == null ? targetNode.size.height : targetAttribute.size.height,
    );
    final targetCenter = Offset(
      targetRect.center.dx * widget.state.scale + widget.state.offset.dx,
      targetRect.center.dy * widget.state.scale + widget.state.offset.dy,
    );
    final delta = targetPoint - targetCenter;

    if (delta.dx.abs() >= delta.dy.abs()) {
      return delta.dx >= 0 ? 'r' : 'l';
    }

    return delta.dy >= 0 ? 'b' : 't';
  }

  Widget _buildDirectionIcon(String direction, double length) {
    final rotations = <String, double>{
      'r': 0,
      'l': math.pi,
      't': -math.pi / 2,
      'b': math.pi / 2,
    };
    final size = length * 0.75;

    return Transform.rotate(
      angle: rotations[direction] ?? 0,
      child: Transform.translate(
        offset: Offset(-size / 6, -size / 6),
        child: Icon(
          Icons.arrow_forward,
          color: Colors.white,
          size: size,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arrow = widget.state.arrowCreated;
    if (arrow == null) {
      return Container();
    }

    final scale = widget.state.scale;
    final length = NodeManager.arrowHandleWidth * scale;
    final borderWidth = NodeManager.resizeHandleBorderWidth * scale;
    final hoverAreaSize = length * 3;
    final pathResult = widget.arrowManager.getCreatedArrowPath();
    final hasTargetHandle = arrow.target.isNotEmpty && pathResult.coordinates.isNotEmpty;
    final targetPoint = hasTargetHandle ? pathResult.coordinates.last : Offset.zero;
    final targetDirection = hasTargetHandle ? _getTargetDirectionFromPosition(arrow.target, targetPoint) : 'l';

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _ArrowCreatedPainter(scale: scale, arrowManager: widget.arrowManager),
              ),
            ),
          ),
          if (hasTargetHandle)
            Positioned(
              left: targetPoint.dx - hoverAreaSize / 2,
              top: targetPoint.dy - hoverAreaSize / 2,
              width: hoverAreaSize,
              height: hoverAreaSize,
              child: MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                cursor: SystemMouseCursors.alias,
                onEnter: (_) {
                  setState(() {
                    _isTargetHovered = true;
                  });
                },
                onExit: (_) {
                  setState(() {
                    _isTargetHovered = false;
                  });
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    widget.state.ignoreNextCreatedArrowCancel = true;
                  },
                  onPointerUp: (_) {
                    widget.arrowManager.confirmCreateArrow(widget.state.arrowCreated!);
                  },
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      width: length,
                      height: length,
                      alignment: Alignment.center,
                      child: AnimatedScale(
                        scale: _isTargetHovered ? 3.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: Container(
                          width: length,
                          height: length,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red, width: borderWidth),
                          ),
                          child: _isTargetHovered
                              ? Center(
                                  child: _buildDirectionIcon(targetDirection, length),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArrowCreatedPainter extends CustomPainter {
  final double scale;
  final ArrowManager arrowManager;

  const _ArrowCreatedPainter({required this.scale, required this.arrowManager});

  @override
  void paint(Canvas canvas, Size size) {
    final painter = ArrowsPainter(arrows: [arrowManager.state.arrowCreated], arrowManager: arrowManager);
    painter.paintCreated(canvas, scale);
  }

  @override
  bool shouldRepaint(covariant _ArrowCreatedPainter oldDelegate) {
    return true;
  }
}
