import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../providers/attendance_provider.dart';

/// Utility class for debugging attendance-related issues
class AttendanceDebugUtils {
  /// Debug class switching and data persistence
  static void debugClassSwitching(
    ClassModel oldClass, 
    ClassModel newClass, 
    AttendanceProvider attendanceProvider
  ) {
    print('=== DEBUGGING CLASS SWITCHING ===');
    print('Switching from class: ${oldClass.className} (${oldClass.id})');
    print('Switching to class: ${newClass.className} (${newClass.id})');
    print('Active class ID in provider: ${attendanceProvider.activeClassId}');
    
    // Check attendance records for both classes
    final oldClassRecords = attendanceProvider.getAttendanceRecordsForClass(oldClass.id);
    final newClassRecords = attendanceProvider.getAttendanceRecordsForClass(newClass.id);
    
    print('Old class attendance records: ${oldClassRecords.length}');
    print('New class attendance records: ${newClassRecords.length}');
    
    // Print sample records for each class
    if (oldClassRecords.isNotEmpty) {
      print('Sample records from old class:');
      for (int i = 0; i < oldClassRecords.length && i < 3; i++) {
        final record = oldClassRecords[i];
        print('  - ${record.studentName} (${record.studentPinNumber}): ${record.status}');
      }
    }
    
    if (newClassRecords.isNotEmpty) {
      print('Sample records from new class:');
      for (int i = 0; i < newClassRecords.length && i < 3; i++) {
        final record = newClassRecords[i];
        print('  - ${record.studentName} (${record.studentPinNumber}): ${record.status}');
      }
    }
  }
  
  /// Debug attendance record creation and indexing
  static void debugAttendanceRecordCreation(
    ClassModel classModel,
    Student student,
    AttendanceStatus status,
    DateTime sessionDate
  ) {
    print('=== DEBUGGING ATTENDANCE RECORD CREATION ===');
    print('Class: ${classModel.className}');
    print('Student: ${student.name} (${student.pinNumber})');
    print('Status: $status');
    print('Session date: $sessionDate');
    
    // Create record ID
    final normalizedSessionDate = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
    final recordId = '${classModel.id}_${student.pinNumber}_${normalizedSessionDate.millisecondsSinceEpoch}';
    
    print('Generated record ID: $recordId');
    
    // Create attendance record
    final record = AttendanceRecord(
      id: recordId,
      classId: classModel.id,
      studentPinNumber: student.pinNumber,
      studentName: student.name,
      scanTime: DateTime.now(),
      status: status,
      scannedCode: status == AttendanceStatus.present ? 'TEST_CODE' : '',
      scanMethod: ScanMethod.manual,
      sessionDate: normalizedSessionDate,
      isSyncedToSheet: false,
    );
    
    print('Created attendance record:');
    print('  ID: ${record.id}');
    print('  Class ID: ${record.classId}');
    print('  Student PIN: ${record.studentPinNumber}');
    print('  Student Name: ${record.studentName}');
    print('  Status: ${record.status}');
    print('  Session Date: ${record.sessionDate}');
  }
  
  /// Debug Google Sheets row indexing
  static void debugSheetRowMapping(
    List<Student> classStudents,
    Map<String, int> sheetNameToRowIndex,
    Map<String, int> sheetPinToRowIndex
  ) {
    print('=== DEBUGGING GOOGLE SHEETS ROW MAPPING ===');
    print('Class students count: ${classStudents.length}');
    print('Sheet name mappings count: ${sheetNameToRowIndex.length}');
    print('Sheet PIN mappings count: ${sheetPinToRowIndex.length}');
    
    // Print class students
    print('Class students:');
    for (int i = 0; i < classStudents.length; i++) {
      final student = classStudents[i];
      print('  ${i + 1}. ${student.name} (${student.pinNumber})');
    }
    
    // Print sheet mappings
    print('Sheet name to row index mappings:');
    sheetNameToRowIndex.forEach((name, rowIndex) {
      print('  "$name" -> Row $rowIndex');
    });
    
    print('Sheet PIN to row index mappings:');
    sheetPinToRowIndex.forEach((pin, rowIndex) {
      print('  "$pin" -> Row $rowIndex');
    });
    
    // Try to match students with sheet rows
    print('Student to sheet row matching:');
    for (final student in classStudents) {
      final studentName = student.name.toLowerCase().trim();
      final studentPin = student.pinNumber;
      
      int? matchedRowIndex;
      
      // Try name match
      if (sheetNameToRowIndex.containsKey(studentName)) {
        matchedRowIndex = sheetNameToRowIndex[studentName];
        print('  ✅ Name match: ${student.name} -> Row $matchedRowIndex');
      } 
      // Try PIN match
      else if (sheetPinToRowIndex.containsKey(studentPin)) {
        matchedRowIndex = sheetPinToRowIndex[studentPin];
        print('  ✅ PIN match: ${student.pinNumber} -> Row $matchedRowIndex');
      } 
      // Try partial matches
      else {
        bool matched = false;
        for (final entry in sheetNameToRowIndex.entries) {
          final sheetName = entry.key;
          final sheetRowIndex = entry.value;
          
          if (studentName.contains(sheetName) || sheetName.contains(studentName)) {
            matchedRowIndex = sheetRowIndex;
            print('  ✅ Partial name match: ${student.name} -> "$sheetName" -> Row $matchedRowIndex');
            matched = true;
            break;
          }
        }
        
        if (!matched) {
          print('  ❌ No match found for: ${student.name} (${student.pinNumber})');
        }
      }
    }
  }
  
  /// Debug attendance data synchronization
  static void debugAttendanceSync(
    List<AttendanceRecord> localRecords,
    Map<String, String> existingSheetData
  ) {
    print('=== DEBUGGING ATTENDANCE SYNCHRONIZATION ===');
    print('Local records count: ${localRecords.length}');
    print('Existing sheet data count: ${existingSheetData.length}');
    
    // Print local records
    print('Local attendance records:');
    for (int i = 0; i < localRecords.length; i++) {
      final record = localRecords[i];
      print('  ${i + 1}. ${record.studentName} (${record.studentPinNumber}): ${record.status}');
    }
    
    // Print existing sheet data
    print('Existing sheet data:');
    int count = 0;
    existingSheetData.forEach((pin, status) {
      if (count < 10) { // Limit output for readability
        print('  $pin: $status');
        count++;
      }
    });
    if (existingSheetData.length > 10) {
      print('  ... and ${existingSheetData.length - 10} more entries');
    }
    
    // Identify conflicts
    print('Conflict analysis:');
    for (final record in localRecords) {
      final pin = record.studentPinNumber;
      final localStatus = record.status.name;
      final sheetStatus = existingSheetData[pin]?.toLowerCase().trim() ?? '';
      
      if (sheetStatus.isNotEmpty) {
        if (localStatus == 'present' && sheetStatus == 'present') {
          print('  ⚠️  Conflict: ${record.studentName} is present locally and in sheet (no action needed)');
        } else if (localStatus == 'present' && sheetStatus == 'absent') {
          print('  ⚠️  Conflict: ${record.studentName} is present locally but absent in sheet (will update to present)');
        } else if (localStatus == 'absent' && sheetStatus == 'present') {
          print('  ⚠️  Conflict: ${record.studentName} is absent locally but present in sheet (keeping present)');
        } else {
          print('  ℹ️  Info: ${record.studentName} local status: $localStatus, sheet status: $sheetStatus');
        }
      } else {
        print('  ℹ️  Info: ${record.studentName} not found in sheet data (will be added)');
      }
    }
  }
}