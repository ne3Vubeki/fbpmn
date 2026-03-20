import 'package:flutter/material.dart';
import '../editor_state.dart';
import '../services/node_manager.dart';
import '../utils/editor_config.dart';
import 'config_action_button.dart';
import 'state_widget.dart';

/// Виджет для отображения маркеров изменения размера узла
class NodeConfig extends StatefulWidget {
  final EditorState state;
  final NodeManager nodeManager;

  const NodeConfig({super.key, required this.state, required this.nodeManager});

  @override
  State<NodeConfig> createState() => _NodeConfigState();
}

class _NodeConfigState extends State<NodeConfig> with StateWidget<NodeConfig> {
  Map<String, bool> isHovered = {};
  String? _lastSelectedNodeId;
  String? _lastArrowCreatedId;

  void _resetHoverStateIfNeeded() {
    final selectedNodeId = widget.state.nodesSelected.length == 1 ? widget.state.nodesSelected.first?.id : null;
    final arrowCreatedId = widget.state.arrowCreated?.id;
    final shouldReset = _lastSelectedNodeId != selectedNodeId || (_lastArrowCreatedId != null && arrowCreatedId == null);

    if (shouldReset && isHovered.isNotEmpty) {
      isHovered.clear();
    }

    _lastSelectedNodeId = selectedNodeId;
    _lastArrowCreatedId = arrowCreatedId;
  }

  @override
  void initState() {
    super.initState();
    widget.nodeManager.setOnStateUpdate('NodeConfig', () {
      timeoutSetState();
    });
  }

  @override
  Widget build(BuildContext context) {
    _resetHoverStateIfNeeded();

    // Проверяем, есть ли выделенный узел
    if (widget.state.nodesSelected.isEmpty || widget.state.nodesSelected.length > 1) return Container();

    final node = widget.state.nodesSelected.first!;
    final scale = widget.state.scale;
    final hasAttributes = node.attributes.isNotEmpty;
    final isEnum = node.qType == 'enum';
    final isGroup = node.qType == 'group';

    final offset = NodeManager.resizeHandleOffset * scale;
    final lengthArrow = NodeManager.arrowHandleWidth * scale;
    final width = NodeManager.resizeHandleBorderWidth * scale;
    // рамка (масштабированный)
    final frame = widget.nodeManager.frameTotalOffset;

    // Размер узла (масштабированный)
    final nodeSize = Size(node.size.width * scale, node.size.height * scale);
    final resizeBoxContainerSize = Size(
      nodeSize.width + offset * 2 + frame * 2,
      nodeSize.height + offset * 2 + frame * 2,
    );

    final containerLeft = widget.state.selectedNodeOffset.dx - offset - width / 4;
    final containerTop = widget.state.selectedNodeOffset.dy - offset - width / 4;
    final buttonSize = 26.0 * scale;

    final showHandles =
        node.qType != 'swimlane' || (node.qType == 'swimlane' && node.isCollapsed != null && node.isCollapsed!);

    if (!showHandles) return Container();

    // Для группы определяем смещение для маркеров (если есть вложенный узел)
    double groupOffsetX = 0;
    double groupOffsetY = 0;

    if (isGroup && node.children != null && node.children!.isNotEmpty) {
      // Берем первый дочерний узел для определения области маркеров
      final firstChild = node.children!.first;
      groupOffsetX = firstChild.position.dx * scale;
      groupOffsetY = firstChild.position.dy * scale;
    }

    final groupSourceId = isGroup && node.children != null && node.children!.isNotEmpty ? node.children!.first.id : null;

    // Позиция кнопки относительно контейнера
    final buttonTop = containerTop - buttonSize / 2;
    final buttonLeft = containerLeft - buttonSize / 2;
    final buttonRight = containerLeft + resizeBoxContainerSize.width - buttonSize / 2;
    final buttonBottom = containerTop + resizeBoxContainerSize.height - buttonSize / 2;

    return Stack(
      children: [
        Positioned(
          left: containerLeft,
          top: containerTop,
          child: SizedBox(
            width: resizeBoxContainerSize.width,
            height: resizeBoxContainerSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: frame,
                  top: frame,
                  child: IgnorePointer(
                    child: Container(
                      width: resizeBoxContainerSize.width - frame * 2,
                      height: resizeBoxContainerSize.height - frame * 2,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: isGroup || isEnum || !hasAttributes
                            ? BorderRadius.zero
                            : BorderRadius.circular(12 * scale),
                      ),
                    ),
                  ),
                ),

                // Подсветка строки атрибута и кружки для всех узлов, включая вложенные в группу
                widget.nodeManager.buildAllAttributesHighlights(
                  node,
                  nodeSize,
                  offset + frame,
                  scale,
                  lengthArrow,
                  width,
                  isHovered,
                  setState,
                ),

                // Боковые маркеры
                widget.nodeManager.buildSideHandle(
                  't',
                  resizeBoxContainerSize.width / 2 - lengthArrow / 2 + width / 4,
                  frame + groupOffsetY - lengthArrow / 2,
                  lengthArrow,
                  width,
                  isHovered,
                  sourceId: groupSourceId,
                  cursor: SystemMouseCursors.alias,
                  setState: setState,
                ),

                widget.nodeManager.buildSideHandle(
                  'b',
                  resizeBoxContainerSize.width / 2 - lengthArrow / 2 + width / 4,
                  resizeBoxContainerSize.height - frame - lengthArrow / 2 - groupOffsetY,
                  lengthArrow,
                  width,
                  isHovered,
                  sourceId: groupSourceId,
                  cursor: SystemMouseCursors.alias,
                  setState: setState,
                ),
                widget.nodeManager.buildSideHandle(
                  'r',
                  resizeBoxContainerSize.width - frame - lengthArrow / 2 - groupOffsetX,
                  frame +
                      groupOffsetY +
                      offset +
                      (node.heightHeader ?? EditorConfig.minHeaderHeight) * scale / 2 -
                      lengthArrow / 2,
                  lengthArrow,
                  width,
                  isHovered,
                  sourceId: groupSourceId,
                  cursor: SystemMouseCursors.alias,
                  setState: setState,
                ),
                widget.nodeManager.buildSideHandle(
                  'l',
                  frame + groupOffsetX - lengthArrow / 2,
                  frame +
                      groupOffsetY +
                      offset +
                      (node.heightHeader ?? EditorConfig.minHeaderHeight) * scale / 2 -
                      lengthArrow / 2,
                  lengthArrow,
                  width,
                  isHovered,
                  sourceId: groupSourceId,
                  cursor: SystemMouseCursors.alias,
                  setState: setState,
                ),
              ],
            ),
          ),
        ),

        ConfigActionButton(
          left: buttonLeft,
          top: buttonTop,
          size: buttonSize,
          color: Colors.white,
          colorIcon: Colors.black,
          icon: Icons.settings_outlined,
          cursor: SystemMouseCursors.click, // Курсор для кнопки настроек
          tooltip: 'Настроить объект',
          onTap: () {
            // TODO: добавить обработчик для кнопки настроек
          },
        ),
        ConfigActionButton(
          left: buttonRight,
          top: buttonTop,
          size: buttonSize,
          color: Colors.red,
          icon: Icons.delete_forever_outlined,
          cursor: SystemMouseCursors.click, // Курсор для кнопки удаления
          tooltip: 'Удалить объект',
          onTap: () {
            widget.nodeManager.confirmDeleteNode(widget.state.nodesSelected.first!.id);
          },
        ),
        _buildResizeButton(
          left: buttonRight,
          top: buttonBottom,
          size: buttonSize,
          color: Colors.amber,
          colorIcon: Colors.black,
        ),
      ],
    );
  }

  /// Создаёт круглую кнопку для изменения размера
  Widget _buildResizeButton({
    required double left,
    required double top,
    required double size,
    required Color color,
    required Color colorIcon,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            widget.nodeManager.startResize(event.position);
          },
          onPointerMove: (event) {
            if (widget.nodeManager.isResizing) {
              widget.nodeManager.updateResize(event.position);
            }
          },
          onPointerUp: (event) {
            widget.nodeManager.endResize();
          },
          child: Tooltip(
            message: 'Изменить размер объекта',
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Center(
                child: Icon(Icons.zoom_out_map_outlined, size: size * 0.5, color: colorIcon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
