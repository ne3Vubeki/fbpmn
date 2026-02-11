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
        final FlutterView view = View.of(context);
        final int viewId = view.viewId;
        // final Map?  properties = views.getInitialData(viewId).dartify() as Map? ?? {'view': 'fbpmn'};
        final Map?  properties = {'view': 'fbpmn'};
        return _views[properties?['view']]!;
      },
    ),
  );
}

const Map<String, Widget> _views = {
  'fbpmn': App(),
};