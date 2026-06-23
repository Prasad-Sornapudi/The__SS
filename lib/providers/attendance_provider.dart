import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../models/qr_payload.dart';
import '../models/session_model.dart' as session_model;
import '../services/hive_service.dart';
import '../services/google_sheets_service.dart';
import '../services/attendance_data_service.dart';
import '../services/firebase_service.dart';
import '../services/department_sheet_service.dart';
import '../services/connectivity_service.dart';
import '../services/hybrid_sync_service.dart';
import '../constants/app_constants.dart';

class AttendanceProvider with ChangeNotifier {
  // Map to store attendance records per class
  Map<String, List<AttendanceRecord>> _classAttendanceRecords = {};
  String? _activeClassId; // Track the currently active class
  
  // OPTIMIZATION: Cached lookup maps for O(1) student search
  final Map<String, Student> _securityCodeMap = {};
  final Map<String, Student> _pinMap = {};
  
  // Stream subscription for real-time updates
  StreamSubscription<List<AttendanceRecord>>? _attendanceSubscription;
  
  // Add a listener for when the active class changes
  void setActiveClassId(String? classId) {
    if (_activeClassId != classId) {
      _activeClassId = classId;
      print('AttendanceProvider: Active class ID changed to: $classId');
      // Clear cache to force rebuild for the new class
      _securityCodeMap.clear();
      _pinMap.clear();
      notifyListeners();
    }
  }

  // Build lookup maps for fast O(1) scanning
  void _buildLookupCache(ClassModel classModel) {
    print('Building lookup cache for class: ${classModel.className} (${classModel.students.length} students)');
    _securityCodeMap.clear();
    _pinMap.clear();

    for (final student in classModel.students) {
      // Map PIN
      _pinMap[student.pinNumber.trim().toLowerCase()] = student;
      
      // Map Security Codes
      for (final code in student.securityCodes) {
        if (code.isNotEmpty) {
          _securityCodeMap[code.trim().toLowerCase()] = student;
        }
      }
    }
    print('Cache built: ${_pinMap.length} PINs, ${_securityCodeMap.length} Security Codes');
  }
  
  // Get attendance records for the active class
  List<AttendanceRecord> get attendanceRecords {
    if (_activeClassId == null) {
      print('attendanceRecords getter called, but no active class - returning empty list');
      return [];
    }
    
    final records = _classAttendanceRecords[_activeClassId!] ?? [];
    print('attendanceRecords getter called for class $_activeClassId, returning ${records.length} records');
    return records;
  }
  
  // Set attendance records for the active class
  set attendanceRecords(List<AttendanceRecord> records) {
    if (_activeClassId == null) {
      print('attendanceRecords setter called, but no active class - ignoring');
      return;
    }
    
    print('attendanceRecords setter called for class $_activeClassId with ${records.length} records');
    _classAttendanceRecords[_activeClassId!] = records;
    notifyListeners();
  }
  
  DateTime _sessionDate = DateTime.now();
  bool _isLoading = false;
  String? _error;
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  // Getters
  DateTime get sessionDate => _sessionDate;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasAttendance => attendanceRecords.isNotEmpty;
  
  // Check if attendance data is from a comprehensive sync (contains remote data)
  bool get hasComprehensiveAttendance {
    // Check if any records are marked as synced to sheet and have comprehensive IDs
    return attendanceRecords.any((record) => 
        record.id.contains('_comprehensive') || record.isSyncedToSheet);
  }

  // Initialize provider for a specific class and date
  Future<void> initialize(String? classId, [DateTime? date, session_model.SessionType? overrideSessionType]) async {
    if (classId == null) return;
    
    // Set the active class ID
    _activeClassId = classId;
    
    // Normalize the session date to canonical times
    final sessionDate = date ?? DateTime.now();
    
    int canonicalHour;
    if (overrideSessionType != null) {
      // Use explicit session type if provided
      canonicalHour = overrideSessionType == session_model.SessionType.morning ? 9 : 14;
    } else {
      // Fallback to time-based logic
      final hour = sessionDate.hour;
      // Morning if < 13:30, Afternoon if >= 13:30
      final isAm = hour < 13 || (hour == 13 && sessionDate.minute < 30);
      canonicalHour = isAm ? 9 : 14;
    }
    
    _sessionDate = DateTime(sessionDate.year, sessionDate.month, sessionDate.day, canonicalHour, 0, 0);
    
    print('Initializing attendance provider for class: $classId, session date: $_sessionDate${overrideSessionType != null ? " (Explicit: $overrideSessionType)" : ""}');
    
    // Use ensureAttendanceLoadedForClass instead of loadAttendanceForSession to avoid overwriting data
    await ensureAttendanceLoadedForClass(classId, _sessionDate, overrideSessionType: overrideSessionType);
  }

  // Load attendance records for a specific class and session date
  Future<void> loadAttendanceForSession(String classId, DateTime sessionDate, {session_model.SessionType? overrideSessionType}) async {
    try {
      _setLoading(true);
      
      int canonicalHour;
      if (overrideSessionType != null) {
         // Use explicit session type
        canonicalHour = overrideSessionType == session_model.SessionType.morning ? 9 : 14;
      } else {
        // Normalize session date to canonical times (Morning: 9:00, Afternoon: 14:00)
        final hour = sessionDate.hour;
        // Morning if < 13:30, Afternoon if >= 13:30
        final isAm = hour < 13 || (hour == 13 && sessionDate.minute < 30);
        canonicalHour = isAm ? 9 : 14;
      }
      
      _sessionDate = DateTime(sessionDate.year, sessionDate.month, sessionDate.day, canonicalHour, 0, 0);
      
      print('Loading attendance for class: $classId, date: $_sessionDate (SessionType: ${overrideSessionType ?? (_sessionDate.hour == 9 ? "Morning" : "Afternoon")})');
      
      // Force reload from database to ensure fresh data
      final records = AttendanceDataService.loadAttendanceRecords(classId, _sessionDate);
      _classAttendanceRecords[classId] = records;
      
      // Debug: Show what records were loaded
      print('Loaded ${records.length} attendance records for class $classId, session:');
      for (final record in records) {
        print('  - ${record.studentName} (${record.studentPinNumber}): ${record.status} (Synced: ${record.isSyncedToSheet})');
      }
      
      _clearError();
      notifyListeners();
      
      // Fetch and merge data from Firebase (background operation)
      _fetchAndMergeFirebaseAttendance(classId, _sessionDate);
      
    } catch (e) {
      print('Error loading attendance: $e');
      _setError('Failed to load attendance: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Ensure attendance data is loaded for the class (without changing active class)
  Future<void> ensureAttendanceLoadedForClass(String classId, DateTime sessionDate, {session_model.SessionType? overrideSessionType}) async {
    // Only load if we don't already have data for this class to avoid overwriting scanned/synced data
    if (!_classAttendanceRecords.containsKey(classId) || _classAttendanceRecords[classId]!.isEmpty) {
      print('Ensuring attendance data is loaded for class: $classId');
      
      // Determine canonical date if override provided
      DateTime targetDate = sessionDate;
      if (overrideSessionType != null) {
          int canonicalHour = overrideSessionType == session_model.SessionType.morning ? 9 : 14;
          targetDate = DateTime(sessionDate.year, sessionDate.month, sessionDate.day, canonicalHour, 0, 0);
          // Update the provider's session date if this is for the current session
          _sessionDate = targetDate; 
      }
      
      final records = AttendanceDataService.loadAttendanceRecords(classId, targetDate);
      _classAttendanceRecords[classId] = records;
      print('Loaded ${records.length} records for class $classId');
    } else {
      print('Attendance data already loaded for class: $classId (${_classAttendanceRecords[classId]!.length} records)');
    }
    
    // Always try to fetch/merge latest from Firebase in background to ensure we are up to date
    await _fetchAndMergeFirebaseAttendance(classId, sessionDate);
    
    // SETUP REAL-TIME STREAM LISTENER
    // Cancel any existing subscription first to avoid duplicates
    await _attendanceSubscription?.cancel();
    
    try {
      if (FirebaseService().isInitialized) {
        final sessionType = _getSessionTypeForFirebase(sessionDate);
        print('AttendanceProvider: Setting up real-time stream listener for $classId ($sessionType)');
        
        _attendanceSubscription = FirebaseService().getAttendanceStream(
          classId: classId,
          sessionDate: sessionDate,
          sessionType: sessionType
        ).listen((remoteRecords) {
          print('AttendanceProvider: Received real-time update with ${remoteRecords.length} records');
          
          if (remoteRecords.isNotEmpty) {
            // Merge with local records
            final localRecords = _classAttendanceRecords[classId] ?? [];
            final mergedRecords = HybridSyncService().mergeAttendanceRecords(localRecords, remoteRecords);
            
            // Update local state
            _classAttendanceRecords[classId] = mergedRecords;
            
            // Persist merged records to Hive
            for (final record in mergedRecords) {
              AttendanceDataService.saveAttendanceRecord(record);
            }
            
            // If this is the active class, notify listeners
            if (_activeClassId == classId) {
              notifyListeners();
            }
          }
        }, onError: (e) {
          print('AttendanceProvider: Stream error: $e');
        });
      }
    } catch (e) {
      print('AttendanceProvider: Failed to setup stream: $e');
    }
    
    // If this is the active class, notify listeners to update the UI
    if (_activeClassId == classId) {
      notifyListeners();
    }
  }
  
  // Get the active class ID
  String? get activeClassId => _activeClassId;
  
  // Check if we have attendance data for a specific class
  bool hasAttendanceForClass(String classId) {
    return _classAttendanceRecords.containsKey(classId) && _classAttendanceRecords[classId]!.isNotEmpty;
  }
  
  // Get attendance records for a specific class
  List<AttendanceRecord> getAttendanceRecordsForClass(String classId) {
    return _classAttendanceRecords[classId] ?? [];
  }
  
  // Set attendance records for a specific class
  void setAttendanceRecordsForClass(String classId, List<AttendanceRecord> records) {
    _classAttendanceRecords[classId] = records;
    // If this is the active class, notify listeners
    if (_activeClassId == classId) {
      notifyListeners();
    }
  }
  
  // Clear attendance records for a specific class
  void clearAttendanceRecordsForClass(String classId) {
    _classAttendanceRecords.remove(classId);
    // If this is the active class, notify listeners
    if (_activeClassId == classId) {
      notifyListeners();
    }
  }

  /// Get the data expiration time (10:00 PM of the current day)
  DateTime getDataExpirationTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 22, 0, 0); // 10:00 PM
  }

  /// Check if data should be preserved (before 10:00 PM)
  bool shouldPreserveData() {
    final now = DateTime.now();
    final cutoffTime = getDataExpirationTime();
    return now.isBefore(cutoffTime);
  }
  
  // Process QR scan
  Future<QRValidationResult> processQRScan(
    String qrData, 
    ClassModel classModel,
    {ScanMethod scanMethod = ScanMethod.qrCamera}
  ) async {
    try {
      print('Processing QR scan: $qrData');
      
      // Ensure Hive boxes are open
      if (!HiveService.areBoxesOpen) {
        print('Hive boxes are closed in processQRScan, reopening...');
        await HiveService.reopenBoxes();
      }
      
      // Prevent rapid consecutive scans of the same code
      if (_isDuplicateQuickScan(qrData)) {
        print('Duplicate quick scan detected, ignoring');
        return QRValidationResult.valid(
          studentName: 'Duplicate Scan',
          pinNumber: qrData,
          isDuplicate: true,
        ).copyWithMessage('Please wait before scanning again');
      }

      _lastScannedCode = qrData;
      _lastScanTime = DateTime.now();

      // Parse QR payload
      final QRPayload payload = QRPayload.parse(qrData);
      
      if (!payload.isValid()) {
        return QRValidationResult.invalid(
          message: AppConstants.invalidQrMessage,
          pinNumber: payload.pinNumber,
        );
      }

      // Find student in class roster
      Student? student = _findStudentByPayload(payload, classModel.students);
      
      if (student == null) {
        return QRValidationResult.invalid(
          message: AppConstants.studentNotFoundMessage,
          pinNumber: payload.pinNumber,
        );
      }
      
      // STRICT VALIDATION: Check if student belongs to this combo
      // Prevents "AWS + JFS" students from scanning into "AWS + GenAI"
      // Normalize by keeping ONLY alphanumeric characters (removes spaces, +, &, -, etc.)
      final String studentCombo = student.combo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final String classCombo = classModel.className.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      
      // Only apply strict check if both appear to be combo classes
      // Heuristic: If they are identical after normalization, it's a match.
      // If they are different, we check if we should enforce it.
      // We enforce if the Class Name seems specific (length > 5?) or contains keywords?
      // Better: We ENFORCE it always if the student HAS a combo and the class HAS a name
      // BUT we must allow "Batch 1" to accept "AWS".
      // Let's stick to the "+" / "&" heuristic for the CLASS name to identify it as a Combo Class.
      
      bool isMismatch = false;
      
      // Check for combo indicators in the ORIGINAL class name (before normalization)
      final String originalClass = classModel.className;
      if (originalClass.contains('+') || originalClass.contains('&') || originalClass.toLowerCase().contains('combo')) {
         // Strict mode for Combo Classes
         if (studentCombo.isNotEmpty && studentCombo != classCombo) {
            isMismatch = true;
         }
      }
      
      if (isMismatch) {
        final displayStudent = student.combo.isEmpty ? 'Unknown' : student.combo;
        final displayClass = classModel.className;
        print('❌ Cross-Combo mismatch! Student: "$displayStudent" (norm: $studentCombo), Class: "$displayClass" (norm: $classCombo)');
        
        return QRValidationResult.invalid(
           message: 'Combo Mismatch!\nStudent: "$displayStudent"\nClass: "$displayClass"',
           pinNumber: payload.pinNumber,
        );
      }

      // Check if student is already marked present (Optimize this check)
      final existingRecord = HiveService.getStudentAttendance(
        classModel.id, 
        student.pinNumber, 
        _sessionDate
      );

      if (existingRecord != null && existingRecord.status == AttendanceStatus.present) {
        // Already present - return immediately
        // Refresh the timestamp in background
        _markAttendance(
          classModel: classModel,
          student: student,
          scannedCode: qrData,
          scanMethod: scanMethod,
        );
        
        return QRValidationResult.valid(
          studentName: student.name,
          pinNumber: student.pinNumber,
          isDuplicate: true,
        );
      }

      // Mark attendance - FIRE AND FORGET (don't await)
      // This is the key optimization for speed
      _markAttendance(
        classModel: classModel,
        student: student,
        scannedCode: qrData,
        scanMethod: scanMethod,
      ).catchError((e) {
        print('BACKGROUND ERROR marking attendance: $e');
      });

      // Valid processing - Return IMMEDIATELY
      return QRValidationResult.valid(
        studentName: student.name,
        pinNumber: student.pinNumber,
        isDuplicate: false,
      );

    } catch (e, stackTrace) {
      print('Error processing QR scan: $e');
      return QRValidationResult.invalid(
        message: 'Error processing scan: $e',
      );
    }
  }

  // Mark student attendance
  Future<void> _markAttendance({
    required ClassModel classModel,
    required Student student,
    required String scannedCode,
    required ScanMethod scanMethod,
  }) async {
    print('Marking attendance for: ${student.name} (${student.pinNumber})');
    print('Session date: $_sessionDate');
    
    // Ensure Hive boxes are open
    if (!HiveService.areBoxesOpen) {
      print('Hive boxes are closed, reopening...');
      await HiveService.reopenBoxes();
    }
    
    // Use _sessionDate directly as it is already normalized to canonical time (Morning/Afternoon)
    final normalizedSessionDate = _sessionDate;
    
    // Delete any existing record for this student on this date first
    final existingRecord = HiveService.getStudentAttendance(
      classModel.id, 
      student.pinNumber, 
      normalizedSessionDate
    );
    if (existingRecord != null) {
      await HiveService.deleteAttendanceRecord(existingRecord.id);
      // Remove from class-specific records
      final classRecords = _classAttendanceRecords[classModel.id] ?? [];
      classRecords.removeWhere((r) => r.id == existingRecord.id);
      _classAttendanceRecords[classModel.id] = classRecords;
      print('Removed existing record for student ${student.name}');
    }
    
    final record = AttendanceRecord(
      id: '${classModel.id}_${student.pinNumber}_${normalizedSessionDate.millisecondsSinceEpoch}',
      classId: classModel.id,
      studentPinNumber: student.pinNumber,
      studentName: student.name,
      scanTime: DateTime.now(),
      status: AttendanceStatus.present,
      scannedCode: scannedCode,
      scanMethod: scanMethod,
      sessionDate: normalizedSessionDate,
      isSyncedToSheet: false, // Mark as not synced initially for offline support
    );

    print('Creating attendance record with ID: ${record.id}');
    print('Record session date: ${record.sessionDate}');
    
    await AttendanceDataService.saveAttendanceRecord(record);
    
    // Update class-specific records - ensure no duplicates
    final classRecords = _classAttendanceRecords[classModel.id] ?? [];
    classRecords.removeWhere((r) => 
        r.classId == classModel.id && 
        r.studentPinNumber == student.pinNumber &&
        _isSameSession(r.sessionDate, normalizedSessionDate)
    );
    classRecords.add(record);
    _classAttendanceRecords[classModel.id] = classRecords;
    
    // If this is the active class, notify listeners
    if (_activeClassId == classModel.id) {
      notifyListeners();
    }
    
    print('Attendance marked successfully. Total present for class ${classModel.id}: ${classRecords.length}');
    
    // Sync to Firebase
    try {
      if (FirebaseService().isInitialized) {
        // Fire and forget - don't await so UI doesn't lag
        FirebaseService().writeAttendance(
          classModel: classModel,
          record: record,
        ).catchError((e) {
          print('⚠️ Error syncing to Firebase: $e');
        });
      }
    } catch (e) {
      print('⚠️ Error initiating Firebase sync: $e');
    }
  }

  // Mark student as absent
  Future<void> markAbsent({
    required ClassModel classModel,
    required Student student,
  }) async {
    print('Marking student as absent: ${student.name} (${student.pinNumber})');
    print('Session date: $_sessionDate');
    
    // Ensure Hive boxes are open
    if (!HiveService.areBoxesOpen) {
      print('Hive boxes are closed, reopening...');
      await HiveService.reopenBoxes();
    }
    
    // Use _sessionDate directly as it is already normalized to canonical time (Morning/Afternoon)
    final normalizedSessionDate = _sessionDate;
    
    // Delete any existing record for this student on this date first
    final existingRecord = HiveService.getStudentAttendance(
      classModel.id, 
      student.pinNumber, 
      normalizedSessionDate
    );
    if (existingRecord != null) {
      await HiveService.deleteAttendanceRecord(existingRecord.id);
      // Remove from class-specific records
      final classRecords = _classAttendanceRecords[classModel.id] ?? [];
      classRecords.removeWhere((r) => r.id == existingRecord.id);
      _classAttendanceRecords[classModel.id] = classRecords;
      print('Removed existing record for student ${student.name}');
    }
    
    final record = AttendanceRecord(
      id: '${classModel.id}_${student.pinNumber}_${normalizedSessionDate.millisecondsSinceEpoch}',
      classId: classModel.id,
      studentPinNumber: student.pinNumber,
      studentName: student.name,
      scanTime: DateTime.now(),
      status: AttendanceStatus.absent,
      scannedCode: '',
      scanMethod: ScanMethod.manual,
      sessionDate: normalizedSessionDate,
      isSyncedToSheet: false, // Mark as not synced initially for offline support
    );

    print('Creating absent record with ID: ${record.id}');
    print('Record session date: ${record.sessionDate}');
    
    await AttendanceDataService.saveAttendanceRecord(record);
    
    // Update class-specific records - ensure no duplicates
    final classRecords = _classAttendanceRecords[classModel.id] ?? [];
    classRecords.removeWhere((r) => 
        r.classId == classModel.id && 
        r.studentPinNumber == student.pinNumber &&
        _isSameSession(r.sessionDate, normalizedSessionDate)
    );
    classRecords.add(record);
    _classAttendanceRecords[classModel.id] = classRecords;
    
    // If this is the active class, notify listeners
    if (_activeClassId == classModel.id) {
      notifyListeners();
    }
    
    print('Absent record created successfully. Total records for class ${classModel.id}: ${classRecords.length}');
    
    // Sync to Firebase
    try {
      if (FirebaseService().isInitialized) {
        // Fire and forget
        FirebaseService().writeAttendance(
          classModel: classModel,
          record: record,
        ).catchError((e) {
          print('⚠️ Error syncing absent status to Firebase: $e');
        });
      }
    } catch (e) {
      print('⚠️ Error initiating Firebase sync for absent status: $e');
    }
  }

  // Revoke attendance (delete record)
  Future<bool> revokeAttendance(String recordId) async {
    try {
      // Ensure Hive boxes are open
      if (!HiveService.areBoxesOpen) {
        print('Hive boxes are closed, reopening...');
        await HiveService.reopenBoxes();
      }
      
      // Find the record across all classes
      AttendanceRecord? record;
      String? recordClassId;
      
      for (final entry in _classAttendanceRecords.entries) {
        final classId = entry.key;
        final records = entry.value;
        try {
          record = records.firstWhere((r) => r.id == recordId);
          recordClassId = classId;
          break;
        } catch (e) {
          // Record not found in this class, continue
        }
      }
      
      if (record != null && recordClassId != null) {
        print('Revoking attendance: Deleting record ${record.id} for student ${record.studentName}');
        
        // DELETE from local DB
        await HiveService.deleteAttendanceRecord(recordId);
        
        // Remove from class-specific records (local state)
        final classRecords = _classAttendanceRecords[recordClassId] ?? [];
        classRecords.removeWhere((r) => r.id == recordId);
        _classAttendanceRecords[recordClassId] = classRecords;
        
        // If this is the active class, notify listeners
        if (_activeClassId == recordClassId) {
          notifyListeners();
        }

        // DELETE from Firebase
        try {
           if (FirebaseService().isInitialized) {
             print('Syncing deletion to Firebase for ${record.studentPinNumber}');
             await FirebaseService().deleteAttendanceRecord(
               classId: recordClassId,
               sessionDate: record.sessionDate,
               studentPinNumber: record.studentPinNumber,
             );
           }
        } catch (e) {
           print('⚠️ Error syncing deletion to Firebase: $e');
        }
      }
      return true;
    } catch (e) {
      _setError('Failed to revoke attendance: $e');
      return false;
    }
  }

  // Helper method to sync updated record to Firebase
  void _syncToFirebase(String classId, AttendanceRecord record) {
     // We need ClassModel to sync to Firebase, but revokeAttendance only has ID
     // In a real app we'd look up the class model, but for now we'll skip 
     // or improved revokeAttendance signature in future
     // TODO: Implement Firebase sync for revoked attendance if needed
     print('⚠️ revokeAttendance Firebase sync not fully implemented (requires ClassModel)');
  }

  // Clear all attendance for current session
  Future<void> clearSessionAttendance(String classId) async {
    try {
      _setLoading(true);
      await HiveService.clearAttendanceForClassAndDate(classId, _sessionDate);
      // Also clear from our in-memory cache
      _classAttendanceRecords[classId] = [];
      _classAttendanceRecords[classId] = [];
      
      // If this is the active class, notify listeners
      if (_activeClassId == classId) {
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to clear attendance: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Get attendance summary for current session
  AttendanceSessionSummary getSessionSummary(ClassModel classModel) {
    final classRecords = _classAttendanceRecords[classModel.id] ?? [];
    final presentStudents = classRecords
        .where((record) => record.status == AttendanceStatus.present)
        .toList();

    final presentPinNumbers = presentStudents
        .map((record) => record.studentPinNumber)
        .toSet();

    final absentStudents = classModel.students
        .where((student) => !presentPinNumbers.contains(student.pinNumber))
        .map((student) => student.pinNumber)
        .toList();

    return AttendanceSessionSummary(
      classId: classModel.id,
      sessionDate: _sessionDate,
      totalStudents: classModel.students.length,
      presentCount: presentStudents.length,
      absentCount: absentStudents.length,
      presentStudents: presentStudents,
      absentStudents: absentStudents,
    );
  }

  // Get present students sorted by scan time (most recent first)
  List<AttendanceRecord> getPresentStudents() {
    final classRecords = attendanceRecords; // This will use the active class records
    print('getPresentStudents() called, current attendanceRecords length: ${classRecords.length}');
    final presentCount = classRecords.where((record) => record.status == AttendanceStatus.present).length;
    print('Number of present students: $presentCount');
    
    // Log some sample data for debugging
    if (classRecords.isNotEmpty) {
      print('Sample attendance records:');
      for (int i = 0; i < classRecords.length && i < 3; i++) {
        final record = classRecords[i];
        print('  Record $i: ${record.studentName} (${record.studentPinNumber}) - ${record.status} - ${record.isSyncedToSheet ? "Synced" : "Not Synced"}');
      }
      if (classRecords.length > 3) {
        print('  ... and ${classRecords.length - 3} more records');
      }
    }
    
    final present = classRecords
        .where((record) => record.status == AttendanceStatus.present)
        .toList();
    
    present.sort((a, b) => b.scanTime.compareTo(a.scanTime));
    print('Returning ${present.length} present students from getPresentStudents()');
    return present;
  }

  // Get absent students from class roster
  List<Student> getAbsentStudents(ClassModel classModel) {
    final classRecords = _classAttendanceRecords[classModel.id] ?? [];
    final presentPinNumbers = classRecords
        .where((record) => record.status == AttendanceStatus.present)
        .map((record) => record.studentPinNumber)
        .toSet();

    return classModel.students
        .where((student) => !presentPinNumbers.contains(student.pinNumber))
        .toList();
  }

  // Get all students with their attendance status
  List<StudentAttendanceStatus> getAllStudentsWithStatus(ClassModel classModel) {
    final classRecords = _classAttendanceRecords[classModel.id] ?? [];
    final presentRecords = Map<String, AttendanceRecord>.fromEntries(
      classRecords
          .where((record) => record.status == AttendanceStatus.present)
          .map((record) => MapEntry(record.studentPinNumber, record))
    );

    return classModel.students.map((student) {
      final record = presentRecords[student.pinNumber];
      return StudentAttendanceStatus(
        student: student,
        attendanceRecord: record,
        isPresent: record != null,
      );
    }).toList();
  }

  // Change session date
  Future<void> changeSessionDate(String classId, DateTime newDate) async {
    await loadAttendanceForSession(classId, newDate);
  }

  // Search students by name or pin number
  List<StudentAttendanceStatus> searchStudents(
    ClassModel classModel, 
    String query
  ) {
    if (query.isEmpty) return getAllStudentsWithStatus(classModel);

    final allStudents = getAllStudentsWithStatus(classModel);
    return allStudents.where((status) {
      final student = status.student;
      return student.name.toLowerCase().contains(query.toLowerCase()) ||
             student.pinNumber.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Private helper methods
  bool _isDuplicateQuickScan(String qrData) {
    if (_lastScannedCode == null || _lastScanTime == null) return false;
    
    final timeDifference = DateTime.now().difference(_lastScanTime!);
    return _lastScannedCode == qrData && 
           timeDifference < AppConstants.duplicateScanWindow;
  }

  Student? _findStudentByPayload(QRPayload payload, List<Student> students) {
    // 1. Ensure Cache is Valid (Lazy fallback)
    // If our map is empty but we have students, we need to rebuild it.
    // Ideally this is done on class load, but this is a safety net.
    if (_pinMap.isEmpty && students.isNotEmpty) {
       // We can't easily access ClassModel here to be pure, but we can rebuild efficiently from the list provided.
       // NOTE: This rebuild is O(N) but happens only ONCE per session/class load.
       print('⚠️ Cache miss in scan (building now)...');
       for (final student in students) {
         _pinMap[student.pinNumber.trim().toLowerCase()] = student;
         for (final code in student.securityCodes) {
            if (code.isNotEmpty) _securityCodeMap[code.trim().toLowerCase()] = student;
         }
       }
    }

    // 2. PRIMARY STRATEGY: O(1) Security Code Lookup
    if (payload.securityCode != null && payload.securityCode!.isNotEmpty) {
      final codeKey = payload.securityCode!.trim().toLowerCase();
      final match = _securityCodeMap[codeKey];
      if (match != null) {
        // print('✓ Fast Match: Security Code'); // Optional: Uncomment for debug
        return match;
      }
    }
    
    // 3. SECONDARY STRATEGY: O(1) PIN Lookup
    final pinKey = payload.pinNumber.trim().toLowerCase();
    final match = _pinMap[pinKey];
    if (match != null) {
      // print('✓ Fast Match: PIN'); // Optional: Uncomment for debug
      return match;
    }

    // No match found
    return null;
  }

  @override
  void notifyListeners() {
    print('AttendanceProvider.notifyListeners() called');
    print('Current active class ID: $_activeClassId');
    if (_activeClassId != null) {
      final classRecords = _classAttendanceRecords[_activeClassId!] ?? [];
      print('Current attendance records for active class: ${classRecords.length}');
      final presentCount = classRecords.where((record) => record.status == AttendanceStatus.present).length;
      print('Current present count for active class: $presentCount');
    }
    super.notifyListeners();
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    print('_setLoading($loading) called');
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    print('_setError($error) called');
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    print('_clearError() called');
  }

  // Helper method to compare sessions (Morning vs Afternoon)
  bool _isSameSession(DateTime date1, DateTime date2) {
    // First check if they are the same day
    final isSameDay = date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
           
    if (!isSameDay) return false;
    
    // Then check if they are in the same session (AM vs PM)
    // AM Session ends at 1:30 PM (13:30)
    final isDate1Am = date1.hour < 13 || (date1.hour == 13 && date1.minute < 30);
    final isDate2Am = date2.hour < 13 || (date2.hour == 13 && date2.minute < 30);
    
    return isDate1Am == isDate2Am;
  }

  // Get unsynced attendance records for upload
  List<AttendanceRecord> getUnsyncedRecords(String classId) {
    return HiveService.getUnsyncedAttendance(classId);
  }

  // Mark records as synced after successful upload
  Future<void> markRecordsAsSynced(List<String> recordIds) async {
    await HiveService.markAttendanceAsSynced(recordIds);
    
    // Also update our in-memory records
    for (final entry in _classAttendanceRecords.entries) {
      final classId = entry.key;
      final records = entry.value;
      
      bool updated = false;
      for (final record in records) {
        if (recordIds.contains(record.id)) {
          final updatedRecord = record.copyWith(isSyncedToSheet: true);
          final index = records.indexWhere((r) => r.id == record.id);
          if (index >= 0) {
            records[index] = updatedRecord;
            updated = true;
          }
        }
      }
      
      if (updated) {
        _classAttendanceRecords[classId] = records;
        // If this is the active class, notify listeners
        if (_activeClassId == classId) {
          notifyListeners();
        }
      }
    }
    
    // Update class-specific records
    for (final entry in _classAttendanceRecords.entries) {
      final classId = entry.key;
      final records = entry.value;
      
      bool updated = false;
      for (final record in records) {
        if (recordIds.contains(record.id)) {
          final updatedRecord = record.copyWith(isSyncedToSheet: true);
          final index = records.indexWhere((r) => r.id == record.id);
          if (index >= 0) {
            records[index] = updatedRecord;
            updated = true;
          }
        }
      }
      
      if (updated) {
        _classAttendanceRecords[classId] = records;
        // If this is the active class, notify listeners
        if (_activeClassId == classId) {
          notifyListeners();
        }
      }
    }
  }
  
  // Resolve conflicts before uploading attendance
  Future<ConflictResolutionResult> resolveConflictsBeforeUpload({
    required ClassModel classModel,
    required List<AttendanceRecord> records,
  }) async {
    return await GoogleSheetsService.resolveAttendanceConflicts(
      classModel: classModel,
      localRecords: records,
      sessionDate: _sessionDate,
    );
  }
  
  // Sync all unsynced records to Google Sheets
  Future<GoogleSheetsUploadResult> syncAllUnsyncedRecords({
    required ClassModel classModel,
    required Function(double) onProgress,
  }) async {
    print('=== SYNC ALL UNSYNCED RECORDS ===');
    print('Class: ${classModel.className}');
    print('Current session date: $_sessionDate');
    
    // Get all unsynced records for this class
    final unsyncedRecords = getUnsyncedRecords(classModel.id);
    print('Found ${unsyncedRecords.length} unsynced records');
    
    // DEBUG: Print unsynced records details
    for (int i = 0; i < unsyncedRecords.length; i++) {
      final record = unsyncedRecords[i];
      print('  Unsynced Record $i: ${record.studentName} (${record.studentPinNumber}) - ${record.status} - ${record.sessionDate}');
    }
    
    // ALSO get all records for the current session (to ensure we're syncing the right data)
    final currentSessionRecords = HiveService.getAttendanceForClass(classModel.id, _sessionDate);
    print('Found ${currentSessionRecords.length} records for current session');
    
    // Auto-mark non-scanned students as present/absent if needed for sync consistency
    // Note: We use existing logic to calculate absent students
    final currentSessionPinNumbers = currentSessionRecords.map((record) => record.studentPinNumber).toSet();
    final studentsWithoutRecords = classModel.students.where((student) => !currentSessionPinNumbers.contains(student.pinNumber)).toList();
    
    print('Found ${studentsWithoutRecords.length} students without records for this session');
    
    final absentRecords = <AttendanceRecord>[];
    if (studentsWithoutRecords.isNotEmpty) {
      final normalizedSessionDate = DateTime(_sessionDate.year, _sessionDate.month, _sessionDate.day);
      
      for (final student in studentsWithoutRecords) {
        absentRecords.add(AttendanceRecord(
          id: '${classModel.id}_${student.pinNumber}_${normalizedSessionDate.millisecondsSinceEpoch}_auto_absent',
          classId: classModel.id,
          studentName: student.name,
          studentPinNumber: student.pinNumber,
          sessionDate: normalizedSessionDate,
          status: AttendanceStatus.absent,
          scanTime: DateTime.now(), // Mark as absent at sync time
          scanMethod: ScanMethod.manual,
          isSyncedToSheet: false,
        ));
      }
    }
    
    // Combine existing records with temporary absent records
    final allRecordsToSync = [...currentSessionRecords, ...absentRecords];
    
    // Call Google Sheets Service with CORRECT signature
    // Note: The service now handles dynamic URL lookup internally
    return GoogleSheetsService.uploadAttendance(
       classModel: classModel,
       attendanceRecords: allRecordsToSync, // Pass consolidated list
       onProgress: onProgress,
    );
  }

  // Fetch and merge attendance from Firebase
  Future<void> _fetchAndMergeFirebaseAttendance(String classId, DateTime date) async {
    final startTime = DateTime.now();
    print('AttendanceProvider: [${startTime.toIso8601String()}] _fetchAndMergeFirebaseAttendance START for $classId');
    try {
      // Check if we are online
      final isOnline = await ConnectivityService().checkConnectivity();
      if (!isOnline) {
        print('Device offline, skipping Firebase fetch');
        return;
      }
      
      if (!FirebaseService().isInitialized) {
        try {
          await FirebaseService().init();
        } catch (e) {
          print('Failed to initialize Firebase: $e');
          return;
        }
      }
      
      // Determine session type (morning/afternoon)
      // We replicate the logic from FirebaseService to ensure consistency
      final sessionType = _getSessionTypeForFirebase(date);
      
      print('Fetching remote attendance from Firebase for class $classId, date $date, session $sessionType');
      
      final remoteRecords = await FirebaseService().getAttendance(
        classId: classId, 
        sessionDate: date, 
        sessionType: sessionType
      );
      
      if (remoteRecords.isEmpty) {
        print('No remote records found in Firebase');
        return;
      }
      
      print('Fetched ${remoteRecords.length} records from Firebase');
      
      // Merge with local records
      final localRecords = _classAttendanceRecords[classId] ?? [];
      final mergedRecords = HybridSyncService().mergeAttendanceRecords(localRecords, remoteRecords);
      
      // Update local state
      _classAttendanceRecords[classId] = mergedRecords;
      notifyListeners();
      
      // Persist merged records to Hive so they are available offline
      for (final record in mergedRecords) {
        await AttendanceDataService.saveAttendanceRecord(record);
      }
      
      print('Merged and saved ${mergedRecords.length} records (Local + Firebase)');
      
    } catch (e) {
      print('Error fetching/merging Firebase attendance: $e');
    }
  }
  
  String _getSessionTypeForFirebase(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    if (hour < 13 || (hour == 13 && minute < 30)) {
      return 'morning';
    }
    return 'afternoon';
  }


  // Enhanced sync method that fetches existing attendance data and displays the complete union
  Future<GoogleSheetsUploadResult> syncWithCompleteUnionDisplay({
    required ClassModel classModel,
    required Function(double) onProgress,
  }) async {
    print('=== SYNC WITH COMPLETE UNION DISPLAY ===');
    print('Class: ${classModel.className}');
    print('Current session date: $_sessionDate');
    
    // Set the active class ID
    _activeClassId = classModel.id;
    
    // First, fetch existing attendance data from Google Sheets for today's date
    print('Fetching existing attendance data from Google Sheets...');
    final existingAttendance = await GoogleSheetsService.fetchAllAttendanceForDate(
      classModel: classModel,
      date: _sessionDate,
    );
    
    print('Found ${existingAttendance.length} existing attendance entries in Google Sheets');
    
    // Log some of the existing attendance data for debugging
    if (existingAttendance.isNotEmpty) {
      print('Sample existing attendance data:');
      int count = 0;
      existingAttendance.forEach((pin, status) {
        if (count < 5) { // Only log first 5 entries
          print('  PIN: $pin, Status: $status');
          count++;
        }
      });
      if (existingAttendance.length > 5) {
        print('  ... and ${existingAttendance.length - 5} more entries');
      }
    } else {
      print('⚠️ No existing attendance data found in Google Sheets');
      print('This might be because:');
      print('  1. The date column does not exist yet');
      print('  2. There is no attendance data for today');
      print('  3. There might be an issue with Google Sheets access');
    }
    
    // Get all current local records for this session
    final currentLocalRecords = HiveService.getAttendanceForClass(classModel.id, _sessionDate);
    print('Found ${currentLocalRecords.length} local attendance records');
    
    // Log some of the local attendance data for debugging
    if (currentLocalRecords.isNotEmpty) {
      print('Sample local attendance records:');
      for (int i = 0; i < currentLocalRecords.length && i < 5; i++) {
        final record = currentLocalRecords[i];
        print('  PIN: ${record.studentPinNumber}, Status: ${record.status}, Name: ${record.studentName}');
      }
      if (currentLocalRecords.length > 5) {
        print('  ... and ${currentLocalRecords.length - 5} more records');
      }
    }
    
    // Create a map of local records by PIN number
    final localRecordsMap = <String, AttendanceRecord>{};
    for (final record in currentLocalRecords) {
      localRecordsMap[record.studentPinNumber] = record;
    }
    
    // Create a set of all PIN numbers that should be present (union of existing and local)
    final allPinNumbers = <String>{};
    allPinNumbers.addAll(existingAttendance.keys);
    allPinNumbers.addAll(localRecordsMap.keys);
    
    print('Total unique students in union: ${allPinNumbers.length}');
    
    // Create a comprehensive list of all attendance records to display
    final comprehensiveAttendanceList = <AttendanceRecord>[];
    
    // Process each student in the union
    for (final pinNumber in allPinNumbers) {
      // Check if we have a local record for this student
      final localRecord = localRecordsMap[pinNumber];
      
      // Check if we have an existing record from Google Sheets
      final existingStatus = existingAttendance[pinNumber]?.toLowerCase().trim();
      
      // Log the existing status for debugging
      if (existingAttendance.containsKey(pinNumber)) {
        print('Student $pinNumber: Found in existing attendance with status "$existingStatus"');
      }
      
      // Determine the final status based on our rules
      String finalStatus;
      DateTime finalScanTime;
      String finalScannedCode;
      ScanMethod finalScanMethod;
      
      if (localRecord != null && localRecord.status == AttendanceStatus.present) {
        // If student is present locally, they stay present (present integrity rule)
        finalStatus = 'present';
        finalScanTime = localRecord.scanTime;
        finalScannedCode = localRecord.scannedCode ?? '';
        finalScanMethod = localRecord.scanMethod;
        print('Student $pinNumber: Present locally, keeping as present');
      } else {
        // For all other cases, determine status based on existing data from Google Sheets
        // Check if existing status indicates present (not just the word 'present')
        // If the existing status is a date, that means the student was present on that date
        bool isPresentInSheet = existingStatus != null && existingStatus != 'absent' && existingStatus.isNotEmpty;
        finalStatus = isPresentInSheet ? 'present' : 'absent';
        
        if (localRecord != null) {
          // If we have local record data, use it for scan time and method
          finalScanTime = localRecord.scanTime;
          finalScannedCode = localRecord.scannedCode ?? '';
          finalScanMethod = localRecord.scanMethod;
        } else {
          // If no local record, use defaults
          finalScanTime = DateTime.now();
          finalScannedCode = '';
          finalScanMethod = ScanMethod.manual;
        }
        
        if (isPresentInSheet) {
          print('Student $pinNumber: Present in Google Sheets (date found: $existingStatus), keeping as present');
        } else if (localRecord != null) {
          print('Student $pinNumber: Using local status: ${localRecord.status.name}');
        } else {
          print('Student $pinNumber: Marking as absent');
        }
      }
      
      // Find the student in the class model to get their name
      final student = classModel.students.firstWhere(
        (s) => s.pinNumber == pinNumber,
        orElse: () => Student(
          pinNumber: pinNumber,
          name: 'Unknown Student ($pinNumber)',
          email: '',
          phone: '',
          branch: '',
          mobileNumber: '',
          combo: '',
          securityCodes: [],
        ),
      );
      
      // Create a comprehensive record for display
      final comprehensiveRecord = AttendanceRecord(
        id: '${classModel.id}_${pinNumber}_${_sessionDate.millisecondsSinceEpoch}_comprehensive',
        classId: classModel.id,
        studentPinNumber: pinNumber,
        studentName: student.name,
        scanTime: finalScanTime,
        status: finalStatus == 'present' ? AttendanceStatus.present : AttendanceStatus.absent,
        scannedCode: finalScannedCode,
        scanMethod: finalScanMethod,
        sessionDate: _sessionDate,
        isSyncedToSheet: true, // Mark as synced since we've considered Google Sheets data
      );
      
      comprehensiveAttendanceList.add(comprehensiveRecord);
    }
    
    final presentCount = comprehensiveAttendanceList.where((record) => record.status == AttendanceStatus.present).length;
    print('Created comprehensive attendance list with ${comprehensiveAttendanceList.length} records ($presentCount present)');
    
    // Update the class-specific attendance records to show the complete union
    print('Setting attendance records for class ${classModel.id} with comprehensive attendance list of ${comprehensiveAttendanceList.length} records');
    final presentInComprehensive = comprehensiveAttendanceList.where((record) => record.status == AttendanceStatus.present).length;
    print('Number of present students in comprehensive list: $presentInComprehensive');
    _classAttendanceRecords[classModel.id] = comprehensiveAttendanceList;
    
    // If this is the active class, notify listeners
    if (_activeClassId == classModel.id) {
      print('Calling notifyListeners after setting comprehensive attendance list for active class');
      notifyListeners();
      print('✅ Updated UI with comprehensive attendance list for active class');
    }
    
    // Now perform the actual sync with all current local records
    final currentSessionRecords = HiveService.getAttendanceForClass(classModel.id, _sessionDate);
    print('Performing sync with ${currentSessionRecords.length} records');
    
    // Handle case where there are no records to sync
    if (currentSessionRecords.isEmpty && comprehensiveAttendanceList.isNotEmpty) {
      print('⚠️ No local records to sync, but comprehensive list has ${comprehensiveAttendanceList.length} records');
      print('This might indicate a sync issue - creating absent records for all students');
      
      // Create absent records for all students in the class
      final absentRecords = <AttendanceRecord>[];
      final normalizedSessionDate = DateTime(_sessionDate.year, _sessionDate.month, _sessionDate.day);
      
      for (final student in classModel.students) {
        // Only create absent record if student is not already marked as present
        final isStudentPresent = comprehensiveAttendanceList.any((record) => 
            record.studentPinNumber == student.pinNumber && 
            record.status == AttendanceStatus.present);
            
        if (!isStudentPresent) {
          final absentRecord = AttendanceRecord(
            id: '${classModel.id}_${student.pinNumber}_${normalizedSessionDate.millisecondsSinceEpoch}_auto_absent_sync',
            classId: classModel.id,
            studentPinNumber: student.pinNumber,
            studentName: student.name,
            scanTime: DateTime.now(),
            status: AttendanceStatus.absent,
            scannedCode: '',
            scanMethod: ScanMethod.manual,
            sessionDate: normalizedSessionDate,
            isSyncedToSheet: false,
          );
          
          absentRecords.add(absentRecord);
          await AttendanceDataService.saveAttendanceRecord(absentRecord);
          print('Created absent record for student: ${student.name} (${student.pinNumber})');
        }
      }
      
      // Use the absent records for sync
      final result = await _performSyncOperation(classModel, absentRecords, onProgress);
      return result;
    }
    
    final result = await _performSyncOperation(classModel, currentSessionRecords, onProgress);
    
    // After successful sync, mark records as synced
    if (result.isSuccess && result.uploadedRecordIds != null) {
      await markRecordsAsSynced(result.uploadedRecordIds!);
      print('✅ Marked ${result.uploadedRecordIds?.length ?? 0} records as synced');
    }
    
    return result;
  }
  
  // Helper method to perform the actual sync operation
  Future<GoogleSheetsUploadResult> _performSyncOperation(
    ClassModel classModel, 
    List<AttendanceRecord> recordsToSync,
    Function(double) onProgress
  ) async {
    print('Performing sync operation with ${recordsToSync.length} records');
    
    try {
      final result = await GoogleSheetsService.uploadAttendance(
        classModel: classModel,
        attendanceRecords: recordsToSync,
        onProgress: onProgress,
      );
      
      print('Google Sheets upload result: ${result.isSuccess ? "SUCCESS" : "FAILED"}');
      print('Message: ${result.message}');
      if (result.uploadedRecordIds != null) {
        print('Uploaded ${result.uploadedRecordIds!.length} records');
      }
      
      // If successful, mark records as synced
      if (result.isSuccess && result.uploadedRecordIds != null && result.uploadedRecordIds!.isNotEmpty) {
        await markRecordsAsSynced(result.uploadedRecordIds!);
        print('✅ Marked ${result.uploadedRecordIds?.length ?? 0} records as synced');
      }
      
      return result;
    } catch (e, stackTrace) {
      print('❌ Error during sync operation: $e');
      print('Stack trace: $stackTrace');
      return GoogleSheetsUploadResult.error(
        message: 'Sync failed: $e',
      );
    }
  }
  /// Sync using only web app approach - creates jobs for the web app to process
  Future<GoogleSheetsUploadResult> syncUsingWebAppOnly({
    required ClassModel classModel,
    required Function(double) onProgress,
  }) async {
    print('=== SYNC USING WEB APP ONLY APPROACH ===');
    print('Class: ${classModel.className}');
    print('Current session date: $_sessionDate');
    print('Class has ${classModel.students.length} students');
    
    try {
      // Get all current local records for this session
      final currentLocalRecords = HiveService.getAttendanceForClass(classModel.id, _sessionDate);
      print('Found ${currentLocalRecords.length} local attendance records');
      
      // Debug: Print sample records
      if (currentLocalRecords.isNotEmpty) {
        print('Sample record: ${currentLocalRecords[0].toJson()}');
      }
      
      // Sync to Firebase RTDB
      for (final record in currentLocalRecords) {
        try {
          await FirebaseService().writeAttendance(
            classModel: classModel,
            record: record,
          );
        } catch (e) {
          print('⚠️ Failed to sync record to Firebase RTDB: $e');
        }
      }
      
      print('✅ Synced ${currentLocalRecords.length} records to Firebase RTDB');
      
      // Create job for web app to sync to Google Sheets
      print('Creating Google Sheets sync job for web app...');
      
      // Get session date
      final now = DateTime.now();
      final sessionDate = DateTime(now.year, now.month, now.day);
      
      // Format date as dd/MM/yyyy for the web app
      final formattedDate = '${sessionDate.day.toString().padLeft(2, '0')}/${sessionDate.month.toString().padLeft(2, '0')}/${sessionDate.year}';
      
      // Extract batch ID from classModel.id
      // classModel.id is like "class_Skill_Sync01_AWS + GENAI"
      // We need to extract "Skill_Sync01" as the batchId
      String batchId = classModel.id;
      if (batchId.startsWith('class_')) {
        // Remove 'class_' prefix
        batchId = batchId.substring(6);
        // Remove everything after the second underscore (the combo part)
        final parts = batchId.split('_');
        if (parts.length >= 2) {
          batchId = parts[0] + '_' + parts[1];
        }
      }
      
      print('Extracted batch ID: $batchId');
      print('Formatted date: $formattedDate');
      
      // Create job data for web app with the correct structure
      final jobData = {
        'classId': batchId, // Use the extracted batch ID
        'className': classModel.className,
        'sheetName': classModel.sheetName ?? classModel.className,
        'jobType': 'attendance',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': {
          'date': formattedDate, // Use the correctly formatted date
          'students': currentLocalRecords.map((record) {
            // Find the student in the class model to get their combo
            print('Looking for student with PIN: ${record.studentPinNumber}');
            final student = classModel.students.firstWhere(
              (s) => s.pinNumber == record.studentPinNumber,
              orElse: () => Student.empty(),
            );
            
            print('Found student: ${student.name} with combo: "${student.combo}"');
            
            final studentData = {
              'pinNumber': record.studentPinNumber,
              'name': record.studentName,
              'status': record.status.name,
              'scanTime': record.scanTime.millisecondsSinceEpoch,
              'combo': student.combo, // Include combo information
            };
            print('Student data for job: $studentData');
            return studentData;
          }).toList(),
        },
      };
      
      print('Job data to be written: $jobData');
      print('Job data JSON: ${jsonEncode(jobData)}');
      
      // Write job to Firebase for the web app to process
      final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}_${batchId}';
      print('Writing job to Firebase path: /outgoingToSheets/$jobId');
      await FirebaseService().writeToPath('/outgoingToSheets/$jobId', jobData);
      print('✅ Created job $jobId for Google Sheets reporting via web app');
      
      // Trigger the web app to process jobs immediately
      try {
        const webAppUrl = 'https://script.google.com/macros/s/AKfycbxRTSfDZrJt9VV4fY33S0lHneW1Q97YbcbBXhaNCxTygtypAmvCl3n0YKvBdzabR_K0_w/exec';
        print('Triggering web app at URL: $webAppUrl');
        // Try different approaches to trigger the web app
        final response = await http.post(
          Uri.parse(webAppUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'action': 'processJobs'}),
        );
        
        print('Web app response status: ${response.statusCode}');
        print('Web app response body: ${response.body}');
        
        if (response.statusCode == 200) {
          print('✅ Web app job processing triggered successfully');
        } else {
          print('⚠️ Web app returned status ${response.statusCode}: ${response.body}');
          // Try alternative approach
          print('Trying alternative web app trigger approach...');
          final altResponse = await http.get(Uri.parse('$webAppUrl?action=processJobs'));
          print('Alternative web app response status: ${altResponse.statusCode}');
          print('Alternative web app response body: ${altResponse.body}');
        }
      } catch (e) {
        print('⚠️ Error triggering web app job processing: $e');
      }
      
      // Mark all records as synced since they're queued for Google Sheets sync
      final recordIds = currentLocalRecords.map((record) => record.id).toList();
      if (recordIds.isNotEmpty) {
        await markRecordsAsSynced(recordIds);
        await HiveService.saveLastSyncTime(classModel.id, DateTime.now());
        print('✅ Marked ${recordIds.length} records as synced');
      }
      
      // Update department sheets via web app as well
      try {
        print('Creating department sheets sync job for web app...');
        
        // Create department sheet job data
        final deptJobData = {
          'classId': batchId, // Use the extracted batch ID
          'className': classModel.className,
          'sheetName': classModel.sheetName ?? classModel.className,
          'jobType': 'department',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': {
            'date': formattedDate, // Use the correctly formatted date
            'students': currentLocalRecords
                .where((record) => record.status == AttendanceStatus.present)
                .map((record) {
                  // Find the student in the class model to get their combo
                  print('Looking for department student with PIN: ${record.studentPinNumber}');
                  final student = classModel.students.firstWhere(
                    (s) => s.pinNumber == record.studentPinNumber,
                    orElse: () => Student.empty(),
                  );
                  
                  print('Found department student: ${student.name} with combo: "${student.combo}"');
                  
                  final studentData = {
                    'pinNumber': record.studentPinNumber,
                    'name': record.studentName,
                    'status': record.status.name,
                    'scanTime': record.scanTime.millisecondsSinceEpoch,
                    'combo': student.combo, // Include combo information
                  };
                  print('Department student data for job: $studentData');
                  return studentData;
                }).toList(),
          },
        };
        
        print('Department job data to be written: $deptJobData');
        print('Department job data JSON: ${jsonEncode(deptJobData)}');
        
        // Write department job to Firebase for the web app to process
        final deptJobId = 'dept_job_${DateTime.now().millisecondsSinceEpoch}_${batchId}';
        print('Writing department job to Firebase path: /outgoingToSheets/$deptJobId');
        await FirebaseService().writeToPath('/outgoingToSheets/$deptJobId', deptJobData);
        print('✅ Created department job $deptJobId for web app processing');
      } catch (e) {
        print('⚠️ Failed to create department sheets job: $e');
      }
      
      return GoogleSheetsUploadResult.success(
        uploadedRecordIds: recordIds,
        message: 'All records synced to Firebase RTDB. Google Sheets sync job created for web app processing.',
      );
    } catch (e, stackTrace) {
      print('❌ Error during sync: $e');
      print('Stack trace: $stackTrace');
      return GoogleSheetsUploadResult.error(
        message: 'Sync failed: $e',
      );
    }
  }
  
  /// Directly upload attendance data to Google Sheets without using the web app
  Future<GoogleSheetsUploadResult> syncDirectToGoogleSheets({
    required ClassModel classModel,
    required Function(double) onProgress,
  }) async {
    print('=== DIRECT GOOGLE SHEETS SYNC APPROACH ===');
    print('Class: ${classModel.className}');
    print('Current session date: $_sessionDate');
    print('Class has ${classModel.students.length} students');
    
    try {
      // Get all current local records for this session
      final currentLocalRecords = HiveService.getAttendanceForClass(classModel.id, _sessionDate);
      print('Found ${currentLocalRecords.length} local attendance records');
      
      // Debug: Print sample records
      if (currentLocalRecords.isNotEmpty) {
        print('Sample record: ${currentLocalRecords[0].toJson()}');
      }
      
      // Sync to Firebase RTDB
      for (final record in currentLocalRecords) {
        try {
          await FirebaseService().writeAttendance(
            classModel: classModel,
            record: record,
          );
        } catch (e) {
          print('⚠️ Failed to sync record to Firebase RTDB: $e');
        }
      }
      
      print('✅ Synced ${currentLocalRecords.length} records to Firebase RTDB');
      
      // Directly upload to Google Sheets
      print('Directly uploading attendance data to Google Sheets...');
      
      final result = await GoogleSheetsService.uploadAttendance(
        classModel: classModel,
        attendanceRecords: currentLocalRecords,
        onProgress: onProgress,
      );
      
      if (result.isSuccess) {
        // Mark all records as synced since they've been uploaded to Google Sheets
        final recordIds = currentLocalRecords.map((record) => record.id).toList();
        if (recordIds.isNotEmpty) {
          await markRecordsAsSynced(recordIds);
          await HiveService.saveLastSyncTime(classModel.id, DateTime.now());
          print('✅ Marked ${recordIds.length} records as synced');
        }
        
        print('✅ Direct Google Sheets sync completed successfully');
        return GoogleSheetsUploadResult.success(
          uploadedRecordIds: recordIds,
          message: 'Successfully synced ${recordIds.length} records directly to Google Sheets',
        );
      } else {
        print('❌ Direct Google Sheets sync failed: ${result.message}');
        return GoogleSheetsUploadResult.error(
          message: 'Direct Google Sheets sync failed: ${result.message}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error during direct sync: $e');
      print('Stack trace: $stackTrace');
      return GoogleSheetsUploadResult.error(
        message: 'Direct sync failed: $e',
      );
    }
  }
  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }
}

// Helper class for student attendance status
class StudentAttendanceStatus {
  final Student student;
  final AttendanceRecord? attendanceRecord;
  final bool isPresent;

  StudentAttendanceStatus({
    required this.student,
    this.attendanceRecord,
    required this.isPresent,
  });

  String get displayStatus => isPresent ? 'Present' : 'Absent';
  
  String? get scanTime {
    return attendanceRecord?.displayTime;
  }
}