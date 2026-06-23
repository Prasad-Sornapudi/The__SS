import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import '../services/hive_service.dart';
import '../models/attendance_record.dart';

class AttendancePersistenceService {
  static const String _lastCleanupDateKey = 'last_cleanup_date';
  static const int _cleanupHour = 22; // 10:00 PM

  /// Check if attendance data should be cleared and perform cleanup if needed
  static Future<void> checkAndCleanupAttendanceData() async {
    try {
      final now = DateTime.now();
      final lastCleanupDateStr = HiveService.getSetting<String>(_lastCleanupDateKey);
      
      // Parse last cleanup date or use a default old date
      DateTime lastCleanupDate;
      if (lastCleanupDateStr != null) {
        lastCleanupDate = DateTime.parse(lastCleanupDateStr);
      } else {
        // If no cleanup date is stored, use a very old date to ensure cleanup happens
        lastCleanupDate = DateTime(2000, 1, 1);
      }
      
      print('AttendancePersistenceService: Last cleanup date: $lastCleanupDate');
      print('AttendancePersistenceService: Current date: $now');
      
      // Check if we need to perform cleanup
      if (_shouldPerformCleanup(now, lastCleanupDate)) {
        print('AttendancePersistenceService: Performing cleanup of old attendance data');
        await _performCleanup(now);
        // Update the last cleanup date
        await HiveService.setSetting(_lastCleanupDateKey, now.toIso8601String());
      } else {
        print('AttendancePersistenceService: No cleanup needed');
      }
    } catch (e, stackTrace) {
      print('AttendancePersistenceService: Error in checkAndCleanupAttendanceData: $e');
      print('Stack trace: $stackTrace');
      // Don't rethrow to avoid breaking the app
    }
  }

  /// Determine if cleanup should be performed
  static bool _shouldPerformCleanup(DateTime now, DateTime lastCleanupDate) {
    // Check if we've already done cleanup today
    if (_isSameDate(now, lastCleanupDate)) {
      return false;
    }
    
    // Check if it's past 10:00 PM today
    final cutoffTime = DateTime(now.year, now.month, now.day, _cleanupHour, 0, 0);
    return now.isAfter(cutoffTime);
  }

  /// Perform the actual cleanup of old attendance data
  static Future<void> _performCleanup(DateTime now) async {
    print('AttendancePersistenceService: Starting cleanup process');
    
    // Define the cutoff date (yesterday)
    final cutoffDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    
    try {
      // Get all attendance records
      final allRecords = HiveService.attendanceBox.values.toList();
      print('AttendancePersistenceService: Found ${allRecords.length} total attendance records');
      
      int deletedCount = 0;
      
      // Delete records that are older than the cutoff date
      for (final record in allRecords) {
        if (record.sessionDate.isBefore(cutoffDate)) {
          print('AttendancePersistenceService: Deleting old record for ${record.studentName} (${record.studentPinNumber}) from ${record.sessionDate}');
          await HiveService.deleteAttendanceRecord(record.id);
          deletedCount++;
        }
      }
      
      print('AttendancePersistenceService: Cleanup completed. Deleted $deletedCount old records');
    } catch (e, stackTrace) {
      print('AttendancePersistenceService: Error during cleanup: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if two dates are the same (ignoring time)
  static bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Get the next cleanup time (10:00 PM today or tomorrow)
  static DateTime getNextCleanupTime() {
    final now = DateTime.now();
    final todayCleanup = DateTime(now.year, now.month, now.day, _cleanupHour, 0, 0);
    
    // If it's already past 10:00 PM today, next cleanup is tomorrow
    if (now.isAfter(todayCleanup)) {
      return todayCleanup.add(const Duration(days: 1));
    }
    
    // Otherwise, next cleanup is today at 10:00 PM
    return todayCleanup;
  }

  /// Check if data should be preserved (before 10:00 PM)
  static bool shouldPreserveData() {
    final now = DateTime.now();
    final cutoffTime = DateTime(now.year, now.month, now.day, _cleanupHour, 0, 0);
    return now.isBefore(cutoffTime);
  }

  /// Get the data expiration time (10:00 PM of the current day)
  static DateTime getDataExpirationTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, _cleanupHour, 0, 0);
  }

  /// Check if data for a specific date should be preserved
  static bool shouldPreserveDataForDate(DateTime date) {
    final now = DateTime.now();
    final cutoffTime = DateTime(now.year, now.month, now.day, _cleanupHour, 0, 0);
    
    // If the data is from today and it's before 10:00 PM, preserve it
    if (_isSameDate(date, now) && now.isBefore(cutoffTime)) {
      return true;
    }
    
    // If the data is from yesterday and it's after 10:00 PM today, preserve it until tomorrow at 10:00 PM
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDate(date, yesterday) && now.isAfter(cutoffTime)) {
      return true;
    }
    
    return false;
  }
}