import 'package:fbpmn/src/services/arrow_manager.dart';
import 'package:fbpmn/src/services/performance_tracker.dart';
import 'package:flutter/material.dart';
import '../models/arrow.dart';
import 'arrow_painter.dart';

class ArrowsCustomPainter extends CustomPainter {
  final List<Arrow?> arrows;
  final double scale;
  final Size arrowsSize;
  final Rect arrowsRect;
  final Offset nodeOffset;
  final ArrowManager arrowManager;
  final double areaNodes;

  ArrowsCustomPainter({
    required this.arrows,
    required this.scale,
    required this.arrowsSize,
    required this.arrowsRect,
    required this.nodeOffset,
    required this.arrowManager,
    required this.areaNodes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stopwatch = Stopwatch()..start();

    final scaleX = arrowsSize.width / size.width;
    final scaleY = arrowsSize.height / size.height;

    // Сохраняем состояние canvas
    canvas.save();

    // Применяем масштаб ко всему (узлу и детям)
    canvas.scale(scaleX, scaleY);

    // Рисуем основной узел
    final painter = ArrowsPainter(arrows: arrows, arrowManager: arrowManager);
    painter.paint(canvas, scale, arrowsRect);

    canvas.restore();

    stopwatch.stop();
    PerformanceTracker().recordSelectedArrowsRender(stopwatch.elapsedMicroseconds / 1000.0);
  }

  @override
  bool shouldRepaint(covariant ArrowsCustomPainter oldDelegate) {
    return oldDelegate.arrows.length != arrows.length ||
        oldDelegate.arrowsSize != arrowsSize ||
        oldDelegate.nodeOffset != nodeOffset ||
        oldDelegate.scale != scale ||
        oldDelegate.areaNodes != areaNodes;
  }
}
