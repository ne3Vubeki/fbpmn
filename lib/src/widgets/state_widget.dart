import 'dart:async';

import 'package:flutter/widgets.dart';

mixin StateWidget<T extends StatefulWidget> on State<T> {

  timeoutSetState({Duration? duration, Function? callback, Timer? timer}) {
    if (timer != null) {
      timer.cancel();
    }
    timer = Timer(duration ?? Duration(milliseconds: 0), () {
      if (mounted) {
        setState(() {
          if(callback != null) {
            callback();
          }
        });
      }
      timer = null;
    });
  }
}
