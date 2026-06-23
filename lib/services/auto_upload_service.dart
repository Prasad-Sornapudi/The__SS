import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../models/session_model.dart';
import '../services/hive_service.dart';
import '../services/department_sheet_service.dart';
import '../services/google_sheets_service.dart';
import '../providers/sync_progress_provider.dart';

class AutoUploadService extends ChangeNotifier with WidgetsBindingObserver {
  // Singleton-like behavior for timers: key = "BatchName_SessionType"
  final Map<String, Timer> _batchTimers = {};
  
  // State
  bool _isUploading = false;
  String? _lastUploadError;
  DateTime? _lastUploadTime;
  int _totalUploaded = 0;
  double _uploadProgress = 0.0;
  
  // Getters
  bool get isUploading => _isUploading;
  String? get lastUploadError => _lastUploadError;
  DateTime? get lastUploadTime => _lastUploadTime;
  int get totalUploaded => _totalUploaded;
  double get uploadProgress => _uploadProgress;

  AutoUploadService() {
    // Initialize lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    // Initialize scheduler
    _initializeScheduler();
  }

  Future<void> _initializeScheduler() async {
    print('AutoUploadService: Initializing scheduler...');
    // Give time for Hive to open if starting up
    await Future.delayed(const Duration(seconds: 2));
    await reloadScheduledSettings();
  }

  /// Reloads all scheduled sync settings from SharedPreferences
  /// Call this whenever settings change in the UI.
  Future<void> reloadScheduledSettings() async {
    if (!kIsWeb) return; // Currently web-focused

    final prefs = await SharedPreferences.getInstance();
    
    // Ensure Hive is ready
    if (!HiveService.areBoxesOpen) {
       print('AutoUploadService: Hive boxes not open, attempting to open...');
       await HiveService.reopenBoxes();
    }
    
    final classes = HiveService.getAllClasses();
    final batches = classes
        .map((c) => c.sheetName ?? c.className)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    print('AutoUploadService: Found ${batches.length} batches to schedule: $batches');

    for (final batchId in batches) {
      // 1. Morning Settings
      final mEnabled = prefs.getBool('batch_${batchId}_morning_enabled') ?? true;
      if (mEnabled) {
        final mHour = prefs.getInt('batch_${batchId}_morning_hour') ?? 10;
        final mMinute = prefs.getInt('batch_${batchId}_morning_minute') ?? 50;
        _scheduleNextSync(batchId, SessionType.morning, TimeOfDay(hour: mHour, minute: mMinute));
      } else {
        _cancelTimer(batchId, SessionType.morning);
      }

      // 2. Afternoon Settings
      final aEnabled = prefs.getBool('batch_${batchId}_afternoon_enabled') ?? true;
      if (aEnabled) {
        final aHour = prefs.getInt('batch_${batchId}_afternoon_hour') ?? 14;
        final aMinute = prefs.getInt('batch_${batchId}_afternoon_minute') ?? 45;
        _scheduleNextSync(batchId, SessionType.afternoon, TimeOfDay(hour: aHour, minute: aMinute));
      } else {
        _cancelTimer(batchId, SessionType.afternoon);
      }
    }
  }

  void _cancelTimer(String batchId, SessionType type) {
    final key = '${batchId}_${type.toString()}';
    if (_batchTimers.containsKey(key)) {
      _batchTimers[key]?.cancel();
      _batchTimers.remove(key);
      print('AutoUploadService: Cancelled timer for $key');
    }
  }

  void _scheduleNextSync(String batchId, SessionType type, TimeOfDay time) {
    final key = '${batchId}_${type.toString()}';
    
    // Cancel existing
    _batchTimers[key]?.cancel();

    final now = DateTime.now();
    var scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If time passed today, schedule for tomorrow
    if (scheduledDateTime.isBefore(now)) {
      scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
    }

    final duration = scheduledDateTime.difference(now);
    print('AutoUploadService: Scheduled $type sync for $batchId in ${duration.inHours}h ${duration.inMinutes % 60}m (at $scheduledDateTime)');

    _batchTimers[key] = Timer(duration, () {
      print('⏰ AutoUploadService: Timer fired for $key');
      _performVerifiedBatchSync(batchId, type);
      // Re-schedule for next day
      _scheduleNextSync(batchId, type, time);
    });
  }

  /// THE CORE SYNC FUNCTION
  /// Performs a robust batch sync:
  /// 1. Identifies classes in batch
  /// 2. Loads attendance for specific Session Type (AM/PM)
  /// 3. Uploads to Main Sheet
  /// 4. Updates Department Sheets
  Future<void> _performVerifiedBatchSync(String batchId, SessionType sessionType) async {
    print('⏳ AutoUploadService: Starting Scheduled Sync for $batchId ($sessionType)');
    
    if (_isUploading) {
       print('AutoUploadService: Upload already in progress, skipping this trigger.');
       return;
    }

    _isUploading = true;
    notifyListeners();

    try {
       // Enable WakeLock
       try { await WakelockPlus.enable(); } catch (_) {}
       
       final allClasses = HiveService.getAllClasses();
       final batchClasses = allClasses.where((c) => (c.sheetName ?? c.className) == batchId).toList();
       
       print('AutoUploadService: Processing ${batchClasses.length} classes for $batchId');

       int successCount = 0;
       List<String> errors = [];

       for (final classModel in batchClasses) {
          try {
             // 1. Get Records for the Correct Session Date
             // We construct the date specifically for the session time (10AM or 2PM) 
             // to ensure HiveService.getAttendanceForClass hits the right bucket.
             final now = DateTime.now();
             DateTime sessionDate;
             
             if (sessionType == SessionType.morning) {
               // 10:00 AM
               sessionDate = DateTime(now.year, now.month, now.day, 10, 0); 
             } else {
               // 2:00 PM
               sessionDate = DateTime(now.year, now.month, now.day, 14, 0);
             }
             
             // Fetch from Hive (using the sessionDate logic)
             final records = HiveService.getAttendanceForClass(classModel.id, sessionDate);
             
             if (records.isEmpty) {
               print('   Skipping ${classModel.className}: No records found for $sessionDate');
               continue; 
             }
             
             print('   Syncing ${classModel.className}: ${records.length} records');

             // 2. Upload to Main Sheet
             await GoogleSheetsService.uploadAttendance(
               classModel: classModel,
               attendanceRecords: records,
               onProgress: (_) {}, 
             );

             // 3. Update Department Sheets
             await DepartmentSheetService.updateDepartmentSheets(
               classModel: classModel,
               attendanceRecords: records,
               sessionType: sessionType,
             );

             successCount++;
             print('   ✅ Synced ${classModel.className}');

          } catch (e) {
             print('   ❌ Failed ${classModel.className}: $e');
             errors.add('${classModel.className}: $e');
          }
       }
       
       _lastUploadTime = DateTime.now();
       if (errors.isEmpty) {
         print('✅ AutoUploadService: Batch $batchId ($sessionType) Completed Successfully ($successCount classes)');
       } else {
         print('⚠️ AutoUploadService: Batch $batchId ($sessionType) Completed with Errors: $errors');
       }

    } catch (e) {
       print('❌ AutoUploadService: Critical Error in Batch Sync: $e');
       _lastUploadError = e.toString();
    } finally {
       _isUploading = false;
       notifyListeners();
       try { await WakelockPlus.disable(); } catch (_) {}
    }
  }

  // --- Methods for external manual trigger (if needed) ---
  Future<void> triggerBatchSyncNow(String batchId, SessionType type) async {
    await _performVerifiedBatchSync(batchId, type);
  }

  // --- Legacy / Backward Compatibility Methods used by UI ---
  // The UI calls this when switching classes. 
  // We no longer rely on this for the main sync logic (which is now scheduled/batch-based),
  // but we keep the method to avoid breaking the UI.
  void startAutoUpload(ClassModel classModel, {bool triggerSync = true}) {
     print('AutoUploadService: Class switched to ${classModel.className}. Legacy auto-upload trigger ignored (using scheduled batch syncs instead).');
     // No-op or lightweight logic here if needed.
  }

  void stopAutoUpload() {
    print('AutoUploadService: stopAutoUpload called (Legacy).');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('AutoUploadService: App resumed, reloading settings...');
      reloadScheduledSettings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var timer in _batchTimers.values) timer.cancel();
    super.dispose();
  }

  String get statusMessage {
    if (_isUploading) return 'Auto-Syncing...';
    if (_lastUploadError != null) return 'Last Auto-Sync Error: $_lastUploadError';
    if (_lastUploadTime != null) {
       return 'Last Auto-Sync: ${_lastUploadTime!.hour}:${_lastUploadTime!.minute}';
    }
    return 'Detailed Auto-Sync Active';
  }
}