// =============================================================================
// TODO: УДАЛИТЬ ЭТОТ ФАЙЛ после завершения отладки производительности
// Этот класс используется для временного замера производительности операций.
// После анализа и оптимизации производительности этот функционал должен быть удален.
// 
// Файлы, которые нужно будет очистить от использования PerformanceTracker:
// - lib/src/services/node_manager.dart (startSelect, endSelect, startDeselect, endDeselect)
// - lib/src/services/tile_manager.dart (startArrowStyleChange, endArrowStyleChange)
// - lib/src/widgets/performance_metrics.dart (весь виджет)
// - lib/src/widgets/zoom_container.dart (отображение PerformanceMetrics)
// - lib/src/widgets/zoom_panel.dart (кнопка переключения метрик)
// - lib/src/utils/canvas_icons.dart (иконка paintPerformance)
// =============================================================================

/// Глобальный трекер производительности для замера времени операций
/// TODO: УДАЛИТЬ после завершения отладки производительности
class PerformanceTracker {
  static final PerformanceTracker _instance = PerformanceTracker._internal();
  factory PerformanceTracker() => _instance;
  PerformanceTracker._internal();

  // ---------------------------------------------------------------------------
  // Время от клика до снятия выделения (сохранение узла в тайлы)
  // Замеряется в node_manager.dart: _saveNodeToTiles()
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------
  double _deselectTimeMs = 0;
  double _deselectTimeMin = double.infinity;
  double _deselectTimeMax = 0;

  // ---------------------------------------------------------------------------
  // Время от клика до появления выделенного узла с рамкой
  // Замеряется в node_manager.dart: _selectNode(), _selectNodeImmediate()
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------
  double _selectTimeMs = 0;
  double _selectTimeMin = double.infinity;
  double _selectTimeMax = 0;

  // ---------------------------------------------------------------------------
  // Время изменения стиля связей при переключении в зумпанели
  // Замеряется в zoom_container.dart или arrow_manager.dart
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------
  double _arrowStyleChangeTimeMs = 0;
  double _arrowStyleChangeTimeMin = double.infinity;
  double _arrowStyleChangeTimeMax = 0;

  // ---------------------------------------------------------------------------
  // Время открытия/закрытия swimlane (рисование узлов)
  // Замеряется в node_manager.dart: _toggleSwimlaneCollapsed()
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------
  double _swimlaneToggleTimeMs = 0;
  double _swimlaneToggleTimeMin = double.infinity;
  double _swimlaneToggleTimeMax = 0;

  // Stopwatch для замеров
  // TODO: УДАЛИТЬ после отладки
  final Stopwatch _deselectStopwatch = Stopwatch();
  final Stopwatch _selectStopwatch = Stopwatch();
  final Stopwatch _arrowStyleStopwatch = Stopwatch();
  final Stopwatch _swimlaneStopwatch = Stopwatch();

  // ---------------------------------------------------------------------------
  // Геттеры для метрик снятия выделения
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------
  double get deselectTimeMs => _deselectTimeMs;
  double get deselectTimeMin => _deselectTimeMin == double.infinity ? 0 : _deselectTimeMin;
  double get deselectTimeMax => _deselectTimeMax;

  // ---------------------------------------------------------------------------
  // Геттеры для метрик выделения узла
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------
  double get selectTimeMs => _selectTimeMs;
  double get selectTimeMin => _selectTimeMin == double.infinity ? 0 : _selectTimeMin;
  double get selectTimeMax => _selectTimeMax;

  // ---------------------------------------------------------------------------
  // Геттеры для метрик изменения стиля связей
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------
  double get arrowStyleChangeTimeMs => _arrowStyleChangeTimeMs;
  double get arrowStyleChangeTimeMin => _arrowStyleChangeTimeMin == double.infinity ? 0 : _arrowStyleChangeTimeMin;
  double get arrowStyleChangeTimeMax => _arrowStyleChangeTimeMax;

  // ---------------------------------------------------------------------------
  // Геттеры для метрик открытия/закрытия swimlane
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------
  double get swimlaneToggleTimeMs => _swimlaneToggleTimeMs;
  double get swimlaneToggleTimeMin => _swimlaneToggleTimeMin == double.infinity ? 0 : _swimlaneToggleTimeMin;
  double get swimlaneToggleTimeMax => _swimlaneToggleTimeMax;

  // ---------------------------------------------------------------------------
  // Методы замера времени снятия выделения
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------
  
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

  // ---------------------------------------------------------------------------
  // Методы замера времени выделения узла
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Методы замера времени изменения стиля связей
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------

  /// Начать замер времени изменения стиля связей
  void startArrowStyleChange() {
    _arrowStyleStopwatch.reset();
    _arrowStyleStopwatch.start();
  }

  /// Завершить замер времени изменения стиля связей
  void endArrowStyleChange() {
    _arrowStyleStopwatch.stop();
    _arrowStyleChangeTimeMs = _arrowStyleStopwatch.elapsedMicroseconds / 1000.0;
    
    if (_arrowStyleChangeTimeMs < _arrowStyleChangeTimeMin) {
      _arrowStyleChangeTimeMin = _arrowStyleChangeTimeMs;
    }
    if (_arrowStyleChangeTimeMs > _arrowStyleChangeTimeMax) {
      _arrowStyleChangeTimeMax = _arrowStyleChangeTimeMs;
    }
  }

  // ---------------------------------------------------------------------------
  // Методы замера времени открытия/закрытия swimlane
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------

  /// Начать замер времени открытия/закрытия swimlane
  void startSwimlaneToggle() {
    _swimlaneStopwatch.reset();
    _swimlaneStopwatch.start();
  }

  /// Завершить замер времени открытия/закрытия swimlane
  void endSwimlaneToggle() {
    _swimlaneStopwatch.stop();
    _swimlaneToggleTimeMs = _swimlaneStopwatch.elapsedMicroseconds / 1000.0;
    
    if (_swimlaneToggleTimeMs < _swimlaneToggleTimeMin) {
      _swimlaneToggleTimeMin = _swimlaneToggleTimeMs;
    }
    if (_swimlaneToggleTimeMs > _swimlaneToggleTimeMax) {
      _swimlaneToggleTimeMax = _swimlaneToggleTimeMs;
    }
  }

  // ---------------------------------------------------------------------------
  // Сброс min/max значений
  // TODO: УДАЛИТЬ после отладки
  // ---------------------------------------------------------------------------

  /// Сбросить min/max значения (вызывается по кнопке в UI)
  void resetMinMax() {
    _deselectTimeMin = double.infinity;
    _deselectTimeMax = 0;
    _selectTimeMin = double.infinity;
    _selectTimeMax = 0;
    _arrowStyleChangeTimeMin = double.infinity;
    _arrowStyleChangeTimeMax = 0;
    _swimlaneToggleTimeMin = double.infinity;
    _swimlaneToggleTimeMax = 0;
  }
}
