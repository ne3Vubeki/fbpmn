import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Node;
import 'controllers/editor_controller.dart';
import 'widgets/canvas_widget.dart';
import 'widgets/scroll_bars.dart';
import 'widgets/control_panel.dart';

class StableGridCanvas extends StatelessWidget {
  const StableGridCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    final EditorController controller = Get.put(EditorController());

    return LayoutBuilder(
      builder: (context, constraints) {
        controller.setViewportSize(
          Size(constraints.maxWidth, constraints.maxHeight),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!controller.isInitialized.value) {
            controller.centerCanvas();
          }
        });

        final Size baseCanvasSize = Size(
          constraints.maxWidth * controller.canvasSizeMultiplier,
          constraints.maxHeight * controller.canvasSizeMultiplier,
        );

        return Obx(() {
          final Size scaledCanvasSize = Size(
            baseCanvasSize.width * controller.scale.value,
            baseCanvasSize.height * controller.scale.value,
          );

          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.updateScrollControllers();
          });

          return Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Основной холст с сеткой и узлами
                    Positioned(
                      left: 0,
                      top: 0,
                      right: 10,
                      bottom: 10,
                      child: CanvasWidget(
                        controller: controller,
                        scaledCanvasSize: scaledCanvasSize,
                      ),
                    ),

                    // Скроллбары
                    ScrollBars(
                      controller: controller,
                      scaledCanvasSize: scaledCanvasSize,
                    ),

                    // Панель управления
                    ControlPanel(controller: controller),
                  ],
                ),
              ),
            ],
          );
        });
      },
    );
  }
}