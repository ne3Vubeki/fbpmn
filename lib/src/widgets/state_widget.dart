import 'dart:async';

import 'package:flutter/widgets.dart';

mixin StateWidget<T extends StatefulWidget> on State<T> {
  Timer? _timer;

  timeoutSetState() {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: 0), () {
      if (mounted) {
        setState(() {});
      }
      _timer = null;
    });
  }
}
