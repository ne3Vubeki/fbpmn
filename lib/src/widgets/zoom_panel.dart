import 'package:flutter/material.dart';

class ZoomPanel extends StatelessWidget {
  final double scale;
  final bool showTileBorders;
  final VoidCallback onResetZoom;
  final VoidCallback onToggleTileBorders;
  
  const ZoomPanel({
    super.key,
    required this.scale,
    required this.showTileBorders,
    required this.onResetZoom,
    required this.onToggleTileBorders,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
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
            '${(scale * 100).round()}%',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.zoom_out_map, size: 18),
            onPressed: onResetZoom,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            tooltip: 'Reset to 100%',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              showTileBorders ? Icons.border_outer : Icons.border_clear,
              size: 18,
              color: showTileBorders ? Colors.red : Colors.grey,
            ),
            onPressed: onToggleTileBorders,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            tooltip: showTileBorders ? 'Hide tile borders' : 'Show tile borders',
          ),
        ],
      ),
    );
  }
}