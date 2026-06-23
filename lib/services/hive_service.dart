import 'package:hive_flutter/hive_flutter.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../models/session_model.dart';

class HiveService {
  static const String classesBoxName = 'classes';
  static const String attendanceBoxName = 'attendance';
  static const String settingsBoxName = 'settings';
  static const String syncTimesBoxName = 'syncTimes';
  static const String userRoleKey = 'userRole';
  static const String userDisplayNameKey = 'userDisplayName';
  static const String userNameKey = 'userName';

  static Box<ClassModel>? _classesBox;
  static Box<AttendanceRecord>? _attendanceBox;
  static Box<dynamic>? _settingsBox;
  static Box<DateTime>? _syncTimesBox;

  static Future<void> init() async {
    try {
      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ClassModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(StudentAdapter());
      }
      // UploadType adapter registration removed - replaced with Firebase real-time sync
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(AttendanceRecordAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(AttendanceStatusAdapter());
      }
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(ScanMethodAdapter());
      }
      // Register SessionModel adapter
      if (!Hive.isAdapterRegistered(7)) {
        Hive.registerAdapter(SessionModelAdapter());
      }
      if (!Hive.isAdapterRegistered(8)) {
        Hive.registerAdapter(SessionTypeAdapter());
      }

      // Open boxes
      try {
        _classesBox = await Hive.openBox<ClassModel>(classesBoxName);
        _attendanceBox = await Hive.openBox<AttendanceRecord>(attendanceBoxName);
        _settingsBox = await Hive.openBox(settingsBoxName);
        _syncTimesBox = await Hive.openBox<DateTime>(syncTimesBoxName);
      } catch (e) {
        print('Error opening Hive boxes: $e');
        // If boxes fail to open, try to delete and recreate them
        try {
          await Hive.deleteBoxFromDisk(classesBoxName);
        } catch (e) {
          print('Failed to delete classes box: $e');
        }
        try {
          await Hive.deleteBoxFromDisk(attendanceBoxName);
        } catch (e) {
          print('Failed to delete attendance box: $e');
        }
        try {
          await Hive.deleteBoxFromDisk(settingsBoxName);
        } catch (e) {
          print('Failed to delete settings box: $e');
        }
        try {
          await Hive.deleteBoxFromDisk(syncTimesBoxName);
        } catch (e) {
          print('Failed to delete sync times box: $e');
        }
        
        // Try to open boxes again
        _classesBox = await Hive.openBox<ClassModel>(classesBoxName);
        _attendanceBox = await Hive.openBox<AttendanceRecord>(attendanceBoxName);
        _settingsBox = await Hive.openBox(settingsBoxName);
        _syncTimesBox = await Hive.openBox<DateTime>(syncTimesBoxName);
      }
      print('HiveService initialized successfully');
    } catch (e) {
      print('HiveService.init() failed: $e');
      // Don't rethrow - allow the app to continue with reduced functionality
    }
  }

  // Classes management
  static Box<ClassModel> get classesBox {
    if (_classesBox == null) {
      throw StateError('Hive not initialized - classesBox is null');
    }
    if (!_classesBox!.isOpen) {
      throw StateError('Hive classesBox is not open');
    }
    return _classesBox!;
  }
  
  static Box<AttendanceRecord> get attendanceBox {
    if (_attendanceBox == null) {
      throw StateError('Hive not initialized - attendanceBox is null');
    }
    if (!_attendanceBox!.isOpen) {
      throw StateError('Hive attendanceBox is not open');
    }
    return _attendanceBox!;
  }
  
  static Box<dynamic> get settingsBox {
    if (_settingsBox == null) {
      throw StateError('Hive not initialized - settingsBox is null');
    }
    if (!_settingsBox!.isOpen) {
      throw StateError('Hive settingsBox is not open');
    }
    return _settingsBox!;
  }

  // Class operations
  static Future<void> saveClass(ClassModel classModel) async {
    if (_classesBox == null || !_classesBox!.isOpen) {
      print('Warning: Hive not initialized or classesBox not open');
      return;
    }
    try {
      print('Attempting to save class: ${classModel.className} with ID: ${classModel.id}');
      print('Students count: ${classModel.students.length}');
      print('Service account key provided: ${classModel.serviceAccountKey != null}');
      
      await _classesBox!.put(classModel.id, classModel);
      print('Class saved successfully to Hive');
    } catch (e, stackTrace) {
      print('Error saving class to Hive: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static ClassModel? getClass(String id) {
    if (_classesBox == null || !_classesBox!.isOpen) {
      print('Warning: Hive not initialized or classesBox not open');
      return null;
    }
    try {
      return _classesBox!.get(id);
    } catch (e) {
      print('Error getting class from Hive: $e');
      return null;
    }
  }

  static List<ClassModel> getAllClasses() {
    if (_classesBox == null || !_classesBox!.isOpen) {
      print('Warning: Hive not initialized or classesBox not open');
      return [];
    }
    try {
      return _classesBox!.values.toList();
    } catch (e) {
      print('Error getting all classes from Hive: $e');
      return [];
    }
  }

  static Future<void> deleteClass(String id) async {
    if (_classesBox == null || !_classesBox!.isOpen) {
      print('Warning: Hive not initialized or classesBox not open');
      return;
    }
    try {
      await _classesBox!.delete(id);
      // Also delete related attendance records
      await deleteAttendanceForClass(id);
    } catch (e) {
      print('Error deleting class from Hive: $e');
    }
  }

  // Attendance operations
  static Future<void> saveAttendanceRecord(AttendanceRecord record) async {
    if (_attendanceBox == null || !_attendanceBox!.isOpen) {
      print('Warning: Hive not initialized or attendanceBox not open');
      return;
    }
    try {
      await _attendanceBox!.put(record.id, record);
    } catch (e) {
      print('Error saving attendance record to Hive: $e');
    }
  }

  static List<AttendanceRecord> getAttendanceForClass(String classId, DateTime sessionDate) {
    if (_attendanceBox == null || !_attendanceBox!.isOpen) {
      print('Warning: Hive not initialized or attendanceBox not open');
      return [];
    }
    print('Getting attendance for class: $classId, date: $sessionDate');
    final allRecords = _attendanceBox!.values.toList();
    print('Total records in database: ${allRecords.length}');
    
    final filteredRecords = allRecords
        .where((record) {
            final matches = record.classId == classId && 
                           _isSameSession(record.sessionDate, sessionDate);
            if (record.classId == classId) {
              print('Record for same class: ${record.studentName} - ${record.sessionDate} vs $sessionDate - matches: $matches');
            }
            return matches;
        })
        .toList();
    
    print('Filtered records count: ${filteredRecords.length}');
    
    // Group records by student PIN number and select the best record for each student
    // Using the priority rules specified in the requirements:
    // 1. Present over absent
    // 2. Synced over unsynced
    // 3. Most recent timestamp last
    final deduplicatedRecords = <String, AttendanceRecord>{};
    for (final record in filteredRecords) {
      final existingRecord = deduplicatedRecords[record.studentPinNumber];
      
      // If no existing record for this student, add it
      if (existingRecord == null) {
        deduplicatedRecords[record.studentPinNumber] = record;
      } 
      // If there's an existing record, apply our priority rules
      else {
        final selectedRecord = _selectBestRecord(existingRecord, record);
        deduplicatedRecords[record.studentPinNumber] = selectedRecord;
      }
    }
    
    final result = deduplicatedRecords.values.toList();
    print('Deduplicated records count: ${result.length}');
    return result;
  }

  /// Select the best record based on priority rules
  /// Priority 1: Present over absent
  /// Priority 2: Synced over unsynced
  /// Priority 3: Most recent timestamp last
  static AttendanceRecord _selectBestRecord(AttendanceRecord record1, AttendanceRecord record2) {
    // Rule 1: Prefer present records over absent records
    if (record1.status == AttendanceStatus.present && record2.status != AttendanceStatus.present) {
      return record1;
    }
    if (record2.status == AttendanceStatus.present && record1.status != AttendanceStatus.present) {
      return record2;
    }
    
    // Rule 2: For records with same status, prefer synced records
    if (record1.status == record2.status) {
      if (record1.isSyncedToSheet && !record2.isSyncedToSheet) {
        return record1;
      }
      if (record2.isSyncedToSheet && !record1.isSyncedToSheet) {
        return record2;
      }
      
      // Rule 3: For records with same status and sync status, prefer the one with the more recent scan time
      if (record1.isSyncedToSheet == record2.isSyncedToSheet) {
        return record1.scanTime.isAfter(record2.scanTime) ? record1 : record2;
      }
    }
    
    // Default to record1 if no clear preference
    return record1;
  }

  static List<AttendanceRecord> getAllAttendanceForClass(String classId) {
    if (_attendanceBox == null || !_attendanceBox!.isOpen) {
      print('Warning: Hive not initialized or attendanceBox not open');
      return [];
    }
    try {
      return _attendanceBox!.values
          .where((record) => record.classId == classId)
          .toList();
    } catch (e) {
      print('Error getting all attendance for class from Hive: $e');
      return [];
    }
  }

  static Future<void> deleteAttendanceRecord(String id) async {
    if (_attendanceBox == null || !_attendanceBox!.isOpen) {
      print('Warning: Hive not initialized or attendanceBox not open');
      return;
    }
    try {
      await _attendanceBox!.delete(id);
    } catch (e) {
      print('Error deleting attendance record from Hive: $e');
    }
  }

  static Future<void> deleteAttendanceForClass(String classId) async {
    if (_attendanceBox == null || !_attendanceBox!.isOpen) {
      print('Warning: Hive not initialized or attendanceBox not open');
      return;
    }
    try {
      final records = _attendanceBox!.values
          .where((record) => record.classId == classId)
          .toList();
      
      for (final record in records) {
        await _attendanceBox!.delete(record.id);
      }
    } catch (e) {
      print('Error deleting attendance for class from Hive: $e');
    }
  }

  static Future<void> clearAttendanceForClassAndDate(String classId, DateTime sessionDate) async {
    if (_attendanceBox == null || !_attendanceBox!.isOpen) {
      print('Warning: Hive not initialized or attendanceBox not open');
      return;
    }
    try {
      final records = getAttendanceForClass(classId, sessionDate);
      for (final record in records) {
        await _attendanceBox!.delete(record.id);
      }
    } catch (e) {
      print('Error clearing attendance for class and date from Hive: $e');
    }
  }

  // Settings operations
  static Future<void> setSetting(String key, dynamic value) async {
    if (_settingsBox == null || !_settingsBox!.isOpen) {
      print('Warning: Hive not initialized or settingsBox not open');
      return;
    }
    try {
      await _settingsBox!.put(key, value);
    } catch (e) {
      print('Error setting Hive setting $key: $e');
    }
  }

  static T? getSetting<T>(String key, [T? defaultValue]) {
    if (_settingsBox == null || !_settingsBox!.isOpen) {
      print('Warning: Hive not initialized or settingsBox not open');
      return defaultValue;
    }
    try {
      return _settingsBox!.get(key, defaultValue: defaultValue) as T?;
    } catch (e) {
      print('Error getting setting from Hive: $e');
      return defaultValue;
    }
  }

  static Future<void> saveUserRole(String role) async {
    try {
      await setSetting(userRoleKey, role);
    } catch (e) {
      print('Error saving user role: $e');
    }
  }

  static String? getUserRole() {
    return getSetting<String>(userRoleKey);
  }

  static Future<void> saveUserDisplayName(String displayName) async {
    try {
      await setSetting(userDisplayNameKey, displayName);
    } catch (e) {
      print('Error saving user display name: $e');
    }
  }

  static String? getUserDisplayName() {
    return getSetting<String>(userDisplayNameKey);
  }

  static Future<void> saveUserName(String userName) async {
    try {
      await setSetting(userNameKey, userName);
    } catch (e) {
      print('Error saving user name: $e');
    }
  }

  static String? getUserName() {
    return getSetting<String>(userNameKey);
  }

  static String? get activeClassId {
    try {
      return getSetting<String>('activeClassId');
    } catch (e) {
      print('Error getting active class ID from Hive: $e');
      return null;
    }
  }
  
  static Future<void> setActiveClassId(String? classId) async {
    try {
      await setSetting('activeClassId', classId);
    } catch (e) {
      print('Error setting active class ID in Hive: $e');
    }
  }

  // Sync time operations
  static Future<void> saveLastSyncTime(String classId, DateTime time) async {
    if (_syncTimesBox == null || !_syncTimesBox!.isOpen) {
      print('Warning: Hive not initialized or syncTimesBox not open');
      return;
    }
    try {
      await _syncTimesBox!.put(classId, time);
    } catch (e) {
      print('Error saving last sync time to Hive: $e');
    }
  }

  static DateTime? getLastSyncTime(String classId) {
    if (_syncTimesBox == null || !_syncTimesBox!.isOpen) {
      print('Warning: Hive not initialized or syncTimesBox not open');
      return null;
    }
    try {
      return _syncTimesBox!.get(classId);
    } catch (e) {
      print('Error getting last sync time from Hive: $e');
      return null;
    }
  }

  // Utility methods
  // Check if two dates are the same session (Morning vs Afternoon)
  // Morning: < 13:00 (1:00 PM)
  // Afternoon: >= 13:00 (1:00 PM)
  static bool _isSameSession(DateTime date1, DateTime date2) {
    // First check if they are the same day
    final isSameDay = date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
           
    if (!isSameDay) return false;
    
    // Then check if they are in the same session (AM vs PM)
    // Morning Session ends at 1:00 PM (13:00)
    // Any time before 13:00 is Morning. 13:00 and after is Afternoon.
    final isDate1Am = date1.hour < 13;
    final isDate2Am = date2.hour < 13;
    
    return isDate1Am == isDate2Am;
  }

  // Check if a student is already marked present for a session
  static bool isStudentPresent(String classId, String pinNumber, DateTime sessionDate) {
    final records = getAttendanceForClass(classId, sessionDate);
    return records.any((record) => 
        record.studentPinNumber == pinNumber && 
        record.status == AttendanceStatus.present);
  }

  // Get attendance record for a specific student on a specific date
  static AttendanceRecord? getStudentAttendance(String classId, String pinNumber, DateTime sessionDate) {
    final records = getAttendanceForClass(classId, sessionDate);
    try {
      return records.firstWhere((record) => record.studentPinNumber == pinNumber);
    } catch (e) {
      return null;
    }
  }

  // Update sync status for attendance records
  static Future<void> markAttendanceAsSynced(List<String> recordIds) async {
    if (_attendanceBox == null || !_attendanceBox!.isOpen) {
      print('Warning: Hive not initialized or attendanceBox not open');
      return;
    }
    try {
      for (final recordId in recordIds) {
        final record = _attendanceBox!.get(recordId);
        if (record != null) {
          final updatedRecord = record.copyWith(isSyncedToSheet: true);
          await _attendanceBox!.put(recordId, updatedRecord);
        }
      }
    } catch (e) {
      print('Error marking attendance as synced in Hive: $e');
    }
  }

  // Get unsynced attendance records for a class
  static List<AttendanceRecord> getUnsyncedAttendance(String classId) {
    if (_attendanceBox == null || !_attendanceBox!.isOpen) {
      print('Warning: Hive not initialized or attendanceBox not open');
      return [];
    }
    try {
      final unsyncedRecords = _attendanceBox!.values
          .where((record) => 
              record.classId == classId && 
              !record.isSyncedToSheet)
          .toList();
      
      print('Found ${unsyncedRecords.length} unsynced attendance records for class $classId');
      for (final record in unsyncedRecords) {
        print('  - ${record.studentName} (${record.studentPinNumber}) on ${record.sessionDate} - ${record.status}');
      }
      
      // Sort records by session date to ensure proper upload order
      unsyncedRecords.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
      
      return unsyncedRecords;
    } catch (e) {
      print('Error getting unsynced attendance from Hive: $e');
      return [];
    }
  }

  // Cleanup old data (optional, for performance)
  static Future<void> cleanupOldData({int daysToKeep = 30}) async {
    if (_attendanceBox == null || !_attendanceBox!.isOpen) {
      print('Warning: Hive not initialized or attendanceBox not open');
      return;
    }
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final oldRecords = _attendanceBox!.values
          .where((record) => record.sessionDate.isBefore(cutoffDate))
          .toList();
      
      for (final record in oldRecords) {
        await _attendanceBox!.delete(record.id);
      }
    } catch (e) {
      print('Error cleaning up old data from Hive: $e');
    }
  }

  // Cleanup duplicate attendance records for a class and date
  static Future<void> cleanupDuplicateAttendanceRecords(String classId, DateTime sessionDate) async {
    if (_attendanceBox == null || !_attendanceBox!.isOpen) {
      print('Warning: Hive not initialized or attendanceBox not open');
      return;
    }
    try {
      print('Cleaning up duplicate attendance records for class: $classId, date: $sessionDate');
      
      // Get all records for this class and date
      final allRecords = _attendanceBox!.values
          .where((record) => 
              record.classId == classId && 
              _isSameSession(record.sessionDate, sessionDate))
          .toList();
      
      print('Found ${allRecords.length} records to check for duplicates');
      
      // Group records by student PIN number
      final recordsByStudent = <String, List<AttendanceRecord>>{};
      for (final record in allRecords) {
        if (!recordsByStudent.containsKey(record.studentPinNumber)) {
          recordsByStudent[record.studentPinNumber] = [];
        }
        recordsByStudent[record.studentPinNumber]!.add(record);
      }
      
      int deletedCount = 0;
      
      // For each student with multiple records, keep only the best one
      for (final entry in recordsByStudent.entries) {
        final studentPin = entry.key;
        final records = entry.value;
        
        if (records.length > 1) {
          print('Found ${records.length} records for student $studentPin, cleaning up duplicates');
          
          // Sort records to determine which one to keep using the same priority rules:
          // 1. Present over absent
          // 2. Synced over unsynced
          // 3. Most recent timestamp last
          records.sort((a, b) {
            // Rule 1: Prefer present records over absent records
            if (a.status == AttendanceStatus.present && b.status != AttendanceStatus.present) return -1;
            if (a.status != AttendanceStatus.present && b.status == AttendanceStatus.present) return 1;
            
            // Rule 2: For records with same status, prefer synced records
            if (a.status == b.status) {
              if (a.isSyncedToSheet && !b.isSyncedToSheet) return -1;
              if (b.isSyncedToSheet && !a.isSyncedToSheet) return 1;
              
              // Rule 3: For records with same status and sync status, prefer the one with the more recent scan time
              if (a.isSyncedToSheet == b.isSyncedToSheet) {
                return b.scanTime.compareTo(a.scanTime); // More recent first
              }
            }
            
            return 0;
          });
          
          // Delete all records except the first one (which is the best one)
          for (int i = 1; i < records.length; i++) {
            await deleteAttendanceRecord(records[i].id);
            deletedCount++;
            print('Deleted duplicate record for student $studentPin: ${records[i].id}');
          }
        }
      }
      
      print('Cleaned up $deletedCount duplicate attendance records');
    } catch (e) {
      print('Error cleaning up duplicate attendance records from Hive: $e');
    }
  }

  // Check if all boxes are open
  static bool get areBoxesOpen => 
    (_classesBox?.isOpen ?? false) && 
    (_attendanceBox?.isOpen ?? false) && 
    (_settingsBox?.isOpen ?? false);
  
  // Reopen boxes if they've been closed
  static Future<void> reopenBoxes() async {
    try {
      if ((_classesBox != null) && !_classesBox!.isOpen) {
        _classesBox = await Hive.openBox<ClassModel>(classesBoxName);
      }
      if ((_attendanceBox != null) && !_attendanceBox!.isOpen) {
        _attendanceBox = await Hive.openBox<AttendanceRecord>(attendanceBoxName);
      }
      if ((_settingsBox != null) && !_settingsBox!.isOpen) {
        _settingsBox = await Hive.openBox(settingsBoxName);
      }
      if ((_syncTimesBox != null) && !_syncTimesBox!.isOpen) {
        _syncTimesBox = await Hive.openBox<DateTime>(syncTimesBoxName);
      }
    } catch (e) {
      print('Error reopening Hive boxes: $e');
    }
  }
}