import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance_record.dart';
import '../models/class_model.dart';

/// Firebase Realtime Database Service
/// Handles real-time attendance synchronization across multiple devices
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseDatabase? _database;
  FirebaseFirestore? _firestore;
  bool _isInitialized = false;

  /// Initialize Firebase connection
  Future<void> init() async {
    try {
      print('FirebaseService: Initializing Firebase...');
      
      // Firebase.initializeApp() should be called in main.dart
      // This just gets the database instance
      _database = FirebaseDatabase.instance;
      _firestore = FirebaseFirestore.instance;
      
      // Enable offline persistence only on mobile platforms (not Web)
      if (!kIsWeb) {
        try {
          _database!.setPersistenceEnabled(true);
          _database!.setPersistenceCacheSizeBytes(10000000); // 10MB cache
          
          // Firestore persistence is enabled by default in recent versions
          _firestore!.settings = const Settings(persistenceEnabled: true);
          
          print('FirebaseService: Offline persistence enabled');
        } catch (e) {
          print('⚠️ FirebaseService: Could not enable persistence: $e');
        }
      } else {
        print('FirebaseService: Running on Web, skipping persistence setup');
      }
      
      _isInitialized = true;
      print('✅ FirebaseService: Firebase initialized successfully');
    } catch (e) {
      print('❌ FirebaseService: Failed to initialize Firebase: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Check if Firebase is initialized
  bool get isInitialized => _isInitialized;

  /// Write attendance record to Firebase in real-time
  Future<void> writeAttendance({
    required ClassModel classModel,
    required AttendanceRecord record,
  }) async {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized, skipping write');
      return;
    }

    try {
      print('FirebaseService: Writing attendance to Firebase...');
      print('  Class: ${classModel.className}');
      print('  Student: ${record.studentName} (${record.studentPinNumber})');
      print('  Status: ${record.status.name}');

      // Build Firebase path: attendance/{classId}/{date}/{sessionType}/students/{pinNumber}
      final sessionType = _getSessionType(record.sessionDate);
      final dateKey = _formatDateKey(record.sessionDate);
      final path = 'attendance/${classModel.id}/$dateKey/$sessionType/students/${record.studentPinNumber}';

      // Prepare data
      final data = {
        'name': record.studentName,
        'status': record.status.name,
        'scanTime': record.scanTime.millisecondsSinceEpoch,
        'scannedCode': record.scannedCode ?? '',
        'scanMethod': record.scanMethod.name,
        'deviceId': await _getDeviceId(),
        'updatedAt': ServerValue.timestamp,
      };

      // Write to Firebase
      final ref = _database!.ref(path);
      await ref.set(data);

      print('✅ FirebaseService: Attendance written successfully to Firebase');
    } catch (e) {
      print('❌ FirebaseService: Failed to write attendance: $e');
      rethrow;
    }
  }

  /// Delete attendance record from Firebase
  Future<void> deleteAttendanceRecord({
    required String classId,
    required DateTime sessionDate,
    required String studentPinNumber,
  }) async {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized, skipping delete');
      return;
    }

    try {
      print('FirebaseService: Deleting attendance from Firebase...');
      print('  Class ID: $classId');
      print('  Student PIN: $studentPinNumber');

      final sessionType = _getSessionType(sessionDate);
      final dateKey = _formatDateKey(sessionDate);
      final path = 'attendance/$classId/$dateKey/$sessionType/students/$studentPinNumber';

      print('  Path: $path');

      final ref = _database!.ref(path);
      await ref.remove();

      print('✅ FirebaseService: Attendance record deleted successfully from Firebase');
    } catch (e) {
      print('❌ FirebaseService: Failed to delete attendance: $e');
      rethrow;
    }
  }

  /// Listen to real-time attendance updates for a class/date/session
  Stream<List<AttendanceRecord>> listenToAttendance({
    required String classId,
    required DateTime sessionDate,
    required String sessionType,
  }) {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized, returning empty stream');
      return Stream.value([]);
    }

    try {
      final dateKey = _formatDateKey(sessionDate);
      final path = 'attendance/$classId/$dateKey/$sessionType/students';
      
      print('FirebaseService: Setting up real-time listener on: $path');

      final ref = _database!.ref(path);
      
      return ref.onValue.map((event) {
        final data = event.snapshot.value;
        
        if (data == null) {
          print('FirebaseService: No data in Firebase for path: $path');
          return <AttendanceRecord>[];
        }

        final records = <AttendanceRecord>[];
        
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              try {
                final record = _parseAttendanceFromFirebase(
                  pinNumber: key as String,
                  data: Map<String, dynamic>.from(value),
                  classId: classId,
                  sessionDate: sessionDate,
                );
                records.add(record);
              } catch (e) {
                print('⚠️ FirebaseService: Failed to parse record for $key: $e');
              }
            }
          });
        }

        print('FirebaseService: Received ${records.length} records from Firebase');
        return records;
      });
    } catch (e) {
      print('❌ FirebaseService: Failed to set up listener: $e');
      return Stream.value([]);
    }
  }

  /// Get all attendance for a specific session (one-time read)
  Future<List<AttendanceRecord>> getAttendance({
    required String classId,
    required DateTime sessionDate,
    required String sessionType,
  }) async {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized');
      return [];
    }

    try {
      final dateKey = _formatDateKey(sessionDate);
      final path = 'attendance/$classId/$dateKey/$sessionType/students';
      
      print('FirebaseService: Reading attendance from: $path');

      final ref = _database!.ref(path);
      final snapshot = await ref.get();
      
      if (!snapshot.exists) {
        print('FirebaseService: No data found at path: $path');
        return [];
      }

      final data = snapshot.value;
      final records = <AttendanceRecord>[];
      
      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final record = _parseAttendanceFromFirebase(
                pinNumber: key as String,
                data: Map<String, dynamic>.from(value),
                classId: classId,
                sessionDate: sessionDate,
              );
              records.add(record);
            } catch (e) {
              print('⚠️ FirebaseService: Failed to parse record for $key: $e');
            }
          }
        });
      }

      print('✅ FirebaseService: Retrieved ${records.length} records from Firebase');
      return records;
    } catch (e) {
      print('❌ FirebaseService: Failed to read attendance: $e');
      return [];
    }
  }

  /// Get real-time attendance stream for a specific session
  Stream<List<AttendanceRecord>> getAttendanceStream({
    required String classId,
    required DateTime sessionDate,
    required String sessionType,
  }) {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized for stream');
      return Stream.value([]);
    }

    try {
      final dateKey = _formatDateKey(sessionDate);
      final path = 'attendance/$classId/$dateKey/$sessionType/students';
      
      print('FirebaseService: Listening to attendance stream at: $path');

      final ref = _database!.ref(path);
      
      return ref.onValue.map((event) {
        final records = <AttendanceRecord>[];
        final data = event.snapshot.value;
        
        if (data != null && data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              try {
                final record = _parseAttendanceFromFirebase(
                  pinNumber: key as String,
                  data: Map<String, dynamic>.from(value),
                  classId: classId,
                  sessionDate: sessionDate,
                );
                records.add(record);
              } catch (e) {
                print('⚠️ FirebaseService: Failed to parse stream record for $key: $e');
              }
            }
          });
        }
        
        return records;
      });
    } catch (e) {
      print('❌ FirebaseService: Failed to setup attendance stream: $e');
      return Stream.value([]);
    }
  }

  Future<List<AttendanceRecord>> getStudentAttendanceHistory({
    required String classId,
    required String studentPinNumber,
    String? studentCombo,
  }) async {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized');
      return [];
    }

    try {
      final safeBatchId = classId.replaceAll(RegExp(r'[.#$\[\]\/]'), '_');
      print('FirebaseService: Fetching history for $studentPinNumber (Batch: $safeBatchId)');
      
      final records = <AttendanceRecord>[];

      // Helper to process a list of student maps (from Sheet-synced structure)
      void processStudentList(List<dynamic> studentsList, String comboName) {
        for (final studentEntry in studentsList) {
          if (studentEntry is Map) {
            // Check formatted string pin match
            final entryPin = studentEntry['Pin-number']?.toString().trim();
            if (entryPin == studentPinNumber.trim()) {
              print('  ✅ Found student $studentPinNumber in combo "$comboName"');
              final entryName = studentEntry['Name of the Student']?.toString() ?? 'Unknown';
              
              // Iterate keys to find dates
              studentEntry.forEach((key, value) {
                // Key looks like "Fri Aug 29 2025 00:00:00 GMT+0530 (India Standard Time)"
                // We check if it contains "2024" or "2025" and some day name to identify it as a date
                if (key.contains('202') && (key.contains('Mon') || key.contains('Tue') || key.contains('Wed') || key.contains('Thu') || key.contains('Fri') || key.contains('Sat') || key.contains('Sun'))) {
                   try {
                     final date = _parseVerboseDateKey(key);
                     if (date != null) {
                       final statusStr = value?.toString().toLowerCase() ?? 'absent';
                       final status = (statusStr == 'present') 
                           ? AttendanceStatus.present 
                           : AttendanceStatus.absent;
                       
                       // Only add present records? Or all? User usually wants history.
                       // The existing UI uses count of "Present".
                       // We will add all, so we can calculate percentage correctly.
                       
                       records.add(AttendanceRecord(
                         id: '${safeBatchId}_${studentPinNumber}_${date.millisecondsSinceEpoch}',
                         classId: classId,
                         studentPinNumber: studentPinNumber,
                         studentName: entryName,
                         scanTime: date, // Use session date as scan time for sheet imports
                         status: status,
                         scanMethod: ScanMethod.manual, // Assumed for historical data
                         sessionDate: date,
                         isSyncedToSheet: true,
                         isSyncedToFirebase: true,
                       ));
                     }
                   } catch (e) {
                     print('  ⚠️ Failed to parse date key "$key": $e');
                   }
                }
              });
            }
          }
        }
      }
      
      // Helper to handle the "data/attendance" path
      Future<void> checkAttendancePath(String basePath) async {
        // Optimization: If combo is known, go directly to that child
        if (studentCombo != null && studentCombo.isNotEmpty) {
           // Try exact match first (most likely)
           final safeCombo = studentCombo.replaceAll(RegExp(r'[.#$\[\]\/]'), '_'); 
           var path = '$basePath/$studentCombo'; // Try exact name first
           
           print('  Checking optimized path: $path');
           var ref = _database!.ref(path);
           var snapshot = await ref.get();
           
           if (snapshot.exists) {
             processStudentList(snapshot.value as List<dynamic>, studentCombo);
             return;
           }
           
           // If strict path fails, try safe path
           if (safeCombo != studentCombo) {
              path = '$basePath/$safeCombo';
              print('  Checking safe combo path: $path');
              ref = _database!.ref(path);
              snapshot = await ref.get();
              if (snapshot.exists) {
                 processStudentList(snapshot.value as List<dynamic>, safeCombo);
                 return;
              }
           }
           
           print('  ⚠️ Optimized path failed, checking all combos for loose match...');
           // Fallback to iterating ONLY if direct fetch failed (rare)
        }

        final ref = _database!.ref(basePath);
        final snapshot = await ref.get();
        
        if (snapshot.exists && snapshot.value is Map) {
          final data = snapshot.value as Map;
          data.forEach((comboName, comboData) {
            // Apply combo filter if provided (and we are here, meaning direct fetch failed)
            if (studentCombo != null && studentCombo.isNotEmpty) {
               // Loose match check
               final normalizedComboName = comboName.toString().replaceAll(' ', '');
               final normalizedStudentCombo = studentCombo.replaceAll(' ', '');
               if (normalizedComboName != normalizedStudentCombo) {
                 return; // Skip this combo
               }
            }
            
            if (comboData is List) {
              processStudentList(comboData, comboName.toString());
            } else if (comboData is Map) {
              processStudentList(comboData.values.toList(), comboName.toString());
            }
          });
        }
      }

      // Check standard path "batches/.../data/attendance"
      await checkAttendancePath('batches/$safeBatchId/data/attendance');
      
      // Also check "Combos" subdirectory just in case (previous assumption)
      await checkAttendancePath('batches/$safeBatchId/data/attendance/Combos');

      print('✅ FirebaseService: Found ${records.length} historical records');
      return records;
    } catch (e) {
      print('❌ FirebaseService: Error fetching history: $e');
      return [];
    }
  }

  /// Parse verbose date string: "Fri Aug 29 2025 00:00:00 GMT+0530 (India Standard Time)"
  DateTime? _parseVerboseDateKey(String key) {
    try {
      // Extract the relevant part: "Aug 29 2025"
      // Split by space
      final parts = key.split(' ');
      // Fri, Aug, 29, 2025, ...
      if (parts.length >= 4) {
        final monthStr = parts[1];
        final day = int.parse(parts[2]);
        final year = int.parse(parts[3]);
        
        final month = _getMonthNumber(monthStr);
        return DateTime(year, month, day);
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }
  
  int _getMonthNumber(String monthAbbr) {
    switch (monthAbbr) {
      case 'Jan': return 1;
      case 'Feb': return 2;
      case 'Mar': return 3;
      case 'Apr': return 4;
      case 'May': return 5;
      case 'Jun': return 6;
      case 'Jul': return 7;
      case 'Aug': return 8;
      case 'Sep': return 9;
      case 'Oct': return 10;
      case 'Nov': return 11;
      case 'Dec': return 12;
      default: return 1;
    }
  }

  /// Calculate attendance percentage for a specific student
  Future<double> calculateStudentAttendancePercentage({
    required String classId,
    required String studentPinNumber,
    String? studentCombo,
  }) async {
    try {
      print('FirebaseService: Calculating attendance percentage for student $studentPinNumber in batch $classId');
      
      // Get all attendance records for this student
      final records = await getStudentAttendanceHistory(
        classId: classId,
        studentPinNumber: studentPinNumber,
        studentCombo: studentCombo,
      );
      
      if (records.isEmpty) {
        print('FirebaseService: No attendance records found for student $studentPinNumber');
        return 0.0;
      }
      
      // Count present sessions
      final presentCount = records.where((record) => record.status == AttendanceStatus.present).length;
      final totalCount = records.length;
      
      final percentage = (presentCount / totalCount) * 100;
      print('✅ FirebaseService: Student $studentPinNumber attendance: $presentCount/$totalCount (${percentage.toStringAsFixed(2)}%)');
      
      return percentage;
    } catch (e) {
      print('❌ FirebaseService: Failed to calculate attendance percentage: $e');
      return 0.0;
    }
  }

  /// Clear attendance data for a session (called during session clearance)
  Future<void> clearSessionData({
    required String classId,
    required DateTime sessionDate,
    required String sessionType,
  }) async {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized');
      return;
    }

    try {
      final dateKey = _formatDateKey(sessionDate);
      final path = 'attendance/$classId/$dateKey/$sessionType';
      
      print('FirebaseService: Clearing session data at: $path');

      final ref = _database!.ref(path);
      await ref.remove();

      print('✅ FirebaseService: Session data cleared from Firebase');
    } catch (e) {
      print('❌ FirebaseService: Failed to clear session data: $e');
      rethrow;
    }
  }

  /// Sync session data to Firestore
  Future<void> syncSessionToFirestore({
    required String classId,
    required DateTime sessionDate,
    required String sessionType,
    required List<AttendanceRecord> records,
  }) async {
    if (!_isInitialized || _firestore == null) {
      print('⚠️ FirebaseService: Firestore not initialized');
      return;
    }

    try {
      print('FirebaseService: Syncing session to Firestore...');
      final dateKey = _formatDateKey(sessionDate);
      
      // Collection structure: attendance_history/{classId}/{dateKey}/{sessionType}
      final docRef = _firestore!
          .collection('attendance_history')
          .doc(classId)
          .collection(dateKey)
          .doc(sessionType);

      final batch = _firestore!.batch();
      
      // Set session metadata
      batch.set(docRef, {
        'classId': classId,
        'date': dateKey,
        'sessionType': sessionType,
        'syncedAt': FieldValue.serverTimestamp(),
        'totalRecords': records.length,
      });

      // Add students as a subcollection or array
      // Using subcollection for scalability
      final studentsCollection = docRef.collection('students');
      
      for (final record in records) {
        final studentDoc = studentsCollection.doc(record.studentPinNumber);
        batch.set(studentDoc, {
          'name': record.studentName,
          'pinNumber': record.studentPinNumber,
          'status': record.status.name,
          'scanTime': record.scanTime.millisecondsSinceEpoch,
          'scannedCode': record.scannedCode,
          'scanMethod': record.scanMethod.name,
        });
      }

      await batch.commit();
      print('✅ FirebaseService: Session synced to Firestore successfully');
      
    } catch (e) {
      print('❌ FirebaseService: Failed to sync to Firestore: $e');
      rethrow;
    }
  }

  /// Parse attendance record from Firebase data
  AttendanceRecord _parseAttendanceFromFirebase({
    required String pinNumber,
    required Map<String, dynamic> data,
    required String classId,
    required DateTime sessionDate,
  }) {
    return AttendanceRecord(
      id: '${classId}_${pinNumber}_${sessionDate.millisecondsSinceEpoch}_firebase',
      classId: classId,
      studentPinNumber: pinNumber,
      studentName: data['name'] as String? ?? 'Unknown',
      scanTime: DateTime.fromMillisecondsSinceEpoch(data['scanTime'] as int? ?? 0),
      status: _parseStatus(data['status'] as String?),
      scannedCode: data['scannedCode'] as String? ?? '',
      scanMethod: _parseScanMethod(data['scanMethod'] as String?),
      sessionDate: sessionDate,
      isSyncedToSheet: false, // Firebase data not yet synced to sheets
    );
  }

  /// Parse attendance status from string
  AttendanceStatus _parseStatus(String? status) {
    if (status == null) return AttendanceStatus.absent;
    
    switch (status.toLowerCase()) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      default:
        return AttendanceStatus.absent;
    }
  }

  /// Parse scan method from string
  ScanMethod _parseScanMethod(String? method) {
    if (method == null) return ScanMethod.manual;
    
    switch (method.toLowerCase()) {
      case 'qr':
        return ScanMethod.qr;
      case 'manual':
        return ScanMethod.manual;
      default:
        return ScanMethod.manual;
    }
  }

  /// Get session type based on time
  String _getSessionType(DateTime date) {
    // Restore timing-based session logic to match Firebase structure requirements
    final hour = date.hour;
    final minute = date.minute;
    
    // Morning: 9:00 AM - 1:30 PM (Using 13:30 as cutoff)
    // Note: Canonical morning time is 9:00
    if (hour < 13 || (hour == 13 && minute < 30)) {
      return 'morning';
    }
    
    // Afternoon: 1:30 PM onwards
    // Note: Canonical afternoon time is 14:00 (2:00 PM)
    return 'afternoon';
  }

  /// Format date as key for Firebase (YYYY-MM-DD)
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get device identifier
  Future<String> _getDeviceId() async {
    // For now, return a simple identifier
    // In production, use a proper device ID package
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Fetch student list from Firebase for a specific class
  /// Path: /sync/{type}/{className}
  /// type: comboAttendance, masterList, mockInterviews
  Future<List<Student>> fetchStudentsFromFirebase({
    required String className,
    String type = 'comboAttendance',
  }) async {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized');
      return [];
    }

    try {
      // Sanitize class name for path (replace special chars with _)
      // This must match the Apps Script logic: sheetName.replace(/[.#$\[\]\/]/g, '_');
      final safeClassName = className.replaceAll(RegExp(r'[.#$\[\]\/]'), '_');
      
      // First try the new path structure: batches/{batchId}/data/master
      final newPath = 'batches/$safeClassName/data/master';
      print('FirebaseService: Trying to fetch students from new path: $newPath');
      
      final newRef = _database!.ref(newPath);
      final newSnapshot = await newRef.get();
      
      if (newSnapshot.exists) {
        print('✅ Found data at new path: $newPath');
        return _parseStudentsFromSnapshot(newSnapshot);
      }
      
      // Fallback to the old path structure: sync/{type}/{className}
      final oldPath = 'sync/$type/$safeClassName';
      print('FirebaseService: Trying to fetch students from old path: $oldPath');
      
      final oldRef = _database!.ref(oldPath);
      final oldSnapshot = await oldRef.get();
      
      if (oldSnapshot.exists) {
        print('✅ Found data at old path: $oldPath');
        return _parseStudentsFromSnapshot(oldSnapshot);
      }
      
      print('FirebaseService: No student data found at either path');
      return [];
    } catch (e) {
      print('❌ FirebaseService: Failed to fetch students: $e');
      return [];
    }
  }
  
  /// Helper method to parse students from Firebase snapshot
  List<Student> _parseStudentsFromSnapshot(DataSnapshot snapshot) {
    final data = snapshot.value;
    final students = <Student>[];
    
    if (data is List) {
      print('📋 Found ${data.length} students (List format)');
      for (var item in data) {
        if (item is Map) {
          try {
            students.add(Student.fromFirebaseJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            print('⚠️ Error parsing student: $e');
          }
        }
      }
    } else if (data is Map) {
      print('📋 Found ${data.length} students (Map format)');
      data.forEach((key, value) {
        if (value is Map) {
          try {
            students.add(Student.fromFirebaseJson(Map<String, dynamic>.from(value)));
          } catch (e) {
            print('⚠️ Error parsing student $key: $e');
          }
        }
      });
    }
    
    print('✅ FirebaseService: Retrieved ${students.length} students from Firebase');
    return students;
  }

  /// Fetch list of available class names from Firebase
  /// Path: /sync/{type}
  Future<List<String>> fetchClassNames({String type = 'comboAttendance'}) async {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized');
      return [];
    }

    try {
      final path = 'sync/$type';
      print('FirebaseService: Fetching class names from: $path');

      final ref = _database!.ref(path);
      final snapshot = await ref.get();
      
      if (!snapshot.exists) {
        print('FirebaseService: No classes found at path: $path');
        return [];
      }

      final data = snapshot.value;
      final classNames = <String>[];
      
      if (data is Map) {
        data.forEach((key, value) {
          classNames.add(key.toString());
        });
      }

      print('✅ FirebaseService: Found ${classNames.length} classes: $classNames');
      return classNames;
    } catch (e) {
      print('❌ FirebaseService: Failed to fetch class names: $e');
      return [];
    }
  }

  /// Write data to a specific path in Firebase Realtime Database
  Future<void> writeToPath(String path, dynamic data) async {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized, skipping write to path: $path');
      return;
    }

    try {
      print('FirebaseService: Writing data to path: $path');
      final ref = _database!.ref(path);
      await ref.set(data);
      print('✅ FirebaseService: Data written successfully to path: $path');
    } catch (e) {
      print('❌ FirebaseService: Failed to write data to path $path: $e');
      rethrow;
    }
  }

  /// Fetch all combos and their students for a specific batch
  /// Path: batches/{batchId}/data/master
  Future<Map<String, List<Student>>> fetchCombosForBatch(String batchId) async {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized');
      return {};
    }

    try {
      // Sanitize batch ID
      final safeBatchId = batchId.replaceAll(RegExp(r'[.#$\[\]\/]'), '_');
      final path = 'batches/$safeBatchId/data/master';
      print('FirebaseService: Fetching combos for batch "$batchId" from: $path');

      final ref = _database!.ref(path);
      final snapshot = await ref.get();
      
      if (!snapshot.exists) {
        print('FirebaseService: No combos found for batch "$batchId" at path: $path');
        return {};
      }

      final data = snapshot.value;
      final combosMap = <String, List<Student>>{};
      
      if (data is Map) {
        print('📋 Found ${data.length} combos for batch "$batchId"');
        print('📊 Data type at path: ${data.runtimeType}');        
        data.forEach((comboName, studentsData) {
          final students = <Student>[];
          
          // Parse students for this combo
          if (studentsData is List) {
            for (var item in studentsData) {
              if (item is Map) {
                try {
                  students.add(Student.fromFirebaseJson(Map<String, dynamic>.from(item)));
                } catch (e) {
                  print('⚠️ Error parsing student in combo "$comboName": $e');
                }
              }
            }
          } else if (studentsData is Map) {
            studentsData.forEach((key, value) {
              if (value is Map) {
                try {
                  students.add(Student.fromFirebaseJson(Map<String, dynamic>.from(value)));
                } catch (e) {
                  print('⚠️ Error parsing student "$key" in combo "$comboName": $e');
                }
              }
            });
          }
          
          if (students.isNotEmpty) {
            combosMap[comboName.toString()] = students;
            print('✅ Loaded combo "$comboName" with ${students.length} students');
          } else {
            print('⚠️ Combo "$comboName" has no valid students');
          }        });
      }
      
      return combosMap;
    } catch (e) {
      print('❌ FirebaseService: Failed to fetch combos for batch "$batchId": $e');
      return {};
    }
  }

  /// Update student information in Firebase
  /// Path: batches/{batchId}/data/master/{comboName}/{studentPinNumber}
  Future<void> updateStudent({
    required String batchId,
    required String comboName,
    required Student updatedStudent,
  }) async {
    if (!_isInitialized || _database == null) {
      print('⚠️ FirebaseService: Firebase not initialized, skipping student update');
      return;
    }

    try {
      // Sanitize batch ID and combo name
      final safeBatchId = batchId.replaceAll(RegExp(r'[.#$\[\]\/]'), '_');
      final safeComboName = comboName.replaceAll(RegExp(r'[.#$\[\]\/]'), '_');
      
      // Build Firebase path: batches/{batchId}/data/master/{comboName}
      final path = 'batches/$safeBatchId/data/master/$safeComboName';
      print('FirebaseService: Updating student in Firebase at path: $path');
      
      // Get all students in this combo
      final ref = _database!.ref(path);
      final snapshot = await ref.get();
      
      if (!snapshot.exists) {
        print('⚠️ No existing data found at path: $path');
        // Create the path with the new student
        final studentData = {
          'Name of the Student': updatedStudent.name,
          'Pin-number': updatedStudent.pinNumber,
          'Branch': updatedStudent.branch,
          'Mail-id': updatedStudent.email,
          'Mobile Number': updatedStudent.mobileNumber,
          'COMBO': updatedStudent.combo,
          'Sec-Codes': updatedStudent.securityCodes.join(', '),
        };
        
        await ref.child(updatedStudent.pinNumber).set(studentData);
        print('✅ Created new student entry in Firebase');
        return;
      }
      
      final data = snapshot.value;
      
      // Look for the student by PIN number and update
      bool studentFound = false;
      
      if (data is Map) {
        data.forEach((key, value) {
          if (key == updatedStudent.pinNumber) {
            // Found the student, update their data
            final studentData = {
              'Name of the Student': updatedStudent.name,
              'Pin-number': updatedStudent.pinNumber,
              'Branch': updatedStudent.branch,
              'Mail-id': updatedStudent.email,
              'Mobile Number': updatedStudent.mobileNumber,
              'COMBO': updatedStudent.combo,
              'Sec-Codes': updatedStudent.securityCodes.join(', '),
            };
            
            ref.child(key).set(studentData);
            studentFound = true;
            print('✅ Updated existing student in Firebase: ${updatedStudent.pinNumber}');
          }
        });
      }
      
      // If student not found, add them as a new entry
      if (!studentFound) {
        final studentData = {
          'Name of the Student': updatedStudent.name,
          'Pin-number': updatedStudent.pinNumber,
          'Branch': updatedStudent.branch,
          'Mail-id': updatedStudent.email,
          'Mobile Number': updatedStudent.mobileNumber,
          'COMBO': updatedStudent.combo,
          'Sec-Codes': updatedStudent.securityCodes.join(', '),
        };
        
        await ref.child(updatedStudent.pinNumber).set(studentData);
        print('✅ Added new student to Firebase: ${updatedStudent.pinNumber}');
      }
      
    } catch (e) {
      print('❌ FirebaseService: Failed to update student: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    print('FirebaseService: Disposing resources');
    _database = null;
    _firestore = null;
    _isInitialized = false;
  }
}
