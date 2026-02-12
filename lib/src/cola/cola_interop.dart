/// Dart interop bindings for Cola WASM module
/// 
/// Usage:
/// ```dart
/// import 'cola_interop.dart';
/// 
/// void main() async {
///   await ColaInterop.init();
///   
///   final layout = ColaLayout(nodeCount: 10, idealEdgeLength: 100);
///   
///   // Set node positions and sizes
///   for (int i = 0; i < 10; i++) {
///     layout.setNode(i, x: i * 50.0, y: 0, width: 40, height: 30);
///   }
///   
///   // Add edges
///   layout.addEdge(0, 1);
///   layout.addEdge(1, 2);
///   
///   // Run layout
///   layout.run();
///   
///   // Get results
///   final positions = layout.getPositions();
///   
///   layout.dispose();
/// }
/// ```
library cola_interop;

import 'dart:js_interop';
import 'dart:typed_data';

// ============================================================================
// JavaScript Bindings
// ============================================================================

@JS('initCola')
external JSPromise _initCola();

@JS('isColaReady')
external bool _isColaReady();

@JS('ColaLayout')
extension type _JSColaLayout._(JSObject _) implements JSObject {
  external factory _JSColaLayout(int nodeCount, [double idealEdgeLength]);
  
  external void setNode(int nodeId, double x, double y, double width, double height);
  external void addEdge(int source, int target);
  external void addSeparationConstraint(int dim, int leftNode, int rightNode, double gap, [bool isEquality]);
  external void addAlignmentConstraint(int dim, JSArray<JSNumber> nodeIds);
  external void setAvoidOverlaps(bool enable);
  external void setConvergence([double tolerance, int maxIterations]);
  external void run();
  external bool tick();
  external void makeFeasible();
  external double getStress();
  external JSObject getNodePosition(int nodeId);
  external JSFloat64Array getAllPositions();
  external JSArray<JSObject> getPositions();
  external int get nodeCount;
  external void destroy();
}

@JS('removeOverlaps')
external JSArray<JSObject> _removeOverlaps(JSArray<JSObject> rects);

// ============================================================================
// Dart API
// ============================================================================

/// Position of a node
class NodePosition {
  final double x;
  final double y;
  
  const NodePosition(this.x, this.y);
  
  @override
  String toString() => 'NodePosition($x, $y)';
}

/// Rectangle definition
class Rectangle {
  final double x;
  final double y;
  final double width;
  final double height;
  
  const Rectangle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
  
  @override
  String toString() => 'Rectangle(x: $x, y: $y, w: $width, h: $height)';
}

/// Dimension for constraints
enum ConstraintDimension {
  horizontal(0),
  vertical(1);
  
  final int value;
  const ConstraintDimension(this.value);
}

/// Static class for Cola initialization
class ColaInterop {
  static bool _initialized = false;
  
  /// Initialize the Cola WASM module
  /// Must be called before creating any layouts
  static Future<void> init() async {
    if (_initialized) return;
    
    await _initCola().toDart;
    _initialized = true;
  }
  
  /// Check if Cola is ready
  static bool get isReady => _initialized && _isColaReady();
  
  /// Remove overlaps between rectangles
  static List<Rectangle> removeOverlaps(List<Rectangle> rectangles) {
    _checkInitialized();
    
    final jsRects = rectangles.map((r) {
      final obj = JSObject();
      (obj as dynamic).x = r.x.toJS;
      (obj as dynamic).y = r.y.toJS;
      (obj as dynamic).width = r.width.toJS;
      (obj as dynamic).height = r.height.toJS;
      return obj;
    }).toList().toJS;
    
    final result = _removeOverlaps(jsRects);
    
    return result.toDart.map((obj) {
      return Rectangle(
        x: ((obj as dynamic).x as JSNumber).toDartDouble,
        y: ((obj as dynamic).y as JSNumber).toDartDouble,
        width: ((obj as dynamic).width as JSNumber).toDartDouble,
        height: ((obj as dynamic).height as JSNumber).toDartDouble,
      );
    }).toList();
  }
  
  static void _checkInitialized() {
    if (!_initialized) {
      throw StateError('Cola not initialized. Call ColaInterop.init() first.');
    }
  }
}

/// Main layout class for constraint-based graph layout
class ColaLayout {
  final _JSColaLayout _js;
  bool _disposed = false;
  
  /// Create a new layout
  /// 
  /// [nodeCount] - Number of nodes in the graph
  /// [idealEdgeLength] - Default ideal edge length (default: 100)
  ColaLayout({
    required int nodeCount,
    double idealEdgeLength = 100,
  }) : _js = _JSColaLayout(nodeCount, idealEdgeLength) {
    ColaInterop._checkInitialized();
  }
  
  /// Number of nodes in the layout
  int get nodeCount => _js.nodeCount;
  
  /// Set the position and size of a node
  void setNode(int nodeId, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    _checkDisposed();
    _js.setNode(nodeId, x, y, width, height);
  }
  
  /// Set multiple nodes at once
  void setNodes(List<Rectangle> nodes) {
    _checkDisposed();
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      _js.setNode(i, n.centerX, n.centerY, n.width, n.height);
    }
  }
  
  /// Add an edge between two nodes
  void addEdge(int source, int target) {
    _checkDisposed();
    _js.addEdge(source, target);
  }
  
  /// Add multiple edges at once
  void addEdges(List<(int, int)> edges) {
    _checkDisposed();
    for (final (source, target) in edges) {
      _js.addEdge(source, target);
    }
  }
  
  /// Add a separation constraint
  /// 
  /// Creates constraint: leftNode + gap <= rightNode (or == if isEquality)
  void addSeparationConstraint({
    required ConstraintDimension dimension,
    required int leftNode,
    required int rightNode,
    required double gap,
    bool isEquality = false,
  }) {
    _checkDisposed();
    _js.addSeparationConstraint(dimension.value, leftNode, rightNode, gap, isEquality);
  }
  
  /// Add an alignment constraint
  /// 
  /// Aligns all specified nodes on a line in the given dimension
  void addAlignmentConstraint({
    required ConstraintDimension dimension,
    required List<int> nodeIds,
  }) {
    _checkDisposed();
    final jsArray = nodeIds.map((id) => id.toJS).toList().toJS;
    _js.addAlignmentConstraint(dimension.value, jsArray);
  }
  
  /// Enable/disable automatic overlap avoidance
  void setAvoidOverlaps(bool enable) {
    _checkDisposed();
    _js.setAvoidOverlaps(enable);
  }
  
  /// Set convergence parameters
  void setConvergence({
    double tolerance = 0.0001,
    int maxIterations = 100,
  }) {
    _checkDisposed();
    _js.setConvergence(tolerance, maxIterations);
  }
  
  /// Run the full layout algorithm until convergence
  void run() {
    _checkDisposed();
    _js.run();
  }
  
  /// Run a single iteration (for animation)
  /// Returns true if the layout has converged
  bool tick() {
    _checkDisposed();
    return _js.tick();
  }
  
  /// Make the current configuration feasible
  /// Satisfies constraints without applying forces
  void makeFeasible() {
    _checkDisposed();
    _js.makeFeasible();
  }
  
  /// Get current stress value (lower is better)
  double getStress() {
    _checkDisposed();
    return _js.getStress();
  }
  
  /// Get position of a single node
  NodePosition getNodePosition(int nodeId) {
    _checkDisposed();
    final pos = _js.getNodePosition(nodeId);
    return NodePosition(
      ((pos as dynamic).x as JSNumber).toDartDouble,
      ((pos as dynamic).y as JSNumber).toDartDouble,
    );
  }
  
  /// Get all node positions as a flat Float64List [x0, y0, x1, y1, ...]
  Float64List getAllPositionsFlat() {
    _checkDisposed();
    return _js.getAllPositions().toDart;
  }
  
  /// Get all node positions as a list of NodePosition objects
  List<NodePosition> getPositions() {
    _checkDisposed();
    final flat = getAllPositionsFlat();
    final result = <NodePosition>[];
    for (int i = 0; i < flat.length; i += 2) {
      result.add(NodePosition(flat[i], flat[i + 1]));
    }
    return result;
  }
  
  /// Dispose the layout and free resources
  void dispose() {
    if (_disposed) return;
    _js.destroy();
    _disposed = true;
  }
  
  void _checkDisposed() {
    if (_disposed) {
      throw StateError('Layout has been disposed');
    }
  }
}

/// Animated layout runner
/// 
/// Runs the layout algorithm with animation, calling a callback after each iteration
class AnimatedLayout {
  final ColaLayout layout;
  final void Function(List<NodePosition> positions) onTick;
  final void Function()? onComplete;
  
  bool _running = false;
  bool _cancelled = false;
  
  AnimatedLayout({
    required this.layout,
    required this.onTick,
    this.onComplete,
  });
  
  /// Start the animation
  void start() {
    if (_running) return;
    _running = true;
    _cancelled = false;
    _tick();
  }
  
  /// Stop the animation
  void stop() {
    _cancelled = true;
    _running = false;
  }
  
  void _tick() {
    if (_cancelled) return;
    
    final converged = layout.tick();
    onTick(layout.getPositions());
    
    if (converged) {
      _running = false;
      onComplete?.call();
    } else {
      // Schedule next tick using requestAnimationFrame equivalent
      Future.delayed(Duration(milliseconds: 16), _tick);
    }
  }
}
