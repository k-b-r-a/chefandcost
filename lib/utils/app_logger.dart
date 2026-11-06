import 'package:flutter/foundation.dart';
import '../constants.dart';

enum LogLevel {
  info,
  warn,
  error,
  debug,
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  String get levelLabel {
    switch (level) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.debug:
        return 'DEBUG';
    }
  }

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() => '[$formattedTime] [$levelLabel] $message';
}

/// In-memory ring buffer logger for diagnostics and beta testing.
class AppLogger {
  static final List<LogEntry> _logs = [];
  static const int _maxLogs = 300;
  static bool _initialized = false;

  static List<LogEntry> get logs {
    if (!_initialized) {
      init();
    }
    return List.unmodifiable(_logs);
  }

  static void init() {
    if (_initialized) return;
    _initialized = true;
    info('Chef&Cost initialized (v$kAppVersion)');
    debug('Database schema v1 loaded');
    info('Platform: ${kIsWeb ? "Web" : defaultTargetPlatform.name}');
  }

  static void info(String message) => log(message, level: LogLevel.info);
  static void warn(String message) => log(message, level: LogLevel.warn);
  static void error(String message) => log(message, level: LogLevel.error);
  static void debug(String message) => log(message, level: LogLevel.debug);

  static void log(String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
    );

    if (_logs.length >= _maxLogs) {
      _logs.removeAt(0);
    }
    _logs.add(entry);

    debugPrint(entry.toString());
  }

  static void clear() {
    _logs.clear();
    _initialized = true;
  }

  static String exportText() {
    if (_logs.isEmpty) return 'No logs recorded.';
    return _logs.map((e) => e.toString()).join('\n');
  }
}
