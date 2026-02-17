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
  external int addAlignmentConstraint(int dim, JSArray<JSNumber> nodeIds);
  external void addDistributionConstraint(int dim, JSArray<JSNumber> alignmentIds, [double separation]);
  external void addPageBoundary(double xMin, double xMax, double yMin, double yMax, [double weight]);
  external int addBoundaryConstraint(int dim, JSArray<JSNumber> nodeIds, JSArray<JSNumber> offsets);
  external void addFixedRelativeConstraint(JSArray<JSNumber> nodeIds, [bool fixedPosition]);
  external void addOrthogonalEdgeConstraint(int dim, int leftNode, int rightNode);
  external void applyFlowLayout(JSArray<JSNumber> nodeIds, [int flowDirection, double separation, bool orthogonal]);
  external int createCluster(JSArray<JSNumber> nodeIds, [double padding, double margin]);
  external void addChildCluster(int parentId, int childId);
  external void setClusterBounds(int clusterId, double xMin, double xMax, double yMin, double yMax);
  external void setDesiredPosition(int nodeId, double x, double y, [double weight]);
  external void clearDesiredPositions();
  external void setAvoidOverlaps(bool enable);
  external void setConvergence([double tolerance, int maxIterations]);
  external void setNeighbourStress(bool enable);
  external void lockNode(int nodeId, double x, double y);
  external void unlockNode(int nodeId);
  external void clearLocks();
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

  const Rectangle({required this.x, required this.y, required this.width, required this.height});

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

    final jsRects = rectangles
        .map((r) {
          final obj = JSObject();
          (obj as dynamic).x = r.x.toJS;
          (obj as dynamic).y = r.y.toJS;
          (obj as dynamic).width = r.width.toJS;
          (obj as dynamic).height = r.height.toJS;
          return obj;
        })
        .toList()
        .toJS;

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
  ColaLayout({required int nodeCount, double idealEdgeLength = 100}) : _js = _JSColaLayout(nodeCount, idealEdgeLength) {
    ColaInterop._checkInitialized();
  }

  /// Number of nodes in the layout
  int get nodeCount => _js.nodeCount;

  /// Set the position and size of a node
  void setNode(int nodeId, {required double x, required double y, required double width, required double height}) {
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
  /// Returns alignment ID for use with distribution constraints
  int addAlignmentConstraint({required ConstraintDimension dimension, required List<int> nodeIds}) {
    _checkDisposed();
    final jsArray = nodeIds.map((id) => id.toJS).toList().toJS;
    return _js.addAlignmentConstraint(dimension.value, jsArray);
  }

  /// Add a distribution constraint (evenly distribute aligned nodes)
  ///
  /// [alignmentIds] - IDs returned from addAlignmentConstraint
  /// [separation] - Fixed separation (0 = auto-calculate)
  void addDistributionConstraint({
    required ConstraintDimension dimension,
    required List<int> alignmentIds,
    double separation = 0,
  }) {
    _checkDisposed();
    final jsArray = alignmentIds.map((id) => id.toJS).toList().toJS;
    _js.addDistributionConstraint(dimension.value, jsArray, separation);
  }

  /// Add page boundary constraint (keep nodes within rectangle)
  void addPageBoundary({
    required double xMin,
    required double xMax,
    required double yMin,
    required double yMax,
    double weight = 100,
  }) {
    _checkDisposed();
    _js.addPageBoundary(xMin, xMax, yMin, yMax, weight);
  }

  /// Add boundary constraint (nodes on one side of a line)
  /// Returns boundary ID
  int addBoundaryConstraint({
    required ConstraintDimension dimension,
    required List<int> nodeIds,
    required List<double> offsets,
  }) {
    _checkDisposed();
    final nodeJsArray = nodeIds.map((id) => id.toJS).toList().toJS;
    final offsetJsArray = offsets.map((o) => o.toJS).toList().toJS;
    return _js.addBoundaryConstraint(dimension.value, nodeJsArray, offsetJsArray);
  }

  /// Add fixed-relative constraint (nodes maintain relative positions)
  void addFixedRelativeConstraint({required List<int> nodeIds, bool fixedPosition = false}) {
    _checkDisposed();
    final jsArray = nodeIds.map((id) => id.toJS).toList().toJS;
    _js.addFixedRelativeConstraint(jsArray, fixedPosition);
  }

  /// Add orthogonal edge constraint (edge endpoints aligned horizontally or vertically)
  ///
  /// This ensures that the edge between two nodes is either horizontal or vertical.
  /// Use this for orthogonal/rectilinear edge routing where edges should only
  /// have horizontal or vertical segments.
  ///
  /// [dimension] - The alignment dimension:
  ///   - `horizontal`: nodes will have the same Y coordinate (horizontal edge)
  ///   - `vertical`: nodes will have the same X coordinate (vertical edge)
  /// [leftNode] - Source/left node index
  /// [rightNode] - Target/right node index
  void addOrthogonalEdgeConstraint({
    required ConstraintDimension dimension,
    required int leftNode,
    required int rightNode,
  }) {
    _checkDisposed();
    _js.addOrthogonalEdgeConstraint(dimension.value, leftNode, rightNode);
  }

  /// Apply flow layout constraints to a sequence of nodes
  ///
  /// Creates separation constraints (left-to-right or top-to-bottom flow)
  /// and alignment constraints (nodes on same axis). This is a convenience
  /// method for creating BPMN-style or flowchart layouts.
  ///
  /// [nodeIds] - Node indices in flow order (e.g., [start, task1, task2, end])
  /// [flowDirection] - Direction of the flow:
  ///   - `horizontal`: left-to-right flow (default)
  ///   - `vertical`: top-to-bottom flow
  /// [separation] - Minimum separation between consecutive nodes (default: 100)
  /// [orthogonal] - If true, also add orthogonal edge constraints (default: true)
  void applyFlowLayout({
    required List<int> nodeIds,
    ConstraintDimension flowDirection = ConstraintDimension.horizontal,
    double separation = 100,
    bool orthogonal = true,
  }) {
    _checkDisposed();
    final jsArray = nodeIds.map((id) => id.toJS).toList().toJS;
    _js.applyFlowLayout(jsArray, flowDirection.value, separation, orthogonal);
  }

  /// Create a rectangular cluster
  ///
  /// Returns cluster ID (1-based, 0 = root)
  int createCluster({required List<int> nodeIds, double padding = 10, double margin = 10}) {
    _checkDisposed();
    final jsArray = nodeIds.map((id) => id.toJS).toList().toJS;
    return _js.createCluster(jsArray, padding, margin);
  }

  /// Add a cluster as child of another cluster
  ///
  /// [parentId] - Parent cluster ID (0 = root)
  /// [childId] - Child cluster ID
  void addChildCluster(int parentId, int childId) {
    _checkDisposed();
    _js.addChildCluster(parentId, childId);
  }

  /// Set desired bounds for a cluster
  void setClusterBounds({
    required int clusterId,
    required double xMin,
    required double xMax,
    required double yMin,
    required double yMax,
  }) {
    _checkDisposed();
    _js.setClusterBounds(clusterId, xMin, xMax, yMin, yMax);
  }

  /// Set desired position for a node (attraction point)
  void setDesiredPosition({required int nodeId, required double x, required double y, double weight = 1}) {
    _checkDisposed();
    _js.setDesiredPosition(nodeId, x, y, weight);
  }

  /// Clear all desired positions
  void clearDesiredPositions() {
    _checkDisposed();
    _js.clearDesiredPositions();
  }

  /// Enable/disable automatic overlap avoidance
  void setAvoidOverlaps(bool enable) {
    _checkDisposed();
    _js.setAvoidOverlaps(enable);
  }

  /// Set convergence parameters
  void setConvergence({double tolerance = 0.0001, int maxIterations = 100}) {
    _checkDisposed();
    _js.setConvergence(tolerance, maxIterations);
  }

  /// Enable/disable neighbour stress mode (better for large graphs)
  void setNeighbourStress(bool enable) {
    _checkDisposed();
    _js.setNeighbourStress(enable);
  }

  /// Lock a node at a specific position
  void lockNode(int nodeId, {required double x, required double y}) {
    _checkDisposed();
    _js.lockNode(nodeId, x, y);
  }

  /// Unlock a previously locked node
  void unlockNode(int nodeId) {
    _checkDisposed();
    _js.unlockNode(nodeId);
  }

  /// Clear all node locks
  void clearLocks() {
    _checkDisposed();
    _js.clearLocks();
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
    return NodePosition(((pos as dynamic).x as JSNumber).toDartDouble, ((pos as dynamic).y as JSNumber).toDartDouble);
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
/// Runs the layout algorithm with animation, calling a callback after each iteration.
/// Uses Cola's native convergence detection (tick() returns true when converged).
class AnimatedLayout {
  final ColaLayout layout;
  final void Function(List<NodePosition> positions) onTick;
  final void Function()? onComplete;
  final int minIterations;
  final int maxIterations;

  bool _running = false;
  bool _cancelled = false;
  int _iterationCount = 0;

  AnimatedLayout({
    required this.layout,
    required this.onTick,
    this.onComplete,
    this.minIterations = 10,
    this.maxIterations = 200,
  });

  /// Start the animation
  void start() {
    if (_running) return;
    _running = true;
    _cancelled = false;
    _iterationCount = 0;
    _tick();
  }

  /// Stop the animation
  void stop() {
    _cancelled = true;
    _running = false;
  }

  void _tick() {
    if (_cancelled) return;

    _iterationCount++;
    
    // tick() возвращает true когда Cola сошлась (нативная сходимость)
    final converged = layout.tick();
    onTick(layout.getPositions());

    // Завершаем только если:
    // 1. Достигнуто минимальное количество итераций И Cola сошлась
    // 2. ИЛИ достигнуто максимальное количество итераций
    final shouldStop = (_iterationCount >= minIterations && converged) || 
                       _iterationCount >= maxIterations;

    if (shouldStop) {
      _running = false;
      onComplete?.call();
    } else {
      // Schedule next tick using requestAnimationFrame equivalent
      Future.delayed(Duration(milliseconds: 16), _tick);
    }
  }
}
