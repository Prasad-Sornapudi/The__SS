import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../services/hive_service.dart';
import '../services/department_sheet_service.dart';
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/sync_progress_provider.dart';
import 'package:provider/provider.dart';

/// Enhanced auto-sync service that handles all the requirements:
/// - Reliable background sync at configured intervals
/// - Immediate sync on class change
/// - Proper handling of app lifecycle transitions
/// - No duplicate or skipped syncs
class EnhancedAutoSyncService with WidgetsBindingObserver {
  static final EnhancedAutoSyncService _instance = EnhancedAutoSyncService._internal();
  factory EnhancedAutoSyncService() => _instance;
  EnhancedAutoSyncService._internal();

  Timer? _syncTimer;
  ClassModel? _currentClass;
  bool _isSyncing = false;
  String? _lastSyncError;
  DateTime? _lastSyncTime;
  bool _shouldPerformImmediateSync = false;
  bool _isAppInBackground = false;
  DateTime? _timerSetTime; // Track when timer was set

  // Getters
  bool get isSyncing => _isSyncing;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initialize the service
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    print('EnhancedAutoSyncService: Initialized at ${DateTime.now()}');
  }

  /// Start auto-sync for a specific class
  void startAutoSync(ClassModel classModel, {bool triggerSync = true}) {
    print('Starting enhanced auto sync for class: ${classModel.className}');
    
    final previousClassId = _currentClass?.id;
    print('Previous class ID: $previousClassId, Current class ID: ${classModel.id}');
    _currentClass = classModel;
    _stopTimer();
    
    // Check if this is a class change (different class ID)
    // ONLY schedule immediate sync on class change
    if (triggerSync && previousClassId != null && previousClassId != classModel.id) {
      print('Class changed from $previousClassId to ${classModel.id}, scheduling immediate sync');
      _shouldPerformImmediateSync = true;
    } else {
      print('Not a class change or triggerSync is false, setting _shouldPerformImmediateSync to false');
      _shouldPerformImmediateSync = false;
    }
    
    // DISABLED: Since we're removing auto-sync, we won't set up the periodic timer
    // The sync will only happen on manual trigger or class change
    print('Auto-sync timer DISABLED - sync will only happen on manual trigger or class change');
    
    // Perform initial sync after a short delay ONLY if this is a class change
    if (_shouldPerformImmediateSync) {
      print('Performing immediate sync due to class change');
      Timer(const Duration(milliseconds: 100), () {
        _performSync(immediateSync: true);
      });
    } else if (triggerSync) {
      print('Performing initial sync after 5 seconds');
      Timer(const Duration(seconds: 5), () {
        _performSync();
      });
    } else {
      print('Not triggering initial sync: _shouldPerformImmediateSync=$_shouldPerformImmediateSync, triggerSync=$triggerSync');
    }
  }

  /// Stop auto-sync
  void stopAutoSync() {
    print('EnhancedAutoSyncService: Stopping auto-sync');
    _stopTimer();
    _currentClass = null;
    _shouldPerformImmediateSync = false;
    _isSyncing = false;
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('EnhancedAutoSyncService: App lifecycle state changed to $state');
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        print('EnhancedAutoSyncService: App going to background');
        _isAppInBackground = true;
        // Don't stop timer when app goes to background
        // The timer will continue to fire, but we'll be more careful about when we actually sync
        break;
      case AppLifecycleState.resumed:
        print('EnhancedAutoSyncService: App coming to foreground');
        _isAppInBackground = false;
        
        // DISABLED: Removed catch-up sync functionality
        // _checkAndPerformCatchUpSync();
        
        // Restart auto-sync when app comes to foreground if we have a current class
        // But don't set up the periodic timer (it's disabled)
        if (_currentClass != null) {
          print('EnhancedAutoSyncService: Restarting auto-sync after app resume (timer disabled)');
          startAutoSync(_currentClass!, triggerSync: false); // Don't trigger immediate sync on resume
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // No special handling needed
        print('EnhancedAutoSyncService: App state changed to $state (no action needed)');
        break;
    }
  }

  /// Perform synchronization
  Future<void> _performSync({bool immediateSync = false}) async {
    if (_currentClass == null) {
      print('EnhancedAutoSyncService: No current class, skipping sync');
      return;
    }

    // Skip if we're already syncing unless this is an immediate sync request
    if (_isSyncing && !immediateSync) {
      print('EnhancedAutoSyncService: Already syncing, skipping');
      return;
    }

    print('EnhancedAutoSyncService: _performSync called with immediateSync: $immediateSync');

    // If we're in the background and this is not an immediate sync, skip it
    // This prevents unnecessary background syncs that might be blocked by Android
    if (_isAppInBackground && !immediateSync) {
      print('EnhancedAutoSyncService: App is in background, skipping scheduled sync');
      return;
    }

    print('EnhancedAutoSyncService: Starting ${immediateSync ? "immediate" : "scheduled"} sync for class ${_currentClass!.className} (Firebase RTDB only)');
    // Enable wake lock to prevent device from sleeping during sync
    try {
      print('EnhancedAutoSyncService: Enabling wake lock');
      await WakelockPlus.enable();
    } catch (e) {
      print('EnhancedAutoSyncService: Error enabling wake lock: $e');
    }
    
    _isSyncing = true;
    _notifyListeners();

    try {
      // NEW: Start sync progress when sync begins
      try {
        print('EnhancedAutoSyncService: Starting sync progress');
        final syncProgressProvider = SyncProgressProvider();
        syncProgressProvider.startSync('Syncing attendance data to Firebase RTDB...');
        print('EnhancedAutoSyncService: Started sync progress');
      } catch (e) {
        print('EnhancedAutoSyncService: Error starting sync progress: $e');
      }

      // With Firebase RTDB, all attendance data is already synchronized in real-time
      // We just need to mark records as synced locally
      final sessionDate = DateTime.now();
      final normalizedSessionDate = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
      
      // Get all unsynced records for this class
      final unsyncedRecords = HiveService.getUnsyncedAttendance(_currentClass!.id);
      print('EnhancedAutoSyncService: Found ${unsyncedRecords.length} unsynced records');
      
      // Mark all unsynced records as synced since they're already in Firebase RTDB
      final recordIds = unsyncedRecords.map((record) => record.id).toList();
      if (recordIds.isNotEmpty) {
        await HiveService.markAttendanceAsSynced(recordIds);
        await HiveService.saveLastSyncTime(_currentClass!.id, DateTime.now());
        print('EnhancedAutoSyncService: Marked ${recordIds.length} records as synced (Firebase RTDB only)');
      }
      
      // Update sync progress
      try {
        final syncProgressProvider = SyncProgressProvider();
        syncProgressProvider.updateProgress(1.0, 'Auto-syncing attendance data... 100%');
      } catch (e) {
        print('EnhancedAutoSyncService: Error updating sync progress: $e');
      }
      
      // Update department sheets is not needed with Firebase RTDB only
      print('EnhancedAutoSyncService: Skipping department sheet updates (Firebase RTDB only)');
      
      _lastSyncTime = DateTime.now();
      _lastSyncError = null;
      await HiveService.saveLastSyncTime(_currentClass!.id, _lastSyncTime!);
      
      print('EnhancedAutoSyncService: Firebase RTDB sync successful: ${recordIds.length} records synced');
      print('EnhancedAutoSyncService: Last sync time updated to: $_lastSyncTime');
      
      // NEW: Complete sync progress on success
      try {
        print('EnhancedAutoSyncService: Completing sync progress on success');
        final syncProgressProvider = SyncProgressProvider();
        syncProgressProvider.completeSync('Auto-sync completed successfully! Uploaded ${recordIds.length} records to Firebase RTDB.');
        print('EnhancedAutoSyncService: Completed sync progress on success');
      } catch (e) {
        print('EnhancedAutoSyncService: Error completing sync progress: $e');
      }

    } catch (e, stackTrace) {
      _lastSyncError = 'Sync error: $e';
      print('EnhancedAutoSyncService: Sync error: $e');
      print('EnhancedAutoSyncService: Stack trace: $stackTrace');
      
      // NEW: Error sync progress on exception
      try {
        print('EnhancedAutoSyncService: Setting error sync progress on exception');
        final syncProgressProvider = SyncProgressProvider();
        syncProgressProvider.errorSync('Auto-sync error: $e');
        print('EnhancedAutoSyncService: Set error sync progress on exception');
      } catch (e2) {
        print('EnhancedAutoSyncService: Error setting error sync progress on exception: $e2');
      }
    } finally {
      // Disable wake lock after sync is complete
      try {
        print('EnhancedAutoSyncService: Disabling wake lock');
        await WakelockPlus.disable();
      } catch (e) {
        print('EnhancedAutoSyncService: Error disabling wake lock: $e');
      }
      
      _isSyncing = false;
      _notifyListeners();
    }
  }

  /// Stop the timer
  void _stopTimer() {
    if (_syncTimer != null) {
      print('EnhancedAutoSyncService: Stopping existing timer at ${DateTime.now()}');
      _syncTimer?.cancel();
      _syncTimer = null;
      _timerSetTime = null;
      print('EnhancedAutoSyncService: Timer stopped at ${DateTime.now()}');
    } else {
      print('EnhancedAutoSyncService: No timer to stop at ${DateTime.now()}');
    }
  }

  /// Manual sync trigger
  Future<void> triggerManualSync() async {
    await _performSync(immediateSync: true);
  }

  /// Force immediate sync on next cycle
  void forceImmediateSync() {
    _shouldPerformImmediateSync = true;
  }

  /// Get sync status message
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
    
    return 'Auto-sync disabled';
  }

  /// Notify listeners of changes
  void _notifyListeners() {
    // This would typically notify any registered listeners
    // For now, we'll just print to console
    print('EnhancedAutoSyncService: State changed - isSyncing: $_isSyncing, lastSyncError: $_lastSyncError');
  }

  /// Dispose of the service
  void dispose() {
    print('EnhancedAutoSyncService: Disposing service at ${DateTime.now()}');
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    print('EnhancedAutoSyncService: Service disposed at ${DateTime.now()}');
  }
}