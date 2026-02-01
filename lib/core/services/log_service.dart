import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// 日志级别
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// 应用日志服务
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];
  final int _maxLogs = 1000; // 最多保留1000条日志
  File? _logFile;
  bool _initialized = false;

  /// 初始化日志服务
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/app_runtime.log');
      
      // 读取已存在的日志文件
      if (await _logFile!.exists()) {
        final content = await _logFile!.readAsString();
        final lines = content.split('\n');
        
        // 只加载最近的日志
        for (var line in lines.take(_maxLogs)) {
          if (line.trim().isNotEmpty) {
            _parseLine(line);
          }
        }
      }
      
      _initialized = true;
      log(LogLevel.info, 'LogService', '日志服务已初始化');
    } catch (e) {
      debugPrint('日志服务初始化失败: $e');
    }
  }

  /// 解析日志行
  void _parseLine(String line) {
    try {
      // 格式: [2024-01-01 12:00:00] [INFO] [Tag] Message
      final regex = RegExp(r'\[(.*?)\] \[(.*?)\] \[(.*?)\] (.+)');
      final match = regex.firstMatch(line);
      
      if (match != null) {
        final timestamp = DateTime.parse(match.group(1)!);
        final level = _parseLogLevel(match.group(2)!);
        final tag = match.group(3)!;
        final message = match.group(4)!;
        
        _logs.add(LogEntry(
          timestamp: timestamp,
          level: level,
          tag: tag,
          message: message,
        ));
      }
    } catch (e) {
      // 忽略解析错误
    }
  }

  LogLevel _parseLogLevel(String level) {
    switch (level.toUpperCase()) {
      case 'DEBUG':
        return LogLevel.debug;
      case 'INFO':
        return LogLevel.info;
      case 'WARNING':
        return LogLevel.warning;
      case 'ERROR':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }

  /// 记录日志
  void log(LogLevel level, String tag, String message, [Object? error, StackTrace? stackTrace]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.add(entry);

    // 限制日志数量
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    // 输出到控制台
    if (kDebugMode) {
      debugPrint(entry.toString());
    }

    // 异步写入文件
    _writeToFile(entry);
  }

  /// 写入日志文件
  Future<void> _writeToFile(LogEntry entry) async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString(
        '${entry.toString()}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      debugPrint('写入日志文件失败: $e');
    }
  }

  /// 获取所有日志
  List<LogEntry> getLogs({LogLevel? level}) {
    if (level == null) {
      return List.unmodifiable(_logs);
    }
    return _logs.where((log) => log.level == level).toList();
  }

  /// 清除日志
  Future<void> clearLogs() async {
    _logs.clear();
    
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.delete();
    }
    
    log(LogLevel.info, 'LogService', '日志已清除');
  }

  /// 导出日志为字符串
  String exportLogs() {
    final buffer = StringBuffer();
    
    buffer.writeln('OpenList Viewer - 运行日志');
    buffer.writeln('导出时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('日志条数: ${_logs.length}');
    buffer.writeln('=' * 80);
    buffer.writeln();
    
    // 系统信息
    buffer.writeln('【系统信息】');
    buffer.writeln('平台: ${Platform.operatingSystem}');
    buffer.writeln('系统版本: ${Platform.operatingSystemVersion}');
    buffer.writeln('Dart版本: ${Platform.version}');
    buffer.writeln();
    
    // 日志统计
    buffer.writeln('【日志统计】');
    buffer.writeln('DEBUG: ${getLogs(level: LogLevel.debug).length}');
    buffer.writeln('INFO: ${getLogs(level: LogLevel.info).length}');
    buffer.writeln('WARNING: ${getLogs(level: LogLevel.warning).length}');
    buffer.writeln('ERROR: ${getLogs(level: LogLevel.error).length}');
    buffer.writeln();
    
    buffer.writeln('【详细日志】');
    buffer.writeln('=' * 80);
    
    for (var log in _logs) {
      buffer.writeln(log.toDetailedString());
    }
    
    return buffer.toString();
  }

  /// 获取日志文件大小
  Future<int> getLogFileSize() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return 0;
    }
    
    return await _logFile!.length();
  }
}

/// 日志条目
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get levelString {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  @override
  String toString() {
    return '[${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)}] [$levelString] [$tag] $message';
  }

  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.writeln(toString());
    
    if (error != null) {
      buffer.writeln('  错误: $error');
    }
    
    if (stackTrace != null) {
      buffer.writeln('  堆栈跟踪:');
      buffer.writeln('  ${stackTrace.toString().split('\n').join('\n  ')}');
    }
    
    return buffer.toString();
  }
}

// 全局日志实例
final appLogger = LogService();

// 便捷方法
void logDebug(String tag, String message) => appLogger.log(LogLevel.debug, tag, message);
void logInfo(String tag, String message) => appLogger.log(LogLevel.info, tag, message);
void logWarning(String tag, String message, [Object? error]) => appLogger.log(LogLevel.warning, tag, message, error);
void logError(String tag, String message, [Object? error, StackTrace? stackTrace]) => 
    appLogger.log(LogLevel.error, tag, message, error, stackTrace);
