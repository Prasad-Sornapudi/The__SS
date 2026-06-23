import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import '../models/class_model.dart';
import '../constants/app_constants.dart';
import 'firebase_config_service.dart';
import 'firebase_service.dart';

class SheetDataService {
  static Future<String> getEmbeddedServiceAccountKey() async {
    // First try to get service account key from Firebase batch configuration
    try {
      // Try to get batch configurations and extract service account key
      final batchConfigs = await FirebaseConfigService.readBatchConfigs();
      if (batchConfigs.isNotEmpty) {
        // Get the first batch config (should be Skill_Sync01)
        final firstBatchConfig = batchConfigs.values.first;
        
        // Try to get service account key from attendance sheet first
        if (firstBatchConfig.attendanceSheet?.credentials?.isNotEmpty == true) {
          print('✅ Using service account key from batch config (attendance sheet)');
          return firstBatchConfig.attendanceSheet!.credentials!;
        }
        
        // Try master sheet if attendance sheet doesn't have credentials
        if (firstBatchConfig.masterSheet?.credentials?.isNotEmpty == true) {
          print('✅ Using service account key from batch config (master sheet)');
          return firstBatchConfig.masterSheet!.credentials!;
        }
      }
    } catch (e) {
      print('⚠️ Failed to get service account key from batch config: $e');
    }
    
    // Fallback to old method
    try {
      final firebaseServiceAccountKey = await FirebaseConfigService.readServiceAccountJson();
      if (firebaseServiceAccountKey != null && firebaseServiceAccountKey.isNotEmpty) {
        print('✅ Using service account key from Firebase (fallback method)');
        return firebaseServiceAccountKey;
      }
    } catch (e) {
      print('⚠️ Failed to get service account key from Firebase (fallback): $e');
    }
    
    // Throw an exception if no Firebase configuration is available
    // The app should only use Firebase configuration, not embedded keys
    throw Exception('No service account key found in Firebase. App requires Firebase configuration.');
  }

  /// Parse student data from Google Sheets values
  static List<Student> parseStudentData(List<List<dynamic>> values) {
    final students = <Student>[];
    
    if (values.isEmpty) return students;
    
    // Get header row
    final headerRow = values[0];
    
    // Create a map of header names to their column indices
    final headerMap = <String, int>{};
    for (int i = 0; i < headerRow.length; i++) {
      headerMap[headerRow[i].toString().trim()] = i;
    }
    
    print('📋 Header columns found: ${headerMap.keys.join(", ")}');
    
    // Parse each row as a student (skip header row)
    for (int i = 1; i < values.length; i++) {
      final row = values[i];
      if (row.isEmpty) continue;
      
      try {
        // Extract security codes and clean them properly
        final secCodesRaw = _getValueFromRow(row, headerMap, 'Sec-Codes', 6);
        print('Raw security codes from Sheet: "$secCodesRaw"');
        
        // Clean and split security codes
        List<String> securityCodes = [];
        if (secCodesRaw.isNotEmpty) {
          // Remove quotes and split by comma
          final cleanedCodes = secCodesRaw.replaceAll('"', '').trim();
          securityCodes = cleanedCodes.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        
        final student = Student(
          name: _getValueFromRow(row, headerMap, 'Name of the Student', 0),
          pinNumber: _getValueFromRow(row, headerMap, 'Pin-number', 1),
          email: _getValueFromRow(row, headerMap, 'Mail-id', 3),
          phone: '', // Add missing parameter
          branch: _getValueFromRow(row, headerMap, 'Branch', 2),
          mobileNumber: _getValueFromRow(row, headerMap, 'Mobile Number', 4),
          combo: _getValueFromRow(row, headerMap, 'COMBO', 5),
          securityCodes: securityCodes,
        );
        
        print('Created student: ${student.name} (${student.pinNumber}) with security codes: ${student.securityCodes}');
        students.add(student);
      } catch (e) {
        print('⚠️ Error parsing student from row $i: $e');
        continue;
      }
    }
    
    print('✅ Successfully parsed ${students.length} students from sheet data');
    return students;
  }
  
  /// Helper method to safely get values from a row
  static String _getValueFromRow(List<dynamic> row, Map<String, int> headerMap, String headerName, int defaultIndex) {
    // First try to get by header name
    if (headerMap.containsKey(headerName)) {
      final index = headerMap[headerName]!;
      if (index < row.length) {
        return row[index].toString().trim();
      }
    }
    
    // Fallback to default index
    if (defaultIndex < row.length) {
      return row[defaultIndex].toString().trim();
    }
    
    return '';
  }

  /// Fetch students directly from Firebase (New Method)
  static Future<SheetDataResult> fetchStudentsFromFirebase({
    required String className,
    String type = 'comboAttendance',
  }) async {
    try {
      print('🔄 Fetching students for $className from Firebase ($type)...');
      
      final firebaseService = FirebaseService();
      if (!firebaseService.isInitialized) {
        await firebaseService.init();
      }
      
      final students = await firebaseService.fetchStudentsFromFirebase(
        className: className,
        type: type,
      );
      
      if (students.isEmpty) {
        return SheetDataResult.error(
          message: 'No students found in Firebase for $className. Please ensure the sheet is synced.',
        );
      }
      
      return SheetDataResult.success(
        students: students,
        message: 'Successfully loaded ${students.length} students from Firebase',
      );
      
    } catch (e) {
      print('❌ Error fetching students from Firebase: $e');
      return SheetDataResult.error(message: 'Failed to load data: $e');
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
  
  /// Fetch list of available sheets from a master spreadsheet
  static Future<SheetListResult> fetchAvailableSheets({
    required String googleSheetUrl,
    required String serviceAccountKey,
  }) async {
    try {
      // Service account key must be provided - no fallback to embedded keys
      if (serviceAccountKey.isEmpty) {
        throw Exception('Service account key not configured. App requires Firebase configuration.');
      }

      print('🔐 Starting Google Sheets authentication for sheet list fetch...');
      
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
      final spreadsheetId = extractSpreadsheetId(googleSheetUrl);
      
      print('📈 Attempting to access Google Sheet: $spreadsheetId');
      
      // Get spreadsheet metadata to list all sheets
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      
      final sheetNames = <String>[];
      if (spreadsheet.sheets != null) {
        for (final sheet in spreadsheet.sheets!) {
          if (sheet.properties?.title != null) {
            sheetNames.add(sheet.properties!.title!);
          }
        }
      }
      
      client.close();
      
      print('✅ Found ${sheetNames.length} sheets in master spreadsheet');
      
      return SheetListResult.success(
        sheetNames: sheetNames,
        message: 'Successfully fetched ${sheetNames.length} sheets from master spreadsheet',
      );

    } catch (e) {
      print('❌ Google Sheets sheet list fetch error: $e');
      
      String errorMessage;
      if (e.toString().contains('SocketException') || e.toString().contains('failed host lookup')) {
        errorMessage = 'Network connection failed. Please check your internet connection and try again. Ensure you have access to Google Sheets.';
      } else if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        errorMessage = 'SSL certificate verification failed. Please check your network security settings.';
      } else if (e.toString().contains('Connection timed out')) {
        errorMessage = 'Connection timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('missing or invalid authentication')) {
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
      } else {
        errorMessage = 'Failed to fetch sheet list: $e';
      }
      
      return SheetListResult.error(
        message: errorMessage,
      );
    }
  }
}

/// Result class for sheet data operations
class SheetDataResult {
  final bool isSuccess;
  final List<Student>? students;
  final String message;

  SheetDataResult._({
    required this.isSuccess,
    this.students,
    required this.message,
  });

  factory SheetDataResult.success({
    required List<Student> students,
    required String message,
  }) {
    return SheetDataResult._(
      isSuccess: true,
      students: students,
      message: message,
    );
  }

  factory SheetDataResult.error({
    required String message,
  }) {
    return SheetDataResult._(
      isSuccess: false,
      message: message,
    );
  }
}

/// Result class for sheet list operations
class SheetListResult {
  final bool isSuccess;
  final List<String>? sheetNames;
  final String message;

  SheetListResult._({
    required this.isSuccess,
    this.sheetNames,
    required this.message,
  });

  factory SheetListResult.success({
    required List<String> sheetNames,
    required String message,
  }) {
    return SheetListResult._(
      isSuccess: true,
      sheetNames: sheetNames,
      message: message,
    );
  }

  factory SheetListResult.error({
    required String message,
  }) {
    return SheetListResult._(
      isSuccess: false,
      message: message,
    );
  }
}