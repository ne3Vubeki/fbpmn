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
        final Map properties = views.getInitialData(viewId).dartify() as Map;
        if (properties['view'] == null) {
          properties['view'] = 'fbpmn';
        }
        print('Start App with properties: $properties');
        return _buildView(properties['view'] as String, properties);
      },
    ),
  );
}

Widget _buildView(String viewName, Map prop) {
  switch (viewName) {
    case 'fbpmn':
      final properties = prop.map((k, v) => MapEntry(k.toString(), v));
      return App(properties: properties);
    default:
      throw ArgumentError('Unknown view: $viewName');
  }
}
