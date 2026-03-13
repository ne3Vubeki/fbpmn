class Manager {
  final Map<String, Function> _onStateUpdate = {};

  void setOnStateUpdate(String key, Function callback) {
    _onStateUpdate[key] = callback;
  }

  void removeOnStateUpdate(String key) {
    _onStateUpdate.remove(key);
  }

  void onStateUpdate([dynamic data]) {
    if (_onStateUpdate.keys.isNotEmpty) {
      for (final key in _onStateUpdate.keys) {
        final callback = _onStateUpdate[key];
        if (callback == null) continue;

        try {
          Function.apply(callback, [data]);
        } on NoSuchMethodError {
          Function.apply(callback, []);
        }
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
