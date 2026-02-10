/// Глобальный трекер производительности для замера времени операций
class PerformanceTracker {
  static final PerformanceTracker _instance = PerformanceTracker._internal();
  factory PerformanceTracker() => _instance;
  PerformanceTracker._internal();

  // Время рисования тайлов (узлы + связи)
  double _tileRenderTimeMs = 0;
  double _tileRenderTimeMin = double.infinity;
  double _tileRenderTimeMax = 0;
  int _tileRenderCount = 0;

  // Время рисования выделенного узла
  double _selectedNodeRenderTimeMs = 0;
  double _selectedNodeRenderTimeMin = double.infinity;
  double _selectedNodeRenderTimeMax = 0;

  // Время рисования выделенных связей
  double _selectedArrowsRenderTimeMs = 0;
  double _selectedArrowsRenderTimeMin = double.infinity;
  double _selectedArrowsRenderTimeMax = 0;

  // Время от клика до снятия выделения (сохранение в тайлы)
  double _deselectTimeMs = 0;
  double _deselectTimeMin = double.infinity;
  double _deselectTimeMax = 0;

  // Время от клика до появления выделенного узла
  double _selectTimeMs = 0;
  double _selectTimeMin = double.infinity;
  double _selectTimeMax = 0;

  // Stopwatch для замеров
  final Stopwatch _stopwatch = Stopwatch();
  final Stopwatch _deselectStopwatch = Stopwatch();
  final Stopwatch _selectStopwatch = Stopwatch();

  // Геттеры для метрик тайлов
  double get tileRenderTimeMs => _tileRenderTimeMs;
  double get tileRenderTimeMin => _tileRenderTimeMin == double.infinity ? 0 : _tileRenderTimeMin;
  double get tileRenderTimeMax => _tileRenderTimeMax;
  int get tileRenderCount => _tileRenderCount;

  // Геттеры для метрик выделенного узла
  double get selectedNodeRenderTimeMs => _selectedNodeRenderTimeMs;
  double get selectedNodeRenderTimeMin => _selectedNodeRenderTimeMin == double.infinity ? 0 : _selectedNodeRenderTimeMin;
  double get selectedNodeRenderTimeMax => _selectedNodeRenderTimeMax;

  // Геттеры для метрик выделенных связей
  double get selectedArrowsRenderTimeMs => _selectedArrowsRenderTimeMs;
  double get selectedArrowsRenderTimeMin => _selectedArrowsRenderTimeMin == double.infinity ? 0 : _selectedArrowsRenderTimeMin;
  double get selectedArrowsRenderTimeMax => _selectedArrowsRenderTimeMax;

  // Геттеры для метрик снятия выделения (сохранение в тайлы)
  double get deselectTimeMs => _deselectTimeMs;
  double get deselectTimeMin => _deselectTimeMin == double.infinity ? 0 : _deselectTimeMin;
  double get deselectTimeMax => _deselectTimeMax;

  // Геттеры для метрик выделения узла
  double get selectTimeMs => _selectTimeMs;
  double get selectTimeMin => _selectTimeMin == double.infinity ? 0 : _selectTimeMin;
  double get selectTimeMax => _selectTimeMax;

  /// Начать замер времени снятия выделения (от клика до сохранения в тайлы)
  void startDeselect() {
    _deselectStopwatch.reset();
    _deselectStopwatch.start();
  }

  /// Завершить замер времени снятия выделения
  void endDeselect() {
    _deselectStopwatch.stop();
    _deselectTimeMs = _deselectStopwatch.elapsedMicroseconds / 1000.0;
    
    if (_deselectTimeMs < _deselectTimeMin) {
      _deselectTimeMin = _deselectTimeMs;
    }
    if (_deselectTimeMs > _deselectTimeMax) {
      _deselectTimeMax = _deselectTimeMs;
    }
  }

  /// Начать замер времени выделения узла (от клика до появления)
  void startSelect() {
    _selectStopwatch.reset();
    _selectStopwatch.start();
  }

  /// Завершить замер времени выделения узла
  void endSelect() {
    _selectStopwatch.stop();
    _selectTimeMs = _selectStopwatch.elapsedMicroseconds / 1000.0;
    
    if (_selectTimeMs < _selectTimeMin) {
      _selectTimeMin = _selectTimeMs;
    }
    if (_selectTimeMs > _selectTimeMax) {
      _selectTimeMax = _selectTimeMs;
    }
  }

  /// Начать замер времени рендеринга тайла
  void startTileRender() {
    _stopwatch.reset();
    _stopwatch.start();
  }

  /// Завершить замер времени рендеринга тайла
  void endTileRender() {
    _stopwatch.stop();
    _tileRenderTimeMs = _stopwatch.elapsedMicroseconds / 1000.0;
    _tileRenderCount++;
    
    if (_tileRenderTimeMs < _tileRenderTimeMin) {
      _tileRenderTimeMin = _tileRenderTimeMs;
    }
    if (_tileRenderTimeMs > _tileRenderTimeMax) {
      _tileRenderTimeMax = _tileRenderTimeMs;
    }
  }

  /// Записать время рендеринга выделенного узла
  void recordSelectedNodeRender(double timeMs) {
    _selectedNodeRenderTimeMs = timeMs;
    
    if (timeMs < _selectedNodeRenderTimeMin) {
      _selectedNodeRenderTimeMin = timeMs;
    }
    if (timeMs > _selectedNodeRenderTimeMax) {
      _selectedNodeRenderTimeMax = timeMs;
    }
  }

  /// Записать время рендеринга выделенных связей
  void recordSelectedArrowsRender(double timeMs) {
    _selectedArrowsRenderTimeMs = timeMs;
    
    if (timeMs < _selectedArrowsRenderTimeMin) {
      _selectedArrowsRenderTimeMin = timeMs;
    }
    if (timeMs > _selectedArrowsRenderTimeMax) {
      _selectedArrowsRenderTimeMax = timeMs;
    }
  }

  /// Сбросить min/max значения (вызывается периодически)
  void resetMinMax() {
    _tileRenderTimeMin = double.infinity;
    _tileRenderTimeMax = 0;
    _tileRenderCount = 0;
    _selectedNodeRenderTimeMin = double.infinity;
    _selectedNodeRenderTimeMax = 0;
    _selectedArrowsRenderTimeMin = double.infinity;
    _selectedArrowsRenderTimeMax = 0;
    _deselectTimeMin = double.infinity;
    _deselectTimeMax = 0;
    _selectTimeMin = double.infinity;
    _selectTimeMax = 0;
  }
}
