// Test script to verify class data persistence fix
// This script can be run to test the fix for class data persistence

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../widgets/scanner_widgets.dart'; // Import GradientButton

// Add import for AppTheme:
import '../constants/theme.dart';

class ClassPersistenceTestScreen extends StatefulWidget {
  const ClassPersistenceTestScreen({super.key});

  @override
  State<ClassPersistenceTestScreen> createState() =>
      _ClassPersistenceTestScreenState();
}

class _ClassPersistenceTestScreenState
    extends State<ClassPersistenceTestScreen> {
  String _testResult = '';
  bool _isTesting = false;

  Future<void> _runTest() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Running test...\n';
    });

    try {
      final classProvider = context.read<ClassProvider>();
      final attendanceProvider = context.read<AttendanceProvider>();

      // Check if we have classes
      if (!classProvider.hasClasses) {
        setState(() {
          _testResult += '❌ No classes available for testing\n';
          _isTesting = false;
        });
        return;
      }

      // Get the first two classes for testing
      if (classProvider.classes.length < 2) {
        setState(() {
          _testResult += '❌ Need at least 2 classes for testing\n';
          _isTesting = false;
        });
        return;
      }

      final classA = classProvider.classes[0];
      final classB = classProvider.classes[1];

      _appendResult('Testing with Class A: ${classA.className} and Class B: ${classB.className}\n');

      // Test 1: Load attendance data for both classes
      _appendResult('Test 1: Loading attendance data for both classes...\n');
      await attendanceProvider.ensureAttendanceLoadedForClass(
          classA.id, attendanceProvider.sessionDate);
      await attendanceProvider.ensureAttendanceLoadedForClass(
          classB.id, attendanceProvider.sessionDate);
      _appendResult('✅ Attendance data loaded for both classes\n');

      // Test 2: Switch to Class A and check data
      _appendResult('Test 2: Switching to Class A...\n');
      await classProvider.setActiveClass(classA);
      await attendanceProvider.loadAttendanceForSession(
          classA.id, attendanceProvider.sessionDate);
      attendanceProvider.setActiveClassId(classA.id);

      final classARecords =
          attendanceProvider.getAttendanceRecordsForClass(classA.id);
      _appendResult(
          '✅ Switched to Class A. Records count: ${classARecords.length}\n');

      // Test 3: Switch to Class B and check data
      _appendResult('Test 3: Switching to Class B...\n');
      await classProvider.setActiveClass(classB);
      await attendanceProvider.loadAttendanceForSession(
          classB.id, attendanceProvider.sessionDate);
      attendanceProvider.setActiveClassId(classB.id);

      final classBRecords =
          attendanceProvider.getAttendanceRecordsForClass(classB.id);
      _appendResult(
          '✅ Switched to Class B. Records count: ${classBRecords.length}\n');

      // Test 4: Switch back to Class A and verify data is still there
      _appendResult('Test 4: Switching back to Class A...\n');
      await classProvider.setActiveClass(classA);
      await attendanceProvider.loadAttendanceForSession(
          classA.id, attendanceProvider.sessionDate);
      attendanceProvider.setActiveClassId(classA.id);

      final classARecordsAfterSwitch =
          attendanceProvider.getAttendanceRecordsForClass(classA.id);
      _appendResult(
          '✅ Switched back to Class A. Records count: ${classARecordsAfterSwitch.length}\n');

      if (classARecords.length == classARecordsAfterSwitch.length) {
        _appendResult('✅ Class A data persistence test PASSED\n');
      } else {
        _appendResult(
            '❌ Class A data persistence test FAILED. Expected ${classARecords.length} records, got ${classARecordsAfterSwitch.length}\n');
      }

      // Test 5: Switch back to Class B and verify data is still there
      _appendResult('Test 5: Switching back to Class B...\n');
      await classProvider.setActiveClass(classB);
      await attendanceProvider.loadAttendanceForSession(
          classB.id, attendanceProvider.sessionDate);
      attendanceProvider.setActiveClassId(classB.id);

      final classBRecordsAfterSwitch =
          attendanceProvider.getAttendanceRecordsForClass(classB.id);
      _appendResult(
          '✅ Switched back to Class B. Records count: ${classBRecordsAfterSwitch.length}\n');

      if (classBRecords.length == classBRecordsAfterSwitch.length) {
        _appendResult('✅ Class B data persistence test PASSED\n');
      } else {
        _appendResult(
            '❌ Class B data persistence test FAILED. Expected ${classBRecords.length} records, got ${classBRecordsAfterSwitch.length}\n');
      }

      _appendResult('\n🎉 All tests completed!\n');
    } catch (e) {
      _appendResult('❌ Test failed with error: $e\n');
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  void _appendResult(String result) {
    setState(() {
      _testResult += result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Persistence Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Class Data Persistence Fix Verification',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This test verifies that attendance data is properly retained when switching between classes.',
            ),
            const SizedBox(height: 24),
            GradientButton(
              isEnabled: !_isTesting,
              onPressed: _isTesting ? () {} : _runTest,
              child: _isTesting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.buttonTextColor),
                      ),
                    )
                  : Text('Run Test', style: TextStyle(color: AppTheme.buttonTextColor)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Test Results:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(_testResult),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}