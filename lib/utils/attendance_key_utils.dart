import 'package:flutter/foundation.dart';
import '../models/attendance_record.dart';

/// Utility class for generating consistent keys for attendance records
/// These keys are used only locally for matching and deduplication, not stored in the sheet
class AttendanceKeyUtils {
  /// Generate a session key for a class and date
  /// Format: classId_date (yyyyMMdd)
  static String generateSessionKey(String classId, DateTime date) {
    final formattedDate = _formatDate(date);
    return '${classId}_$formattedDate';
  }

  /// Generate a student session key for a class, student, and date
  /// Format: classId_studentPin_date (yyyyMMdd)
  static String generateStudentSessionKey(String classId, String studentPin, DateTime date) {
    final formattedDate = _formatDate(date);
    return '${classId}_${studentPin}_$formattedDate';
  }

  /// Generate a consistent ID for attendance records in Hive
  /// Format: classId_studentPin_timestamp
  static String generateAttendanceId(String classId, String studentPin, DateTime sessionDate) {
    return '${classId}_${studentPin}_${sessionDate.millisecondsSinceEpoch}';
  }

  /// Format date as yyyyMMdd string
  static String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${year}${month}${day}';
  }

  /// Extract date from session key
  static DateTime? extractDateFromSessionKey(String sessionKey) {
    try {
      final parts = sessionKey.split('_');
      if (parts.length < 2) return null;
      
      final dateStr = parts[parts.length - 1]; // Last part should be the date
      if (dateStr.length != 8) return null;
      
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      
      return DateTime(year, month, day);
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting date from session key: $e');
      }
      return null;
    }
  }

  /// Extract student PIN from student session key
  static String? extractStudentPinFromSessionKey(String studentSessionKey) {
    try {
      final parts = studentSessionKey.split('_');
      if (parts.length < 2) return null;
      return parts[parts.length - 2]; // Second to last part should be the student PIN
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting student PIN from session key: $e');
      }
      return null;
    }
  }
}