import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/attendance_record.dart';
import '../models/class_model.dart';
import '../services/hive_service.dart';
import '../services/firebase_service.dart';
import '../services/google_sheets_service.dart';
import '../services/connectivity_service.dart';
import '../models/session_model.dart' as session_model;

/// Hybrid synchronization service that manages real-time and offline-first data entry
/// 
/// Core responsibilities:
/// 1. Real-time & Offline-First Data Entry
/// 2. Automatic Session Management
/// 3. Session-End Auto-Sync
/// 4. Duplicate Detection & Data Merging
class HybridSyncService extends ChangeNotifier {
  static final HybridSyncService _instance = HybridSyncService._internal();
  factory HybridSyncService() => _instance;
  HybridSyncService._internal();

  // Connectivity tracking
  bool _isOnline = false;
  bool _isInitialized = false;

  // Session timing constants (removed as per user request)
  // Morning Session: 9:30 AM - 12:30 PM
  // static const int morningStartHour = 9;
  // static const int morningStartMinute = 30;
  // static const int morningEndHour = 12;
  // static const int morningEndMinute = 30;
  // 
  // Afternoon Session: 1:30 PM - 4:30 PM
  // static const int afternoonStartHour = 13;
  // static const int afternoonStartMinute = 30;
  // static const int afternoonEndHour = 16;
  // static const int afternoonEndMinute = 30;

  // Background sync tracking
  Timer? _sessionEndTimer;
  Timer? _connectivityRecoveryTimer;
  Timer? _periodicSyncTimer;

  // Getters
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;

  /// Initialize the hybrid sync service
  Future<void> init() async {
    if (_isInitialized) return;
    
    print('HybridSyncService: Initializing service');
    
    // Check initial connectivity
    _isOnline = await ConnectivityService().checkConnectivity();
    print('HybridSyncService: Initial connectivity status: $_isOnline');
    
    // Check initial connectivity
    _isOnline = await ConnectivityService().checkConnectivity();
    print('HybridSyncService: Initial connectivity status: $_isOnline');
    
    // Register for connectivity changes
    ConnectivityService().registerOnlineCallback(_handleConnectivityOnline);
    
    // Start periodic sync checks
    // _startPeriodicSync(); // Disabled as per user request
    
    // Start session end monitoring
    // DISABLED: _scheduleSessionEndCheck();
    
    _isInitialized = true;
    print('HybridSyncService: Service initialized successfully');
  }

  /// Handle connectivity changes when device comes online
  void _handleConnectivityOnline() {
    final wasOnline = _isOnline;
    _isOnline = true;
    
    print('HybridSyncService: Connectivity changed to: $_isOnline');
    
    if (!wasOnline && _isOnline) {
      // Went online - trigger recovery sync
      _scheduleConnectivityRecovery();
    }
    
    notifyListeners();
  }

  /// Schedule connectivity recovery sync
  void _scheduleConnectivityRecovery() {
    _connectivityRecoveryTimer?.cancel();
    _connectivityRecoveryTimer = Timer(const Duration(seconds: 5), () {
      print('HybridSyncService: Triggering connectivity recovery sync');
      _performRecoverySync();
    });
  }

  /// Perform recovery sync for offline data
  Future<void> _performRecoverySync() async {
    if (!_isOnline) return;
    
    print('HybridSyncService: Performing recovery sync for offline data');
    
    try {
      // Get all classes
      final classes = HiveService.getAllClasses();
      print('HybridSyncService: Found ${classes.length} classes for recovery sync');
      
      for (final classModel in classes) {
        // Get unsynced records for this class
        final unsyncedRecords = HiveService.getUnsyncedAttendance(classModel.id);
        print('HybridSyncService: Found ${unsyncedRecords.length} unsynced records for class ${classModel.className}');
        
        // Sync each unsynced record to Firebase
        for (final record in unsyncedRecords) {
          try {
            await FirebaseService().writeAttendance(
              classModel: classModel,
              record: record,
            );
            
            // Mark as synced in Hive
            await HiveService.markAttendanceAsSynced([record.id]);
            print('HybridSyncService: Successfully synced record ${record.id} to Firebase');
          } catch (e) {
            print('HybridSyncService: Failed to sync record ${record.id} to Firebase: $e');
          }
        }
      }
      
      print('HybridSyncService: Recovery sync completed');
    } catch (e) {
      print('HybridSyncService: Error during recovery sync: $e');
    }
  }

  /// Start periodic sync checks
  /* DISABLED - Removed periodic sync as per user request
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      print('HybridSyncService: Performing periodic sync check');
      _performPeriodicSync();
    });
  }
  */

  /// Perform periodic sync
  /* DISABLED - Removed periodic sync as per user request
  Future<void> _performPeriodicSync() async {
    if (!_isOnline) return;
    
    print('HybridSyncService: Performing periodic sync');
    // This could be used for maintenance tasks or additional sync operations
  }
  */

  /// Schedule session end check
  /* DISABLED - Removed session end auto-sync as per user request */
  void _scheduleSessionEndCheck() {
    // _sessionEndTimer?.cancel();
    
    // final now = DateTime.now();
    // final nextSessionEndTime = _getNextSessionEndTime(now);
    
    // if (nextSessionEndTime != null) {
    //   final duration = nextSessionEndTime.difference(now);
    //   print('HybridSyncService: Scheduling session end check in ${duration.inMinutes} minutes');
    //   
    //   _sessionEndTimer = Timer(duration, () {
    //     print('HybridSyncService: Session end time reached, triggering auto-sync');
    //     _performSessionEndSync();
    //     // Schedule next check
    //     _scheduleSessionEndCheck();
    //   });
    // }
  }

  /// Get the next session end time
  DateTime? _getNextSessionEndTime(DateTime fromTime) {
    return null;
    
    /* ORIGINAL CODE - COMMENTED OUT AS PER USER REQUEST
    final today = DateTime(fromTime.year, fromTime.month, fromTime.day);
    
    // Morning session end
    final morningEnd = DateTime(
      fromTime.year, 
      fromTime.month, 
      fromTime.day, 
      morningEndHour, 
      morningEndMinute
    );
    
    // Afternoon session end
    final afternoonEnd = DateTime(
      fromTime.year, 
      fromTime.month, 
      fromTime.day, 
      afternoonEndHour, 
      afternoonEndMinute
    );
    
    // If we're past both session ends today, return tomorrow's morning end
    if (fromTime.isAfter(afternoonEnd)) {
      return morningEnd.add(const Duration(days: 1));
    }
    
    // If we're past morning but before afternoon end, return afternoon end
    if (fromTime.isAfter(morningEnd)) {
      return afternoonEnd;
    }
    
    // Otherwise return morning end
    return morningEnd;
    */
  }

  /// Perform session end sync
  /* DISABLED - Removed session end auto-sync as per user request */
  Future<void> _performSessionEndSync() async {
    // print('HybridSyncService: Performing session end sync');
    
    // try {
    //   // Get all classes
    //   // final classes = HiveService.getAllClasses();
    //   
    //   // for (final classModel in classes) {
    //   //   await _syncClassSessionToEnd(classModel);
    //   // }
    //   
    //   // print('HybridSyncService: Session end sync completed for all classes');
    // } catch (e) {
    //   // print('HybridSyncService: Error during session end sync: $e');
    // }
  }

  /// Sync a class session to its end (archive to Firestore and report to Google Sheets)
  Future<void> _syncClassSessionToEnd(ClassModel classModel) async {
    print('HybridSyncService: Syncing session to end for class ${classModel.className}');
    
    try {
      final now = DateTime.now();
      final sessionDate = DateTime(now.year, now.month, now.day);
      final sessionType = _getCurrentSessionType(now);
      
      // Get all attendance records for today's session
      final attendanceRecords = HiveService.getAttendanceForClass(classModel.id, sessionDate);
      print('HybridSyncService: Found ${attendanceRecords.length} attendance records for today');
      
      if (attendanceRecords.isEmpty) {
        print('HybridSyncService: No attendance records to sync for class ${classModel.className}');
        return;
      }
      
      // Archive to Firestore if online
      if (_isOnline) {
        try {
          await FirebaseService().syncSessionToFirestore(
            classId: classModel.id,
            sessionDate: sessionDate,
            sessionType: sessionType.name,
            records: attendanceRecords,
          );
          print('HybridSyncService: ✅ Archived session to Firestore for class ${classModel.className}');
        } catch (e) {
          print('HybridSyncService: ⚠️ Failed to archive session to Firestore: $e');
        }
        
        // Report to Google Sheets if online
        try {
          await _reportSessionToGoogleSheets(classModel, attendanceRecords, sessionDate, sessionType);
        } catch (e) {
          print('HybridSyncService: ⚠️ Failed to report session to Google Sheets: $e');
        }
      } else {
        print('HybridSyncService: 🔌 Device offline, deferring Firestore archival and Google Sheets reporting');
      }
      
      // Mark records as synced
      final recordIds = attendanceRecords.map((record) => record.id).toList();
      await HiveService.markAttendanceAsSynced(recordIds);
      await HiveService.saveLastSyncTime(classModel.id, now);
      
      print('HybridSyncService: ✅ Completed session end sync for class ${classModel.className}');
    } catch (e) {
      print('HybridSyncService: ❌ Error syncing class session to end: $e');
    }
  }

  /// Get current session type based on time
  session_model.SessionType _getCurrentSessionType(DateTime time) {
    // As per user request, remove all timing-based session logic
    // Always return morning session as default
    return session_model.SessionType.morning;
    
    /* ORIGINAL CODE - COMMENTED OUT AS PER USER REQUEST
    final hour = time.hour;
    final minute = time.minute;
    
    // Morning session: 9:30 AM - 12:30 PM
    if ((hour > morningStartHour || (hour == morningStartHour && minute >= morningStartMinute)) && 
        (hour < morningEndHour || (hour == morningEndHour && minute <= morningEndMinute))) {
      return session_model.SessionType.morning;
    }
    
    // Afternoon session: 1:30 PM - 4:30 PM
    if ((hour > afternoonStartHour || (hour == afternoonStartHour && minute >= afternoonStartMinute)) && 
        (hour < afternoonEndHour || (hour == afternoonEndHour && minute <= afternoonEndMinute))) {
      return session_model.SessionType.afternoon;
    }
    
    // Default to morning
    return session_model.SessionType.morning;
    */
  }

  /// Handle attendance record creation with hybrid sync
  Future<void> handleAttendanceRecordCreation({
    required ClassModel classModel,
    required AttendanceRecord record,
  }) async {
    print('HybridSyncService: Handling attendance record creation for ${record.studentName}');
    
    try {
      // Always save to local storage (Hive) immediately
      await HiveService.saveAttendanceRecord(record);
      print('HybridSyncService: Saved attendance record to local storage');
      
      // If online, also write to Firebase RTDB for real-time sync
      if (_isOnline) {
        try {
          await FirebaseService().writeAttendance(
            classModel: classModel,
            record: record,
          );
          print('HybridSyncService: Written attendance record to Firebase RTDB');
          
          // Mark as synced since we've successfully written to Firebase
          await HiveService.markAttendanceAsSynced([record.id]);
        } catch (e) {
          print('HybridSyncService: Failed to write to Firebase RTDB: $e');
          // Record will remain unsynced and be picked up by recovery sync later
        }
      } else {
        print('HybridSyncService: Device offline, record marked as unsynced');
        // Record is saved locally but not synced - will be synced when connectivity is restored
      }
    } catch (e) {
      print('HybridSyncService: Error handling attendance record creation: $e');
      rethrow;
    }
  }

  /// Detect and merge duplicate records
  Future<void> detectAndMergeDuplicates({
    required String classId,
    required DateTime sessionDate,
  }) async {
    print('HybridSyncService: Detecting and merging duplicates for class $classId');
    
    try {
      // Clean up duplicate attendance records in Hive
      await HiveService.cleanupDuplicateAttendanceRecords(classId, sessionDate);
      print('HybridSyncService: ✅ Duplicate cleanup completed');
    } catch (e) {
      print('HybridSyncService: ❌ Error during duplicate detection and merge: $e');
    }
  }

  /// Check if a scan is a duplicate based on recent scans
  bool isDuplicateScan(String scannedCode, DateTime scanTime, {Duration window = const Duration(seconds: 5)}) {
    // This would typically check against a cache of recent scans
    // For now, we'll return false to allow all scans
    // In a full implementation, you would maintain a cache of recent scans
    return false;
  }

  /// Merge attendance records from multiple sources, resolving conflicts
  List<AttendanceRecord> mergeAttendanceRecords(List<AttendanceRecord> localRecords, List<AttendanceRecord> remoteRecords) {
    print('HybridSyncService: Merging ${localRecords.length} local records with ${remoteRecords.length} remote records');
    
    // Create a map of records by student PIN for easy lookup
    final mergedRecords = <String, AttendanceRecord>{};
    
    // Add all local records first
    for (final record in localRecords) {
      mergedRecords[record.studentPinNumber] = record;
    }
    
    // Process remote records, applying conflict resolution rules
    for (final remoteRecord in remoteRecords) {
      final studentPin = remoteRecord.studentPinNumber;
      final localRecord = mergedRecords[studentPin];
      
      if (localRecord == null) {
        // No local record for this student, add the remote one
        mergedRecords[studentPin] = remoteRecord;
        print('HybridSyncService: Added remote record for student ${remoteRecord.studentName}');
      } else {
        // Both local and remote records exist, resolve conflict
        final resolvedRecord = _resolveAttendanceConflict(localRecord, remoteRecord);
        mergedRecords[studentPin] = resolvedRecord;
        
        // If the resolved record is different from the local one, log it
        if (resolvedRecord.id != localRecord.id) {
          print('HybridSyncService: Resolved conflict for student ${localRecord.studentName}');
          print('  Local: ${localRecord.status} at ${localRecord.scanTime}');
          print('  Remote: ${remoteRecord.status} at ${remoteRecord.scanTime}');
          print('  Resolved: ${resolvedRecord.status} at ${resolvedRecord.scanTime}');
        }
      }
    }
    
    final result = mergedRecords.values.toList();
    print('HybridSyncService: Merge completed, returning ${result.length} records');
    return result;
  }

  /// Resolve conflicts between two attendance records for the same student
  AttendanceRecord _resolveAttendanceConflict(AttendanceRecord local, AttendanceRecord remote) {
    // Conflict resolution rules:
    // 1. Present status takes precedence over absent
    // 2. More recent scan time takes precedence
    // 3. Remote records from other devices may have more up-to-date information
    
    // Rule 1: Present over absent
    if (local.status == AttendanceStatus.present && remote.status != AttendanceStatus.present) {
      return local;
    }
    if (remote.status == AttendanceStatus.present && local.status != AttendanceStatus.present) {
      return remote;
    }
    
    // Rule 2: More recent scan time
    if (remote.scanTime.isAfter(local.scanTime)) {
      return remote;
    }
    
    // Default to local record
    return local;
  }

  /// Report session attendance to Google Sheets via the web app
  Future<void> _reportSessionToGoogleSheets(
    ClassModel classModel, 
    List<AttendanceRecord> attendanceRecords, 
    DateTime sessionDate,
    session_model.SessionType sessionType,
  ) async {
    print('HybridSyncService: 📊 Reporting session to Google Sheets for class ${classModel.className}');
    
    try {
      // Create a job for the web app to process
      final jobData = {
        'classId': classModel.id,
        'jobType': 'attendance',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': {
          'date': '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}',
          'students': attendanceRecords.map((record) => {
            'pinNumber': record.studentPinNumber,
            'name': record.studentName,
            'status': record.status.name,
            'scanTime': record.scanTime.millisecondsSinceEpoch,
          }).toList(),
        },
      };
      
      // Write job to Firebase for the web app to process
      final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}_${classModel.id}';
      await FirebaseService().writeToPath('/outgoingToSheets/$jobId', jobData);
      
      print('HybridSyncService: ✅ Created job $jobId for Google Sheets reporting');
      
      // Optionally, trigger the web app to process jobs immediately
      await _triggerWebAppJobProcessing();
      
    } catch (e) {
      print('HybridSyncService: ❌ Error creating Google Sheets job: $e');
      rethrow;
    }
  }
  
  /// Trigger the web app to process jobs
  Future<void> _triggerWebAppJobProcessing() async {
    const webAppUrl = 'https://script.google.com/macros/s/AKfycbxRTSfDZrJt9VV4fY33S0lHneW1Q97YbcbBXhaNCxTygtypAmvCl3n0YKvBdzabR_K0_w/exec';
    
    try {
      print('HybridSyncService: 🔁 Triggering web app job processing');
      
      final response = await http.post(
        Uri.parse(webAppUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'processJobs'}),
      );
      
      if (response.statusCode == 200) {
        print('HybridSyncService: ✅ Web app job processing triggered successfully');
        print('Response: ${response.body}');
      } else {
        print('HybridSyncService: ⚠️ Web app returned status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('HybridSyncService: ❌ Error triggering web app job processing: $e');
    }
  }
  
  /// Manually trigger session end sync (for testing/debugging)
  Future<void> triggerManualSessionEndSync() async {
    print('HybridSyncService: Manual session end sync triggered');
    await _performSessionEndSync();
  }

  /// Dispose of the service
  void dispose() {
    print('HybridSyncService: Disposing service');
    _sessionEndTimer?.cancel();
    _connectivityRecoveryTimer?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}