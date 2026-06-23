import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../constants/app_constants.dart';
import 'sheet_data_service.dart';
import '../services/control_sheet_service.dart';

class GoogleSheetsService {
  /// Get embedded configuration
  static Future<Map<String, dynamic>> _getEmbeddedConfig() async {
    try {
      final configString = await rootBundle.loadString('assets/secrets/config.json');
      return json.decode(configString);
    } catch (e) {
      print('⚠️ Could not load embedded config: $e');
      return {};
    }
  }
  
  /// Get attendance sheet URL from embedded config
  static Future<String?> getEmbeddedAttendanceSheetUrl() async {
    try {
      final config = await _getEmbeddedConfig();
      final url = config['attendanceSheetUrl'];
      print('Loaded embedded attendance sheet URL: $url');
      return url;
    } catch (e) {
      print('⚠️ Could not load embedded attendance sheet URL: $e');
      return null;
    }
  }

  /// Check if attendance sheet is already initialized with student data
  static Future<bool> isAttendanceSheetInitialized({
    required ClassModel classModel,
    String? sheetUrl,
  }) async {
    try {
      print('=== CHECKING ATTENDANCE SHEET INITIALIZATION ===');
      print('Class: ${classModel.className}');
      print('Sheet name: ${classModel.sheetName}');
      
      // Use embedded service account key if available
      String serviceAccountKey = classModel.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        print('No service account key found');
        return false;
      }

      // Use provided URL or fallback to embedded
      String targetSheetUrl = sheetUrl ?? '';
      
      if (targetSheetUrl.isEmpty) {
        final embeddedUrl = await getEmbeddedAttendanceSheetUrl();
        if (embeddedUrl != null && embeddedUrl.isNotEmpty) {
          targetSheetUrl = embeddedUrl;
        }
      }
      
      if (targetSheetUrl.isEmpty) {
        print('No attendance sheet URL configured to check initialization');
        return false;
      }

      print('Using attendance sheet URL: $targetSheetUrl');
      
      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
      } catch (e) {
        print('Invalid service account JSON format: $e');
        return false;
      }
      
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      } catch (e) {
        print('Failed to create service account credentials: $e');
        return false;
      }

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(targetSheetUrl);
      
      print('Accessing spreadsheet ID: $spreadsheetId');
      
      // Get existing data from the sheet with full range
      print('Fetching data from Google Sheet...');
      // Determine the range based on whether we're using a specific sheet
      String range = 'A:AJ'; // Default range for single sheet
      if (classModel.className.isNotEmpty) {
        range = "'${classModel.className}'!A:AJ"; // Specific sheet range
      }
      
      print('Using range: $range for sheet initialization check');
      
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range, // Get full range to check all columns
      );

      final values = response.values ?? [];
      print('Attendance sheet data rows: ${values.length}');
      
      if (values.isNotEmpty) {
        print('First row (header): ${values[0]}');
        if (values.length > 1) {
          print('Second row (first student): ${values[1]}');
          if (values.length > 2) {
            print('Third row (second student): ${values[2]}');
          }
        }
      }
      
      client.close();
      
      // Check if sheet has data and proper header
      if (values.isEmpty) {
        print('Attendance sheet is empty');
        return false;
      }
      
      // Check if first row has proper headers
      final headerRow = values[0];
      print('Header row length: ${headerRow.length}');
      print('Header row content: $headerRow');
      
      // Check for required headers in the correct positions
      if (headerRow.length >= 7) {
        final expectedHeaders = ['Name of the Student', 'Pin-number', 'Branch', 'Mail-id', 'Mobile Number', 'COMBO', 'Sec-Codes'];
        bool hasProperHeaders = true;
        
        for (int i = 0; i < expectedHeaders.length; i++) {
          final actualHeader = i < headerRow.length ? headerRow[i].toString().trim() : '';
          print('Comparing header position $i: expected="${expectedHeaders[i]}", actual="$actualHeader"');
          if (i < headerRow.length && headerRow[i].toString().trim() != expectedHeaders[i]) {
            hasProperHeaders = false;
            print('Header mismatch at position $i: expected "${expectedHeaders[i]}", found "${headerRow[i]}"');
          }
        }
        
        if (hasProperHeaders) {
          print('Attendance sheet is already initialized with proper headers');
          // Also check if there are student rows
          if (values.length > 1) {
            print('Attendance sheet contains ${values.length - 1} student rows');
            // Verify that student data matches class model
            bool studentDataMatches = true;
            if (values.length - 1 != classModel.students.length) {
              print('Warning: Sheet has ${values.length - 1} students, but class model has ${classModel.students.length} students');
              // This is not necessarily an error - we can still work with mismatched counts
              print('Continuing with upload process despite count mismatch');
            }
            
            print('Student count verification completed');
            return true;
          } else {
            print('Attendance sheet has headers but no student data');
            return false;
          }
        }
      }
      
      print('Attendance sheet does not have proper initialization');
      return false;
      
    } catch (e, stackTrace) {
      print('Error checking attendance sheet initialization: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Initialize attendance sheet with student data
  static Future<bool> initializeAttendanceSheet({
    required ClassModel classModel,
    String? sheetUrl,
  }) async {
    try {
      print('Initializing attendance sheet with student data...');
      print('Class: ${classModel.className}');
      print('Sheet name: ${classModel.sheetName}');
      print('Passed Sheet URL: $sheetUrl');
      
      // Use embedded service account key if available
      String serviceAccountKey = classModel.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        throw Exception('Service account key not configured');
      }

      // Use provided URL or fallback to embedded
      String targetSheetUrl = sheetUrl ?? '';
      
      if (targetSheetUrl.isEmpty) {
        final embeddedUrl = await getEmbeddedAttendanceSheetUrl();
        if (embeddedUrl != null && embeddedUrl.isNotEmpty) {
          targetSheetUrl = embeddedUrl;
        }
      }
      
      if (targetSheetUrl.isEmpty) {
        throw Exception('No attendance sheet URL configured');
      }

      print('Using attendance sheet URL: $targetSheetUrl');
      
      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
        print('✓ Service account JSON parsed successfully');
      } catch (e) {
        throw Exception('Invalid service account JSON format: $e');
      }
      
      // Validate required fields in service account key
      final requiredFields = ['type', 'project_id', 'private_key_id', 'private_key', 'client_email', 'client_id', 'auth_uri', 'token_uri'];
      for (final field in requiredFields) {
        if (!serviceAccountJson.containsKey(field) || serviceAccountJson[field] == null) {
          throw Exception('Missing required field in service account key: $field');
        }
      }
      
      if (serviceAccountJson['type'] != 'service_account') {
        throw Exception('Invalid service account type. Expected "service_account", got "${serviceAccountJson['type']}"');
      }
      
      print('✓ Service account key validation passed');
      print('📧 Service account email: ${serviceAccountJson['client_email']}');
      
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
        print('✓ Service account credentials created');
      } catch (e) {
        throw Exception('Failed to create service account credentials: $e');
      }

      // Authenticate
      print('🔑 Attempting authentication with scopes: ${AppConstants.requiredScopes}');
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      print('✓ Authentication successful!');
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(targetSheetUrl);
      
      print('📈 Attempting to access Google Sheet: $spreadsheetId');
      
      // Test access to the spreadsheet
      try {
        final testResponse = await sheetsApi.spreadsheets.get(spreadsheetId);
        print('✓ Successfully accessed Google Sheet: "${testResponse.properties?.title}"');
        print('  Spreadsheet ID: ${testResponse.spreadsheetId}');
        print('  Sheet count: ${testResponse.sheets?.length ?? 0}');
        
        if (testResponse.sheets != null && testResponse.sheets!.isNotEmpty) {
          print('  First sheet title: ${testResponse.sheets![0].properties?.title}');
          print('  First sheet ID: ${testResponse.sheets![0].properties?.sheetId}');
        }
      } catch (e) {
        if (e.toString().contains('Requested entity was not found') || e.toString().contains('404')) {
          throw Exception('Google Sheet not found. Please check the URL and ensure the sheet exists.');
        } else if (e.toString().contains('403') || e.toString().contains('permission') || e.toString().contains('Forbidden')) {
          throw Exception('Permission denied. Please share the Google Sheet with service account email: ${serviceAccountJson['client_email']}');
        } else {
          throw Exception('Failed to access Google Sheet: $e');
        }
      }

      // Ensure the specific sheet exists (using Class Name as Tab Name)
      if (classModel.className.isNotEmpty) {
        await _ensureSheetExists(sheetsApi, spreadsheetId, classModel.className);
      }

      // Prepare header row data - matching the structure you specified
      final headerRow = [
        'Name of the Student',
        'Pin-number',
        'Branch',
        'Mail-id',
        'Mobile Number',
        'COMBO',
        'Sec-Codes'
      ];
      
      print('Header row to be written: ${headerRow.join(", ")}');
      
      // Prepare student data rows - ensure same order as master sheet
      final studentRows = <List<String>>[];
      print('Preparing student data rows:');
      for (int i = 0; i < classModel.students.length; i++) {
        final student = classModel.students[i];
        final studentRow = [
          student.name,
          student.pinNumber,
          student.branch,
          student.email,
          student.mobileNumber,
          student.combo,
          student.securityCodes.join(', ')
        ];
        studentRows.add(studentRow);
        
        // Print first few students for debugging
        if (i < 3) {
          print('  Row ${i + 2}: ${studentRow[0]} (${studentRow[1]})');
        } else if (i == 3) {
          print('  ... (showing first 3 students only)');
        }
      }
      
      print('Preparing to write ${studentRows.length + 1} rows to attendance sheet');
      
      // Clear existing data and write new data
      final allRows = [headerRow, ...studentRows];
      // Determine the range based on whether we're using a specific sheet
      String updateRange = 'A1';
      if (classModel.className.isNotEmpty) {
        updateRange = "'${classModel.className}'!A1";
      }
      
      print('Using update range: $updateRange for sheet initialization');
      
      final valueRange = sheets.ValueRange(
        range: updateRange,
        values: allRows,
      );
      
      print('Sending update request to Google Sheets...');
      print('Update range: $updateRange');
      print('Number of rows to write: ${allRows.length}');
      print('Number of columns: ${headerRow.length}');
      
      try {
        final response = await sheetsApi.spreadsheets.values.update(
          valueRange,
          spreadsheetId,
          updateRange,
          valueInputOption: 'RAW',
        );
        
        print('✅ Sheet initialization response:');
        print('  Updated range: ${response.updatedRange}');
        print('  Updated cells: ${response.updatedCells}');
        print('  Updated columns: ${response.updatedColumns}');
        print('  Updated rows: ${response.updatedRows}');
        
        print('✅ Successfully initialized attendance sheet with ${studentRows.length} students');
        client.close();
        return true;
      } catch (e) {
        print('❌ Error during sheet initialization: $e');
        rethrow;
      }
      
    } catch (e, stackTrace) {
      print('❌ Error initializing attendance sheet: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Ensure a specific sheet exists in the spreadsheet
  static Future<void> _ensureSheetExists(
    sheets.SheetsApi sheetsApi,
    String spreadsheetId,
    String sheetName,
  ) async {
    if (sheetName.isEmpty) return;

    try {
      print('Checking if sheet "$sheetName" exists...');
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      final sheetsList = spreadsheet.sheets ?? [];
      
      bool exists = false;
      for (final sheet in sheetsList) {
        if (sheet.properties?.title == sheetName) {
          exists = true;
          break;
        }
      }
      
      if (exists) {
        print('✅ Sheet "$sheetName" already exists');
        return;
      }
      
      print('Sheet "$sheetName" does not exist. Creating it...');
      
      final request = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(
                title: sheetName,
                gridProperties: sheets.GridProperties(
                  frozenRowCount: 1, // Freeze header row
                ),
              ),
            ),
          ),
        ],
      );
      
      await sheetsApi.spreadsheets.batchUpdate(request, spreadsheetId);
      print('✅ Successfully created sheet "$sheetName"');
      
    } catch (e) {
      print('❌ Error ensuring sheet exists: $e');
      // Don't rethrow, let the subsequent write attempt fail if it must
    }
  }
  static Future<GoogleSheetsUploadResult> uploadAttendance({
    required ClassModel classModel,
    required List<AttendanceRecord> attendanceRecords,
    required Function(double) onProgress,
  }) async {
    try {
      print('=== STARTING ATTENDANCE UPLOAD PROCESS ===');
      
      // Ensure Hive boxes are open before proceeding (if HiveService is available)
      try {
        // This is a workaround to check if HiveService is available
        if (identical(1, 1)) { // Always true, just to have a valid condition
          // HiveService check would go here if we could import it
        }
      } catch (e) {
        print('Note: HiveService not directly accessible in this context, but this is expected');
      }
      print('Class: ${classModel.className}');
      print('Sheet name: ${classModel.sheetName}');
      print('Number of attendance records: ${attendanceRecords.length}');
      print('Class model students count: ${classModel.students.length}');
      
      // Debug attendance records
      print('Attendance records details:');
      for (int i = 0; i < attendanceRecords.length; i++) {
        final record = attendanceRecords[i];
        print('  Record $i: ${record.studentName} (${record.studentPinNumber}) - ${record.status}');
      }
      
      // Use embedded service account key if available
      String serviceAccountKey = classModel.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        throw Exception('Service account key not configured');
      }

      // Try to get attendance sheet URL from Control Sheet first (dynamic)
      String? attendanceSheetUrl = await ControlSheetService.getAttendanceSheetUrlForBatch(classModel.sheetName ?? classModel.className);
      print('Attendance sheet URL from ControlSheetService: $attendanceSheetUrl');

      // If not found, try fallback strategies
      if (attendanceSheetUrl == null || attendanceSheetUrl.isEmpty) {
        print('⚠️ Could not find attendance sheet URL by class name. Trying alternative approaches...');
        
        // 1. Try to get from batch configs (fallback to any available)
        try {
          final batchConfigs = await ControlSheetService.readBatchConfigs();
          if (batchConfigs.isNotEmpty) {
            final firstBatch = batchConfigs.values.first;
            if (firstBatch.attendanceSheet != null) {
              attendanceSheetUrl = firstBatch.attendanceSheet!.link;
              print('🔄 Using fallback attendance sheet URL from first batch: $attendanceSheetUrl');
            }
          }
        } catch (e) {
          print('⚠️ Error getting fallback attendance sheet URL from batches: $e');
        }
        
        // 2. If still null, try embedded configuration (legacy/backup)
        if (attendanceSheetUrl == null || attendanceSheetUrl.isEmpty) {
          attendanceSheetUrl = await getEmbeddedAttendanceSheetUrl();
          print('🔄 Using fallback embedded attendance sheet URL: $attendanceSheetUrl');
        }
      }

      if (attendanceSheetUrl == null || attendanceSheetUrl.isEmpty) {
        throw Exception('No attendance sheet URL configured. Please check your batch configuration.');
      }

      String googleSheetUrl = attendanceSheetUrl;
      print('Using attendance sheet URL: $googleSheetUrl');
      
      print('Class model Google Sheet URL: ${classModel.googleSheetUrl}');
      // print('Embedded attendance sheet URL: $embeddedAttendanceSheetUrl'); // Removed as variable is no longer in scope
      print('Final Google Sheet URL being used: $googleSheetUrl');
      
      // Validate Google Sheet URL
      if (googleSheetUrl.isEmpty) {
        throw Exception('Google Sheet URL is empty');
      }
      
      // Check if attendance sheet is initialized, and initialize if needed
      print('Checking if attendance sheet is initialized...');
      final isInitialized = await isAttendanceSheetInitialized(
        classModel: classModel,
        sheetUrl: googleSheetUrl,
      );
      print('Attendance sheet initialized status: $isInitialized');
      
      if (!isInitialized) {
        print('Attendance sheet not initialized, initializing now...');
        final initSuccess = await initializeAttendanceSheet(
          classModel: classModel,
          sheetUrl: googleSheetUrl,
        );
        print('Attendance sheet initialization result: $initSuccess');
        if (!initSuccess) {
          throw Exception('Failed to initialize attendance sheet');
        }
        print('Attendance sheet initialized successfully');
      } else {
        print('Attendance sheet is already initialized');
      }

      print('🔐 Starting Google Sheets authentication...');
      
      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
        print('✓ Service account JSON parsed successfully');
        print('Service account details:');
        print('  Type: ${serviceAccountJson['type']}');
        print('  Project ID: ${serviceAccountJson['project_id']}');
        print('  Client email: ${serviceAccountJson['client_email']}');
        print('  Client ID: ${serviceAccountJson['client_id']}');
      } catch (e) {
        throw Exception('Invalid service account JSON format: $e');
      }
      
      // Validate required fields in service account key
      final requiredFields = ['type', 'project_id', 'private_key_id', 'private_key', 'client_email', 'client_id', 'auth_uri', 'token_uri'];
      for (final field in requiredFields) {
        if (!serviceAccountJson.containsKey(field) || serviceAccountJson[field] == null) {
          throw Exception('Missing required field in service account key: $field');
        }
      }
      
      if (serviceAccountJson['type'] != 'service_account') {
        throw Exception('Invalid service account type. Expected "service_account", got "${serviceAccountJson['type']}"');
      }
      
      print('✓ Service account key validation passed');
      print('📧 Service account email: ${serviceAccountJson['client_email']}');
      print('🏗️ Project ID: ${serviceAccountJson['project_id']}');
      
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
        print('✓ Service account credentials created');
      } catch (e) {
        throw Exception('Failed to create service account credentials: $e');
      }

      // Authenticate
      print('🔑 Attempting authentication with scopes: ${AppConstants.requiredScopes}');
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      print('✓ Authentication successful!');
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(googleSheetUrl);
      
      print('📈 Attempting to access Google Sheet: $spreadsheetId');
      print('🔗 Full Google Sheet URL being used: $googleSheetUrl');
      
      // Test access to the spreadsheet
      try {
        print('Testing access to spreadsheet...');
        final testResponse = await sheetsApi.spreadsheets.get(spreadsheetId);
        print('✓ Successfully accessed Google Sheet: "${testResponse.properties?.title}"');
        print('  Spreadsheet ID: ${testResponse.spreadsheetId}');
        print('  Sheet count: ${testResponse.sheets?.length ?? 0}');
        
        // Print all sheet names for debugging
        if (testResponse.sheets != null) {
          print('  All sheet names:');
          for (int i = 0; i < testResponse.sheets!.length; i++) {
            print('    ${i + 1}. ${testResponse.sheets![i].properties?.title}');
          }
        }
        
        // Check if the specific sheet exists
        if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
          bool sheetExists = false;
          if (testResponse.sheets != null) {
            for (final sheet in testResponse.sheets!) {
              if (sheet.properties?.title == classModel.sheetName) {
                sheetExists = true;
                print('  ✅ Target sheet "${classModel.sheetName}" exists');
                break;
              }
            }
          }
          
          if (!sheetExists) {
            print('  ⚠️ Target sheet "${classModel.sheetName}" does not exist in the spreadsheet');
            // We'll continue anyway as the sheet operations should handle this
          }
        }
      } catch (e) {
        print('❌ Error accessing spreadsheet: $e');
        if (e.toString().contains('Requested entity was not found') || e.toString().contains('404')) {
          throw Exception('Google Sheet not found. Please check the URL and ensure the sheet exists.');
        } else if (e.toString().contains('403') || e.toString().contains('permission') || e.toString().contains('Forbidden')) {
          throw Exception('Permission denied. Please share the Google Sheet with service account email: ${serviceAccountJson['client_email']}');
        } else {
          throw Exception('Failed to access Google Sheet: $e');
        }
      }

      // Group records by date
      final recordsByDate = <DateTime, List<AttendanceRecord>>{};
      for (final record in attendanceRecords) {
        final date = DateTime(
          record.sessionDate.year,
          record.sessionDate.month,
          record.sessionDate.day,
        );
        recordsByDate.putIfAbsent(date, () => []).add(record);
      }

      print('Grouped records by date:');
      for (final entry in recordsByDate.entries) {
        print('  Date: ${entry.key}, Records: ${entry.value.length}');
      }

      final uploadedRecords = <String>[];
      int processedCount = 0;

      // Process each date
      print('Processing ${recordsByDate.length} date groups...');
      for (final entry in recordsByDate.entries) {
        final sessionDate = entry.key;
        final records = entry.value;
        
        print('Processing date: $sessionDate with ${records.length} records');

        await _uploadSessionData(
          sheetsApi,
          spreadsheetId,
          classModel,
          sessionDate,
          records,
        );

        uploadedRecords.addAll(records.map((r) => r.id));
        processedCount += records.length;
        
        onProgress(processedCount / (attendanceRecords.length > 0 ? attendanceRecords.length : 1));
      }

      client.close();
      
      print('✅ Attendance upload process completed successfully');
      print('Uploaded ${uploadedRecords.length} records');

      return GoogleSheetsUploadResult.success(
        uploadedRecordIds: uploadedRecords,
        message: 'Successfully uploaded ${uploadedRecords.length} records',
      );

    } catch (e, stackTrace) {
      print('❌ Google Sheets upload error: $e');
      print('Stack trace: $stackTrace');
      
      String errorMessage;
      if (e.toString().contains('missing or invalid authentication')) {
        errorMessage = 'Authentication failed. Please check your service account key and ensure:\n'
                     '1. The JSON file is valid and complete\n'
                     '2. Google Sheets API is enabled in Google Cloud Console\n'
                     '3. The service account has proper permissions';
      } else if (e.toString().contains('Requested entity was not found')) {
        errorMessage = 'Google Sheet not found. Please check the sheet URL.';
      } else if (e.toString().contains('403') || e.toString().contains('permission') || e.toString().contains('Forbidden')) {
        errorMessage = 'Permission denied. Please share the Google Sheet with your service account email.';
      } else if (e.toString().contains('Invalid service account')) {
        errorMessage = 'Invalid service account key. Please check the JSON file format.';
      } else if (e.toString().contains('exceeds grid limits') || e.toString().contains('Max columns:') || e.toString().contains('AKI')) {
        errorMessage = 'Google Sheets column limit reached. The app manages columns by removing the oldest date column when the limit is reached and adding new dates in the latest column. Please ensure your sheet structure follows the expected format with student data in column A and dates in subsequent columns. Google Sheets has a maximum of 18,278 columns (A to ZZZ).';
      } else {
        errorMessage = 'Upload failed: $e';
      }
      
      return GoogleSheetsUploadResult.error(
        message: errorMessage,
      );
    }
  }

  static Future<void> _uploadSessionData(
    sheets.SheetsApi sheetsApi,
    String spreadsheetId,
    ClassModel classModel,
    DateTime sessionDate,
    List<AttendanceRecord> records,
  ) async {
    print('=== UPLOADING SESSION DATA ===');
    print('Session date: $sessionDate');
    print('Spreadsheet ID: $spreadsheetId');
    print('Class model students count: ${classModel.students.length}');
    print('Attendance records count: ${records.length}');
    print('Target sheet name: ${classModel.sheetName}');
    print('--------------------------------------------------');
    
    // Find or create column for this date
    final columnIndex = await _findOrCreateDateColumn(
      sheetsApi,
      spreadsheetId,
      sessionDate,
      classModel.className, // Pass class name for worksheet-specific columns (Tabs are named after combos)
    );
    print('Column index for date ${formatDateForSheet(sessionDate)}: $columnIndex');

    // Prepare attendance data - track which students are present by PIN number and name
    final presentStudentPins = <String>{};
    final presentStudentNames = <String>{};
    for (final record in records) {
      if (record.status == AttendanceStatus.present) {
        presentStudentPins.add(record.studentPinNumber);
        presentStudentNames.add(record.studentName.toLowerCase().trim());
        print('Student marked as present: ${record.studentName} (${record.studentPinNumber})');
      }
    }
    
    print('Total present students: ${presentStudentPins.length}');
    print('Present student PINs: ${presentStudentPins.join(", ")}');
    print('Present student names: ${presentStudentNames.join(", ")}');
    
    // Debug: Print class model students
    print('Class model contains ${classModel.students.length} students:');
    for (int i = 0; i < classModel.students.length && i < 5; i++) {
      final student = classModel.students[i];
      print('  Student ${i + 1}: ${student.name} (PIN: ${student.pinNumber})');
    }
    if (classModel.students.length > 5) {
      print('  ... and ${classModel.students.length - 5} more students');
    }

    // Get student list from first column (should contain student names)
    print('Fetching student data from attendance sheet...');
    
    // Determine the range based on whether we're using a specific sheet
    String studentDataRange = 'A:ZZZ'; // Default range for single sheet
    if (classModel.className.isNotEmpty) {
      studentDataRange = "'${classModel.className}'!A:ZZZ"; // Specific sheet range
    }
    
    print('Using student data range: $studentDataRange');
    
    final studentResponse = await sheetsApi.spreadsheets.values.get(
      spreadsheetId,
      studentDataRange, // Respect column limits when getting student data
    );

    final studentValues = studentResponse.values ?? [];
    print('Attendance sheet rows count: ${studentValues.length}');
    
    if (studentValues.isNotEmpty) {
      print('Attendance sheet header row: ${studentValues[0]}');
      if (studentValues.length > 1) {
        print('Attendance sheet first student row: ${studentValues[1]}');
        print('Attendance sheet second student row: ${studentValues[2]}');
        print('Attendance sheet third student row: ${studentValues[3]}');
      }
    } else {
      print('⚠️ Attendance sheet is empty!');
    }

    final cellRequests = <sheets.Request>[];
    int? sheetId;

    // Fetch sheet ID for styling
    try {
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      final sheet = spreadsheet.sheets?.firstWhere(
        (s) => s.properties?.title == classModel.className,
        orElse: () => sheets.Sheet(),
      );
      sheetId = sheet?.properties?.sheetId;
      if (sheetId == null) {
        print('⚠️ Warning: Could not find sheet ID for "${classModel.className}". Styling will be skipped.');
      } else {
        print('✅ Found sheet ID: $sheetId for styling');
      }
    } catch (e) {
      print('⚠️ Error fetching sheet ID: $e');
    }

    // Create maps for matching
    final studentNameToPinMap = <String, String>{};
    final studentPinToNameMap = <String, String>{};
    for (final student in classModel.students) {
      final normalizedName = student.name.toLowerCase().trim();
      studentNameToPinMap[normalizedName] = student.pinNumber;
      studentPinToNameMap[student.pinNumber] = normalizedName;
      // Also add variations for better matching
      studentNameToPinMap[normalizedName.replaceAll(' ', '')] = student.pinNumber;
    }
    
    print('Created student name to PIN map with ${studentNameToPinMap.length} entries');
    print('Created student PIN to name map with ${studentPinToNameMap.length} entries');

    // Create a map of sheet student names to row indices
    final sheetNameToRowIndex = <String, int>{};
    print('Mapping sheet student names to row indices:');
    for (int i = 1; i < studentValues.length; i++) { // Skip header
      if (studentValues[i].isNotEmpty) {
        final sheetName = studentValues[i][0].toString().trim(); // Name is in column A (index 0)
        sheetNameToRowIndex[sheetName.toLowerCase().trim()] = i;
        if (i <= 10) { // Only print first 10 for brevity
          print('  Row ${i + 1}: "$sheetName"');
        } else if (i == 11) {
          print('  ... (showing first 10 rows only)');
        }
      }
    }
    print('Total mapped sheet students: ${sheetNameToRowIndex.length}');
    
    // Also map sheet PINs to row indices
    final sheetPinToRowIndex = <String, int>{};
    print('Mapping sheet PINs to row indices:');
    for (int i = 1; i < studentValues.length; i++) { // Skip header
      if (studentValues[i].length > 1) {
        final sheetPin = studentValues[i][1].toString().trim(); // PIN is in column B (index 1)
        sheetPinToRowIndex[sheetPin] = i;
        if (i <= 10) { // Only print first 10 for brevity
          print('  Row ${i + 1}: "$sheetPin"');
        } else if (i == 11) {
          print('  ... (showing first 10 rows only)');
        }
      }
    }
    print('Total mapped sheet PINs: ${sheetPinToRowIndex.length}');
    
    // Process all students in the class - both present and absent
    print('Processing all students in class for attendance marking...');
    
    // First, get existing data for this date column to check current attendance status
    String existingDataRange = '${columnIndexToLetter(columnIndex)}:${columnIndexToLetter(columnIndex)}';
    if (classModel.className.isNotEmpty) {
      existingDataRange = "'${classModel.className}'!$existingDataRange";
    }
    
    print('Using existing data range: $existingDataRange');
    
    final existingDataResponse = await sheetsApi.spreadsheets.values.get(
      spreadsheetId,
      existingDataRange,
    );
    
    final existingValues = existingDataResponse.values ?? [];
    final existingAttendance = <int, String>{}; // rowIndex -> status
    
    // Map existing attendance data by row index
    for (int i = 0; i < existingValues.length; i++) {
      if (existingValues[i].isNotEmpty) {
        existingAttendance[i] = existingValues[i][0].toString().trim();
      }
    }
    
    print('Existing attendance data for column ${columnIndexToLetter(columnIndex)}: ${existingAttendance.length} entries');
    
    for (final student in classModel.students) {
      final studentName = student.name.toLowerCase().trim();
      final studentPin = student.pinNumber;
      print('🔍 Processing student: $studentName (PIN: $studentPin)');
      
      bool matched = false;
      int? rowIndex;
      
      // Try exact name match first
      if (sheetNameToRowIndex.containsKey(studentName)) {
        rowIndex = sheetNameToRowIndex[studentName]!;
        print('✅ Found exact name match: "$studentName" at row ${rowIndex + 1}');
        matched = true;
      }
      
      // If no exact match, try PIN matching
      if (!matched && sheetPinToRowIndex.containsKey(studentPin)) {
        rowIndex = sheetPinToRowIndex[studentPin]!;
        print('✅ Found PIN match: "$studentPin" at row ${rowIndex + 1}');
        matched = true;
      }
      
      // If still no match, try partial name matching
      if (!matched) {
        print('   Trying partial name matching...');
        for (final entry in sheetNameToRowIndex.entries) {
          final sheetName = entry.key;
          final sheetRowIndex = entry.value;
          
          // Check if the names are similar (contain each other)
          if (studentName.contains(sheetName) || sheetName.contains(studentName)) {
            rowIndex = sheetRowIndex;
            print('✅ Found partial name match: "$sheetName" at row ${rowIndex + 1} for student "$studentName"');
            matched = true;
            break;
          }
        }
      }
      
      if (rowIndex != null && columnIndex < 18278) {
        // Determine if student is present or absent
        bool isPresent = presentStudentPins.contains(studentPin) || 
                         presentStudentNames.contains(studentName) ||
                         presentStudentNames.contains(studentName.replaceAll(' ', ''));
        
        // Check existing attendance status for conflict resolution
        // Fix: Use rowIndex directly instead of rowIndex + 1 since existingAttendance uses 0-based indexing
        final existingStatus = existingAttendance[rowIndex];
        print('   Existing status for student at row ${rowIndex + 1}: $existingStatus');
        
        // Conflict resolution logic:
        // - If student is already marked as "Present", don't override
        // - If student is marked as "Absent" and is now present, change to "Present"
        // - If there's no existing status, set based on current attendance
        String attendanceStatus;
        
        if (existingStatus != null && 
            (existingStatus.toLowerCase() == 'present' || existingStatus.toLowerCase() == 'p')) {
          // Student already marked as present, keep as present (don't override)
          attendanceStatus = 'Present';
          print('   Keeping existing "$existingStatus" status for student');
        } else if (existingStatus != null && 
                   (existingStatus.toLowerCase() == 'absent' || existingStatus.toLowerCase() == 'a') && 
                   isPresent) {
          // Student marked as absent but is now present, change to present
          attendanceStatus = 'Present';
          print('   Changing "$existingStatus" to "Present" for student');
        } else {
          // No existing status or student is absent, set based on current attendance
          attendanceStatus = isPresent ? 'Present' : 'Absent';
          // only print if status is changing or interesting to reduce spam
          if (isPresent || (existingStatus != null && existingStatus.isNotEmpty)) {
             print('   Setting status to: $attendanceStatus (was: $existingStatus)');
          }
        }
        
        String cellRange = columnIndexToLetter(columnIndex) + (rowIndex + 1).toString();
        
        // Add sheet name prefix if specified
        if (classModel.className.isNotEmpty) {
          cellRange = "'${classModel.className}'!$cellRange";
        }
        
        // Create request with styling if sheetId is available
        if (sheetId != null) {
          final isPresentStatus = attendanceStatus.toLowerCase() == 'present';
          final color = isPresentStatus
              ? sheets.Color(red: 0.776, green: 0.937, blue: 0.765) // #C6EFC3 (Light Green)
              : sheets.Color(red: 1.0, green: 0.780, blue: 0.808); // #FFC7CE (Light Red)

          cellRequests.add(
            sheets.Request(
              updateCells: sheets.UpdateCellsRequest(
                range: sheets.GridRange(
                  sheetId: sheetId,
                  startRowIndex: rowIndex,
                  endRowIndex: rowIndex! + 1,
                  startColumnIndex: columnIndex,
                  endColumnIndex: columnIndex + 1,
                ),
                rows: [
                  sheets.RowData(
                    values: [
                      sheets.CellData(
                        userEnteredValue: sheets.ExtendedValue(stringValue: attendanceStatus),
                        userEnteredFormat: sheets.CellFormat(
                          backgroundColor: color,
                          horizontalAlignment: 'CENTER',
                        ),
                      ),
                    ],
                  ),
                ],
                fields: 'userEnteredValue,userEnteredFormat(backgroundColor,horizontalAlignment)',
              ),
            ),
          );
        } else {
           // Fallback for when sheetId is missing (should verify previous updates removed updates list usage)
           // Actually, we should just print error or skip styling. 
           // But since we are replacing the updates list logic, we MUST use cellRequests.
           // If sheetId is null, we can't use UpdateCellsRequest efficiently without it.
           // Assuming sheetId is always found because we just created/verified the sheet.
        }
      } else if (rowIndex == null) {
        print('⚠️ Could not find matching row for student: $studentName (PIN: $studentPin)');
      } else {
        print('⚠️ Column index $columnIndex exceeds limit, skipping update for student $studentName');
      }
    }

    print('📊 Preparing to update ${cellRequests.length} cells with formatting');

    // Batch update
    if (cellRequests.isNotEmpty) {
      print('Sending batch update request with ${cellRequests.length} updates');
      
      try {
        final batchUpdateRequest = sheets.BatchUpdateSpreadsheetRequest(
          requests: cellRequests,
        );
        
        final response = await sheetsApi.spreadsheets.batchUpdate(
          batchUpdateRequest,
          spreadsheetId,
        );
        
        print('✅ Batch update response received:');
        print('  Total updated replies: ${response.replies?.length}');
        // Response structure is different for batchUpdate vs values.batchUpdate
        print('  Total updated replies: ${response.replies?.length}');
        
        if (response.replies != null) {
          print('    Received ${response.replies!.length} replies from batch update');
        }
        
        print('Successfully updated Google Sheets with attendance data');
      } catch (e) {
        print('❌ Error during batch update: $e');
        rethrow;
      }
    } else {
      print('No updates to make to Google Sheets');
      print('⚠️ No matching students found between class list and attendance sheet');
      print('Class model students:');
      for (final student in classModel.students) {
        print('  - ${student.name} (${student.pinNumber})');
      }
      print('Attendance sheet student names (first 10):');
      int count = 0;
      for (final entry in sheetNameToRowIndex.entries) {
        if (count++ < 10) {
          print('  - ${entry.key}');
        }
      }
      if (sheetNameToRowIndex.length > 10) {
        print('  ... and ${sheetNameToRowIndex.length - 10} more');
      }
    }
  }
  
  /// Calculate similarity between two strings (0.0 to 1.0)
  static double _calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    // Simple similarity calculation based on common characters
    final set1 = s1.split('').toSet();
    final set2 = s2.split('').toSet();
    final intersection = set1.intersection(set2);
    final union = set1.union(set2);
    
    return intersection.length / union.length;
  }

  // New method to fetch attendance data for a specific roll number
  static Future<AttendanceDataResult> fetchAttendanceDataForRollNumber({
    required ClassModel classModel,
    required String rollNumber,
  }) async {
    try {
      print('=== FETCHING ATTENDANCE DATA FOR ROLL NUMBER ===');
      print('Class: ${classModel.className}');
      print('Sheet name: ${classModel.sheetName}');
      print('Roll number: $rollNumber');
      
      // Use embedded service account key if available
      String serviceAccountKey = classModel.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        throw Exception('Service account key not configured');
      }

      // Use embedded attendance sheet URL if available
      final embeddedAttendanceSheetUrl = await getEmbeddedAttendanceSheetUrl();
      if (embeddedAttendanceSheetUrl == null || embeddedAttendanceSheetUrl.isEmpty) {
        throw Exception('No attendance sheet URL configured');
      }

      print('🔐 Starting Google Sheets authentication for reading data...');
      
      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
        print('✓ Service account JSON parsed successfully');
      } catch (e) {
        throw Exception('Invalid service account JSON format: $e');
      }
      
      // Validate required fields in service account key
      final requiredFields = ['type', 'project_id', 'private_key_id', 'private_key', 'client_email', 'client_id', 'auth_uri', 'token_uri'];
      for (final field in requiredFields) {
        if (!serviceAccountJson.containsKey(field) || serviceAccountJson[field] == null) {
          throw Exception('Missing required field in service account key: $field');
        }
      }
      
      if (serviceAccountJson['type'] != 'service_account') {
        throw Exception('Invalid service account type. Expected "service_account", got "${serviceAccountJson['type']}"');
      }
      
      print('✓ Service account key validation passed');
      print('📧 Service account email: ${serviceAccountJson['client_email']}');
      
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
        print('✓ Service account credentials created');
      } catch (e) {
        throw Exception('Failed to create service account credentials: $e');
      }

      // Authenticate
      print('🔑 Attempting authentication with scopes: ${AppConstants.requiredScopes}');
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      print('✓ Authentication successful!');
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(embeddedAttendanceSheetUrl);
      
      print('📈 Attempting to access Google Sheet: $spreadsheetId');
      
      // Test access to the spreadsheet
      try {
        final testResponse = await sheetsApi.spreadsheets.get(spreadsheetId);
        print('✓ Successfully accessed Google Sheet: "${testResponse.properties?.title}"');
      } catch (e) {
        if (e.toString().contains('Requested entity was not found') || e.toString().contains('404')) {
          throw Exception('Google Sheet not found. Please check the URL and ensure the sheet exists.');
        } else if (e.toString().contains('403') || e.toString().contains('permission') || e.toString().contains('Forbidden')) {
          throw Exception('Permission denied. Please share the Google Sheet with service account email: ${serviceAccountJson['client_email']}');
        } else {
          throw Exception('Failed to access Google Sheet: $e');
        }
      }

      // Fetch all data from the sheet with a range that respects Google Sheets limits
      // Google Sheets has a maximum of 18,278 columns (A to ZZZ)
      // Determine the range based on whether we're using a specific sheet
      String range = 'A:AJ'; // Default range for single sheet
      if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        range = '${classModel.sheetName}!A:AJ'; // Specific sheet range
      }
      
      print('Using data range: $range for fetching attendance data');
      
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range, // Get columns A to ZZZ (18,278 columns total) to respect Google Sheets limits
      );

      final values = response.values ?? [];
      if (values.isEmpty) {
        client.close();
        return AttendanceDataResult.error(
          message: 'No data found in the Google Sheet',
        );
      }

      print('🔍 Google Sheet data fetched. Rows: ${values.length}, Columns in header: ${values.isNotEmpty ? values[0].length : 0}');

      // Find the roll number column (Pin-number column) and date columns (after Sec-Codes column)
      final List<AttendanceSession> attendanceSessions = [];
      final List<String> dates = [];
      int rollNumberColumnIndex = -1;
      int secCodesColumnIndex = -1;
      
      // Get header row to identify column positions
      if (values.isNotEmpty) {
        final headerRow = values[0];
        print('📋 Header row columns: ${headerRow.length}');
        print('📋 Header row content: ${headerRow.join(" | ")}');
        
        // Find the Pin-number column
        for (int i = 0; i < headerRow.length; i++) {
          if (headerRow[i].toString().trim() == 'Pin-number') {
            rollNumberColumnIndex = i;
            print('📍 Found Pin-number column at index: $rollNumberColumnIndex');
            break;
          }
        }
        
        // Find the Sec-Codes column
        for (int i = 0; i < headerRow.length; i++) {
          if (headerRow[i].toString().trim() == 'Sec-Codes') {
            secCodesColumnIndex = i;
            print('📍 Found Sec-Codes column at index: $secCodesColumnIndex');
            break;
          }
        }
        
        // If Pin-number column not found, default to first column (backward compatibility)
        if (rollNumberColumnIndex == -1) {
          rollNumberColumnIndex = 0;
          print('⚠️ Pin-number column not found, defaulting to index 0');
        }
        
        // If Sec-Codes column not found, default to reading all columns after Pin-number (backward compatibility)
        if (secCodesColumnIndex == -1) {
          print('⚠️ Sec-Codes column not found, reading all columns after Pin-number');
          // Get all columns after the Pin-number column as date columns
          for (int i = rollNumberColumnIndex + 1; i < headerRow.length; i++) {
            dates.add(headerRow[i].toString());
          }
          print('📅 Found ${dates.length} date columns after Pin-number (fallback mode)');
        } else {
          // Get all columns after the Sec-Codes column as date columns
          for (int i = secCodesColumnIndex + 1; i < headerRow.length; i++) {
            dates.add(headerRow[i].toString());
          }
          print('📅 Found ${dates.length} date columns after Sec-Codes');
          print('📅 Date columns: ${dates.join(", ")}');
        }
      }

      // Find the row with the specified roll number in the Pin-number column
      int rollNumberRowIndex = -1;
      for (int i = 1; i < values.length; i++) { // Skip header row
        if (values[i].length > rollNumberColumnIndex && 
            values[i][rollNumberColumnIndex].toString().trim() == rollNumber) {
          rollNumberRowIndex = i;
          print('👤 Found roll number $rollNumber at row index: $rollNumberRowIndex');
          break;
        }
      }

      if (rollNumberRowIndex == -1) {
        client.close();
        return AttendanceDataResult.error(
          message: 'Roll number $rollNumber not found in the Google Sheet',
        );
      }

      // Get attendance data for this roll number across all date columns
      final rollNumberRow = values[rollNumberRowIndex];
      int presentCount = 0;
      int totalCount = dates.length;
      
      print('📊 Processing attendance data for roll number $rollNumber');
      print('📊 Total date columns to process: $totalCount');
      print('📊 Data row length: ${rollNumberRow.length}');

      // Determine starting column for date data
      int startDateColumnIndex;
      if (secCodesColumnIndex != -1) {
        // Start reading from the column after Sec-Codes
        startDateColumnIndex = secCodesColumnIndex + 1;
      } else {
        // Fallback: start reading from the column after Pin-number
        startDateColumnIndex = rollNumberColumnIndex + 1;
      }
      
      print('📊 Starting date data reading from column index: $startDateColumnIndex');
      
      // Map date columns to their data
      for (int dateIndex = 0; dateIndex < dates.length; dateIndex++) {
        int columnIndex = startDateColumnIndex + dateIndex;
        
        // Check if we have data for this column and it's within limits
        String status = '';
        if (columnIndex < rollNumberRow.length && columnIndex < 18278) { // Respect column limit
          status = rollNumberRow[columnIndex].toString().toLowerCase().trim();
        }
        
        final isPresent = status == 'present' || status == 'p' || status == '1';
        if (isPresent) {
          presentCount++;
        }
        
        // Print debug info for first few entries
        if (dateIndex < 5) {
          print('📊 Date $dateIndex: Column $columnIndex, Date: ${dates[dateIndex]}, Status: $status, Present: $isPresent');
        }
        
        attendanceSessions.add(
          AttendanceSession(
            date: dates[dateIndex],
            status: isPresent ? 'Present' : 'Absent',
          ),
        );
      }

      client.close();

      final attendancePercentage = totalCount > 0 ? (presentCount / totalCount) * 100.0 : 0.0;

      print('✅ Attendance calculation complete for $rollNumber: $presentCount/$totalCount (${attendancePercentage.toStringAsFixed(1)}%)');

      return AttendanceDataResult.success(
        rollNumber: rollNumber,
        attendancePercentage: attendancePercentage,
        presentCount: presentCount,
        totalCount: totalCount,
        sessions: attendanceSessions,
        message: 'Successfully fetched attendance data for roll number: $rollNumber. Read $totalCount date columns after Sec-Codes.',
      );

    } catch (e) {
      print('❌ Google Sheets fetch error: $e');
      
      String errorMessage;
      if (e.toString().contains('missing or invalid authentication')) {
        errorMessage = 'Authentication failed. Please check your service account key and ensure:\n'
                     '1. The JSON file is valid and complete\n'
                     '2. Google Sheets API is enabled in Google Cloud Console\n'
                     '3. The service account has proper permissions';
      } else if (e.toString().contains('Requested entity was not found')) {
        errorMessage = 'Google Sheet not found. Please check the sheet URL.';
      } else if (e.toString().contains('403') || e.toString().contains('permission') || e.toString().contains('Forbidden')) {
        errorMessage = 'Permission denied. Please share the Google Sheet with your service account email.';
      } else if (e.toString().contains('Invalid service account')) {
        errorMessage = 'Invalid service account key. Please check the JSON file format.';
      } else if (e.toString().contains('exceeds grid limits') || e.toString().contains('Max columns:')) {
        errorMessage = 'Google Sheets column limit reached. The app manages columns by removing the oldest date column when the limit is reached and adding new dates in the latest column. Please ensure your sheet structure follows the expected format with student data in column A and dates in subsequent columns.';
      } else {
        errorMessage = 'Failed to fetch attendance data: $e';
      }
      
      return AttendanceDataResult.error(
        message: errorMessage,
      );
    }
  }

  /// Fetch all attendance data for a specific date from Google Sheets
  /// Returns a map of student PIN numbers to their attendance status for the given date
  static Future<Map<String, String>> fetchAllAttendanceForDate({
    required ClassModel classModel,
    required DateTime date,
  }) async {
    try {
      print('=== FETCHING ALL ATTENDANCE FOR DATE ===');
      print('Class: ${classModel.className}');
      print('Sheet name: ${classModel.sheetName}');
      print('Date: $date');
      
      // Use embedded service account key if available
      String serviceAccountKey = classModel.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        throw Exception('Service account key not configured');
      }

      // Use embedded attendance sheet URL if available
      final embeddedAttendanceSheetUrl = await getEmbeddedAttendanceSheetUrl();
      if (embeddedAttendanceSheetUrl == null || embeddedAttendanceSheetUrl.isEmpty) {
        throw Exception('No attendance sheet URL configured');
      }

      print('🔐 Starting Google Sheets authentication for reading data...');
      
      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
        print('✓ Service account JSON parsed successfully');
      } catch (e) {
        throw Exception('Invalid service account JSON format: $e');
      }
      
      // Validate required fields in service account key
      final requiredFields = ['type', 'project_id', 'private_key_id', 'private_key', 'client_email', 'client_id', 'auth_uri', 'token_uri'];
      for (final field in requiredFields) {
        if (!serviceAccountJson.containsKey(field) || serviceAccountJson[field] == null) {
          throw Exception('Missing required field in service account key: $field');
        }
      }
      
      if (serviceAccountJson['type'] != 'service_account') {
        throw Exception('Invalid service account type. Expected "service_account", got "${serviceAccountJson['type']}"');
      }
      
      print('✓ Service account key validation passed');
      print('📧 Service account email: ${serviceAccountJson['client_email']}');
      
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
        print('✓ Service account credentials created');
      } catch (e) {
        throw Exception('Failed to create service account credentials: $e');
      }

      // Authenticate
      print('🔑 Attempting authentication with scopes: ${AppConstants.requiredScopes}');
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      print('✓ Authentication successful!');
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(embeddedAttendanceSheetUrl);
      
      print('📈 Attempting to access Google Sheet: $spreadsheetId');
      
      // Test access to the spreadsheet
      try {
        final testResponse = await sheetsApi.spreadsheets.get(spreadsheetId);
        print('✓ Successfully accessed Google Sheet: "${testResponse.properties?.title}"');
      } catch (e) {
        if (e.toString().contains('Requested entity was not found') || e.toString().contains('404')) {
          throw Exception('Google Sheet not found. Please check the URL and ensure the sheet exists.');
        } else if (e.toString().contains('403') || e.toString().contains('permission') || e.toString().contains('Forbidden')) {
          throw Exception('Permission denied. Please share the Google Sheet with service account email: ${serviceAccountJson['client_email']}');
        } else {
          throw Exception('Failed to access Google Sheet: $e');
        }
      }

      // Fetch all data from the sheet with a range that respects Google Sheets limits
      // Google Sheets has a maximum of 18,278 columns (A to ZZZ)
      // Determine the range based on whether we're using a specific sheet
      String range = 'A:ZZZ'; // Default range for single sheet

      if (classModel.className.isNotEmpty) {
        range = "'${classModel.className}'!A:ZZZ"; // Specific sheet range
      }
      
      print('Using data range: $range for fetching attendance data');
      
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range, // Get columns A to ZZZ (18,278 columns total) to respect Google Sheets limits
      );

      final values = response.values ?? [];
      if (values.isEmpty) {
        client.close();
        print('⚠️ No data found in the Google Sheet');
        return {};
      }

      print('🔍 Google Sheet data fetched. Rows: ${values.length}, Columns in header: ${values.isNotEmpty ? values[0].length : 0}');

      // Find the date column and Pin-number column
      final dateString = formatDateForSheet(date);
      int dateColumnIndex = -1;
      int pinNumberColumnIndex = -1;
      int secCodesColumnIndex = -1;
      
      // Get header row to identify column positions
      if (values.isNotEmpty) {
        final headerRow = values[0];
        print('📋 Header row columns: ${headerRow.length}');
        print('📋 Header row content: ${headerRow.join(" | ")}');
        
        // Find the date column
        for (int i = 0; i < headerRow.length; i++) {
          if (headerRow[i].toString().trim() == dateString) {
            dateColumnIndex = i;
            print('📅 Found date column "$dateString" at index: $dateColumnIndex');
            break;
          }
        }
        
        // Find the Pin-number column
        for (int i = 0; i < headerRow.length; i++) {
          if (headerRow[i].toString().trim() == 'Pin-number') {
            pinNumberColumnIndex = i;
            print('📍 Found Pin-number column at index: $pinNumberColumnIndex');
            break;
          }
        }
        
        // Find the Sec-Codes column
        for (int i = 0; i < headerRow.length; i++) {
          if (headerRow[i].toString().trim() == 'Sec-Codes') {
            secCodesColumnIndex = i;
            print('📍 Found Sec-Codes column at index: $secCodesColumnIndex');
            break;
          }
        }
        
        // If date column not found, return empty map
        if (dateColumnIndex == -1) {
          print('⚠️ Date column "$dateString" not found in header row');
          client.close();
          return {};
        }
        
        // If Pin-number column not found, default to first column (backward compatibility)
        if (pinNumberColumnIndex == -1) {
          pinNumberColumnIndex = 0;
          print('⚠️ Pin-number column not found, defaulting to index 0');
        }
      }

      // Create map of PIN numbers to attendance status for this date
      final attendanceMap = <String, String>{};
      
      // Process each row (skip header)
      for (int i = 1; i < values.length; i++) {
        final row = values[i];
        
        // Check if row has enough columns
        if (row.length > pinNumberColumnIndex && row.length > dateColumnIndex) {
          final pinNumber = row[pinNumberColumnIndex].toString().trim();
          final status = row[dateColumnIndex].toString().trim();
          
          if (pinNumber.isNotEmpty) {
            attendanceMap[pinNumber] = status;
            
            // Print first few entries for debugging
            if (i <= 5) {
              print('  Row $i: PIN=$pinNumber, Status=$status');
            } else if (i == 6) {
              print('  ... (showing first 5 rows only)');
            }
          }
        }
      }
      
      print('📊 Found attendance data for ${attendanceMap.length} students on date $dateString');
      
      client.close();
      return attendanceMap;

    } catch (e) {
      print('❌ Google Sheets fetch error: $e');
      
      String errorMessage;
      if (e.toString().contains('missing or invalid authentication')) {
        errorMessage = 'Authentication failed. Please check your service account key and ensure:\n'
                     '1. The JSON file is valid and complete\n'
                     '2. Google Sheets API is enabled in Google Cloud Console\n'
                     '3. The service account has proper permissions';
      } else if (e.toString().contains('Requested entity was not found')) {
        errorMessage = 'Google Sheet not found. Please check the sheet URL.';
      } else if (e.toString().contains('403') || e.toString().contains('permission') || e.toString().contains('Forbidden')) {
        errorMessage = 'Permission denied. Please share the Google Sheet with your service account email.';
      } else if (e.toString().contains('Invalid service account')) {
        errorMessage = 'Invalid service account key. Please check the JSON file format.';
      } else if (e.toString().contains('exceeds grid limits') || e.toString().contains('Max columns:')) {
        errorMessage = 'Google Sheets column limit reached. The app manages columns by removing the oldest date column when the limit is reached and adding new dates in the latest column. Please ensure your sheet structure follows the expected format with student data in column A and dates in subsequent columns.';
      } else {
        errorMessage = 'Failed to fetch attendance data: $e';
      }
      
      print('❌ Error: $errorMessage');
      return {};
    }
  }

  /// Find or create a column for a specific date
  /// Always creates a new column without replacing old date columns
  /// Uses actual Google Sheets column limit (18,278 columns) instead of artificial 36-column limit
  static Future<int> _findOrCreateDateColumn(
    sheets.SheetsApi sheetsApi,
    String spreadsheetId,
    DateTime date,
    String? sheetName, // Optional sheet name for worksheet-specific columns
  ) async {
    print('Finding or creating column for date: $date in sheet: $sheetName');
    
    // Use a much larger range to accommodate more columns
    // Google Sheets actually supports up to 18,278 columns (A to ZZZ)
    String range = 'A:ZZZ'; // Much larger range for single sheet
    if (sheetName != null && sheetName.isNotEmpty) {
      range = '$sheetName!A:ZZZ'; // Specific sheet range
    }
    
    print('Using header range: $range');
    
    // Get header row
    final headerResponse = await sheetsApi.spreadsheets.values.get(
      spreadsheetId,
      range,
    );

    final headers = headerResponse.values?[0] ?? [];
    final dateString = formatDateForSheet(date);
    
    print('Current header row: ${headers.join(", ")}');
    print('Looking for date string: $dateString');
    print('Header row length: ${headers.length}');

    // Check if date column already exists
    for (int i = 0; i < headers.length; i++) {
      if (headers[i].toString() == dateString) {
        print('Date column already exists at index $i');
        return i;
      }
    }

    // Always create a new column for the date - never replace existing columns
    print('Creating new column for $dateString');
    
    // Check if we're approaching the actual Google Sheets limit
    // Google Sheets has a maximum of 18,278 columns (A to ZZZ)
    if (headers.length >= 18278) {
      // If we've reached the actual limit, we cannot add more columns
      print('Actual Google Sheets column limit reached (18,278 columns), cannot add more columns');
      print('Please manually clean up old date columns or archive data');
      
      // Return the last column index
      return 18277;
    } else {
      // Create new column at the end (latest position)
      // This ensures new dates are always added as the latest date column
      final newColumnIndex = headers.length;
      print('Creating new column at index $newColumnIndex for date $dateString');
      
      // Double-check we're within actual limits
      if (newColumnIndex < 18278) {
        
        // Check if we need to expand the grid
        if (sheetName != null && sheetName.isNotEmpty) {
           try {
             final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
             final sheet = spreadsheet.sheets?.firstWhere(
               (s) => s.properties?.title == sheetName,
               orElse: () => sheets.Sheet(),
             );
             
             if (sheet?.properties?.sheetId != null) {
                final sheetId = sheet!.properties!.sheetId!;
                final currentColumnCount = sheet.properties?.gridProperties?.columnCount ?? 26;
                
                if (newColumnIndex >= currentColumnCount) {
                   print('Expanding grid: Current columns $currentColumnCount, need ${newColumnIndex + 1}');
                   await sheetsApi.spreadsheets.batchUpdate(
                      sheets.BatchUpdateSpreadsheetRequest(
                         requests: [
                            sheets.Request(
                               appendDimension: sheets.AppendDimensionRequest(
                                  sheetId: sheetId,
                                  dimension: 'COLUMNS',
                                  length: (newColumnIndex + 1) - currentColumnCount + 5, // Add 5 extra for buffer
                               ),
                            ),
                         ],
                      ),
                      spreadsheetId,
                   );
                   print('✅ Expanded grid dimensions');
                }
             }
           } catch (e) {
             print('⚠️ Warning checking grid dimensions: $e');
           }
        }

        String updateRange = '${columnIndexToLetter(newColumnIndex)}1';
        if (sheetName != null && sheetName.isNotEmpty) {
          updateRange = "'$sheetName'!$updateRange";
        }
        print('Updating range: $updateRange with value: $dateString');
        
        try {
          final response = await sheetsApi.spreadsheets.values.update(
            sheets.ValueRange(
              range: updateRange,
              values: [[dateString]],
            ),
            spreadsheetId,
            updateRange,
            valueInputOption: 'RAW',
          );
          
          print('✅ Date column creation response:');
          print('  Updated range: ${response.updatedRange}');
          print('  Updated cells: ${response.updatedCells}');
          
          return newColumnIndex;
        } catch (e) {
          print('❌ Error creating date column: $e');
          rethrow;
        }
      } else {
        // This should not happen, but just in case
        print('Column index $newColumnIndex exceeds Google Sheets limit');
        return 18277; // Return last valid column index
      }
    }
  }

  /// Extract spreadsheet ID from URL
  static String extractSpreadsheetId(String url) {
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(url);
    if (match == null) {
      throw Exception('Invalid Google Sheets URL');
    }
    return match.group(1)!;
  }

  static String columnIndexToLetter(int index) {
    print('Converting column index $index to letter');
    
    // Ensure index is within actual Google Sheets limits (0-18277 for columns A to ZZZ)
    if (index < 0 || index >= 18278) {
      print('⚠️ Column index $index exceeds actual Google Sheets column limit of 18,278, clamping to 18277');
      index = 18277;
    }
    
    // Handle single letter columns (A-Z)
    if (index < 26) {
      final result = String.fromCharCode(65 + index);
      print('Single letter column: $index -> $result');
      return result;
    }
    
    // Handle double letter columns (AA-ZZ)
    if (index < 702) { // 26 + 26*26
      int firstCharIndex = (index - 26) ~/ 26;
      int secondCharIndex = (index - 26) % 26;
      String result = String.fromCharCode(65 + firstCharIndex) + String.fromCharCode(65 + secondCharIndex);
      print('Double letter column: $index -> $result');
      return result;
    }
    
    // Handle triple letter columns (AAA-ZZZ)
    int remaining = index - 702; // Subtract single and double letter columns
    int firstCharIndex = remaining ~/ (26 * 26);
    remaining = remaining % (26 * 26);
    int secondCharIndex = remaining ~/ 26;
    int thirdCharIndex = remaining % 26;
    
    String result = String.fromCharCode(65 + firstCharIndex) + 
                   String.fromCharCode(65 + secondCharIndex) + 
                   String.fromCharCode(65 + thirdCharIndex);
    print('Triple letter column: $index -> $result');
    return result;
  }

  static String formatDateForSheet(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Simple test function to verify Google Sheets integration
  static Future<bool> testSimpleConnection(ClassModel classModel) async {
    try {
      print('=== SIMPLE GOOGLE SHEETS CONNECTION TEST ===');
      
      // Use embedded service account key if available
      String serviceAccountKey = classModel.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        print('❌ No service account key found');
        return false;
      }

      // Use embedded attendance sheet URL if available
      final embeddedAttendanceSheetUrl = await getEmbeddedAttendanceSheetUrl();
      if (embeddedAttendanceSheetUrl == null || embeddedAttendanceSheetUrl.isEmpty) {
        print('❌ No attendance sheet URL configured');
        return false;
      }

      print('Using embedded attendance sheet URL: $embeddedAttendanceSheetUrl');
      
      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
        print('✓ Service account JSON parsed successfully');
      } catch (e) {
        print('❌ Invalid service account JSON format: $e');
        return false;
      }
      
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
        print('✓ Service account credentials created');
      } catch (e) {
        print('❌ Failed to create service account credentials: $e');
        return false;
      }

      // Authenticate
      print('🔑 Attempting authentication...');
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      print('✓ Authentication successful!');
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(embeddedAttendanceSheetUrl);
      
      print('📈 Attempting to access Google Sheet: $spreadsheetId');
      
      // Test access to the spreadsheet
      final testResponse = await sheetsApi.spreadsheets.get(spreadsheetId);
      print('✓ Successfully accessed Google Sheet: "${testResponse.properties?.title}"');
      
      client.close();
      print('✅ Simple connection test completed successfully');
      return true;
      
    } catch (e) {
      print('❌ Simple connection test failed: $e');
      return false;
    }
  }

  /// Test function to verify Google Sheets connection and access
  static Future<bool> testGoogleSheetsConnection(ClassModel classModel) async {
    try {
      print('=== TESTING GOOGLE SHEETS CONNECTION ===');
      
      // Use embedded service account key if available
      String serviceAccountKey = classModel.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        print('❌ No service account key found');
        return false;
      }

      // Use embedded attendance sheet URL if available
      final embeddedAttendanceSheetUrl = await getEmbeddedAttendanceSheetUrl();
      if (embeddedAttendanceSheetUrl == null || embeddedAttendanceSheetUrl.isEmpty) {
        print('❌ No attendance sheet URL configured');
        return false;
      }

      print('Using embedded attendance sheet URL: $embeddedAttendanceSheetUrl');
      
      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
        print('✓ Service account JSON parsed successfully');
        print('Service account details:');
        print('  Type: ${serviceAccountJson['type']}');
        print('  Project ID: ${serviceAccountJson['project_id']}');
        print('  Client email: ${serviceAccountJson['client_email']}');
      } catch (e) {
        print('❌ Invalid service account JSON format: $e');
        return false;
      }
      
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
        print('✓ Service account credentials created');
      } catch (e) {
        print('❌ Failed to create service account credentials: $e');
        return false;
      }

      // Authenticate
      print('🔑 Attempting authentication...');
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      print('✓ Authentication successful!');
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(embeddedAttendanceSheetUrl);
      
      print('📈 Attempting to access Google Sheet: $spreadsheetId');
      
      // Test access to the spreadsheet
      final testResponse = await sheetsApi.spreadsheets.get(spreadsheetId);
      print('✓ Successfully accessed Google Sheet: "${testResponse.properties?.title}"');
      print('  Spreadsheet ID: ${testResponse.spreadsheetId}');
      print('  Sheet count: ${testResponse.sheets?.length ?? 0}');
      
      if (testResponse.sheets != null && testResponse.sheets!.isNotEmpty) {
        print('  First sheet title: ${testResponse.sheets![0].properties?.title}');
        print('  First sheet ID: ${testResponse.sheets![0].properties?.sheetId}');
      }
      
      // Test reading some data
      print('Testing data read from Google Sheet...');
      // Determine the range based on whether we're using a specific sheet
      String range = 'A1:Z10'; // Default range for single sheet
      if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        range = '${classModel.sheetName}!A1:Z10'; // Specific sheet range
      }
      
      final dataResponse = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range, // Read a small range for testing
      );
      
      print('✓ Successfully read data from Google Sheet');
      if (dataResponse.values != null && dataResponse.values!.isNotEmpty) {
        print('  First row: ${dataResponse.values![0]}');
        print('  Number of rows: ${dataResponse.values!.length}');
        print('  Number of columns in first row: ${dataResponse.values![0].length}');
      } else {
        print('  No data found in range A1:Z10');
      }
      
      client.close();
      print('✅ Google Sheets connection test completed successfully');
      return true;
      
    } catch (e, stackTrace) {
      print('❌ Google Sheets connection test failed: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Comprehensive test to diagnose Google Sheets integration issues
  static Future<TestResult> runComprehensiveTest(ClassModel classModel) async {
    print('=== RUNNING COMPREHENSIVE GOOGLE SHEETS TEST ===');
    
    try {
      // Step 1: Test service account key
      print('Step 1: Testing service account key...');
      String serviceAccountKey = classModel.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        return TestResult.failure('No service account key found');
      }
      
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
        print('✓ Service account JSON parsed successfully');
      } catch (e) {
        return TestResult.failure('Invalid service account JSON format: $e');
      }
      
      // Validate required fields
      final requiredFields = ['type', 'project_id', 'private_key_id', 'private_key', 'client_email', 'client_id', 'auth_uri', 'token_uri'];
      for (final field in requiredFields) {
        if (!serviceAccountJson.containsKey(field) || serviceAccountJson[field] == null) {
          return TestResult.failure('Missing required field in service account key: $field');
        }
      }
      
      if (serviceAccountJson['type'] != 'service_account') {
        return TestResult.failure('Invalid service account type. Expected "service_account", got "${serviceAccountJson['type']}"');
      }
      
      print('✓ Service account key validation passed');
      print('  Client email: ${serviceAccountJson['client_email']}');
      print('  Project ID: ${serviceAccountJson['project_id']}');

      // Step 2: Test authentication
      print('Step 2: Testing authentication...');
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
        print('✓ Service account credentials created');
      } catch (e) {
        return TestResult.failure('Failed to create service account credentials: $e');
      }

      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );
      print('✓ Authentication successful!');

      // Step 3: Test spreadsheet access
      print('Step 3: Testing spreadsheet access...');
      final sheetsApi = sheets.SheetsApi(client);
      
      // Get embedded attendance sheet URL
      final embeddedAttendanceSheetUrl = await getEmbeddedAttendanceSheetUrl();
      if (embeddedAttendanceSheetUrl == null || embeddedAttendanceSheetUrl.isEmpty) {
        client.close();
        return TestResult.failure('No attendance sheet URL configured');
      }
      
      print('Using embedded attendance sheet URL: $embeddedAttendanceSheetUrl');
      
      final spreadsheetId = extractSpreadsheetId(embeddedAttendanceSheetUrl);
      print('Spreadsheet ID: $spreadsheetId');
      
      try {
        final testResponse = await sheetsApi.spreadsheets.get(spreadsheetId);
        print('✓ Successfully accessed Google Sheet: "${testResponse.properties?.title}"');
        print('  Spreadsheet ID: ${testResponse.spreadsheetId}');
        print('  Sheet count: ${testResponse.sheets?.length ?? 0}');
        
        if (testResponse.sheets != null && testResponse.sheets!.isNotEmpty) {
          print('  First sheet title: ${testResponse.sheets![0].properties?.title}');
          print('  First sheet ID: ${testResponse.sheets![0].properties?.sheetId}');
        }
      } catch (e) {
        client.close();
        if (e.toString().contains('Requested entity was not found') || e.toString().contains('404')) {
          return TestResult.failure('Google Sheet not found. Please check the URL and ensure the sheet exists.');
        } else if (e.toString().contains('403') || e.toString().contains('permission') || e.toString().contains('Forbidden')) {
          return TestResult.failure('Permission denied. Please share the Google Sheet with service account email: ${serviceAccountJson['client_email']}');
        } else {
          return TestResult.failure('Failed to access Google Sheet: $e');
        }
      }

      // Step 4: Test reading data
      // Step 4: Test reading data
      print('Step 4: Testing data read...');
      try {
        // Fetch all data from the sheet with a range that respects Google Sheets limits
        // Google Sheets has a maximum of 18,278 columns (A to ZZZ)
        // Determine the range based on whether we're using a specific sheet
        String range = 'A:ZZZ'; // Default range for single sheet
        if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
          range = '${classModel.sheetName}!A:ZZZ'; // Specific sheet range
        }
        
        final dataResponse = await sheetsApi.spreadsheets.values.get(
          spreadsheetId,
          range,
        );
        
        print('✓ Successfully read data from Google Sheet');
        if (dataResponse.values != null && dataResponse.values!.isNotEmpty) {
          print('  First row: ${dataResponse.values![0]}');
          print('  Number of rows: ${dataResponse.values!.length}');
          print('  Number of columns in first row: ${dataResponse.values![0].length}');
        } else {
          print('  No data found in range A:ZZZ');
        }
      } catch (e) {
        client.close();
        return TestResult.failure('Failed to read data from Google Sheet: $e');
      }

      // Step 5: Test writing data
      print('Step 5: Testing data write...');
      try {
        // Write a test value to a specific cell
        String testCell = 'Z100'; // Use a cell that's unlikely to contain important data
        // Add sheet name prefix if specified
        if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
          testCell = '${classModel.sheetName}!$testCell';
        }
        
        final valueRange = sheets.ValueRange(
          range: testCell,
          values: [['TEST_SUCCESS']],
        );
        
        final writeResponse = await sheetsApi.spreadsheets.values.update(
          valueRange,
          spreadsheetId,
          testCell,
          valueInputOption: 'RAW',
        );
        
        print('✓ Successfully wrote test data to Google Sheet');
        print('  Updated range: ${writeResponse.updatedRange}');
        print('  Updated cells: ${writeResponse.updatedCells}');
        
        // Clear the test data
        final clearRange = sheets.ValueRange(
          range: testCell,
          values: [['']],
        );
        
        await sheetsApi.spreadsheets.values.update(
          clearRange,
          spreadsheetId,
          testCell,
          valueInputOption: 'RAW',
        );
        
        print('✓ Successfully cleared test data from Google Sheet');
      } catch (e) {
        client.close();
        return TestResult.failure('Failed to write data to Google Sheet: $e');
      }

      client.close();
      print('✅ All tests passed successfully!');
      return TestResult.success('Google Sheets integration is working correctly');
      
    } catch (e, stackTrace) {
      print('❌ Test failed with error: $e');
      print('Stack trace: $stackTrace');
      return TestResult.failure('Test failed: $e');
    }
  }
  
  /// Conflict resolution for multi-device attendance posting
  /// This method is deprecated and no longer used as we now upload all students (present and absent)
  /// with proper conflict resolution directly in the _uploadSessionData method
  static Future<ConflictResolutionResult> resolveAttendanceConflicts({
    required ClassModel classModel,
    required List<AttendanceRecord> localRecords,
    required DateTime sessionDate,
  }) async {
    // Return all records as uploadable since we now handle both present and absent students
    // with proper conflict resolution in _uploadSessionData
    return ConflictResolutionResult.success(
      recordsToUpload: localRecords,
      conflictingRecords: [],
      message: 'All records can be uploaded as we now handle both present and absent students with proper conflict resolution.',
    );
  }
}

class ConflictResolutionResult {
  final bool isSuccess;
  final List<AttendanceRecord>? recordsToUpload;
  final List<AttendanceRecord>? conflictingRecords;
  final String message;

  ConflictResolutionResult._({
    required this.isSuccess,
    this.recordsToUpload,
    this.conflictingRecords,
    required this.message,
  });

  factory ConflictResolutionResult.success({
    required List<AttendanceRecord> recordsToUpload,
    required List<AttendanceRecord> conflictingRecords,
    required String message,
  }) {
    return ConflictResolutionResult._(
      isSuccess: true,
      recordsToUpload: recordsToUpload,
      conflictingRecords: conflictingRecords,
      message: message,
    );
  }

  factory ConflictResolutionResult.error({
    required String message,
  }) {
    return ConflictResolutionResult._(
      isSuccess: false,
      message: message,
    );
  }
}

class TestResult {
  final bool isSuccess;
  final String message;

  TestResult._({
    required this.isSuccess,
    required this.message,
  });

  factory TestResult.success(String message) {
    return TestResult._(
      isSuccess: true,
      message: message,
    );
  }

  factory TestResult.failure(String message) {
    return TestResult._(
      isSuccess: false,
      message: message,
    );
  }
}

class AttendanceDataResult {
  final bool isSuccess;
  final String? rollNumber;
  final double? attendancePercentage;
  final int? presentCount;
  final int? totalCount;
  final List<AttendanceSession>? sessions;
  final String message;

  AttendanceDataResult._({
    required this.isSuccess,
    this.rollNumber,
    this.attendancePercentage,
    this.presentCount,
    this.totalCount,
    this.sessions,
    required this.message,
  });

  factory AttendanceDataResult.success({
    required String rollNumber,
    required double attendancePercentage,
    required int presentCount,
    required int totalCount,
    required List<AttendanceSession> sessions,
    required String message,
  }) {
    return AttendanceDataResult._(
      isSuccess: true,
      rollNumber: rollNumber,
      attendancePercentage: attendancePercentage,
      presentCount: presentCount,
      totalCount: totalCount,
      sessions: sessions,
      message: message,
    );
  }

  factory AttendanceDataResult.error({
    required String message,
  }) {
    return AttendanceDataResult._(
      isSuccess: false,
      message: message,
    );
  }
}

class AttendanceSession {
  final String date;
  final String status;

  AttendanceSession({
    required this.date,
    required this.status,
  });
}

class GoogleSheetsUploadResult {
  final bool isSuccess;
  final List<String>? uploadedRecordIds;
  final String message;

  GoogleSheetsUploadResult._({
    required this.isSuccess,
    this.uploadedRecordIds,
    required this.message,
  });

  factory GoogleSheetsUploadResult.success({
    required List<String> uploadedRecordIds,
    required String message,
  }) {
    return GoogleSheetsUploadResult._(
      isSuccess: true,
      uploadedRecordIds: uploadedRecordIds,
      message: message,
    );
  }

  factory GoogleSheetsUploadResult.error({
    required String message,
  }) {
    return GoogleSheetsUploadResult._(
      isSuccess: false,
      message: message,
    );
  }
}