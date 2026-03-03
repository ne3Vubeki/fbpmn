import 'package:flutter/material.dart';

import 'src/models/app.model.dart';
import 'src/services/broadcast.service.dart';
import 'src/stable_grid_image.dart';

class App extends StatefulWidget {
  final Map<String, dynamic> properties;

  final String app = 'fbpmn';
  final String view = 'fbpmn';

  const App({super.key, required this.properties});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late Broadcast _broadcastManager;
  late EventApp? _appEvent;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _broadcastManager = Broadcast(app: widget.app, source: widget.view);
    _appEvent = _broadcastManager.register();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WASM редактор BPMN',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        body: StableGridImage(properties: widget.properties, appEvent: _appEvent),
      ),
    );
  }
}
