import 'dart:convert';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import '../models/class_model.dart';
import '../models/student_details.dart';
import '../services/control_sheet_service.dart';
import '../services/sheet_data_service.dart';
import '../constants/app_constants.dart';
import 'firebase_config_service.dart';

class AttendanceSheetService {
  /// Search for a student by roll number in the master sheet (class sheet) and calculate attendance percentage
  static Future<StudentDetails?> searchStudentByRollNumber(
    ClassModel classModel,
    String rollNumber,
  ) async {
    try {
      print('🔍 Searching for student with roll number: $rollNumber in class: ${classModel.className}');
      print('Class model details:');

      print('📋 Using master sheet URL: ${classModel.googleSheetUrl}');

      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        final keyString = await FirebaseConfigService.readServiceAccountJson();
        if (keyString == null) throw Exception('Service account key not found');
        serviceAccountJson = json.decode(keyString);
      } catch (e) {
        print('❌ Invalid service account JSON format: $e');
        throw Exception('Invalid service account JSON format: $e');
      }

      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      } catch (e) {
        print('❌ Failed to create service account credentials: $e');
        throw Exception('Failed to create service account credentials: $e');
      }

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      // First, get student details from master sheet
      final studentDetails = await _getStudentDetailsFromMasterSheet(
        client, 
        classModel, 
        rollNumber
      );
      
      if (studentDetails == null) {
        client.close();
        return null;
      }

      // Then, get attendance percentage from attendance sheet
      final attendanceData = await _getAttendancePercentage(
        client, 
        classModel, 
        rollNumber
      );
      
      client.close();
      
      // Combine student details with attendance data
      return StudentDetails(
        name: studentDetails.name,
        rollNumber: studentDetails.rollNumber,
        branch: studentDetails.branch,
        email: studentDetails.email,
        mobile: studentDetails.mobile,
        combo: studentDetails.combo,
        attendancePercentage: attendanceData.attendancePercentage,
        totalSessions: attendanceData.totalSessions,
        attendedSessions: attendanceData.attendedSessions,
      );
      
    } catch (e, stackTrace) {
      print('💥 Error searching student by roll number: $e');
      print('📜 Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Get student details from master sheet
  static Future<StudentDetails?> _getStudentDetailsFromMasterSheet(
    AuthClient client,
    ClassModel classModel,
    String rollNumber,
  ) async {
    try {
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = SheetDataService.extractSpreadsheetId(classModel.googleSheetUrl!);

      // Determine the range to fetch based on whether we're using a specific sheet
      String range = 'A:ZZZ'; // Default range for single sheet
      if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        range = '${classModel.sheetName}!A:ZZZ'; // Specific sheet range
      }

      print('📄 Searching student details in range: $range');

      // Fetch data from the sheet
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
      );

      final values = response.values ?? [];
      print('📊 Master sheet has ${values.length} rows');
      
      if (values.isEmpty) {
        print('⚠️ No data found in the master sheet');
        return null;
      }

      // Parse headers
      final headerRow = values[0];
      print('📋 Headers in master sheet: $headerRow');
      
      // Create a map of header names to their column indices
      final headerMap = <String, int>{};
      for (int i = 0; i < headerRow.length; i++) {
        headerMap[headerRow[i].toString().trim()] = i;
      }
      
      // Find the Pin-number column
      final pinNumberColumnIndex = headerMap['Pin-number'] ?? -1;
      final nameColumnIndex = headerMap['Name of the Student'] ?? headerMap['Name'] ?? 0;
      final branchColumnIndex = headerMap['Branch'] ?? 2;
      final emailColumnIndex = headerMap['Mail-id'] ?? headerMap['Email'] ?? 3;
      final mobileColumnIndex = headerMap['Mobile Number'] ?? headerMap['Mobile'] ?? 4;
      final comboColumnIndex = headerMap['COMBO'] ?? 5;

      print('📍 Column indices - Pin-number: $pinNumberColumnIndex, Name: $nameColumnIndex, Branch: $branchColumnIndex, Email: $emailColumnIndex, Mobile: $mobileColumnIndex, Combo: $comboColumnIndex');

      if (pinNumberColumnIndex == -1) {
        print('⚠️ Pin-number column not found in master sheet');
        return null;
      }

      // Search through data rows
      for (int i = 1; i < values.length; i++) {
        final row = values[i];
        print('🔎 Checking row $i: $row');
        
        // Check if this row has the matching roll number
        if (pinNumberColumnIndex < row.length) {
          final rowPinNumber = row[pinNumberColumnIndex].toString().trim();
          print('🔄 Comparing "$rowPinNumber" with "$rollNumber" (case-insensitive)');
          // Case-insensitive comparison with whitespace trimming as per specification
          if (rowPinNumber.toLowerCase().trim() == rollNumber.toLowerCase().trim()) {
            print('🎉 Found matching roll number in row $i');
            // Found the student, extract all details
            final name = nameColumnIndex < row.length 
                ? row[nameColumnIndex].toString().trim() 
                : 'N/A';
                
            final branch = branchColumnIndex < row.length 
                ? row[branchColumnIndex].toString().trim() 
                : 'N/A';
                
            final email = emailColumnIndex < row.length 
                ? row[emailColumnIndex].toString().trim() 
                : 'N/A';
                
            final mobile = mobileColumnIndex < row.length 
                ? row[mobileColumnIndex].toString().trim() 
                : 'N/A';
                
            final combo = comboColumnIndex < row.length 
                ? row[comboColumnIndex].toString().trim() 
                : 'N/A';

            print('✅ Found student: $name with roll number: $rollNumber');
            
            return StudentDetails(
              name: name,
              rollNumber: rollNumber,
              branch: branch,
              email: email,
              mobile: mobile,
              combo: combo,
            );
          }
        }
      }

      print('❓ Student with roll number $rollNumber not found in class ${classModel.className}');
      return null;
      
    } catch (e, stackTrace) {
      print('💥 Error getting student details from master sheet: $e');
      print('📜 Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Get attendance percentage from attendance sheet
  static Future<StudentDetails> _getAttendancePercentage(
    AuthClient client,
    ClassModel classModel,
    String rollNumber,
  ) async {
    try {
      print('=== DEBUG: _getAttendancePercentage ===');
      print('Class: ${classModel.className}');
      print('Roll number: $rollNumber');
      
      // Get attendance sheet URL for this batch
      String? attendanceSheetUrl = await ControlSheetService.getAttendanceSheetUrlForBatch(classModel.sheetName ?? classModel.className);
      print('Attendance sheet URL from ControlSheetService: $attendanceSheetUrl');
      
      // If we couldn't find the attendance sheet URL by class name, try other approaches
      if (attendanceSheetUrl == null) {
        print('⚠️ Could not find attendance sheet URL by class name. Trying alternative approaches...');
        
        // Try to get batch configurations and find the attendance sheet URL from any batch
        try {
          final batchConfigs = await ControlSheetService.readBatchConfigs();
          if (batchConfigs.isNotEmpty) {
            // Use the first batch's attendance sheet URL as fallback
            final firstBatch = batchConfigs.values.first;
            if (firstBatch.attendanceSheet != null) {
              attendanceSheetUrl = firstBatch.attendanceSheet!.link;
              print('🔄 Using fallback attendance sheet URL: $attendanceSheetUrl');
            }
          }
        } catch (e) {
          print('⚠️ Error getting fallback attendance sheet URL: $e');
        }
      }
      
      if (attendanceSheetUrl == null) {
        print('⚠️ No attendance sheet URL found for class: ${classModel.className}');
        return StudentDetails(
          name: '',
          rollNumber: rollNumber,
          branch: '',
          email: '',
          mobile: '',
          combo: '',
          attendancePercentage: 0.0,
          totalSessions: 0,
          attendedSessions: 0,
        );
      }

      print('📋 Using attendance sheet URL: $attendanceSheetUrl');

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = ControlSheetService.extractSpreadsheetId(attendanceSheetUrl);
      print('Spreadsheet ID: $spreadsheetId');

      // First, get the spreadsheet metadata to see what sheets exist
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      final sheetNames = spreadsheet.sheets?.map((sheet) => sheet.properties?.title ?? '').toList() ?? [];
      
      print('📚 Available sheets in attendance workbook: $sheetNames');

      // Search through each sheet for the student's attendance
      int totalSessions = 0;
      int attendedSessions = 0;
      
      // Use the class name as sheet name or search all sheets
      String targetSheetName = classModel.sheetName ?? classModel.className;
      print('Target sheet name: $targetSheetName');
      
      // Try to find the sheet by class name first
      String? sheetNameToUse;
      for (final sheetName in sheetNames) {
        print('Checking sheet: "$sheetName" against target: "$targetSheetName"');
        if (sheetName.toLowerCase() == targetSheetName.toLowerCase()) {
          sheetNameToUse = sheetName;
          print('✅ Found matching sheet: $sheetNameToUse');
          break;
        }
      }
      
      // If not found, try partial matching
      if (sheetNameToUse == null) {
        for (final sheetName in sheetNames) {
          if (sheetName.toLowerCase().contains(targetSheetName.toLowerCase()) || 
              targetSheetName.toLowerCase().contains(sheetName.toLowerCase())) {
            sheetNameToUse = sheetName;
            // print('🔄 Found partial match sheet: $sheetNameToUse');
            break;
          }
        }
      }
      
      // If still not found, use the first sheet
      if (sheetNameToUse == null && sheetNames.isNotEmpty) {
        sheetNameToUse = sheetNames.first;
        print('⚠️ Using first sheet as fallback: $sheetNameToUse');
      }
      
      if (sheetNameToUse != null) {
        print('📄 Searching attendance in sheet: $sheetNameToUse');
        
        try {
          // Read the sheet data with a larger range to capture all columns
          final response = await sheetsApi.spreadsheets.values.get(
            spreadsheetId,
            '$sheetNameToUse!A:ZZZ', // Read all columns to respect Google Sheets limits
          );

          final values = response.values ?? [];
          print('📊 Attendance sheet $sheetNameToUse has ${values.length} rows');
          
          if (values.length > 1) { // Need at least header row and one data row
            // Look for column headers
            final headers = values.first;
            print('📋 Headers in attendance sheet: ${headers.join(" | ")}');
            print('📋 Headers length: ${headers.length}');
            
            // Find the Pin-number column (exact match like in working implementation)
            int pinNumberColumnIndex = -1;
            for (int i = 0; i < headers.length; i++) {
              final header = headers[i].toString().trim();
              print('Checking header at index $i: "$header"');
              if (header == 'Pin-number') {
                pinNumberColumnIndex = i;
                print('📍 Found Pin-number column at index: $pinNumberColumnIndex');
                break;
              }
            }
            
            // Find the Sec-Codes column to determine where date columns start
            int secCodesColumnIndex = -1;
            for (int i = 0; i < headers.length; i++) {
              final header = headers[i].toString().trim();
              print('Checking header for Sec-Codes at index $i: "$header"');
              if (header == 'Sec-Codes') {
                secCodesColumnIndex = i;
                print('📍 Found Sec-Codes column at index: $secCodesColumnIndex');
                break;
              }
            }
            
            if (pinNumberColumnIndex != -1) {
              // Collect date column headers (columns after Sec-Codes column)
              final List<String> dates = [];
              if (secCodesColumnIndex == -1) {
                print('⚠️ Sec-Codes column not found, reading all columns after Pin-number');
                // Get all columns after the Pin-number column as date columns
                for (int i = pinNumberColumnIndex + 1; i < headers.length; i++) {
                  dates.add(headers[i].toString());
                }
                print('📅 Found ${dates.length} date columns after Pin-number (fallback mode)');
              } else {
                // Get all columns after the Sec-Codes column as date columns
                for (int i = secCodesColumnIndex + 1; i < headers.length; i++) {
                  dates.add(headers[i].toString());
                }
                print('📅 Found ${dates.length} date columns after Sec-Codes');
                print('📅 Date columns: ${dates.join(", ")}');
              }
              
              totalSessions = dates.length;
              print('📅 Found $totalSessions date columns (sessions)');
              
              // Find the row with the specified roll number in the Pin-number column (exact match like in working implementation)
              int rollNumberRowIndex = -1;
              print('🔍 Searching for roll number: "$rollNumber"');
              for (int i = 1; i < values.length; i++) { // Skip header row
                if (values[i].length > pinNumberColumnIndex) {
                  final cellValue = values[i][pinNumberColumnIndex].toString().trim();
                  print('Checking row $i, column $pinNumberColumnIndex: "$cellValue"');
                  if (cellValue == rollNumber) {
                    rollNumberRowIndex = i;
                    print('✅ Found roll number $rollNumber at row index: $rollNumberRowIndex');
                    break;
                  }
                }
              }

              if (rollNumberRowIndex != -1) {
                // Get attendance data for this roll number across all date columns
                final rollNumberRow = values[rollNumberRowIndex];
                print('📊 Processing attendance data for roll number $rollNumber');
                print('📊 Total date columns to process: $totalSessions');
                print('📊 Data row length: ${rollNumberRow.length}');

                // Determine starting column for date data
                int startDateColumnIndex;
                if (secCodesColumnIndex != -1) {
                  // Start reading from the column after Sec-Codes
                  startDateColumnIndex = secCodesColumnIndex + 1;
                } else {
                  // Fallback: start reading from the column after Pin-number
                  startDateColumnIndex = pinNumberColumnIndex + 1;
                }
                
                print('📊 Starting date data reading from column index: $startDateColumnIndex');
                
                // Count attended sessions (exact matching logic like in working implementation)
                int attendedCount = 0;
                for (int dateIndex = 0; dateIndex < dates.length; dateIndex++) {
                  int columnIndex = startDateColumnIndex + dateIndex;
                  
                  // Check if we have data for this column and it's within limits
                  String status = '';
                  if (columnIndex < rollNumberRow.length && columnIndex < 18278) { // Respect column limit
                    status = rollNumberRow[columnIndex].toString().toLowerCase().trim();
                  }
                  
                  final isPresent = status == 'present' || status == 'p' || status == '1';
                  if (isPresent) {
                    attendedCount++;
                  }
                  
                  // Print debug info for first few entries
                  if (dateIndex < 5) {
                    print('📊 Date $dateIndex: Column $columnIndex, Date: ${dates[dateIndex]}, Status: "$status", Present: $isPresent');
                  }
                }
                
                attendedSessions = attendedCount;
                print('✅ Student attended $attendedSessions out of $totalSessions sessions');
              } else {
                print('❓ Roll number $rollNumber not found in attendance sheet');
                // Let's also try a more flexible search
                print('🔍 Trying flexible search for roll number: "$rollNumber"');
                for (int i = 1; i < values.length; i++) { // Skip header row
                  if (values[i].length > pinNumberColumnIndex) {
                    final cellValue = values[i][pinNumberColumnIndex].toString().trim();
                    print('Flexible check row $i: "$cellValue" vs "$rollNumber"');
                    if (cellValue.toLowerCase().contains(rollNumber.toLowerCase()) || 
                        rollNumber.toLowerCase().contains(cellValue.toLowerCase())) {
                      print('🔄 Flexible match found at row $i: "$cellValue"');
                    }
                  }
                }
              }
            } else {
              print('⚠️ Pin-number column not found in attendance sheet');
              // Let's check what headers we actually have
              print('📋 Actual headers in sheet:');
              for (int i = 0; i < headers.length; i++) {
                print('  Header $i: "${headers[i]}"');
              }
            }
          } else {
            print('⚠️ Not enough data in sheet (need at least 2 rows, got ${values.length})');
          }
        } catch (e, stackTrace) {
          print('❌ Error reading attendance sheet $sheetNameToUse: $e');
          print('📜 Stack trace: $stackTrace');
        }
      } else {
        print('⚠️ No suitable sheet found in attendance workbook');
      }

      // Calculate percentage
      double attendancePercentage = totalSessions > 0 
          ? (attendedSessions / totalSessions) * 100 
          : 0.0;
          
      print('📊 Attendance summary - Total: $totalSessions, Attended: $attendedSessions, Percentage: ${attendancePercentage.toStringAsFixed(1)}%');

      return StudentDetails(
        name: '',
        rollNumber: rollNumber,
        branch: '',
        email: '',
        mobile: '',
        combo: '',
        attendancePercentage: attendancePercentage,
        totalSessions: totalSessions,
        attendedSessions: attendedSessions,
      );
      
    } catch (e, stackTrace) {
      print('💥 Error getting attendance percentage: $e');
      print('📜 Stack trace: $stackTrace');
      
      // Return default values
      return StudentDetails(
        name: '',
        rollNumber: rollNumber,
        branch: '',
        email: '',
        mobile: '',
        combo: '',
        attendancePercentage: 0.0,
        totalSessions: 0,
        attendedSessions: 0,
      );
    }
  }
  
  /// Helper method to find column index by possible header names
  static int _findColumnIndex(List<dynamic> headers, List<String> possibleNames) {
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toString().trim().toLowerCase();
      for (final name in possibleNames) {
        // Also check for variations with spaces replaced by underscores and vice versa
        final normalizedName = name.toLowerCase();
        if (header == normalizedName || 
            header == normalizedName.replaceAll(' ', '_') || 
            header == normalizedName.replaceAll('_', ' ') ||
            header == normalizedName.replaceAll('-', ' ') ||
            header == normalizedName.replaceAll(' ', '-')) {
          return i;
        }
      }
    }
    return -1; // Not found
  }
}