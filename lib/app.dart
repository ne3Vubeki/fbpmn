import 'package:flutter/material.dart';

import 'example_editor/editor.dart';
import 'models/app.model.dart';
import 'services/broadcast.service.dart';

class App extends StatefulWidget {
  final String app = 'child';
  final String view = 'example';

  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late Broadcast _bcs;
  late EventApp _appEventCtrl;
  
  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _bcs = Broadcast(app: widget.app, source: widget.view);
    _appEventCtrl = _bcs.register();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zoomable Canvas with Stable Grid',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const Scaffold(body: StableGridCanvas()),
    );
  }
}

