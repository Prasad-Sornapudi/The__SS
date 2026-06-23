import 'dart:convert';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'firebase_config_service.dart';
import '../constants/app_constants.dart';

class SheetDiagnosticService {
  /// Run a comprehensive diagnostic on the control sheet access
  static Future<SheetDiagnosticResult> runControlSheetDiagnostic() async {
    try {
      // Step 1: Read service account key from Firebase
      print('Step 1: Reading service account key from Firebase...');
      final serviceAccountJsonString = await FirebaseConfigService.readServiceAccountJson();
      
      if (serviceAccountJsonString == null) {
        return SheetDiagnosticResult(
          success: false,
          message: '❌ No service account key found in Firebase',
          details: 'Please upload your service account key to Firebase Realtime Database at sync/sheetConfig/serviceAccountJson',
        );
      }
      
      print('✅ Service account key found in Firebase');
      
      // Parse the JSON string to a Map
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = jsonDecode(serviceAccountJsonString);
      } catch (e) {
        return SheetDiagnosticResult(
          success: false,
          message: '❌ Failed to parse service account JSON',
          details: 'Error: $e',
        );
      }
      
      // Step 2: Validate service account key structure
      print('Step 2: Validating service account key structure...');
      final requiredFields = [
        'type',
        'project_id',
        'private_key_id',
        'private_key',
        'client_email',
        'client_id',
        'auth_uri',
        'token_uri',
      ];
      
      for (final field in requiredFields) {
        if (!serviceAccountJson.containsKey(field) || serviceAccountJson[field] == null) {
          return SheetDiagnosticResult(
            success: false,
            message: '❌ Missing required field in service account key',
            details: 'Missing field: $field',
          );
        }
      }
      
      if (serviceAccountJson['type'] != 'service_account') {
        return SheetDiagnosticResult(
          success: false,
          message: '❌ Invalid service account type',
          details: 'Expected "service_account", got "${serviceAccountJson['type']}"',
        );
      }
      
      print('✅ Service account validation passed');
      print('Service Account Email: ${serviceAccountJson['client_email']}');
      
      // Step 3: Read control sheet URL from Firebase
      print('Step 3: Reading control sheet URL from Firebase...');
      final controlSheetUrl = await FirebaseConfigService.readControlSheetUrl();
      
      if (controlSheetUrl == null || controlSheetUrl.isEmpty) {
        return SheetDiagnosticResult(
          success: false,
          message: '❌ No control sheet URL found in Firebase',
          details: 'Please set your control sheet URL in Firebase Realtime Database at sync/sheetConfig/googleSheetUrl',
        );
      }
      
      print('✅ Control sheet URL found: $controlSheetUrl');
      
      // Step 4: Create service account credentials
      print('Step 4: Creating service account credentials...');
      ServiceAccountCredentials credentials;
      try {
        credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
        print('✅ Service account credentials created successfully');
      } catch (e) {
        return SheetDiagnosticResult(
          success: false,
          message: '❌ Failed to create service account credentials',
          details: 'Error: $e',
        );
      }
      
      // Step 5: Authenticate with Google Sheets API
      print('Step 5: Authenticating with Google Sheets API...');
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );
      print('✅ Authentication successful');
      
      // Step 6: Extract spreadsheet ID
      print('Step 6: Extracting spreadsheet ID...');
      final spreadsheetId = _extractSpreadsheetId(controlSheetUrl);
      print('Spreadsheet ID: $spreadsheetId');
      
      // Step 7: Access spreadsheet metadata
      print('Step 7: Accessing spreadsheet metadata...');
      final sheetsApi = sheets.SheetsApi(client);
      
      sheets.Spreadsheet spreadsheet;
      try {
        spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
        print('✅ Successfully accessed spreadsheet: "${spreadsheet.properties?.title}"');
      } catch (e) {
        client.close();
        return SheetDiagnosticResult(
          success: false,
          message: '❌ Failed to access spreadsheet',
          details: 'Error: $e\n'
                 'This usually means:\n'
                 '1. The spreadsheet ID is incorrect\n'
                 '2. The spreadsheet doesn\'t exist\n'
                 '3. The service account doesn\'t have access to the spreadsheet',
        );
      }
      
      // Step 8: List all sheets in the spreadsheet
      print('Step 8: Listing all sheets in spreadsheet...');
      final sheetNames = <String>[];
      final sheetDetails = <Map<String, dynamic>>[];
      
      if (spreadsheet.sheets != null) {
        for (final sheet in spreadsheet.sheets!) {
          final title = sheet.properties?.title ?? 'Untitled';
          final sheetId = sheet.properties?.sheetId ?? 0;
          sheetNames.add(title);
          sheetDetails.add({
            'title': title,
            'id': sheetId,
          });
          print('  📄 "$title" (ID: $sheetId)');
        }
      }
      
      print('Found ${sheetNames.length} sheets: ${sheetNames.join(", ")}');
      
      // Step 9: Check for Login_Credentials sheet
      print('Step 9: Checking for Login_Credentials sheet...');
      final hasLoginCredentialsSheet = sheetNames.contains('Login_Credentials');
      if (!hasLoginCredentialsSheet) {
        client.close();
        return SheetDiagnosticResult(
          success: false,
          message: '❌ Login_Credentials sheet not found',
          details: 'Available sheets: ${sheetNames.join(", ")}\n'
                 'Please create a sheet named exactly "Login_Credentials" in your spreadsheet.',
        );
      }
      
      print('✅ Login_Credentials sheet found');
      
      // Step 10: Try to access Login_Credentials sheet data
      print('Step 10: Accessing Login_Credentials sheet data...');
      try {
        final response = await sheetsApi.spreadsheets.values.get(
          spreadsheetId,
          'Login_Credentials!A:C',
        );
        
        final values = response.values ?? [];
        print('✅ Successfully accessed Login_Credentials sheet');
        print('📊 Sheet contains ${values.length} rows');
        
        if (values.isNotEmpty) {
          print('📋 Header row: ${values[0]}');
        }
        
        client.close();
        
        return SheetDiagnosticResult(
          success: true,
          message: '✅ All checks passed!',
          details: 'Successfully accessed Login_Credentials sheet.\n'
                 'Spreadsheet: "${spreadsheet.properties?.title}"\n'
                 'Total sheets: ${sheetNames.length}\n'
                 'Login_Credentials sheet: Found\n'
                 'Data rows: ${values.length}',
          sheetNames: sheetNames,
          loginCredentialsSheetFound: true,
          dataRows: values.length,
        );
        
      } catch (e) {
        client.close();
        return SheetDiagnosticResult(
          success: false,
          message: '❌ Failed to access Login_Credentials sheet data',
          details: 'Error: $e\n'
                 'This usually means:\n'
                 '1. The service account doesn\'t have editor permissions\n'
                 '2. The sheet range is invalid\n'
                 '3. Network connectivity issues',
        );
      }
      
    } catch (e, stackTrace) {
      print('💥 Diagnostic failed with error: $e');
      print('📜 Stack trace: $stackTrace');
      return SheetDiagnosticResult(
        success: false,
        message: '❌ Diagnostic failed',
        details: 'Error: $e\n'
               'Stack trace: $stackTrace',
      );
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
}

class SheetDiagnosticResult {
  final bool success;
  final String message;
  final String details;
  final List<String>? sheetNames;
  final bool? loginCredentialsSheetFound;
  final int? dataRows;
  
  SheetDiagnosticResult({
    required this.success,
    required this.message,
    required this.details,
    this.sheetNames,
    this.loginCredentialsSheetFound,
    this.dataRows,
  });
}