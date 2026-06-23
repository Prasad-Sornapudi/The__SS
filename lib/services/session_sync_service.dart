import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart'; // Add this for TimeOfDay
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Add this for Hive
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../models/session_model.dart' as session_model; // Use alias to avoid conflict
import '../services/hive_service.dart';
import '../services/google_sheets_service.dart';
import '../services/department_sheet_service.dart';
import '../services/robust_sync_service.dart';
import '../providers/sync_progress_provider.dart';
import 'package:provider/provider.dart';

class SessionSyncService extends ChangeNotifier with WidgetsBindingObserver {
  static final SessionSyncService _instance = SessionSyncService._internal();
  factory SessionSyncService() => _instance;
  SessionSyncService._internal();

  // Session timing constants (removed as per user request)
  // static const int morningStartHour = 9;
  // static const int morningStartMinute = 30;
  // static const int morningEndHour = 12;
  // static const int morningEndMinute = 30;
  // static const int morningClearHour = 14;
  // static const int morningClearMinute = 0;
  // 
  // static const int afternoonStartHour = 13;
  // static const int afternoonStartMinute = 30;
  // static const int afternoonEndHour = 16;
  // static const int afternoonEndMinute = 30;
  // static const int afternoonClearHour = 22;
  // static const int afternoonClearMinute = 30;

  // Background sync tracking
  Timer? _backgroundSyncTimer;
  int _backgroundSyncCount = 0;
  static const int maxBackgroundSyncCycles = 2;
  bool _isInBackground = false;
  bool _isSyncing = false;
  String? _lastSyncError;
  DateTime? _lastSyncTime;

  // Session tracking
  late Box<session_model.SessionModel> _sessionsBox;

  // Getters
  bool get isSyncing => _isSyncing;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initialize the service
  Future<void> init() async {
    print('SessionSyncService: Initializing service');
    
    // Register as app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Open sessions box
    _sessionsBox = await Hive.openBox<session_model.SessionModel>('sessions');
    
    print('SessionSyncService: Service initialized');
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('SessionSyncService: App lifecycle state changed to $state');
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleAppBackground();
        break;
      case AppLifecycleState.resumed:
        _handleAppForeground();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // No special handling needed
        break;
    }
  }

  /// Handle app going to background
  void _handleAppBackground() {
    print('SessionSyncService: App going to background');
    _isInBackground = true;
    _backgroundSyncCount = 0; // Reset background sync count when app goes to background
    _startBackgroundSync();
  }

  /// Handle app coming to foreground
  void _handleAppForeground() {
    print('SessionSyncService: App coming to foreground');
    _isInBackground = false;
    _stopBackgroundSync();
    _backgroundSyncCount = 0; // Reset background sync count when app comes to foreground
  }

  /// Start background sync when app goes to background
  void _startBackgroundSync() {
    if (!_isInBackground) return;
    
    print('SessionSyncService: Starting background sync');
    _stopBackgroundSync(); // Stop any existing timer
    
    // Perform first background sync immediately
    _performBackgroundSync();
    
    // DISABLED: Removed periodic background sync timer as per user request
    // _backgroundSyncTimer = Timer.periodic(
    //   const Duration(minutes: 1), // Check every minute
    //   (timer) => _performBackgroundSync(),
    // );
    print('SessionSyncService: Background sync timer DISABLED');
  }

  /// Stop background sync
  void _stopBackgroundSync() {
    print('SessionSyncService: Stopping background sync');
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
  }

  /// Perform background sync
  Future<void> _performBackgroundSync() async {
    if (!_isInBackground) return;
    
    // Check if we've reached the maximum background sync cycles
    if (_backgroundSyncCount >= maxBackgroundSyncCycles) {
      print('SessionSyncService: Maximum background sync cycles reached, stopping');
      _stopBackgroundSync();
      return;
    }
    
    // Check if there are any unsynced records
    final hasUnsyncedData = await _hasUnsyncedData();
    if (!hasUnsyncedData) {
      print('SessionSyncService: No unsynced data, stopping background sync');
      _stopBackgroundSync();
      return;
    }
    
    print('SessionSyncService: Performing background sync cycle ${_backgroundSyncCount + 1}');
    _backgroundSyncCount++;
    
    // Perform sync
    await performSessionSync();
  }

  /// Check if there are any unsynced records
  Future<bool> _hasUnsyncedData() async {
    // Get all classes and check each one
    final classes = HiveService.getAllClasses();
    for (final classModel in classes) {
      final unsyncedRecords = HiveService.getUnsyncedAttendance(classModel.id);
      if (unsyncedRecords.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Perform session sync for all classes
  Future<void> performSessionSync({bool manualTrigger = false}) async {
    if (_isSyncing && !manualTrigger) {
      print('SessionSyncService: Sync already in progress, skipping...');
      return;
    }

    print('SessionSyncService: Performing session sync...');
    
    try {
      _isSyncing = true;
      _lastSyncError = null;
      notifyListeners();

      // Enable wake lock to prevent device from sleeping during sync
      try {
        print('SessionSyncService: Enabling wake lock');
        await WakelockPlus.enable();
      } catch (e) {
        print('SessionSyncService: Error enabling wake lock: $e');
      }

      // Get all classes
      final classes = HiveService.getAllClasses();
      print('SessionSyncService: Found ${classes.length} classes for sync');
      
      for (final classModel in classes) {
        print('SessionSyncService: Processing class: ${classModel.className} (ID: ${classModel.id})');
        
        // Perform robust sync for this class
        await _performClassSessionSync(classModel);
      }

      _lastSyncTime = DateTime.now();
      print('SessionSyncService: Session sync completed successfully');

    } catch (e, stackTrace) {
      _lastSyncError = 'Session sync error: $e';
      print('SessionSyncService: Session sync error: $e');
      print('Stack trace: $stackTrace');
    } finally {
      // Disable wake lock after sync is complete
      try {
        print('SessionSyncService: Disabling wake lock');
        await WakelockPlus.disable();
      } catch (e) {
        print('SessionSyncService: Error disabling wake lock: $e');
      }
      
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Perform session sync for a specific class
  Future<void> _performClassSessionSync(ClassModel classModel) async {
    print('SessionSyncService: Performing session sync for class ${classModel.className}');
    
    try {
      // Get current session type
      final currentSession = _getCurrentSession();
      if (currentSession == null) {
        print('SessionSyncService: No active session, skipping sync');
        return;
      }
      
      // Get all attendance records for today
      final today = DateTime.now();
      final todayRecords = HiveService.getAttendanceForClass(
        classModel.id, 
        DateTime(today.year, today.month, today.day)
      );
      print('SessionSyncService: Found ${todayRecords.length} attendance records for today');
      
      // Perform robust sync using existing service
      await RobustSyncService().performRobustSync(manualTrigger: true);
      
      // Update department sheets
      print('SessionSyncService: Updating department sheets for class ${classModel.className}');
      try {
        final departmentUpdateSuccess = await DepartmentSheetService.updateDepartmentSheets(
          classModel: classModel,
          attendanceRecords: todayRecords,
        );
        
        if (departmentUpdateSuccess) {
          print('SessionSyncService: ✅ Department sheets updated successfully for class ${classModel.className}');
        } else {
          print('SessionSyncService: ⚠️ Failed to update department sheets for class ${classModel.className}');
        }
      } catch (e) {
        print('SessionSyncService: ⚠️ Error updating department sheets: $e');
      }
      
      // Check if we should clear session data
      await _checkAndClearSessionData(classModel, currentSession);
      
      print('SessionSyncService: Session sync successful for class ${classModel.className}');
      
    } catch (e, stackTrace) {
      print('SessionSyncService: Error during class session sync: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if session data should be cleared and clear it if appropriate
  Future<void> _checkAndClearSessionData(ClassModel classModel, session_model.SessionType sessionType) async {
    print('SessionSyncService: Checking if session data should be cleared for ${sessionType.toString()}');
    
    // Check if it's time to clear this session
    final now = DateTime.now();
    final shouldClear = _shouldClearSession(now, sessionType);
    
    if (shouldClear) {
      print('SessionSyncService: Clearing session data for ${sessionType.toString()}');
      
      // Clear all attendance records for today for this class
      final today = DateTime(now.year, now.month, now.day);
      await HiveService.clearAttendanceForClassAndDate(classModel.id, today);
      
      print('SessionSyncService: Session data cleared for ${sessionType.toString()}');
    } else {
      print('SessionSyncService: Not time to clear session data for ${sessionType.toString()}');
    }
  }

  /// Determine if it's time to clear a session (always false as per user request to remove timings)
  bool _shouldClearSession(DateTime now, session_model.SessionType sessionType) {
    // As per user request, remove all timing-based session clearing
    return false;
  }

  /// Get the current session type (always return morning as default since timings are removed)
  session_model.SessionType? _getCurrentSession() {
    // As per user request, remove all timing-based session logic
    // Always return morning session as default
    return session_model.SessionType.morning;
  }

  /// Check if there are pending syncs that need to be completed
  Future<bool> hasPendingSyncs() async {
    // Get all classes and check each one
    final classes = HiveService.getAllClasses();
    for (final classModel in classes) {
      final unsyncedRecords = HiveService.getUnsyncedAttendance(classModel.id);
      if (unsyncedRecords.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Get pending sync information
  Future<List<PendingSyncInfo>> getPendingSyncInfo() async {
    final pendingSyncs = <PendingSyncInfo>[];
    
    // Get all classes
    final classes = HiveService.getAllClasses();
    
    for (final classModel in classes) {
      final unsyncedRecords = HiveService.getUnsyncedAttendance(classModel.id);
      if (unsyncedRecords.isNotEmpty) {
        // Group by session date
        final recordsByDate = <DateTime, List<AttendanceRecord>>{};
        for (final record in unsyncedRecords) {
          final dateKey = DateTime(record.sessionDate.year, record.sessionDate.month, record.sessionDate.day);
          if (!recordsByDate.containsKey(dateKey)) {
            recordsByDate[dateKey] = [];
          }
          recordsByDate[dateKey]!.add(record);
        }
        
        // Create pending sync info for each date
        recordsByDate.forEach((date, records) {
          final sessionType = _getSessionTypeForDate(date);
          pendingSyncs.add(PendingSyncInfo(
            classModel: classModel,
            sessionDate: date,
            sessionType: sessionType,
            recordCount: records.length,
            records: records,
          ));
        });
      }
    }
    
    return pendingSyncs;
  }

  /// Get session type for a specific date and time (always return morning since timings are removed)
  session_model.SessionType _getSessionTypeForDate(DateTime date) {
    // As per user request, remove all timing-based session logic
    // Always return morning session as default
    return session_model.SessionType.morning;
  }

  /// Manual sync trigger
  Future<void> triggerManualSync() async {
    await performSessionSync(manualTrigger: true);
  }

  /// Clean up the service
  void cleanup() {
    print('SessionSyncService: Cleaning up service');
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      print('SessionSyncService: Error removing lifecycle observer: $e');
    }
    _stopBackgroundSync();
    print('SessionSyncService: Service cleaned up');
  }

  /// Dispose of the service
  @override
  void dispose() {
    print('SessionSyncService: Disposing service');
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      print('SessionSyncService: Error removing lifecycle observer: $e');
    }
    _stopBackgroundSync();
    print('SessionSyncService: Service disposed');
    super.dispose();
  }

  /// Get sync status message
  String get statusMessage {
    if (_isSyncing) {
      return 'Session syncing...';
    }
    
    if (_lastSyncError != null) {
      return 'Error: $_lastSyncError';
    }
    
    if (_lastSyncTime != null) {
      final timeDiff = DateTime.now().difference(_lastSyncTime!);
      if (timeDiff.inMinutes < 1) {
        return 'Last session sync: ${timeDiff.inSeconds}s ago';
      } else if (timeDiff.inHours < 1) {
        return 'Last session sync: ${timeDiff.inMinutes}m ago';
      } else {
        return 'Last session sync: ${timeDiff.inHours}h ago';
      }
    }
    
    return 'No session syncs yet';
  }
}

/// Data class to hold pending sync information
class PendingSyncInfo {
  final ClassModel classModel;
  final DateTime sessionDate;
  final session_model.SessionType sessionType;
  final int recordCount;
  final List<AttendanceRecord> records;

  PendingSyncInfo({
    required this.classModel,
    required this.sessionDate,
    required this.sessionType,
    required this.recordCount,
    required this.records,
  });

  String get sessionName {
    return sessionType == session_model.SessionType.morning ? 'Morning' : 'Afternoon';
  }
}