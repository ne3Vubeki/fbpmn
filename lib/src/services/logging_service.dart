import 'dart:developer' as developer;
import 'dart:async';

/// Уровни логирования
enum LogLevel {
  debug,
  info,
  warning,
  error,
  performance,
}

/// Структурированная система логирования для приложения
class AppLogger {
  static bool _enableDebug = true;
  static bool _enablePerformanceLogging = true;
  static bool _enableInfoLogging = true;
  static bool _enableWarningLogging = true;
  static bool _enableErrorLogging = true;
  
  static final Map<String, List<Map<String, dynamic>>> _logBuffer = {};
  static final StreamController<Map<String, dynamic>> _logStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  /// Поток для подписки на логи в реальном времени
  static Stream<Map<String, dynamic>> get logStream => _logStreamController.stream;
  
  /// Включить/выключить логирование
  static void setLoggingEnabled({
    bool? debug,
    bool? performance,
    bool? info,
    bool? warning,
    bool? error,
  }) {
    if (debug != null) _enableDebug = debug;
    if (performance != null) _enablePerformanceLogging = performance;
    if (info != null) _enableInfoLogging = info;
    if (warning != null) _enableWarningLogging = warning;
    if (error != null) _enableErrorLogging = error;
  }
  
  /// Логирование производительности
  static void performance(String tag, String operation, Duration duration, {Map<String, dynamic>? extra}) {
    if (!_enablePerformanceLogging) return;
    
    final logEntry = {
      'timestamp': DateTime.now(),
      'level': LogLevel.performance,
      'tag': tag,
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      'duration_micros': duration.inMicroseconds,
      'extra': extra ?? {},
    };
    
    _bufferLog('performance', logEntry);
    _logStreamController.add(logEntry);
    
    developer.log(
      'PERF: $tag - $operation: ${duration.inMilliseconds}ms',
      name: 'fbpmn.performance',
      error: extra,
    );
    
    // Также логируем в консоль если операция занимает много времени
    if (duration.inMilliseconds > 100) {
      developer.log(
        'SLOW OPERATION: $tag - $operation took ${duration.inMilliseconds}ms',
        name: 'fbpmn.slow',
        level: 900, // Уровень warning
      );
    }
  }
  
  /// Отладочное логирование
  static void debug(String tag, String message, {Map<String, dynamic>? data}) {
    if (!_enableDebug) return;
    
    final logEntry = {
      'timestamp': DateTime.now(),
      'level': LogLevel.debug,
      'tag': tag,
      'message': message,
      'data': data ?? {},
    };
    
    _bufferLog('debug', logEntry);
    
    developer.log(
      'DEBUG: $tag - $message',
      name: 'fbpmn.debug',
      error: data,
    );
  }
  
  /// Информационное логирование
  static void info(String tag, String message, {Map<String, dynamic>? data}) {
    if (!_enableInfoLogging) return;
    
    final logEntry = {
      'timestamp': DateTime.now(),
      'level': LogLevel.info,
      'tag': tag,
      'message': message,
      'data': data ?? {},
    };
    
    _bufferLog('info', logEntry);
    _logStreamController.add(logEntry);
    
    developer.log(
      'INFO: $tag - $message',
      name: 'fbpmn.info',
      error: data,
    );
  }
  
  /// Логирование предупреждений
  static void warning(String tag, String message, {Object? error, Map<String, dynamic>? data}) {
    if (!_enableWarningLogging) return;
    
    final logEntry = {
      'timestamp': DateTime.now(),
      'level': LogLevel.warning,
      'tag': tag,
      'message': message,
      'error': error?.toString(),
      'data': data ?? {},
    };
    
    _bufferLog('warning', logEntry);
    _logStreamController.add(logEntry);
    
    developer.log(
      'WARN: $tag - $message',
      name: 'fbpmn.warning',
      error: error,
    );
  }
  
  /// Логирование ошибок
  static void error(String tag, String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    if (!_enableErrorLogging) return;
    
    final logEntry = {
      'timestamp': DateTime.now(),
      'level': LogLevel.error,
      'tag': tag,
      'message': message,
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
      'data': data ?? {},
    };
    
    _bufferLog('error', logEntry);
    _logStreamController.add(logEntry);
    
    developer.log(
      'ERROR: $tag - $message',
      name: 'fbpmn.error',
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  /// Замер времени выполнения операции
  static T measureOperation<T>(String tag, String operation, T Function() operationFn, {Map<String, dynamic>? extra}) {
    final stopwatch = Stopwatch()..start();
    try {
      final result = operationFn();
      stopwatch.stop();
      performance(tag, operation, stopwatch.elapsed, extra: extra);
      return result;
    } catch (e, st) {
      stopwatch.stop();
      error(tag, 'Operation failed: $operation', error: e, stackTrace: st, data: {
        'duration_ms': stopwatch.elapsed.inMilliseconds,
        ...?extra,
      });
      rethrow;
    }
  }
  
  /// Асинхронный замер времени выполнения операции
  static Future<T> measureAsyncOperation<T>(String tag, String operation, Future<T> Function() operationFn, {Map<String, dynamic>? extra}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operationFn();
      stopwatch.stop();
      performance(tag, operation, stopwatch.elapsed, extra: extra);
      return result;
    } catch (e, st) {
      stopwatch.stop();
      error(tag, 'Async operation failed: $operation', error: e, stackTrace: st, data: {
        'duration_ms': stopwatch.elapsed.inMilliseconds,
        ...?extra,
      });
      rethrow;
    }
  }
  
  /// Буферизация логов для последующего анализа
  static void _bufferLog(String category, Map<String, dynamic> logEntry) {
    _logBuffer.putIfAbsent(category, () => []).add(logEntry);
    
    // Ограничиваем размер буфера
    if (_logBuffer[category]!.length > 1000) {
      _logBuffer[category]!.removeRange(0, 500);
    }
  }
  
  /// Получить логи из буфера
  static List<Map<String, dynamic>> getLogs(String category, {int limit = 100}) {
    final logs = _logBuffer[category] ?? [];
    return logs.length > limit ? logs.sublist(logs.length - limit) : List.from(logs);
  }
  
  /// Получить все логи
  static Map<String, List<Map<String, dynamic>>> getAllLogs() {
    return Map.from(_logBuffer);
  }
  
  /// Очистить буфер логов
  static void clearLogs({String? category}) {
    if (category != null) {
      _logBuffer.remove(category);
    } else {
      _logBuffer.clear();
    }
  }
  
  /// Экспорт логов в формат для анализа
  static Map<String, dynamic> exportLogsForAnalysis() {
    final allLogs = getAllLogs();
    final performanceLogs = allLogs['performance'] ?? [];
    
    // Анализ производительности
    final performanceAnalysis = <String, dynamic>{};
    final operationStats = <String, List<int>>{};
    
    for (final log in performanceLogs) {
      final operation = '${log['tag']}.${log['operation']}';
      final duration = log['duration_ms'] as int;
      operationStats.putIfAbsent(operation, () => []).add(duration);
    }
    
    for (final entry in operationStats.entries) {
      final durations = entry.value;
      if (durations.isNotEmpty) {
        final avg = durations.reduce((a, b) => a + b) / durations.length;
        final max = durations.reduce((a, b) => a > b ? a : b);
        final min = durations.reduce((a, b) => a < b ? a : b);
        final slowCount = durations.where((d) => d > 100).length;
        
        performanceAnalysis[entry.key] = {
          'count': durations.length,
          'avg_ms': avg.round(),
          'min_ms': min,
          'max_ms': max,
          'slow_count': slowCount,
          'slow_percentage': (slowCount / durations.length * 100).toStringAsFixed(1),
        };
      }
    }
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'total_logs': allLogs.values.fold(0, (sum, logs) => sum + logs.length),
      'performance_analysis': performanceAnalysis,
      'error_count': (allLogs['error'] ?? []).length,
      'warning_count': (allLogs['warning'] ?? []).length,
    };
  }
  
  /// Закрыть поток логов
  static void dispose() {
    _logStreamController.close();
  }
}