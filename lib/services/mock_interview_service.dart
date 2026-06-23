import 'dart:convert';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import '../models/class_model.dart';
import '../services/control_sheet_service.dart';
import '../services/sheet_data_service.dart';
import '../constants/app_constants.dart';
import 'firebase_config_service.dart';
import '../models/mock_interview.dart';

class MockInterviewService {
  /// Get mock interview sheet URL for a specific batch from control sheet
  static Future<String?> getMockInterviewSheetUrlForBatch(String batchName) async {
    print('🔍 Getting mock interview sheet URL for batch: "$batchName"');
    final result = await ControlSheetService.getMockInterviewSheetUrlForBatch(batchName);
    print('📄 Mock interview sheet URL result for "$batchName": $result');
    return result;
  }
  
  /// Get mock interview service account key for a specific batch from control sheet
  static Future<String?> _getMockInterviewServiceAccountKey(String batchName) async {
    print('🔍 Getting mock interview service account key for batch: "$batchName"');
    final result = await ControlSheetService.getMockInterviewServiceAccountKey(batchName);
    print('📄 Mock interview service account key result for "$batchName": ${result?.length ?? 0} characters');
    return result;
  }

  /// Save mock interview data to Google Sheets
  static Future<bool> saveMockInterview({
    required ClassModel classModel,
    required MockInterview mockInterview,
  }) async {
    try {
      print('=== MOCK INTERVIEW SAVE PROCESS STARTED ===');
      print('Input Parameters:');
      print('  Class Name: ${classModel.className}');
      print('  Student Pin: ${mockInterview.studentPinNumber}');
      print('  Student Name: ${mockInterview.studentName}');
      print('  Interview Date: ${mockInterview.interviewDate}');
      
      // Validate inputs
      if (classModel.className.isEmpty) {
        print('❌ ERROR: Class name is empty');
        return false;
      }
      
      if (mockInterview.studentPinNumber.isEmpty) {
        print('❌ ERROR: Student pin number is empty');
        return false;
      }
      
      // Step 1: Get mock interview sheet URL
      // First, try to get the URL using the class name directly (for backward compatibility)
      // If that fails, try to get it using the batch name from the sheetName field
      print('STEP 1: Retrieving mock interview sheet URL...');
      String? mockInterviewSheetUrl;
      String batchNameToUse = classModel.className;
      
      // Try getting URL with class name first
      mockInterviewSheetUrl = await getMockInterviewSheetUrlForBatch(classModel.className);
      
      // If that fails and we have a sheetName (which should be the batch name), try that
      if ((mockInterviewSheetUrl == null || mockInterviewSheetUrl.isEmpty) && 
          classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        print('🔄 Class name lookup failed, trying with sheetName (batch name): "${classModel.sheetName}"');
        batchNameToUse = classModel.sheetName!;
        mockInterviewSheetUrl = await getMockInterviewSheetUrlForBatch(classModel.sheetName!);
      }
      
      if (mockInterviewSheetUrl == null || mockInterviewSheetUrl.isEmpty) {
        print('❌ ERROR: Mock interview sheet URL is null or empty');
        print('  Class name used: ${classModel.className}');
        print('  Batch name used: $batchNameToUse');
        print('💡 SOLUTION: Make sure the batch "$batchNameToUse" exists in your control sheet with a mock interview sheet URL');
        return false;
      }

      // Step 2: Get service account key
      print('STEP 2: Retrieving service account key...');
      String? serviceAccountKey;
      
      // Try to get service account key from control sheet
      serviceAccountKey = await _getMockInterviewServiceAccountKey(batchNameToUse);
      
      // If that fails, try to get it from Firebase
      if (serviceAccountKey == null || serviceAccountKey.isEmpty) {
        print('🔄 Service account key not found in control sheet, trying Firebase...');
        final config = await FirebaseConfigService.readConfiguration();
        if (config != null) {
          serviceAccountKey = config.serviceAccountJson;
          print('✅ Service account key retrieved from Firebase (${serviceAccountKey.length} characters)');
        }
      }
      
      // If still no service account key, use embedded one
      if (serviceAccountKey == null || serviceAccountKey.isEmpty) {
        print('⚠️ No service account key found, using embedded key...');
        serviceAccountKey = await SheetDataService.getEmbeddedServiceAccountKey();
      }
      
      if (serviceAccountKey == null || serviceAccountKey.isEmpty) {
        print('❌ ERROR: No service account key available');
        return false;
      }

      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
      } catch (e) {
        print('❌ Invalid service account JSON format: $e');
        return false;
      }

      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      } catch (e) {
        print('❌ Failed to create service account credentials: $e');
        return false;
      }

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = SheetDataService.extractSpreadsheetId(mockInterviewSheetUrl);

      // Use the class name as sheet name
      String targetSheetName = classModel.sheetName ?? classModel.className;
      print('🎯 Target sheet name: "$targetSheetName"');
      print('  Class sheet name: "${classModel.sheetName}"');
      print('  Class class name: "${classModel.className}"');
      
      // Try to find the sheet by class name
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      final sheetNames = spreadsheet.sheets?.map((sheet) => sheet.properties?.title ?? '').toList() ?? [];
      print('📚 Available sheets in spreadsheet (count: ${sheetNames.length}):');
      for (int i = 0; i < sheetNames.length; i++) {
        print('  Sheet $i: "${sheetNames[i]}"');
      }
      
      String? sheetNameToUse;
      
      // Try exact match first
      print('🔍 Looking for exact match for: "$targetSheetName"');
      for (final sheetName in sheetNames) {
        print('  Comparing with: "$sheetName"');
        if (sheetName.toLowerCase() == targetSheetName.toLowerCase()) {
          sheetNameToUse = sheetName;
          print('✅ Found exact match: "$sheetNameToUse"');
          break;
        }
      }
      
      // If exact match not found, try partial match
      if (sheetNameToUse == null) {
        print('🔍 Looking for partial match for: "$targetSheetName"');
        for (final sheetName in sheetNames) {
          print('  Checking partial match with: "$sheetName"');
          if (sheetName.toLowerCase().contains(targetSheetName.toLowerCase()) || 
              targetSheetName.toLowerCase().contains(sheetName.toLowerCase())) {
            sheetNameToUse = sheetName;
            print('🔄 Found partial match: "$sheetNameToUse"');
            break;
          }
        }
      }
      
      if (sheetNameToUse == null) {
        print('⚠️ Sheet not found: "$targetSheetName"');
        print('💡 Available sheets: $sheetNames');
        client.close();
        return false;
      }
      
      print('📄 Using sheet: "$sheetNameToUse"');
      
      // Prepare data to write - using the actual fields from MockInterview model
      final List<Object?> rowData = [
        mockInterview.studentPinNumber,
        mockInterview.studentName,
        mockInterview.interviewDate.toIso8601String(),
        // TR Round metrics
        mockInterview.tr.problemSolving ?? '',
        mockInterview.tr.technicalKnowledge ?? '',
        mockInterview.tr.codingEfficiency ?? '',
        mockInterview.tr.systemDesign ?? '',
        mockInterview.tr.logicalReasoning ?? '',
        // HR Round metrics
        mockInterview.hr.communication ?? '',
        mockInterview.hr.confidence ?? '',
        mockInterview.hr.bodyLanguage ?? '',
        mockInterview.hr.attitude ?? '',
        mockInterview.hr.listening ?? '',
        // MR Round metrics
        mockInterview.mr.decisionMaking ?? '',
        mockInterview.mr.leadership ?? '',
        mockInterview.mr.teamwork ?? '',
        mockInterview.mr.stressHandling ?? '',
        mockInterview.mr.realScenarioProblemSolving ?? '',
        // Profile data
        mockInterview.profile.gitHub ?? '',
        mockInterview.profile.linkedIn ?? '',
        mockInterview.profile.resumeScore?.toString() ?? '',
        // Coding data
        mockInterview.coding.leetCode?.toString() ?? '',
        mockInterview.coding.codeChef?.toString() ?? '',
        mockInterview.coding.geeksForGeeks ?? '',
      ];
      
      // Create the request to append data
      final request = sheets.AppendCellsRequest(
        sheetId: spreadsheet.sheets?.firstWhere(
          (sheet) => sheet.properties?.title == sheetNameToUse,
          orElse: () => spreadsheet.sheets!.first,
        ).properties?.sheetId,
        rows: [
          sheets.RowData(
            values: rowData.map((value) => sheets.CellData(
              userEnteredValue: sheets.ExtendedValue(
                stringValue: value?.toString() ?? '',
              ),
            )).toList(),
          ),
        ],
        fields: '*',
      );
      
      final updateRequest = sheets.BatchUpdateSpreadsheetRequest(
        requests: [
          sheets.Request(appendCells: request),
        ],
      );
      
      // Execute the request
      await sheetsApi.spreadsheets.batchUpdate(updateRequest, spreadsheetId);
      
      client.close();
      
      print('✅ Mock interview data saved successfully');
      return true;
      
    } catch (e, stackTrace) {
      print('💥 Error saving mock interview data: $e');
      print('📜 Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Fetch mock interview data by roll number
  static Future<List<Map<String, dynamic>>> fetchMockInterviewDataByRollNumber({
    required String rollNumber,
    required ClassModel classModel,
  }) async {
    try {
      print('=== FETCHING MOCK INTERVIEW DATA BY ROLL NUMBER ===');
      print('Input Parameters:');
      print('  Roll Number: $rollNumber');
      print('  Class Name: ${classModel.className}');
      
      // Validate inputs
      if (rollNumber.isEmpty) {
        print('❌ ERROR: Roll number is empty');
        return [];
      }
      
      if (classModel.className.isEmpty) {
        print('❌ ERROR: Class name is empty');
        return [];
      }
      
      // Step 1: Get mock interview sheet URL
      print('STEP 1: Retrieving mock interview sheet URL...');
      String? mockInterviewSheetUrl;
      String batchNameToUse = classModel.className;
      
      // Try getting URL with class name first
      mockInterviewSheetUrl = await getMockInterviewSheetUrlForBatch(classModel.className);
      
      // If that fails and we have a sheetName (which should be the batch name), try that
      if ((mockInterviewSheetUrl == null || mockInterviewSheetUrl.isEmpty) && 
          classModel.sheetName != null && classModel.sheetName!.isNotEmpty) {
        print('🔄 Class name lookup failed, trying with sheetName (batch name): "${classModel.sheetName}"');
        batchNameToUse = classModel.sheetName!;
        mockInterviewSheetUrl = await getMockInterviewSheetUrlForBatch(classModel.sheetName!);
      }
      
      if (mockInterviewSheetUrl == null || mockInterviewSheetUrl.isEmpty) {
        print('❌ ERROR: Mock interview sheet URL is null or empty');
        print('  Class name used: ${classModel.className}');
        print('  Batch name used: $batchNameToUse');
        print('💡 SOLUTION: Make sure the batch "$batchNameToUse" exists in your control sheet with a mock interview sheet URL');
        return [];
      }

      // Step 2: Get service account key
      print('STEP 2: Retrieving service account key...');
      String? serviceAccountKey;
      
      // Try to get service account key from control sheet
      serviceAccountKey = await _getMockInterviewServiceAccountKey(batchNameToUse);
      
      // If that fails, try to get it from Firebase
      if (serviceAccountKey == null || serviceAccountKey.isEmpty) {
        print('🔄 Service account key not found in control sheet, trying Firebase...');
        final config = await FirebaseConfigService.readConfiguration();
        if (config != null) {
          serviceAccountKey = config.serviceAccountJson;
          print('✅ Service account key retrieved from Firebase (${serviceAccountKey.length} characters)');
        }
      }
      
      // If still no service account key, use embedded one
      if (serviceAccountKey == null || serviceAccountKey.isEmpty) {
        print('⚠️ No service account key found, using embedded key...');
        serviceAccountKey = await SheetDataService.getEmbeddedServiceAccountKey();
      }
      
      if (serviceAccountKey == null || serviceAccountKey.isEmpty) {
        print('❌ ERROR: No service account key available');
        return [];
      }

      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
      } catch (e) {
        print('❌ Invalid service account JSON format: $e');
        return [];
      }

      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      } catch (e) {
        print('❌ Failed to create service account credentials: $e');
        return [];
      }

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = SheetDataService.extractSpreadsheetId(mockInterviewSheetUrl);

      // Use the class name as sheet name
      String targetSheetName = classModel.sheetName ?? classModel.className;
      print('🎯 Target sheet name: "$targetSheetName"');
      print('  Class sheet name: "${classModel.sheetName}"');
      print('  Class class name: "${classModel.className}"');
      
      // Try to find the sheet by class name
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      final sheetNames = spreadsheet.sheets?.map((sheet) => sheet.properties?.title ?? '').toList() ?? [];
      print('📚 Available sheets in spreadsheet (count: ${sheetNames.length}):');
      for (int i = 0; i < sheetNames.length; i++) {
        print('  Sheet $i: "${sheetNames[i]}"');
      }
      
      String? sheetNameToUse;
      
      // Try exact match first
      print('🔍 Looking for exact match for: "$targetSheetName"');
      for (final sheetName in sheetNames) {
        print('  Comparing with: "$sheetName"');
        if (sheetName.toLowerCase() == targetSheetName.toLowerCase()) {
          sheetNameToUse = sheetName;
          print('✅ Found exact match: "$sheetNameToUse"');
          break;
        }
      }
      
      // If exact match not found, try partial match
      if (sheetNameToUse == null) {
        print('🔍 Looking for partial match for: "$targetSheetName"');
        for (final sheetName in sheetNames) {
          print('  Checking partial match with: "$sheetName"');
          if (sheetName.toLowerCase().contains(targetSheetName.toLowerCase()) || 
              targetSheetName.toLowerCase().contains(sheetName.toLowerCase())) {
            sheetNameToUse = sheetName;
            print('🔄 Found partial match: "$sheetNameToUse"');
            break;
          }
        }
      }
      
      if (sheetNameToUse == null) {
        print('⚠️ Sheet not found: "$targetSheetName"');
        print('💡 Available sheets: $sheetNames');
        client.close();
        return [];
      }
      
      print('📄 Using sheet: "$sheetNameToUse"');
      
      try {
        // Read the sheet data
        final response = await sheetsApi.spreadsheets.values.get(
          spreadsheetId,
          '$sheetNameToUse!A:ZZZ', // Read all columns
        );

        final values = response.values ?? [];
        print('📊 Mock interview sheet has ${values.length} rows');
        
        if (values.isEmpty) {
          client.close();
          return [];
        }
        
        // Parse headers
        final headers = values.first;
        print('📋 Headers (count: ${headers.length}):');
        for (int i = 0; i < headers.length; i++) {
          print('  Column $i: "${headers[i]}"');
        }
        
        // Find the Pin-number column
        int pinNumberColumnIndex = -1;
        print('🔍 Looking for "Pin-number" column');
        for (int i = 0; i < headers.length; i++) {
          final headerValue = headers[i].toString().trim();
          print('  Checking column $i: "$headerValue"');
          if (headerValue == 'Pin-number') {
            pinNumberColumnIndex = i;
            print('✅ Found Pin-number column at index: $i');
            break;
          }
        }
        
        // Find the Name of the Student column
        int nameColumnIndex = -1;
        print('🔍 Looking for "Name of the Student" column');
        for (int i = 0; i < headers.length; i++) {
          final headerValue = headers[i].toString().trim();
          print('  Checking column $i: "$headerValue"');
          if (headerValue == 'Name of the Student') {
            nameColumnIndex = i;
            print('✅ Found Name of the Student column at index: $i');
            break;
          }
        }
        
        if (pinNumberColumnIndex == -1) {
          print('⚠️ Pin-number column not found');
          client.close();
          return [];
        }
        
        // Find student row (case-insensitive comparison with whitespace trimming)
        int studentRowIndex = -1;
        final normalizedRollNumber = rollNumber.trim().toLowerCase();
        print('🔍 Searching for roll number: "$normalizedRollNumber"');
        
        for (int i = 1; i < values.length; i++) {
          if (values[i].length > pinNumberColumnIndex) {
            final cellValue = values[i][pinNumberColumnIndex].toString().trim().toLowerCase();
            print('  Comparing with row $i value: "$cellValue"');
            if (cellValue == normalizedRollNumber) {
              studentRowIndex = i;
              print('✅ Found matching roll number at row: $i');
              break;
            }
          }
        }
        
        if (studentRowIndex == -1) {
          print('❓ Student not found in mock interview sheet');
          print('  Searched for roll number: "$normalizedRollNumber"');
          print('  Available student rows: ${values.length > 1 ? values.length - 1 : 0}');
          
          // Print first few student pin numbers for debugging
          for (int i = 1; i < values.length && i <= 5; i++) {
            if (values[i].length > pinNumberColumnIndex) {
              final cellValue = values[i][pinNumberColumnIndex].toString().trim().toLowerCase();
              print('  Row $i pin number: "$cellValue"');
            }
          }
          
          client.close();
          return [];
        }
        
        print('👤 Found student at row: ${studentRowIndex + 1}');
        
        // Get student name if available
        String studentName = 'Student';
        if (nameColumnIndex != -1 && values[studentRowIndex].length > nameColumnIndex) {
          studentName = values[studentRowIndex][nameColumnIndex].toString().trim();
          if (studentName.isEmpty) {
            studentName = 'Student';
          }
          print('👤 Student name: $studentName');
        }
        
        // Parse date columns and extract JSON data
        final results = <Map<String, dynamic>>[];
        final studentRow = values[studentRowIndex];
        
        // Find the Sec-Codes column to determine where date columns start
        int startIndex = headers.length; // Default to end if not found
        print('🔍 Looking for "Sec-Codes" column to determine date column start position');
        for (int i = 0; i < headers.length; i++) {
          final headerValue = headers[i].toString().trim();
          print('  Checking column $i: "$headerValue"');
          if (headerValue == 'Sec-Codes') {
            startIndex = i + 1;
            print('✅ Found Sec-Codes column at index $i, date columns start at index: $startIndex');
            break;
          }
        }
        
        // If Sec-Codes column not found, start from the first column after Pin-number
        if (startIndex == headers.length) {
          startIndex = pinNumberColumnIndex + 1;
          print('⚠️ Sec-Codes column not found, using fallback start index: $startIndex');
        }
        
        print('📅 Starting to parse date columns from index: $startIndex');
        
        print('📅 Processing date columns from index $startIndex');
        print('  Headers length: ${headers.length}');
        print('  Student row length: ${studentRow.length}');
        
        // Process each date column
        for (int i = startIndex; i < headers.length && i < studentRow.length; i++) {
          final date = headers[i].toString().trim();
          final jsonData = studentRow[i].toString().trim();
          
          print('  Processing column $i: Date="$date", Data="$jsonData"');
          
          // Skip empty cells
          if (jsonData.isEmpty) {
            print('  Skipping empty cell at column $i');
            continue;
          }
          
          try {
            // Try to parse JSON data
            // Fix trailing commas that might cause parsing issues
            String cleanJsonData = jsonData.trim();
            if (cleanJsonData.endsWith(',')) {
              cleanJsonData = cleanJsonData.substring(0, cleanJsonData.length - 1);
              print('🔧 Fixed trailing comma in JSON data for date: $date');
            }
            
            final parsedData = jsonDecode(cleanJsonData);
            parsedData['date'] = date; // Add date to the data
            parsedData['studentName'] = studentName; // Add student name to the data
            results.add(parsedData);
            print('✅ Parsed data for date: $date');
          } catch (e) {
            print('⚠️ Could not parse JSON for date $date: $e');
            print('  Raw JSON data: $jsonData');
          }
        }
        
        print('📊 Total parsed records: ${results.length}');
        
        client.close();
        return results;
        
      } catch (e) {
        print('❌ Error reading mock interview sheet: $e');
        client.close();
        return [];
      }
      
    } catch (e, stackTrace) {
      print('💥 Error fetching mock interview data: $e');
      print('📜 Stack trace: $stackTrace');
      return [];
    }
  }
}