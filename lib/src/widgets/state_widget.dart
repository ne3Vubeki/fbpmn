import 'dart:async';

import 'package:flutter/widgets.dart';

mixin StateWidget<T extends StatefulWidget> on State<T> {
  Timer? _timer;

  timeoutSetState([Function? callback]) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: 0), () {
      if (mounted) {
        setState(() {
          if(callback != null) {
            callback();
          }
        });
      }
      _timer = null;
    });
  }
}
