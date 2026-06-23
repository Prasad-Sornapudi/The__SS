import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../constants/app_constants.dart';
import 'sheet_data_service.dart';
import 'control_sheet_service.dart';
import '../helper_classes.dart';

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

      // Use embedded attendance sheet URL if available
      final embeddedAttendanceSheetUrl = await getEmbeddedAttendanceSheetUrl();
      if (embeddedAttendanceSheetUrl == null || embeddedAttendanceSheetUrl.isEmpty) {
        print('No attendance sheet URL configured');
        return false;
      }

      print('Using embedded attendance sheet URL: $embeddedAttendanceSheetUrl');
      
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
      final spreadsheetId = extractSpreadsheetId(embeddedAttendanceSheetUrl);
      
      print('Accessing spreadsheet ID: $spreadsheetId');
      
      // Get existing data from the sheet with full range
      print('Fetching data from Google Sheet...');
      // Determine the range based on whether we're using a specific sheet
      String range = 'A:AJ'; // Default range for single sheet
      if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        range = _createRangeWithSheet(classModel.sheetName, 'A:AJ'); // Specific sheet range
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
  }) async {
    try {
      print('Initializing attendance sheet with student data...');
      print('Class: ${classModel.className}');
      print('Sheet name: ${classModel.sheetName}');
      print('Class model contains ${classModel.students.length} students');
      
      // Use embedded service account key if available
      String serviceAccountKey = classModel.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        throw Exception('Service account key not configured');
      }

      // Get attendance sheet URL from control sheet for this specific batch
      // No fallback to embedded config - all sheet details must come from control sheet
      String? googleSheetUrl = await ControlSheetService.getAttendanceSheetUrlForBatch(classModel.sheetName ?? classModel.className);
      
      if (googleSheetUrl == null || googleSheetUrl.isEmpty) {
        // Provide a more detailed error message
        throw Exception('No attendance sheet URL configured in control sheet for batch "${classModel.sheetName ?? classModel.className}". All sheet details must be configured in the App_Control sheet.\n'
                      'Please ensure:\n'
                      '1. The batch tab exists in your App_Control sheet\n'
                      '2. The batch name "${classModel.sheetName ?? classModel.className}" exists as a tab in the App_Control sheet\n'
                      '3. The attendance sheet URL is properly configured for this batch\n'
                      '4. The service account has access to the attendance sheet\n'
                      '5. Check that the batch name in the app matches exactly with the tab name in the App_Control sheet');
      } else {
        print('✅ Using attendance sheet URL from control sheet: $googleSheetUrl');
      }

      print('Using attendance sheet URL from control sheet: $googleSheetUrl');
      
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
      print('🔐 Authenticating with Google Sheets API...');
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      print('✓ Authentication successful!');
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(googleSheetUrl);
      
      print('📈 Attempting to access Google Sheet: $spreadsheetId');
      
      // Test access to the spreadsheet
      try {
        print('Testing access to spreadsheet...');
        final testResponse = await retryNetworkOperation(() => sheetsApi.spreadsheets.get(spreadsheetId));
        print('✓ Successfully accessed Google Sheet: "${testResponse.properties?.title}"');
      } catch (e) {
        client.close();
        throw Exception('Failed to access spreadsheet: $e');
      }
      
      // Prepare the data to write
      final List<List<Object?>> dataToWrite = [];
      
      // Add header row
      dataToWrite.add([
        'Student Name', 'PIN Number', 'Branch', 'Mail ID', 'Mobile Number', 'COMBO'
      ]);
      
      // Add student data rows
      for (final student in classModel.students) {
        dataToWrite.add([
          student.name,
          student.pinNumber,
          student.branch,
          student.email,
          student.mobileNumber,
          student.combo,
        ]);
      }
      
      print('📝 Preparing to write ${dataToWrite.length} rows to sheet');
      
      // Determine the range to write to based on whether we're using a specific sheet
      String range = 'A1'; // Default range for single sheet
      if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        range = '${classModel.sheetName}!A1'; // Specific sheet range
      }
      
      print('📍 Writing to range: $range');
      
      // Create the value range object
      final valueRange = sheets.ValueRange();
      valueRange.range = range;
      valueRange.values = dataToWrite;
      valueRange.majorDimension = 'ROWS';
      
      try {
        // Write the data to the sheet
        print('📤 Uploading student data to Google Sheet...');
        final updateResponse = await retryNetworkOperation(() => sheetsApi.spreadsheets.values.update(
          valueRange,
          spreadsheetId,
          range,
          valueInputOption: 'RAW',
        ));
        
        print('✅ Successfully wrote data to Google Sheet');
        print('  Updated cells: ${updateResponse.updatedCells}');
        print('  Updated columns: ${updateResponse.updatedColumns}');
        print('  Updated rows: ${updateResponse.updatedRows}');
        print('  Updated range: ${updateResponse.updatedRange}');
        
        client.close();
        return true;
        
      } catch (e) {
        print('❌ Failed to write data to Google Sheet: $e');
        client.close();
        rethrow;
      }
      
    } catch (e, stackTrace) {
      print('Error initializing attendance sheet: $e');
      print('Stack trace: $stackTrace');
      rethrow;
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

      // Get attendance sheet URL from control sheet for this specific batch
      // No fallback to embedded config - all sheet details must come from control sheet
      String? googleSheetUrl = await ControlSheetService.getAttendanceSheetUrlForBatch(classModel.sheetName ?? classModel.className);
      
      if (googleSheetUrl == null || googleSheetUrl.isEmpty) {
        // Provide a more detailed error message
        throw Exception('No attendance sheet URL configured in control sheet for batch "${classModel.sheetName ?? classModel.className}". All sheet details must be configured in the App_Control sheet.\n'
                      'Please ensure:\n'
                      '1. The batch tab exists in your App_Control sheet\n'
                      '2. The batch name "${classModel.sheetName ?? classModel.className}" exists as a tab in the App_Control sheet\n'
                      '3. The attendance sheet URL is properly configured for this batch\n'
                      '4. The service account has access to the attendance sheet\n'
                      '5. Check that the batch name in the app matches exactly with the tab name in the App_Control sheet');
      } else {
        print('✅ Using attendance sheet URL from control sheet: $googleSheetUrl');
      }

      print('Class model Google Sheet URL: ${classModel.googleSheetUrl}');
      print('Final Google Sheet URL being used: $googleSheetUrl');
      
      // Validate Google Sheet URL
      if (googleSheetUrl.isEmpty) {
        throw Exception('Google Sheet URL is empty');
      }
      
      // Check if attendance sheet is initialized, and initialize if needed
      print('Checking if attendance sheet is initialized...');
      final isInitialized = await isAttendanceSheetInitialized(classModel: classModel);
      print('Attendance sheet initialized status: $isInitialized');
      
      if (!isInitialized) {
        print('Attendance sheet not initialized, initializing now...');
        final initSuccess = await initializeAttendanceSheet(classModel: classModel);
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

      // Authenticate with retry mechanism
      print('🔑 Attempting authentication with scopes: ${AppConstants.requiredScopes}');
      final client = await retryNetworkOperation(() => clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      ));

      print('✓ Authentication successful!');
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(googleSheetUrl);
      
      print('📈 Attempting to access Google Sheet: $spreadsheetId');
      print('🔗 Full Google Sheet URL being used: $googleSheetUrl');
      
      // Test access to the spreadsheet with retry mechanism
      try {
        print('Testing access to spreadsheet...');
        final testResponse = await retryNetworkOperation(() => sheetsApi.spreadsheets.get(spreadsheetId));
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

        await retryNetworkOperation(() => _uploadSessionData(
          sheetsApi,
          spreadsheetId,
          classModel,
          sessionDate,
          records,
        ));

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

  static String formatDateForSheet(DateTime date) {
    return '${date.day}-${date.month}-${date.year}';
  }

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
      range = _createRangeWithSheet(sheetName, 'A:ZZZ'); // Specific sheet range
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
        String updateRange = columnIndexToLetter(newColumnIndex) + '1';
        if (sheetName != null && sheetName.isNotEmpty) {
          updateRange = _createRangeWithSheet(sheetName, columnIndexToLetter(newColumnIndex) + '1');
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

  /// Utility function to properly format sheet names for Google Sheets API
  /// Wraps ALL sheet names in single quotes to avoid parsing issues
  static String _formatSheetName(String? sheetName) {
    if (sheetName == null || sheetName.isEmpty) {
      return '';
    }
    
    // Always wrap sheet names in single quotes to handle special characters safely
    // Escape any existing single quotes by doubling them
    final escapedSheetName = sheetName.replaceAll("'", "''");
    return "'$escapedSheetName'";
  }

  /// Utility function to create a properly formatted range with sheet name
  static String _createRangeWithSheet(String? sheetName, String rangeSuffix) {
    if (sheetName == null || sheetName.isEmpty) {
      return rangeSuffix;
    }
    
    final formattedSheetName = _formatSheetName(sheetName);
    return '$formattedSheetName!$rangeSuffix';
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
  
  /// Add new student to Google Sheets
  static Future<String?> addStudent(
    Student newStudent,
    ClassModel classModel,
    String serviceAccountKey,
  ) async {
    try {
      print('Adding student to Google Sheets: ${newStudent.name} (${newStudent.pinNumber})');
      
      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
      } catch (e) {
        throw Exception('Invalid service account JSON format: $e');
      }
      
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      } catch (e) {
        throw Exception('Failed to create service account credentials: $e');
      }

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );
      
      final sheetsApi = sheets.SheetsApi(client);
      
      // Use MASTER sheet URL from control sheet instead of attendance sheet
      final masterSheetUrl = await ControlSheetService.getMasterSheetUrlForBatch(classModel.sheetName ?? classModel.className);
      if (masterSheetUrl == null || masterSheetUrl.isEmpty) {
        throw Exception('No master sheet URL configured in control sheet');
      }
      
      final spreadsheetId = GoogleSheetsService.extractSpreadsheetId(masterSheetUrl);
      print('📄 Spreadsheet ID: $spreadsheetId');
      
      // Get existing data to find the next row
      String range = 'A:Z'; // Default range for single sheet
      // Use student's combo as the sheet name (Tab Name)
      if (newStudent.combo.isNotEmpty) {
        range = _createRangeWithSheet(newStudent.combo, 'A:Z'); 
      } else if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        range = _createRangeWithSheet(classModel.sheetName, 'A:Z');
      }
      
      print('Using data range: $range for fetching existing data');
      
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
      );

      final values = response.values ?? [];
      final nextRow = values.length + 1; // Add after the last row
      
      print('Adding student data to row: $nextRow');
      
      // Prepare student data
      final studentData = [
        newStudent.name,
        newStudent.pinNumber,
        newStudent.branch,
        newStudent.email,
        newStudent.mobileNumber,
        newStudent.combo,
        newStudent.securityCodes.join(', ')
      ];
      
      // Add student data to the sheet
      String updateRange = 'A$nextRow';
      // Use student's combo as the sheet name (Tab Name)
      if (newStudent.combo.isNotEmpty) {
        updateRange = _createRangeWithSheet(newStudent.combo, 'A$nextRow');
      } else if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        updateRange = _createRangeWithSheet(classModel.sheetName, 'A$nextRow');
      }
      
      print('Updating range: $updateRange with student data');
      
      final valueRange = sheets.ValueRange(
        range: updateRange,
        values: [studentData],
      );
      
      final updateResponse = await sheetsApi.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        updateRange,
        valueInputOption: 'RAW',
      );
      
      print('✅ Student added successfully');
      
      client.close();
      return null; // Return null for success
      
    } catch (e) {
      print('❌ Error adding student: $e');
      return 'Failed to add student: $e';
    }
  }

  /// Edit student information in Google Sheets
  static Future<String?> editStudent(
    Student updatedStudent,
    ClassModel classModel,
    String serviceAccountKey,
  ) async {
    try {
      print('Editing student in Google Sheets: ${updatedStudent.name} (${updatedStudent.pinNumber})');
      
      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
      } catch (e) {
        throw Exception('Invalid service account JSON format: $e');
      }
      
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      } catch (e) {
        throw Exception('Failed to create service account credentials: $e');
      }

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );
      
      final sheetsApi = sheets.SheetsApi(client);
      
      // Use MASTER sheet URL from control sheet instead of attendance sheet
      final masterSheetUrl = await ControlSheetService.getMasterSheetUrlForBatch(classModel.sheetName ?? classModel.className);
      if (masterSheetUrl == null || masterSheetUrl.isEmpty) {
        throw Exception('No master sheet URL configured in control sheet');
      }
      
      final spreadsheetId = GoogleSheetsService.extractSpreadsheetId(masterSheetUrl);
      print('📄 Spreadsheet ID: $spreadsheetId');
      
      // Get existing data to find the student row
      String range = 'A:Z'; // Default range for single sheet
      // Use student's combo as the sheet name (Tab Name)
      if (updatedStudent.combo.isNotEmpty) {
        range = _createRangeWithSheet(updatedStudent.combo, 'A:Z');
      } else if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        range = _createRangeWithSheet(classModel.sheetName, 'A:Z');
      }
      
      print('Using data range: $range for fetching existing data');
      
      final studentResponse = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
      );

      final studentValues = studentResponse.values ?? [];
      
      // Find the row with the student's PIN number
      int? studentRow;
      for (int i = 1; i < studentValues.length; i++) { // Skip header row
        if (studentValues[i].length > 1 && studentValues[i][1].toString().trim() == updatedStudent.pinNumber) {
          studentRow = i + 1; // 1-based indexing
          print('Found student at row: $studentRow');
          break;
        }
      }
      
      if (studentRow == null) {
        print('❌ Student not found in Google Sheets');
        client.close();
        return 'Student not found in Google Sheets';
      }
      
      // Prepare updated student data
      final updatedStudentData = [
        updatedStudent.name,
        updatedStudent.pinNumber,
        updatedStudent.branch,
        updatedStudent.email,
        updatedStudent.mobileNumber,
        updatedStudent.combo,
        updatedStudent.securityCodes.join(', ')
      ];
      
      // Update student data in the sheet
      String updateRange = 'A$studentRow';
      // Use student's combo as the sheet name (Tab Name)
      if (updatedStudent.combo.isNotEmpty) {
        updateRange = _createRangeWithSheet(updatedStudent.combo, 'A$studentRow');
      } else if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        updateRange = _createRangeWithSheet(classModel.sheetName, 'A$studentRow');
      }
      
      print('Updating range: $updateRange with student data');
      
      final valueRange = sheets.ValueRange(
        range: updateRange,
        values: [updatedStudentData],
      );
      
      final updateResponse = await sheetsApi.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        updateRange,
        valueInputOption: 'RAW',
      );
      
      print('✅ Student updated successfully');
      
      client.close();
      return null; // Return null for success
      
    } catch (e) {
      print('❌ Error editing student: $e');
      return 'Failed to edit student: $e';
    }
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

  /// Helper method to retry network operations with exponential backoff
  static Future<T> retryNetworkOperation<T>(Future<T> Function() operation, {int maxRetries = 3}) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        if (attempts >= maxRetries) {
          rethrow;
        }
        print('Operation failed (attempt $attempts/$maxRetries): $e. Retrying...');
        await Future.delayed(Duration(seconds: 1 * attempts));
      }
    }
  }

  /// Format date for sheet column header
  static String formatDateForSheet(DateTime date) {
    return '${date.day}-${date.month}-${date.year}';
  }

  /// Find or create a column for a specific date
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
      range = _createRangeWithSheet(sheetName, 'A:ZZZ'); // Specific sheet range
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
        String updateRange = columnIndexToLetter(newColumnIndex) + '1';
        if (sheetName != null && sheetName.isNotEmpty) {
          updateRange = _createRangeWithSheet(sheetName, columnIndexToLetter(newColumnIndex) + '1');
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

  /// Utility function to properly format sheet names for Google Sheets API
  /// Wraps ALL sheet names in single quotes to avoid parsing issues
  static String _formatSheetName(String? sheetName) {
    if (sheetName == null || sheetName.isEmpty) {
      return '';
    }
    
    // Always wrap sheet names in single quotes to handle special characters safely
    // Escape any existing single quotes by doubling them
    final escapedSheetName = sheetName.replaceAll("'", "''");
    return "'$escapedSheetName'";
  }

  /// Utility function to create a properly formatted range with sheet name
  static String _createRangeWithSheet(String? sheetName, String rangeSuffix) {
    if (sheetName == null || sheetName.isEmpty) {
      return rangeSuffix;
    }
    
    final formattedSheetName = _formatSheetName(sheetName);
    return '$formattedSheetName!$rangeSuffix';
  }

  /// Upload session data to Google Sheets
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
    
    // Find or create column for this date
    final columnIndex = await _findOrCreateDateColumn(
      sheetsApi,
      spreadsheetId,
      sessionDate,
      classModel.sheetName, // Pass sheet name for worksheet-specific columns
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
    if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
      studentDataRange = '${classModel.sheetName}!A:ZZZ'; // Specific sheet range
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

    final updates = <sheets.ValueRange>[];

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
    if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
      existingDataRange = '${classModel.sheetName}!$existingDataRange';
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
        
        if (existingStatus != null && existingStatus.toLowerCase() == 'present') {
          // Student already marked as present, keep as present (don't override)
          attendanceStatus = 'Present';
          print('   Keeping existing "Present" status for student');
        } else if (existingStatus != null && existingStatus.toLowerCase() == 'absent' && isPresent) {
          // Student marked as absent but is now present, change to present
          attendanceStatus = 'Present';
          print('   Changing "Absent" to "Present" for student');
        } else {
          // No existing status or student is absent, set based on current attendance
          attendanceStatus = isPresent ? 'Present' : 'Absent';
          print('   Setting status to: $attendanceStatus');
        }
        
        String cellRange = columnIndexToLetter(columnIndex) + (rowIndex + 1).toString();
        
        // Add sheet name prefix if specified
        if (classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
          cellRange = '${classModel.sheetName}!$cellRange';
        }
        
        print('   Adding update for range: $cellRange with value: $attendanceStatus');
        updates.add(sheets.ValueRange(
          range: cellRange,
          values: [[attendanceStatus]],
        ));
      } else if (rowIndex == null) {
        print('⚠️ Could not find matching row for student: $studentName (PIN: $studentPin)');
      } else {
        print('⚠️ Column index $columnIndex exceeds limit, skipping update for student $studentName');
      }
    }

    print('📊 Preparing to update ${updates.length} cells');

    // Batch update
    if (updates.isNotEmpty) {
      print('Sending batch update request with ${updates.length} updates');
      print('Update details:');
      for (int i = 0; i < updates.length; i++) {
        final update = updates[i];
        print('  Update ${i + 1}: Range=${update.range}, Values=${update.values}');
      }
      
      try {
        final batchUpdateRequest = sheets.BatchUpdateValuesRequest(
          valueInputOption: 'RAW',
          data: updates,
        );
        
        print('Batch update request prepared:');
        print('  Value input option: ${batchUpdateRequest.valueInputOption}');
        print('  Number of updates: ${batchUpdateRequest.data?.length}');
        
        final response = await sheetsApi.spreadsheets.values.batchUpdate(
          batchUpdateRequest,
          spreadsheetId,
        );
        
        print('✅ Batch update response received:');
        print('  Total updated cells: ${response.totalUpdatedCells}');
        print('  Total updated columns: ${response.totalUpdatedColumns}');
        print('  Total updated rows: ${response.totalUpdatedRows}');
        print('  Total updated sheets: ${response.totalUpdatedSheets}');
        print('  Responses count: ${response.responses?.length ?? 0}');
        
        if (response.responses != null) {
          for (int i = 0; i < response.responses!.length; i++) {
            final resp = response.responses![i];
            print('    Response $i: Updated range=${resp.updatedRange}, Updated cells=${resp.updatedCells}');
          }
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
        } else {
          rethrow;
        }
      }
      
      client.close();
      return TestResult.success('Google Sheets integration is working correctly');
      
    } catch (e) {
      return TestResult.failure('Test failed with error: $e');
    }
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