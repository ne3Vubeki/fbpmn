import 'package:flutter/material.dart';

import '../controllers/editor_controller.dart';

class ControlPanel extends StatelessWidget {
  final EditorController controller;

  const ControlPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Панель зума
        Positioned(
          right: 20,
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(controller.scale.value * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.zoom_out_map, size: 18),
                  onPressed: controller.resetZoom,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  tooltip: 'Reset to 100%',
                ),
              ],
            ),
          ),
        ),

        // Кнопка добавления узла
        Positioned(
          right: 20,
          bottom: 70,
          child: FloatingActionButton(
            onPressed: () {
              controller.addNodeAt(
                (controller.mousePosition.value - controller.offset.value) /
                    controller.scale.value,
              );
            },
            mini: true,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}