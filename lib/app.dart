import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/wasmapi/app.model.dart';
import 'src/wasmapi/broadcast.service.dart';
import 'src/stable_grid_image.dart';

class App extends StatefulWidget {
  final Map? properties;

  final String app = 'fbpmn';
  final String view = 'fbpmn';

  const App({super.key, this.properties});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Map<String, dynamic> _diagram = {};
  bool _isLoading = true;
  late Broadcast _broadcastManager;
  late EventApp? _appEvent;

  @override
  void initState() {
    super.initState();
    _loadXmlFile();
  }

  Future<void> _loadXmlFile() async {
    try {
      final diagram = await rootBundle.loadString('diagram_7.json');
      setState(() {
        _diagram = jsonDecode(diagram);
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки файла diagram1.json: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : StableGridImage(diagram: _diagram, appEvent: _appEvent),
      ),
    );
  }
}
