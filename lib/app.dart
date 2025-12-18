import 'package:fbpmn/src/editor.dart';
import 'package:flutter/material.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  
  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
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

