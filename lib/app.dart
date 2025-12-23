import 'dart:convert';

import 'package:fbpmn/src/editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/stable_grid_image.dart';


class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  Map _diagram = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadXmlFile();
  }

  Future<void> _loadXmlFile() async {
    try {
      final diagram = await rootBundle.loadString('1.json');
      setState(() {
        _diagram = jsonDecode(diagram);
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки файла 1.json: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zoomable Canvas with Stable Grid',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            // : StableGridCanvas(diagram: _diagram),
            : StableGridImage(diagram: _diagram),
      ),
    );
  }
}