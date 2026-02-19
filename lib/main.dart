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
        final Map<String, dynamic> properties =
            views.getInitialData(viewId).dartify() as Map<String, dynamic>? ?? {'view': 'fbpmn'};
        return _buildView(properties['view'] as String, properties);
      },
    ),
  );
}

Widget _buildView(String viewName, Map<String, dynamic> properties) {
  switch (viewName) {
    case 'fbpmn':
      return App(properties: properties);
    default:
      throw ArgumentError('Unknown view: $viewName');
  }
}
