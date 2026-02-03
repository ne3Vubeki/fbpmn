import 'package:fbpmn/src/painters/snap_lines_painter.dart';
import 'package:fbpmn/src/services/node_manager.dart';
import 'package:fbpmn/src/widgets/state_widget.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';

class SnapLinesOverlay extends StatefulWidget {
  final EditorState state;
  final NodeManager nodeManager;

  const SnapLinesOverlay({
    super.key,
    required this.state,
    required this.nodeManager,
  });

  @override
  State<SnapLinesOverlay> createState() => _SnapLinesOverlayState();
}

class _SnapLinesOverlayState extends State<SnapLinesOverlay>
    with StateWidget<SnapLinesOverlay> {
  @override
  void initState() {
    super.initState();
    widget.nodeManager.setOnStateUpdate('SnapLinesOverlay', () {
      timeoutSetState();
    });
  }

  @override
  void dispose() {
    widget.nodeManager.removeOnStateUpdate('SnapLinesOverlay');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.snapLines.isEmpty || 
        widget.state.viewportSize == Size.zero) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: SizedBox(
        width: widget.state.viewportSize.width,
        height: widget.state.viewportSize.height,
        child: CustomPaint(
          painter: SnapLinesPainter(
            snapLines: widget.state.snapLines,
            viewportSize: widget.state.viewportSize,
          ),
        ),
      ),
    );
  }
}
