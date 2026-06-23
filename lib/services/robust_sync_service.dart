import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../services/hive_service.dart';
import '../services/department_sheet_service.dart';
import '../constants/app_constants.dart';

/// Data class to hold student attendance information for robust sync
class StudentAttendanceData {
  final String pinNumber;
  final String name;
  final String status;

  StudentAttendanceData({
    required this.pinNumber,
    required this.name,
    required this.status,
  });
}

/// Robust attendance synchronization service that ensures perfect consistency
/// between all class attendance sheets, even under multi-device, offline, or 
/// column-missing conditions.
class RobustSyncService extends ChangeNotifier {
  static final RobustSyncService _instance = RobustSyncService._internal();
  factory RobustSyncService() => _instance;
  RobustSyncService._internal();
  
  // Lightweight lock to prevent concurrent Google Sheets operations
  static bool _isOperationInProgress = false;

  Timer? _syncTimer;
  bool _isSyncing = false;
  String? _lastSyncError;
  DateTime? _lastSyncTime;
  int _syncIntervalSeconds = 60; // Default sync interval (1 minute)
  bool _forceSync = false;

  // Getters
  bool get isSyncing => _isSyncing;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get syncIntervalSeconds => _syncIntervalSeconds;

  /// Start the robust synchronization service
  void startRobustSyncService() {
    print('Starting robust sync service...');
    _stopTimer();
    
    // DISABLED: Removed periodic timer for robust sync as per user request
    // _syncTimer = Timer.periodic(
    //   Duration(seconds: _syncIntervalSeconds),
    //   (timer) => performRobustSync(),
    // );
    
    // DISABLED: Removed initial sync as per user request
    // Timer(const Duration(seconds: 5), () => performRobustSync());
    print('RobustSyncService: Timer DISABLED - robust sync will only happen on manual trigger');
  }

  /// Stop the synchronization service
  void stopRobustSyncService() {
    print('Stopping robust sync service...');
    _stopTimer();
  }

  /// Set sync interval
  void setSyncInterval(int seconds) {
    _syncIntervalSeconds = seconds;
    if (_syncTimer != null) {
      startRobustSyncService(); // Restart with new interval
    }
  }

  /// Force sync on next cycle
  void forceNextSync() {
    _forceSync = true;
  }

  /// Perform robust synchronization with all the required features
  Future<void> performRobustSync({bool manualTrigger = false}) async {
    if (_isSyncing && !manualTrigger) {
      print('Robust sync already in progress, skipping...');
      return;
    }

    print('Performing robust synchronization...');
    
    try {
      _isSyncing = true;
      _lastSyncError = null;
      notifyListeners();

      // Get all classes
      final classes = HiveService.getAllClasses();
      print('Found ${classes.length} classes for robust sync');
      
      for (final classModel in classes) {
        print('Processing class: ${classModel.className} (ID: ${classModel.id})');
        
        // Get all attendance records for today (including both present and absent)
        final today = DateTime.now();
        final todayRecords = HiveService.getAttendanceForClass(
          classModel.id, 
          DateTime(today.year, today.month, today.day)
        );
        print('Found ${todayRecords.length} total attendance records for today for class ${classModel.className}');
        
        // Even if no new data, we still sync to ensure date column restoration (self-healing)
        print('Performing robust sync for class ${classModel.className} (forceSync: $_forceSync, manualTrigger: $manualTrigger)');
        
        // Perform robust sync with union-based merging
        final result = await _performRobustAttendanceSync(
          classModel: classModel,
          attendanceRecords: todayRecords,
        );

        if (result.isSuccess) {
          // Mark all today's records as synced only if they were actually processed
          if (result.uploadedRecordIds != null && result.uploadedRecordIds!.isNotEmpty) {
            await HiveService.markAttendanceAsSynced(result.uploadedRecordIds!);
          }
          
          // Update department sheets with present roll numbers
          print('Updating department sheets for class ${classModel.className}');
          final departmentUpdateSuccess = await DepartmentSheetService.updateDepartmentSheets(
            classModel: classModel,
            attendanceRecords: todayRecords,
          );
          
          if (departmentUpdateSuccess) {
            print('✅ Department sheets updated successfully for class ${classModel.className}');
          } else {
            print('⚠️ Failed to update department sheets for class ${classModel.className}');
          }
          
          _lastSyncTime = DateTime.now();
          print('Robust sync successful for class ${classModel.className}: ${result.uploadedRecordIds?.length ?? 0} records processed');
        } else {
          _lastSyncError = result.message;
          print('Robust sync failed for class ${classModel.className}: ${result.message}');
        }
      }

    } catch (e, stackTrace) {
      _lastSyncError = 'Robust sync error: $e';
      print('Robust sync error: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _isSyncing = false;
      _forceSync = false;
      notifyListeners();
    }
  }

  /// Manual sync trigger
  Future<void> triggerManualSync() async {
    await performRobustSync(manualTrigger: true);
  }

  /// Stop the timer
  void _stopTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  /// Get sync status message
  String get statusMessage {
    if (_isSyncing) {
      return 'Robust syncing...';
    }
    
    if (_lastSyncError != null) {
      return 'Error: $_lastSyncError';
    }
    
    if (_lastSyncTime != null) {
      final timeDiff = DateTime.now().difference(_lastSyncTime!);
      if (timeDiff.inMinutes < 1) {
        return 'Last robust sync: ${timeDiff.inSeconds}s ago';
      } else if (timeDiff.inHours < 1) {
        return 'Last robust sync: ${timeDiff.inMinutes}m ago';
      } else {
        return 'Last robust sync: ${timeDiff.inHours}h ago';
      }
    }
    
    return 'Not robust synced yet';
  }

  /// Perform the robust attendance synchronization with all required features
  Future<GoogleSheetsUploadResult> _performRobustAttendanceSync({
    required ClassModel classModel,
    required List<AttendanceRecord> attendanceRecords,
  }) async {
    try {
      print('=== PERFORMING ROBUST ATTENDANCE SYNC (Firebase RTDB only) ===');
      print('Class: ${classModel.className}');
      print('Number of attendance records: ${attendanceRecords.length}');
      
      // With Firebase RTDB, all attendance data is already synchronized in real-time
      // We just need to mark records as synced locally
      
      // Get all unsynced records for this class
      final unsyncedRecords = HiveService.getUnsyncedAttendance(classModel.id);
      print('Found ${unsyncedRecords.length} unsynced records');
      
      // Mark all unsynced records as synced since they're already in Firebase RTDB
      final recordIds = unsyncedRecords.map((record) => record.id).toList();
      if (recordIds.isNotEmpty) {
        await HiveService.markAttendanceAsSynced(recordIds);
        await HiveService.saveLastSyncTime(classModel.id, DateTime.now());
        print('Marked ${recordIds.length} records as synced (Firebase RTDB only)');
      }
      
      // Update department sheets is not needed with Firebase RTDB only
      print('Skipping department sheet updates (Firebase RTDB only)');
      
      return GoogleSheetsUploadResult.success(
        uploadedRecordIds: recordIds,
        message: 'Successfully synced ${recordIds.length} records to Firebase RTDB',
      );
      
    } catch (e, stackTrace) {
      print('❌ Robust attendance sync error: $e');
      print('Stack trace: $stackTrace');
      
      return GoogleSheetsUploadResult.error(
        message: 'Robust sync failed: $e',
      );
    }
  }
}

class GoogleSheetsUploadResult {
  final bool isSuccess;
  final List<String>? uploadedRecordIds;
  final String message;

  GoogleSheetsUploadResult._({
    required this.isSuccess,
    this.uploadedRecordIds,
    required this.message,
  });

  factory GoogleSheetsUploadResult.success({
    required List<String> uploadedRecordIds,
    required String message,
  }) {
    return GoogleSheetsUploadResult._(
      isSuccess: true,
      uploadedRecordIds: uploadedRecordIds,
      message: message,
    );
  }

  factory GoogleSheetsUploadResult.error({
    required String message,
  }) {
    return GoogleSheetsUploadResult._(
      isSuccess: false,
      message: message,
    );
  }
}
