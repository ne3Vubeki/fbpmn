import 'package:fbpmn/src/painters/arrow_painter.dart';
import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/widgets/state_widget.dart';
import 'package:flutter/material.dart';

import '../editor_state.dart';

class ArrowCreated extends StatefulWidget {
  final EditorState state;
  final ArrowManager arrowManager;

  const ArrowCreated({
    super.key,
    required this.state,
    required this.arrowManager,
  });

  @override
  State<ArrowCreated> createState() => _ArrowCreatedState();
}

class _ArrowCreatedState extends State<ArrowCreated> with StateWidget<ArrowCreated> {
  @override
  void initState() {
    super.initState();
    widget.arrowManager.setOnStateUpdate('ArrowCreated', (path) {
      if(path == null || path == 'ArrowCreated') timeoutSetState();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.arrowCreated == null) {
      return Container();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ArrowCreatedPainter(
              scale: widget.state.scale,
              arrowManager: widget.arrowManager,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowCreatedPainter extends CustomPainter {
  final double scale;
  final ArrowManager arrowManager;

  const _ArrowCreatedPainter({
    required this.scale,
    required this.arrowManager,
  });

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
