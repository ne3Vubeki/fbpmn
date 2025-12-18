import 'dart:js_interop';
import 'dart:ui';
import 'dart:ui_web';
import 'package:flutter/material.dart';

import 'package:fbpmn/app.dart';
import 'multi_view_app.dart';

void main() {
  runWidget(
    MultiViewApp(
      viewBuilder: (BuildContext context) {
        // final FlutterView view = View.of(context);
        // final int viewId = view.viewId;
        // final Map  properties= views.getInitialData(viewId).dartify() as Map;
        // return _views[initialData['view']]!;
        return App();
      },
    ),
  );
}

const Map<String, Widget> _views = {
  'bpmn_editor': App(),
};