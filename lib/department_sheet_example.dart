import 'package:flutter/material.dart';
import 'models/class_model.dart';
import 'models/attendance_record.dart';
import 'services/department_sheet_service.dart';

/// Example usage of the DepartmentSheetService
class DepartmentSheetExample {
  /// Example of how to update department sheets with attendance data
  static Future<void> updateDepartmentSheetsExample() async {
    // Create a sample class model
    final classModel = ClassModel(
      id: 'class_001',
      className: 'Computer Science Engineering',
      students: [
        Student(
          pinNumber: 'CSE001',
          name: 'John Doe',
          email: 'john.doe@example.com',
          phone: '1234567890',
          branch: 'CSE',
          mobileNumber: '1234567890',
          combo: 'A',
          securityCodes: ['CODE1', 'CODE2'],
        ),
        Student(
          pinNumber: 'CSE002',
          name: 'Jane Smith',
          email: 'jane.smith@example.com',
          phone: '0987654321',
          branch: 'CSE',
          mobileNumber: '0987654321',
          combo: 'B',
          securityCodes: ['CODE3', 'CODE4'],
        ),
      ],
    );
    
    // Create sample attendance records
    final attendanceRecords = [
      AttendanceRecord(
        id: 'record_001',
        classId: 'class_001',
        studentPinNumber: 'CSE001',
        studentName: 'John Doe',
        scanTime: DateTime.now(),
        status: AttendanceStatus.present,
        scannedCode: 'CODE1',
        scanMethod: ScanMethod.qrCamera,
        sessionDate: DateTime.now(),
        isSyncedToSheet: false,
      ),
      AttendanceRecord(
        id: 'record_002',
        classId: 'class_001',
        studentPinNumber: 'CSE002',
        studentName: 'Jane Smith',
        scanTime: DateTime.now(),
        status: AttendanceStatus.absent,
        scannedCode: null,
        scanMethod: ScanMethod.qrCamera,
        sessionDate: DateTime.now(),
        isSyncedToSheet: false,
      ),
    ];
    
    // Update department sheets with present roll numbers only
    print('Updating department sheets...');
    final success = await DepartmentSheetService.updateDepartmentSheets(
      classModel: classModel,
      attendanceRecords: attendanceRecords,
    );
    
    if (success) {
      print('✅ Department sheets updated successfully');
    } else {
      print('❌ Failed to update department sheets');
    }
  }
  
  /// Example of how to get the current session type
  static void getCurrentSessionExample() {
    final sessionType = DepartmentSheetService.getCurrentSession();
    print('Current session: $sessionType');
  }
}