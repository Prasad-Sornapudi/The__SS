import 'package:flutter/foundation.dart';
import '../services/hive_service.dart';
import '../services/attendance_data_service.dart';
import '../models/attendance_record.dart';

class DataPersistenceTestService {
  /// Test function to verify that data persistence is working correctly
  static Future<void> testDataPersistence() async {
    try {
      if (kDebugMode) {
        print('=== Data Persistence Test ===');
        
        // Print comprehensive attendance summary
        await AttendanceDataService.printAttendanceSummary();
        
        print('=== End Data Persistence Test ===');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in data persistence test: $e');
      }
    }
  }
}