import 'dart:convert';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../constants/app_constants.dart';
import '../services/control_sheet_service.dart';

import '../models/session_model.dart';

/// Information about a department sheet
class DepartmentSheetInfo {
  final String departmentName;
  final String sheetName;
  final String sheetLink;
  final String credentials;

  DepartmentSheetInfo({
    required this.departmentName,
    required this.sheetName,
    required this.sheetLink,
    required this.credentials,
  });
}

/// Service to handle department sheet updates in Google Sheets
class DepartmentSheetService {
  // Lightweight lock to prevent concurrent operations
  static bool _isOperationInProgress = false;
  


  /// Group present students by department
  static Map<String, List<AttendanceRecord>> _groupStudentsByDepartment(
    List<AttendanceRecord> presentRecords,
    ClassModel classModel,
  ) {
    final departmentStudents = <String, List<AttendanceRecord>>{};
    
    print('Processing ${presentRecords.length} present records:');
    print('Present records count: ${presentRecords.length}');
    
    for (final record in presentRecords) {
      print('Processing present record: ${record.studentName} (${record.studentPinNumber})');
      // Find student in class model to get department/branch
      Student? student;
      try {
        student = classModel.students.firstWhere(
          (s) => s.pinNumber == record.studentPinNumber,
        );
        print('Found student in class model: ${student.name} (${student.pinNumber}) - Branch: "${student.branch}"');
      } catch (e) {
        print('Student ${record.studentPinNumber} not found in class model, creating default student');
        student = Student(
          pinNumber: record.studentPinNumber,
          name: record.studentName,
          email: '',
          phone: '',
          branch: '', // Default to empty branch
          mobileNumber: '',
          combo: '',
        );
      }
      
      // Map student branch to department
      // Branches are ECE, EEE, CSE, etc.
      final department = student.branch.isNotEmpty ? student.branch.toUpperCase() : 'UNKNOWN';
      print('Student ${record.studentName} (${record.studentPinNumber}) belongs to department: "$department"');
      
      if (!departmentStudents.containsKey(department)) {
        departmentStudents[department] = [];
      }
      departmentStudents[department]!.add(record);
    }
    
    return departmentStudents;
  }

  /// Get department sheet information from control sheet
  static Future<DepartmentSheetInfo?> _getDepartmentSheetInfo(String batchName) async {
    try {
      print('Fetching department sheet info for batch: $batchName');
      
      // Get department sheet URL and credentials from control sheet
      final departmentSheetUrl = await ControlSheetService.getDepartmentSheetUrlForBatch(batchName);
      final departmentSheetCredentials = await ControlSheetService.getDepartmentSheetServiceAccountKey(batchName);
      
      if (departmentSheetUrl == null || departmentSheetUrl.isEmpty) {
        print('❌ No department sheet URL found for batch: $batchName');
        return null;
      }
      
      if (departmentSheetCredentials == null || departmentSheetCredentials.isEmpty) {
        print('❌ No department sheet credentials found for batch: $batchName');
        return null;
      }
      
      print('✅ Department sheet info found for batch: $batchName');
      print('  Sheet URL: $departmentSheetUrl');
      
      return DepartmentSheetInfo(
        departmentName: batchName,
        sheetName: 'Department_Attendance', // Default sheet name
        sheetLink: departmentSheetUrl,
        credentials: departmentSheetCredentials,
      );
      
    } catch (e, stackTrace) {
      print('💥 Error getting department sheet info: $e');
      print('📜 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Extract spreadsheet ID from URL
  static String _extractSpreadsheetId(String url) {
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(url);
    if (match == null) {
      throw Exception('Invalid Google Sheets URL');
    }
    return match.group(1)!;
  }

  /// Find or create column for today's date
  static Future<int> _findOrCreateDateColumn(
    sheets.SheetsApi sheetsApi,
    String spreadsheetId,
    String departmentName,
    DateTime date,
  ) async {
    print('Finding or creating column for date: $date in department: $departmentName');
    
    // Format date as DD-MM-YY
    final dateString = '${date.day}-${date.month}-${date.year.toString().substring(2)}';
    print('Looking for date string: $dateString');
    
    // Get header row to find existing date column
    final range = '$departmentName!1:1';
    print('Using header range: $range');
    
    try {
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
      );
      
      final headers = response.values?.firstOrNull ?? [];
      print('Current header row: ${headers.join(", ")}');
      print('Header row length: ${headers.length}');
      
      // Check if date column already exists
      for (int i = 0; i < headers.length; i++) {
        if (headers[i].toString() == dateString) {
          print('Date column already exists at index $i');
          return i;
        }
      }
      
      // Date column doesn't exist, create new column at the end
      final newColumnIndex = headers.length;
      print('Creating new column at index $newColumnIndex for date $dateString');
      
      // Update the header with the new date
      final updateRange = '$departmentName!${_columnIndexToLetter(newColumnIndex)}1';
      print('Updating range: $updateRange with value: $dateString');
      
      final valueRange = sheets.ValueRange(
        range: updateRange,
        values: [
          [dateString]
        ],
      );
      
      await sheetsApi.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        updateRange,
        valueInputOption: 'RAW',
      );
      
      print('✅ Date column created at index $newColumnIndex');
      return newColumnIndex;
      
    } catch (e) {
      print('❌ Error finding or creating date column: $e');
      rethrow;
    }
  }

  /// Convert column index to letter (0=A, 1=B, 25=Z, 26=AA, etc.)
  static String _columnIndexToLetter(int index) {
    String result = '';
    int dividend = index + 1;
    
    while (dividend > 0) {
      int modulo = (dividend - 1) % 26;
      result = String.fromCharCode(65 + modulo) + result;
      dividend = (dividend - modulo) ~/ 26;
    }
    
    return result.isEmpty ? 'A' : result;
  }

  /// Update department sheet with present student data
  static Future<bool> _updateDepartmentSheet({
    required String departmentName,
    required List<AttendanceRecord> presentStudents,
    required DepartmentSheetInfo sheetInfo,
    required SessionType sessionType,
  }) async {
    try {
      print('=== UPDATING DEPARTMENT SHEET ===');
      print('Department: $departmentName');
      print('Students to update: ${presentStudents.length}');
      print('Session type: $sessionType');
      
      // Parse service account credentials
      final serviceAccountJson = json.decode(sheetInfo.credentials);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      
      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = _extractSpreadsheetId(sheetInfo.sheetLink);
      
      // Fetch sheet ID for styling
      int? sheetId;
      try {
        final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
        final sheet = spreadsheet.sheets?.firstWhere(
          (s) => s.properties?.title == departmentName,
          orElse: () => sheets.Sheet(),
        );
        sheetId = sheet?.properties?.sheetId;
        if (sheetId != null) {
           print('✅ Found sheet ID for department $departmentName: $sheetId');
        }
      } catch (e) {
        print('⚠️ Error fetching sheet ID for styling: $e');
      }
      
      // Find or create column for today's date
      final columnIndex = await _findOrCreateDateColumn(
        sheetsApi,
        spreadsheetId,
        departmentName,
        DateTime.now(),
      );
      
      // Get the column letter
      final columnLetter = _columnIndexToLetter(columnIndex);
      print('Using column: $columnLetter for department: $departmentName');
      
      // Get existing data in this column to check current session entries
      final existingDataRange = '$departmentName!$columnLetter:$columnLetter';
      print('Reading existing data from range: $existingDataRange');
      
      final existingDataResponse = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        existingDataRange,
      );
      
      final existingValues = existingDataResponse.values ?? [];
      print('Existing values count: ${existingValues.length}');
      
      // Find if session header already exists
      int sessionStartIndex = -1;
      for (int i = 0; i < existingValues.length; i++) {
        final value = existingValues[i].firstOrNull?.toString().toLowerCase() ?? '';
        if ((sessionType == SessionType.morning && value == 'morning') ||
            (sessionType == SessionType.afternoon && value == 'afternoon')) {
          sessionStartIndex = i;
          break;
        }
      }
      
      // If session header doesn't exist, add it
      if (sessionStartIndex == -1) {
        // Find the next empty row
        int nextRow = existingValues.length + 1;
        
        // If this is afternoon session, we might want to add a gap after morning
        if (sessionType == SessionType.afternoon) {
          // Look for morning session and add after it
          for (int i = 0; i < existingValues.length; i++) {
            final value = existingValues[i].firstOrNull?.toString().toLowerCase() ?? '';
            if (value == 'morning') {
              // Find the end of morning entries
              int morningEndIndex = i + 1;
              while (morningEndIndex < existingValues.length) {
                final nextValue = existingValues[morningEndIndex].firstOrNull?.toString() ?? '';
                if (nextValue.toLowerCase() == 'afternoon' || 
                    RegExp(r'^\d+-\d+-\d+$').hasMatch(nextValue)) {
                  // We've reached the end of morning entries
                  break;
                }
                morningEndIndex++;
              }
              nextRow = morningEndIndex + 2; // Add gap (empty row) and then afternoon header
              print('Found end of morning session at row $morningEndIndex. Starting afternoon at row $nextRow (leaving gap)');
              break;
            }
          }
        }
        
        // Add session header
        final sessionHeaderRange = '$departmentName!${columnLetter}${nextRow}';
        print('Adding session header at range: $sessionHeaderRange');
        
        final sessionHeaderValue = sessionType == SessionType.morning ? 'Morning' : 'Afternoon';
        
        // Use batchUpdate to set value AND formatting (Light Blue)
        if (sheetId != null) {
           await sheetsApi.spreadsheets.batchUpdate(
              sheets.BatchUpdateSpreadsheetRequest(
                 requests: [
                    sheets.Request(
                       updateCells: sheets.UpdateCellsRequest(
                          range: sheets.GridRange(
                             sheetId: sheetId,
                             startRowIndex: nextRow - 1,
                             endRowIndex: nextRow,
                             startColumnIndex: columnIndex,
                             endColumnIndex: columnIndex + 1,
                          ),
                          rows: [
                             sheets.RowData(
                                values: [
                                   sheets.CellData(
                                      userEnteredValue: sheets.ExtendedValue(stringValue: sessionHeaderValue),
                                      userEnteredFormat: sheets.CellFormat(
                                         backgroundColor: sheets.Color(red: 0.812, green: 0.886, blue: 0.953), // #CFE2F3 Light Blue
                                         textFormat: sheets.TextFormat(bold: true),
                                         horizontalAlignment: 'CENTER',
                                      ),
                                   ),
                                ],
                             ),
                          ],
                          fields: 'userEnteredValue,userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)',
                       ),
                    ),
                 ],
              ),
              spreadsheetId,
           );
        } else {
           // Fallback to simple update if sheetId missing
           await sheetsApi.spreadsheets.values.update(
              sheets.ValueRange(
                 range: sessionHeaderRange,
                 values: [[sessionHeaderValue]],
              ),
              spreadsheetId,
              sessionHeaderRange,
              valueInputOption: 'RAW',
           );
        }
        
        sessionStartIndex = nextRow - 1; // Convert to 0-based index
        nextRow++; // Move to next row for student data
      }
      
      // Collect existing roll numbers for this session to avoid duplicates
      final existingRollNumbers = <String>{};
      if (sessionStartIndex >= 0) {
        // Look for existing roll numbers after the session header
        for (int i = sessionStartIndex + 1; i < existingValues.length; i++) {
          final value = existingValues[i].firstOrNull?.toString() ?? '';
          // Stop if we reach another session header or date header
          if (value.toLowerCase() == 'morning' || 
              value.toLowerCase() == 'afternoon' || 
              RegExp(r'^\d+-\d+-\d+$').hasMatch(value)) {
            break;
          }
          if (value.isNotEmpty) {
            existingRollNumbers.add(value);
          }
        }
      }
      
      print('Existing roll numbers for this session: ${existingRollNumbers.length}');
      
      // Filter out students who are already recorded
      final newStudents = presentStudents.where(
        (record) => !existingRollNumbers.contains(record.studentPinNumber)
      ).toList();
      
      print('New students to add: ${newStudents.length}');
      
      if (newStudents.isEmpty) {
        print('No new students to add for this session');
        client.close();
        return true;
      }
      
      // Prepare student data for batch update
      final studentData = newStudents.map((record) => [record.studentPinNumber]).toList();
      print('Prepared ${studentData.length} student records for update');
      
      // Find the insertion point (after session header and existing entries)
      int insertRow = sessionStartIndex + existingRollNumbers.length + 2; // +1 for header, +1 for 1-based indexing
      
      // If no session header was found, insert after existing data
      if (sessionStartIndex == -1) {
        insertRow = existingValues.length + 2; // +1 for session header, +1 for 1-based indexing
      }
      
      // Create the range for batch update
      final startRange = '$departmentName!${columnLetter}$insertRow';
      print('Inserting student data starting at range: $startRange');
      
      // Batch update student roll numbers
      final valueRange = sheets.ValueRange(
        range: startRange,
        values: studentData,
      );
      
      final response = await sheetsApi.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        startRange,
        valueInputOption: 'RAW',
      );
      
      print('✅ Department sheet update response:');
      print('  Updated range: ${response.updatedRange}');
      print('  Updated cells: ${response.updatedCells}');
      
      client.close();
      return true;
      
    } catch (e, stackTrace) {
      print('💥 Error updating department sheet: $e');
      print('📜 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Update department data with present student data
  /// Returns null on success, or an error message string on failure
  static Future<String?> updateDepartmentSheets({
    required ClassModel classModel,
    required List<AttendanceRecord> attendanceRecords,
    required SessionType sessionType,
  }) async {
    print('=== DEPARTMENT SHEET SERVICE CALLED ===');
    print('=== DETAILED DEPARTMENT DEBUG INFO ===');
    print('Class Model Details:');
    print('  Class Name: ${classModel.className}');
    print('  Class ID: ${classModel.id}');
    print('  Students Count: ${classModel.students.length}');
    print('Attendance Records Details:');
    print('  Total Records: ${attendanceRecords.length}');
    
    // Print all attendance records for debugging
    print('All Attendance Records:');
    for (int i = 0; i < attendanceRecords.length; i++) {
      final record = attendanceRecords[i];
      print('  Record $i: ${record.studentName} (${record.studentPinNumber}) - ${record.status} - ${record.isSyncedToSheet ? "Synced" : "Not Synced"} - ID: ${record.id}');
    }
    
    print('=== UPDATING DEPARTMENT SHEETS IN GOOGLE SHEETS ===');
    print('Class: ${classModel.className}');
    print('Attendance records: ${attendanceRecords.length}');
    print('Class model students count: ${classModel.students.length}');
    print('Attendance records count: ${attendanceRecords.length}');
    
    // Lightweight lock to prevent concurrent operations
    while (_isOperationInProgress) {
      print('⚠️ Another operation is in progress, waiting...');
      await Future.delayed(Duration(milliseconds: 100));
    }
    _isOperationInProgress = true;
    print('🔒 Acquired operation lock for department sheets');
    
    try {
      // Get department sheet information
      final sheetInfo = await _getDepartmentSheetInfo(classModel.sheetName ?? classModel.className);
      if (sheetInfo == null) {
        print('❌ Could not get department sheet information');
        return "Failed: Sheet Info not found for ${classModel.className}";
      }
      
      // Filter for present students only
      final presentRecords = attendanceRecords
          .where((record) => record.status == AttendanceStatus.present)
          .toList();
      
      print('Present records: ${presentRecords.length}');
      print('Present students details:');
      for (int i = 0; i < presentRecords.length; i++) {
        final record = presentRecords[i];
        print('  Present Record $i: ${record.studentName} (${record.studentPinNumber}) - ID: ${record.id}');
      }
      
      if (presentRecords.isEmpty) {
        print('No present students to update in department sheets');
        // This is technically a success (nothing to update)
        // But maybe return a note?
        return "No present students found";
      }
      
      // Group present students by department
      final departmentStudents = _groupStudentsByDepartment(presentRecords, classModel);
      
      print('Students grouped by department:');
      departmentStudents.forEach((dept, records) {
        print('  Department "$dept": ${records.length} students');
      });
      
      // Use passed session type
      print('Using session type: $sessionType');
      
      // Process each student department (branch) and update its sheet
      print('Processing ${departmentStudents.length} departments...');
      print('Processing ${departmentStudents.length} departments...');
      
      // Create a list of futures to run in parallel
      final updateFutures = departmentStudents.entries.map((departmentEntry) async {
        final departmentName = departmentEntry.key;  // This is the branch name (ECE, EEE, CSE)
        final students = departmentEntry.value;
        
        print('Queueing update for department: $departmentName with ${students.length} students');
        
        final success = await _updateDepartmentSheet(
          departmentName: departmentName,
          presentStudents: students,
          sheetInfo: sheetInfo,
          sessionType: sessionType,
        );

        if (!success) {
           return "Failed to update $departmentName";
        }
        return null; // Success
      }).toList();
      
      // Wait for all updates to complete
      print('Waiting for ${updateFutures.length} department updates to complete...');
      final results = await Future.wait(updateFutures);
      
      // Collect errors
      final errors = results.where((e) => e != null).toList();
      
      if (errors.isEmpty) {
        print('✅ All department sheet updates successful');
        return null; // Success
      } else {
        print('❌ Some department updates failed: $errors');
        return "Partial/Full Failure: ${errors.join(', ')}";
      }
      
    } catch (e, stackTrace) {
      print('💥 Error updating department sheets: $e');
      print('📜 Stack trace: $stackTrace');
      return "Exception: $e";
    } finally {
      // Release the lock
      _isOperationInProgress = false;
      print('🔓 Released operation lock after department sheets update');
    }
  }
}