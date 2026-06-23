import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/attendance_record.dart';
import '../models/class_model.dart';

class SyncLogEntry {
  final String id;
  final DateTime timestamp;
  final String deviceId;
  final String className;
  final String classId;
  final int recordCount;
  final SyncOperationType operationType;
  final SyncResult result;
  final String? errorMessage;
  final int attemptNumber;

  SyncLogEntry({
    required this.id,
    required this.timestamp,
    required this.deviceId,
    required this.className,
    required this.classId,
    required this.recordCount,
    required this.operationType,
    required this.result,
    this.errorMessage,
    required this.attemptNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
      'className': className,
      'classId': classId,
      'recordCount': recordCount,
      'operationType': operationType.toString(),
      'result': result.toString(),
      'errorMessage': errorMessage,
      'attemptNumber': attemptNumber,
    };
  }

  factory SyncLogEntry.fromJson(Map<String, dynamic> json) {
    return SyncLogEntry(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      deviceId: json['deviceId'],
      className: json['className'],
      classId: json['classId'],
      recordCount: json['recordCount'],
      operationType: _parseOperationType(json['operationType']),
      result: _parseResult(json['result']),
      errorMessage: json['errorMessage'],
      attemptNumber: json['attemptNumber'],
    );
  }

  static SyncOperationType _parseOperationType(String type) {
    // Parse the enum from string representation
    switch (type) {
      case 'SyncOperationType.sessionSync':
        return SyncOperationType.sessionSync;
      case 'SyncOperationType.backgroundSync':
        return SyncOperationType.backgroundSync;
      case 'SyncOperationType.manualSync':
        return SyncOperationType.manualSync;
      default:
        return SyncOperationType.sessionSync;
    }
  }

  static SyncResult _parseResult(String result) {
    // Parse the enum from string representation
    switch (result) {
      case 'SyncResult.success':
        return SyncResult.success;
      case 'SyncResult.failure':
        return SyncResult.failure;
      case 'SyncResult.partial':
        return SyncResult.partial;
      default:
        return SyncResult.failure;
    }
  }
}

enum SyncOperationType {
  sessionSync,
  backgroundSync,
  manualSync,
}

enum SyncResult {
  success,
  failure,
  partial,
}

class SyncLoggingService {
  static final SyncLoggingService _instance = SyncLoggingService._internal();
  factory SyncLoggingService() => _instance;
  SyncLoggingService._internal();

  late Box<Map> _syncLogsBox;

  Future<void> init() async {
    _syncLogsBox = await Hive.openBox<Map>('sync_logs');
  }

  /// Log a sync operation
  Future<void> logSyncOperation({
    required String deviceId,
    required ClassModel classModel,
    required int recordCount,
    required SyncOperationType operationType,
    required SyncResult result,
    String? errorMessage,
    int attemptNumber = 1,
  }) async {
    try {
      final logEntry = SyncLogEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}_$deviceId',
        timestamp: DateTime.now(),
        deviceId: deviceId,
        className: classModel.className,
        classId: classModel.id,
        recordCount: recordCount,
        operationType: operationType,
        result: result,
        errorMessage: errorMessage,
        attemptNumber: attemptNumber,
      );

      await _syncLogsBox.put(logEntry.id, logEntry.toJson());
      if (kDebugMode) {
        print('SyncLoggingService: Logged sync operation - $operationType, Result: $result');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SyncLoggingService: Error logging sync operation: $e');
      }
    }
  }

  /// Get all sync logs
  List<SyncLogEntry> getAllSyncLogs() {
    try {
      final logs = <SyncLogEntry>[];
      for (final key in _syncLogsBox.keys) {
        final json = _syncLogsBox.get(key);
        if (json != null) {
          logs.add(SyncLogEntry.fromJson(Map<String, dynamic>.from(json)));
        }
      }
      // Sort by timestamp, newest first
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    } catch (e) {
      if (kDebugMode) {
        print('SyncLoggingService: Error retrieving sync logs: $e');
      }
      return [];
    }
  }

  /// Get sync logs for a specific class
  List<SyncLogEntry> getSyncLogsForClass(String classId) {
    try {
      final logs = <SyncLogEntry>[];
      for (final key in _syncLogsBox.keys) {
        final json = _syncLogsBox.get(key);
        if (json != null) {
          final logEntry = SyncLogEntry.fromJson(Map<String, dynamic>.from(json));
          if (logEntry.classId == classId) {
            logs.add(logEntry);
          }
        }
      }
      // Sort by timestamp, newest first
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    } catch (e) {
      if (kDebugMode) {
        print('SyncLoggingService: Error retrieving sync logs for class $classId: $e');
      }
      return [];
    }
  }

  /// Get recent sync logs (last 24 hours)
  List<SyncLogEntry> getRecentSyncLogs() {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
      final logs = <SyncLogEntry>[];
      for (final key in _syncLogsBox.keys) {
        final json = _syncLogsBox.get(key);
        if (json != null) {
          final logEntry = SyncLogEntry.fromJson(Map<String, dynamic>.from(json));
          if (logEntry.timestamp.isAfter(cutoffTime)) {
            logs.add(logEntry);
          }
        }
      }
      // Sort by timestamp, newest first
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    } catch (e) {
      if (kDebugMode) {
        print('SyncLoggingService: Error retrieving recent sync logs: $e');
      }
      return [];
    }
  }

  /// Clear old sync logs (older than 7 days)
  Future<void> clearOldSyncLogs() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(days: 7));
      final keysToDelete = <String>[];
      
      for (final key in _syncLogsBox.keys) {
        final json = _syncLogsBox.get(key);
        if (json != null) {
          final logEntry = SyncLogEntry.fromJson(Map<String, dynamic>.from(json));
          if (logEntry.timestamp.isBefore(cutoffTime)) {
            keysToDelete.add(key.toString());
          }
        }
      }
      
      if (keysToDelete.isNotEmpty) {
        await _syncLogsBox.deleteAll(keysToDelete);
        if (kDebugMode) {
          print('SyncLoggingService: Cleared ${keysToDelete.length} old sync logs');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('SyncLoggingService: Error clearing old sync logs: $e');
      }
    }
  }

  /// Export logs as JSON string
  String exportLogsAsJson() {
    try {
      final logs = getAllSyncLogs();
      final List<Map<String, dynamic>> jsonLogs = logs.map((log) => log.toJson()).toList();
      return jsonEncode(jsonLogs);
    } catch (e) {
      if (kDebugMode) {
        print('SyncLoggingService: Error exporting logs as JSON: $e');
      }
      return '[]';
    }
  }

  /// Get summary statistics
  SyncLogSummary getLogSummary() {
    try {
      final logs = getAllSyncLogs();
      int totalSyncs = logs.length;
      int successfulSyncs = logs.where((log) => log.result == SyncResult.success).length;
      int failedSyncs = logs.where((log) => log.result == SyncResult.failure).length;
      int partialSyncs = logs.where((log) => log.result == SyncResult.partial).length;
      
      // Calculate success rate
      double successRate = totalSyncs > 0 ? (successfulSyncs / totalSyncs) * 100 : 0;
      
      // Get most common error messages
      final errorCounts = <String, int>{};
      for (final log in logs) {
        if (log.errorMessage != null && log.errorMessage!.isNotEmpty) {
          errorCounts[log.errorMessage!] = (errorCounts[log.errorMessage!] ?? 0) + 1;
        }
      }
      
      // Sort errors by frequency
      final sortedErrors = errorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final mostCommonErrors = sortedErrors.take(5).map((e) => e.key).toList();
      
      return SyncLogSummary(
        totalSyncs: totalSyncs,
        successfulSyncs: successfulSyncs,
        failedSyncs: failedSyncs,
        partialSyncs: partialSyncs,
        successRate: successRate,
        mostCommonErrors: mostCommonErrors,
      );
    } catch (e) {
      if (kDebugMode) {
        print('SyncLoggingService: Error generating log summary: $e');
      }
      return SyncLogSummary(
        totalSyncs: 0,
        successfulSyncs: 0,
        failedSyncs: 0,
        partialSyncs: 0,
        successRate: 0,
        mostCommonErrors: [],
      );
    }
  }
}

class SyncLogSummary {
  final int totalSyncs;
  final int successfulSyncs;
  final int failedSyncs;
  final int partialSyncs;
  final double successRate;
  final List<String> mostCommonErrors;

  SyncLogSummary({
    required this.totalSyncs,
    required this.successfulSyncs,
    required this.failedSyncs,
    required this.partialSyncs,
    required this.successRate,
    required this.mostCommonErrors,
  });
}