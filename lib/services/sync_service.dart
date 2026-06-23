import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../services/hive_service.dart';
import '../services/department_sheet_service.dart';
import '../services/firebase_service.dart';
import '../providers/attendance_provider.dart';
import '../constants/app_constants.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;
  String? _lastSyncError;
  DateTime? _lastSyncTime;
  int _syncIntervalSeconds = 30; // Default sync interval
  
  // Track last session sync to avoid duplicate syncs
  String? _lastSyncedSessionKey;

  // Getters
  bool get isSyncing => _isSyncing;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get syncIntervalSeconds => _syncIntervalSeconds;

  // Start synchronization service
  void startSyncService() {
    print('Starting sync service...');
    _stopTimer();
    
    // DISABLED: Removed periodic timer for sync service as per user request
    // _syncTimer = Timer.periodic(
    //   Duration(seconds: _syncIntervalSeconds),
    //   (timer) => _performSync(),
    // );
    
    // DISABLED: Removed initial sync as per user request
    // Timer(const Duration(seconds: 5), () => _performSync());
    print('SyncService: Timer DISABLED - sync will only happen on manual trigger');
  }

  // Stop synchronization service
  void stopSyncService() {
    print('Stopping sync service...');
    _stopTimer();
  }

  // Set sync interval
  void setSyncInterval(int seconds) {
    _syncIntervalSeconds = seconds;
    if (_syncTimer != null) {
      startSyncService(); // Restart with new interval
    }
  }

  // Perform synchronization
  Future<void> _performSync() async {
    print('=== SYNC SERVICE _performSync CALLED (Firebase RTDB only) ===');
    
    if (_isSyncing) {
      print('Sync already in progress, skipping...');
      return;
    }
    
    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();
    
    try {
      print('Performing Firebase RTDB sync...');
      
      final classes = HiveService.getAllClasses();
      print('Found ${classes.length} classes to sync');
      
      for (final classModel in classes) {
        print('Processing class: ${classModel.className}');
        
        // Get all unsynced records for this class
        final unsyncedRecords = HiveService.getUnsyncedAttendance(classModel.id);
        print('Found ${unsyncedRecords.length} unsynced records for class ${classModel.className}');
        
        // With Firebase RTDB, all records are already synchronized in real-time
        // Just mark them as synced locally
        final recordIds = unsyncedRecords.map((record) => record.id).toList();
        if (recordIds.isNotEmpty) {
          await HiveService.markAttendanceAsSynced(recordIds);
          await HiveService.saveLastSyncTime(classModel.id, DateTime.now());
          print('Marked ${recordIds.length} records as synced for class ${classModel.className} (Firebase RTDB only)');
        }
      }
      
      // Update department sheets is not needed with Firebase RTDB only
      print('Skipping department sheet updates (Firebase RTDB only)');
      
      _lastSyncTime = DateTime.now();
      print('✅ Firebase RTDB sync completed successfully');
      
    } catch (e, stackTrace) {
      _lastSyncError = 'Sync error: $e';
      print('Sync error: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  // Check if session has ended and perform sync to Firestore
  Future<void> _checkAndPerformSessionSync() async {
    // As per user request, remove all timing-based session logic
    return;
    
    /* ORIGINAL CODE - COMMENTED OUT AS PER USER REQUEST
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    
    String? sessionTypeToSync;
    
    // Check Morning Session End (12:30 PM)
    // Trigger window: 12:30 PM - 1:00 PM
    if (hour == 12 && minute >= 30) {
      sessionTypeToSync = 'morning';
    }
    
    // Check Afternoon Session End (4:30 PM)
    // Trigger window: 4:30 PM - 5:00 PM
    if (hour == 16 && minute >= 30) {
      sessionTypeToSync = 'afternoon';
    }
    
    if (sessionTypeToSync == null) return;
    
    final dateKey = '${now.year}-${now.month}-${now.day}';
    final sessionKey = '${dateKey}_$sessionTypeToSync';
    
    // Check if already synced this session
    if (_lastSyncedSessionKey == sessionKey) {
      print('Session $sessionKey already synced, skipping');
      return;
    }
    
    print('=== SESSION END DETECTED: $sessionTypeToSync ===');
    print('Initiating Session End Sync to Firestore...');
    
    final classes = HiveService.getAllClasses();
    
    for (final classModel in classes) {
      try {
        // Get records for this session
        // Note: We assume records for today match the session type based on time
        // In a more complex app, we might filter by scan time
        final todayRecords = HiveService.getAttendanceForClass(
          classModel.id, 
          DateTime(now.year, now.month, now.day)
        );
        
        if (todayRecords.isEmpty) continue;
        
        // 1. Sync to Firestore
        await FirebaseService().syncSessionToFirestore(
          classId: classModel.id,
          sessionDate: now,
          sessionType: sessionTypeToSync,
          records: todayRecords,
        );
        
        print('✅ Session End Sync completed for class ${classModel.className}');
        
      } catch (e) {
        print('❌ Session End Sync failed for class ${classModel.className}: $e');
      }
    }
    
    // Mark this session as synced
    _lastSyncedSessionKey = sessionKey;
    print('Session End Sync process completed');
    */
  }

  void _stopTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  // Get sync status message
  String get statusMessage {
    if (_isSyncing) {
      return 'Syncing...';
    }
    
    if (_lastSyncError != null) {
      return 'Error: $_lastSyncError';
    }
    
    if (_lastSyncTime != null) {
      final timeDiff = DateTime.now().difference(_lastSyncTime!);
      if (timeDiff.inMinutes < 1) {
        return 'Last sync: ${timeDiff.inSeconds}s ago';
      } else if (timeDiff.inHours < 1) {
        return 'Last sync: ${timeDiff.inMinutes}m ago';
      } else {
        return 'Last sync: ${timeDiff.inHours}h ago';
      }
    }
    
    return 'Not synced yet';
  }
}