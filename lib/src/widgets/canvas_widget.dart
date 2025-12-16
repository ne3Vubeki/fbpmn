import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Node;
import 'hierarchical_grid_painter.dart';

import '../controllers/editor_controller.dart';

class CanvasWidget extends StatelessWidget {
  final EditorController controller;
  final Size scaledCanvasSize;

  const CanvasWidget({
    super.key,
    required this.controller,
    required this.scaledCanvasSize,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: controller.focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight) {
          controller.setShiftPressed(
            event is KeyDownEvent || event is KeyRepeatEvent,
          );
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.delete) {
          controller.deleteSelectedNode();
        }
      },
      child: Obx(() {
        return MouseRegion(
          cursor: _getCursor(controller),
          onHover: (PointerHoverEvent event) {
            controller.setMousePosition(event.localPosition);
          },
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent &&
                  controller.isShiftPressed.value) {
                controller.handleZoom(
                  pointerSignal.scrollDelta.dy,
                  controller.mousePosition.value,
                );
              }
            },
            onPointerMove: (PointerMoveEvent event) {
              controller.setMousePosition(event.localPosition);

              if (controller.isPanning.value && controller.isShiftPressed.value) {
                controller.updatePan(event.localPosition);
              } else if (controller.isNodeDragging.value) {
                controller.updateNodeDrag(event.localPosition);
              }
            },
            onPointerDown: (PointerDownEvent event) {
              controller.setMousePosition(event.localPosition);

              if (controller.isShiftPressed.value) {
                controller.setPanning(
                  true,
                  startOffset: controller.offset.value,
                  startMousePosition: event.localPosition,
                );
              } else {
                controller.selectNodeAtPosition(event.localPosition);
                if (controller.selectedNode.value != null) {
                  controller.startNodeDrag(event.localPosition);
                }
              }
              controller.focusNode.requestFocus();
            },
            onPointerUp: (PointerUpEvent event) {
              controller.setPanning(false);
              controller.endNodeDrag();
            },
            onPointerCancel: (PointerCancelEvent event) {
              controller.setPanning(false);
              controller.endNodeDrag();
            },
            child: Obx(() {
              final forceRepaint = controller.nodes.length;
              final selectedId = controller.selectedNode.value?.id;
              final isDragging = controller.isNodeDragging.value;

              return ClipRect(
                child: CustomPaint(
                  size: scaledCanvasSize,
                  painter: HierarchicalGridPainter(
                    scale: controller.scale.value,
                    offset: controller.offset.value,
                    canvasSize: scaledCanvasSize,
                    nodes: controller.nodes,
                    forceRepaintId: forceRepaint,
                    selectedNodeId: selectedId,
                    isDragging: isDragging,
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  MouseCursor _getCursor(EditorController controller) {
    if (controller.isShiftPressed.value && controller.isPanning.value) {
      return SystemMouseCursors.grabbing;
    } else if (controller.isShiftPressed.value) {
      return SystemMouseCursors.grab;
    } else {
      return SystemMouseCursors.basic;
    }
  }
}