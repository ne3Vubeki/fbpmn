import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../editor_state.dart';
import '../services/node_manager.dart';

class CursorLayer extends StatefulWidget {
  final EditorState state;
  final NodeManager nodeManager;
  final String? currentResizeHandle;
  final Widget child;

  const CursorLayer({
    super.key,
    required this.state,
    required this.nodeManager,
    required this.currentResizeHandle,
    required this.child,
  });

  @override
  State<CursorLayer> createState() => _CursorLayerState();
}

class _CursorLayerState extends State<CursorLayer> {
  MouseCursor _getCursor() {
    if (widget.nodeManager.isResizing && widget.currentResizeHandle != null) {
      return widget.nodeManager.getResizeCursor(widget.currentResizeHandle);
    }

    if (widget.state.isShiftPressed && widget.state.isPanning) {
      return SystemMouseCursors.grabbing;
    }
    if (widget.state.isShiftPressed) {
      return SystemMouseCursors.grab;
    }

    if (widget.state.isCtrlPressed) {
      return SystemMouseCursors.cell;
    }
    
    return SystemMouseCursors.basic;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _getCursor(),
      child: widget.child,
    );
  }
}
