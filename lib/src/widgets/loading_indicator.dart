import 'package:flutter/material.dart';

import '../editor_state.dart';
import '../services/tile_manager.dart';

class LoadingIndicator extends StatefulWidget {
  final EditorState state;
  final TileManager tileManager;

  const LoadingIndicator({
    super.key,
    required this.state,
    required this.tileManager,
  });

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> {
  @override
  void initState() {
    super.initState();
    widget.tileManager.setOnStateUpdate('LoadingIndicator', () {
      if (this.mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.state.isLoading
        ? Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.2),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
          )
        : Container();
  }
}
