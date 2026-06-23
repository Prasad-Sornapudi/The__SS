import 'package:flutter/foundation.dart';
import '../models/attendance_record.dart';
import '../models/class_model.dart';
import '../services/hive_service.dart';
import '../utils/attendance_key_utils.dart';

class AttendanceDataService {
  static const int _cleanupHour = 22; // 10:00 PM

  /// Generate a consistent ID for attendance records
  static String generateAttendanceId(String classId, String studentPinNumber, DateTime sessionDate) {
    // Use the new consistent ID format
    return AttendanceKeyUtils.generateAttendanceId(classId, studentPinNumber, sessionDate);
  }
  
  /// Save an attendance record with a consistent ID
  static Future<void> saveAttendanceRecord(AttendanceRecord record) async {
    await HiveService.saveAttendanceRecord(record);
  }
  
  /// Load attendance records for a specific class and date
  static List<AttendanceRecord> loadAttendanceRecords(String classId, DateTime sessionDate) {
    final records = HiveService.getAttendanceForClass(classId, sessionDate);
    if (kDebugMode) {
      print('📥 Loaded ${records.length} attendance records for class $classId on ${sessionDate.toIso8601String()}');
      
      // Print sample records for debugging
      if (records.isNotEmpty) {
        print('Sample loaded records:');
        for (int i = 0; i < records.length && i < 5; i++) {
          final record = records[i];
          print('  - ${record.studentName} (${record.studentPinNumber}): ${record.status} (Synced: ${record.isSyncedToSheet}, ID: ${record.id})');
        }
        if (records.length > 5) {
          print('  ... and ${records.length - 5} more records');
        }
      }
    }
    return records;
  }

  /// Get the data expiration time (10:00 PM of the current day)
  static DateTime getDataExpirationTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, _cleanupHour, 0, 0);
  }

  /// Check if data should be preserved (before 10:00 PM)
  static bool shouldPreserveData() {
    final now = DateTime.now();
    final cutoffTime = getDataExpirationTime();
    return now.isBefore(cutoffTime);
  }

  /// Check if data for a specific date should be preserved
  static bool shouldPreserveDataForDate(DateTime date) {
    final now = DateTime.now();
    final cutoffTime = getDataExpirationTime();
    
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

  /// Cleanup old attendance data based on the 10:00 PM rule
  static Future<void> cleanupOldData() async {
    try {
      final now = DateTime.now();
      final cutoffDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      
      if (kDebugMode) {
        print('🧹 Cleaning up old attendance data. Cutoff date: ${cutoffDate.toIso8601String()}');
      }
      
      // Get all attendance records
      final allRecords = HiveService.attendanceBox.values.toList();
      
      int deletedCount = 0;
      for (final record in allRecords) {
        // Delete records that are older than the cutoff date
        if (record.sessionDate.isBefore(cutoffDate)) {
          await HiveService.deleteAttendanceRecord(record.id);
          deletedCount++;
          if (kDebugMode) {
            print('🗑️ Deleted old record: ${record.studentName} (${record.studentPinNumber}) from ${record.sessionDate}');
          }
        }
      }
      
      if (kDebugMode) {
        print('🧹 Cleanup completed. Deleted $deletedCount old records.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during cleanup: $e');
      }
    }
  }

  /// Check if two dates are the same (ignoring time)
  static bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Force save all current attendance data to ensure persistence
  static Future<void> forceSaveAllData(Map<String, List<AttendanceRecord>> classAttendanceRecords) async {
    try {
      int savedCount = 0;
      for (final entry in classAttendanceRecords.entries) {
        final classId = entry.key;
        final records = entry.value;
        
        for (final record in records) {
          await HiveService.saveAttendanceRecord(record);
          savedCount++;
        }
      }
      
      if (kDebugMode) {
        print('💾 Force saved $savedCount attendance records to Hive');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during force save: $e');
      }
    }
  }

  /// Get attendance summary for debugging
  static Future<void> printAttendanceSummary() async {
    try {
      final allRecords = HiveService.attendanceBox.values.toList();
      final now = DateTime.now();
      
      if (kDebugMode) {
        print('📊 === Attendance Data Summary ===');
        print('Total records in database: ${allRecords.length}');
        
        // Group by date
        final recordsByDate = <DateTime, List<AttendanceRecord>>{};
        for (final record in allRecords) {
          final dateKey = DateTime(record.sessionDate.year, record.sessionDate.month, record.sessionDate.day);
          if (!recordsByDate.containsKey(dateKey)) {
            recordsByDate[dateKey] = [];
          }
          recordsByDate[dateKey]!.add(record);
        }
        
        // Print records by date
        recordsByDate.forEach((date, records) {
          final shouldPreserve = shouldPreserveDataForDate(date);
          print('📅 ${date.toIso8601String()}: ${records.length} records (Preserve: $shouldPreserve)');
          
          // Print first few records as samples
          for (int i = 0; i < records.length && i < 3; i++) {
            final record = records[i];
            print('   - ${record.studentName} (${record.studentPinNumber}): ${record.status} at ${record.scanTime}');
          }
          if (records.length > 3) {
            print('   ... and ${records.length - 3} more');
          }
        });
        
        print('📊 === End Attendance Data Summary ===');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error printing attendance summary: $e');
      }
    }
  }
}