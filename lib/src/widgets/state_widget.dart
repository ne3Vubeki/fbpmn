import 'dart:async';

import 'package:flutter/widgets.dart';

mixin StateWidget<T extends StatefulWidget> on State<T> {
  Timer? _timer; // Добавляем поле класса для хранения таймера

  void timeoutSetState({
    Duration? duration, 
    VoidCallback? callback,
  }) {
    _timer?.cancel(); // Отменяем предыдущий таймер если есть
    
    _timer = Timer(duration ?? Duration.zero, () {
      if (mounted) {
        setState(() {
          callback?.call();
        });
      }
      _timer = null;
    });
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}