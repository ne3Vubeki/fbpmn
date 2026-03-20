import 'package:fbpmn/src/painters/icon_painter.dart';
import 'package:flutter/material.dart';

class ConfigActionButton extends StatelessWidget {
  final double left;
  final double top;
  final double size;
  final Color color;
  final Color colorIcon;
  final dynamic icon;
  final MouseCursor? cursor;
  final String? tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onPointerDown;

  const ConfigActionButton({
    super.key,
    required this.left,
    required this.top,
    required this.size,
    required this.color,
    this.colorIcon = Colors.white,
    required this.icon,
    this.cursor,
    this.tooltip,
    this.onTap,
    this.onPointerDown,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: Tooltip(
        message: tooltip ?? '',
        child: MouseRegion(
          cursor: cursor ?? SystemMouseCursors.click,
          opaque: true,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              onPointerDown?.call();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: icon is IconData
                      ? Icon(icon, size: size * 0.5, color: colorIcon)
                      : CustomPaint(
                          size: Size(size * 0.5, size * 0.5),
                          painter: IconPainter(
                            painter: icon as void Function(Canvas, Size, Color),
                            color: colorIcon,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
