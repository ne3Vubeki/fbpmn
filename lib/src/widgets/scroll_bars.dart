import 'package:flutter/material.dart';
import '../controllers/editor_controller.dart';

class ScrollBars extends StatelessWidget {
  final EditorController controller;
  final Size scaledCanvasSize;

  const ScrollBars({
    super.key,
    required this.controller,
    required this.scaledCanvasSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Горизонтальный скроллбар
        Positioned(
          left: 0,
          right: 10,
          bottom: 0,
          height: 10,
          child: Listener(
            onPointerDown: controller.handleHorizontalScrollbarDragStart,
            onPointerMove: controller.handleHorizontalScrollbarDragUpdate,
            onPointerUp: controller.handleHorizontalScrollbarDragEnd,
            child: Scrollbar(
              controller: controller.horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: false,
              thickness: 10,
              child: SingleChildScrollView(
                controller: controller.horizontalScrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: scaledCanvasSize.width,
                  height: 10,
                ),
              ),
            ),
          ),
        ),

        // Вертикальный скроллбар
        Positioned(
          top: 0,
          bottom: 10,
          right: 0,
          width: 10,
          child: Listener(
            onPointerDown: controller.handleVerticalScrollbarDragStart,
            onPointerMove: controller.handleVerticalScrollbarDragUpdate,
            onPointerUp: controller.handleVerticalScrollbarDragEnd,
            child: Scrollbar(
              controller: controller.verticalScrollController,
              thumbVisibility: true,
              trackVisibility: false,
              thickness: 10,
              child: SingleChildScrollView(
                controller: controller.verticalScrollController,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: 10,
                  height: scaledCanvasSize.height,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}