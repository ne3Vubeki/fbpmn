import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import '../services/performance_tracker.dart';

class PerformanceMetrics extends StatefulWidget {
  final double panelWidth;

  const PerformanceMetrics({
    super.key,
    required this.panelWidth,
  });

  @override
  State<PerformanceMetrics> createState() => _PerformanceMetricsState();
}

class _PerformanceMetricsState extends State<PerformanceMetrics>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final PerformanceTracker _tracker = PerformanceTracker();
  
  // FPS metrics
  int _frameCount = 0;
  double _fps = 0;
  double _fpsMin = double.infinity;
  double _fpsMax = 0;
  Duration _lastFpsUpdate = Duration.zero;
  
  // Frame time metrics
  Duration _lastFrameTime = Duration.zero;
  double _frameTimeMs = 0;
  double _frameTimeMin = double.infinity;
  double _frameTimeMax = 0;
  
  // Render time (approximation based on frame callback)
  double _renderTimeMs = 0;
  double _renderTimeMin = double.infinity;
  double _renderTimeMax = 0;
  
  // JS Heap memory
  double _jsHeapSizeMB = 0;
  double _jsHeapLimitMB = 0;
  
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
    _updateMemory();
  }

  void _onTick(Duration elapsed) {
    final now = elapsed;
    
    // Calculate frame time
    if (_lastFrameTime != Duration.zero) {
      final frameDuration = now - _lastFrameTime;
      _frameTimeMs = frameDuration.inMicroseconds / 1000.0;
      
      if (_frameTimeMs < _frameTimeMin && _frameTimeMs > 0) {
        _frameTimeMin = _frameTimeMs;
      }
      if (_frameTimeMs > _frameTimeMax) {
        _frameTimeMax = _frameTimeMs;
      }
      
      _renderTimeMs = _frameTimeMs * 0.7; // Approximation: ~70% is render time
      
      if (_renderTimeMs < _renderTimeMin && _renderTimeMs > 0) {
        _renderTimeMin = _renderTimeMs;
      }
      if (_renderTimeMs > _renderTimeMax) {
        _renderTimeMax = _renderTimeMs;
      }
    }
    _lastFrameTime = now;
    
    // Count frames for FPS calculation
    _frameCount++;
    
    // Update FPS every second
    if (_lastFpsUpdate == Duration.zero) {
      _lastFpsUpdate = now;
    } else if (now - _lastFpsUpdate >= const Duration(seconds: 1)) {
      _fps = _frameCount / ((now - _lastFpsUpdate).inMilliseconds / 1000.0);
      
      if (_fps < _fpsMin && _fps > 0) {
        _fpsMin = _fps;
      }
      if (_fps > _fpsMax) {
        _fpsMax = _fps;
      }
      
      _frameCount = 0;
      _lastFpsUpdate = now;
      _updateMemory();
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  void _updateMemory() {
    try {
      // Access performance.memory via JS interop
      final performance = globalContext['performance'];
      if (performance != null) {
        final memory = (performance as JSObject)['memory'];
        if (memory != null) {
          final memoryObj = memory as JSObject;
          final usedHeap = memoryObj['usedJSHeapSize'];
          final totalHeap = memoryObj['jsHeapSizeLimit'];
          
          if (usedHeap != null) {
            _jsHeapSizeMB = (usedHeap as JSNumber).toDartDouble / (1024 * 1024);
          }
          if (totalHeap != null) {
            _jsHeapLimitMB = (totalHeap as JSNumber).toDartDouble / (1024 * 1024);
          }
        }
      }
    } catch (e) {
      // Memory API not available (not Chrome or not enabled)
    }
  }

  void _resetMinMax() {
    setState(() {
      _fpsMin = double.infinity;
      _fpsMax = 0;
      _frameTimeMin = double.infinity;
      _frameTimeMax = 0;
      _renderTimeMin = double.infinity;
      _renderTimeMax = 0;
      _tracker.resetMinMax();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Color _getFpsColor(double fps) {
    if (fps >= 55) return Colors.green;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }

  Color _getFrameTimeColor(double ms) {
    if (ms <= 16.67) return Colors.green; // 60 FPS target
    if (ms <= 33.33) return Colors.orange; // 30 FPS
    return Colors.red;
  }

  String _formatMinMax(double min, double max) {
    final minStr = min == double.infinity ? '-' : min.toStringAsFixed(1);
    final maxStr = max == 0 ? '-' : max.toStringAsFixed(1);
    return '$minStr/$maxStr';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.panelWidth,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with reset button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.speed, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Performance',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _resetMinMax,
                child: Icon(Icons.refresh, size: 14, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          
          // FPS row with min/max
          _MetricRowWithMinMax(
            label: 'FPS',
            value: _fps.toStringAsFixed(1),
            minMax: _formatMinMax(_fpsMin, _fpsMax),
            color: _getFpsColor(_fps),
          ),
          const SizedBox(height: 3),
          
          // Frame time row with min/max
          _MetricRowWithMinMax(
            label: 'Frame',
            value: '${_frameTimeMs.toStringAsFixed(1)}ms',
            minMax: _formatMinMax(_frameTimeMin, _frameTimeMax),
            color: _getFrameTimeColor(_frameTimeMs),
          ),
          const SizedBox(height: 3),
          
          // Render time row with min/max
          _MetricRowWithMinMax(
            label: 'Render',
            value: '${_renderTimeMs.toStringAsFixed(1)}ms',
            minMax: _formatMinMax(_renderTimeMin, _renderTimeMax),
            color: _getFrameTimeColor(_renderTimeMs),
          ),
          
          // Divider for click-to-action metrics
          // TODO: УДАЛИТЬ после отладки производительности
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: Colors.grey[700]),
          ),
          
          // Select time (click to node selection)
          // TODO: УДАЛИТЬ после отладки производительности
          _MetricRowWithMinMax(
            label: 'Select',
            value: '${_tracker.selectTimeMs.toStringAsFixed(1)}ms',
            minMax: _formatMinMax(_tracker.selectTimeMin, _tracker.selectTimeMax),
            color: _getFrameTimeColor(_tracker.selectTimeMs / 10),
          ),
          const SizedBox(height: 3),
          
          // Deselect time (click to save to tiles)
          // TODO: УДАЛИТЬ после отладки производительности
          _MetricRowWithMinMax(
            label: 'Deselect',
            value: '${_tracker.deselectTimeMs.toStringAsFixed(1)}ms',
            minMax: _formatMinMax(_tracker.deselectTimeMin, _tracker.deselectTimeMax),
            color: _getFrameTimeColor(_tracker.deselectTimeMs / 10),
          ),
          const SizedBox(height: 3),
          
          // Arrow style change time
          // TODO: УДАЛИТЬ после отладки производительности
          _MetricRowWithMinMax(
            label: 'ArrowStyle',
            value: '${_tracker.arrowStyleChangeTimeMs.toStringAsFixed(1)}ms',
            minMax: _formatMinMax(_tracker.arrowStyleChangeTimeMin, _tracker.arrowStyleChangeTimeMax),
            color: _getFrameTimeColor(_tracker.arrowStyleChangeTimeMs / 10),
          ),
          const SizedBox(height: 3),
          
          // Swimlane toggle time
          // TODO: УДАЛИТЬ после отладки производительности
          _MetricRowWithMinMax(
            label: 'Swimlane',
            value: '${_tracker.swimlaneToggleTimeMs.toStringAsFixed(1)}ms',
            minMax: _formatMinMax(_tracker.swimlaneToggleTimeMin, _tracker.swimlaneToggleTimeMax),
            color: _getFrameTimeColor(_tracker.swimlaneToggleTimeMs / 10),
          ),
          
          // Memory section
          if (_jsHeapSizeMB > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, color: Colors.grey[700]),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'JS Heap',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
                Text(
                  '${_jsHeapSizeMB.toStringAsFixed(0)}MB / ${_jsHeapLimitMB.toStringAsFixed(0)}MB',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _jsHeapSizeMB / _jsHeapLimitMB > 0.8 ? Colors.red : Colors.cyan,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (_jsHeapSizeMB / _jsHeapLimitMB).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _jsHeapSizeMB / _jsHeapLimitMB > 0.8 ? Colors.red : Colors.cyan,
                ),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricRowWithMinMax extends StatelessWidget {
  final String label;
  final String value;
  final String minMax;
  final Color color;

  const _MetricRowWithMinMax({
    required this.label,
    required this.value,
    required this.minMax,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 65,
              child: Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        Text(
          minMax,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
