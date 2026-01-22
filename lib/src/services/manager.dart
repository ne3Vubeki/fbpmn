import 'dart:ui';

import 'package:flutter/material.dart';

class Manager {
  final Map<String, VoidCallback> _onStateUpdate = {};

  void setOnStateUpdate(String key, VoidCallback callback) {
    _onStateUpdate[key] = callback;
  }

  void onStateUpdate() {
    if(_onStateUpdate.keys.isNotEmpty) {
      for(final key in _onStateUpdate.keys) {
        print('========================== Event for $key =================================');
        _onStateUpdate[key]!();
      }
    }
  }

  void clearOnStateUpdate() {
    _onStateUpdate.clear();
  }

  void dispose() {
    clearOnStateUpdate();
  }
}
