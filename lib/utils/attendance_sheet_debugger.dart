import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import '../services/sheet_data_service.dart';
import '../constants/app_constants.dart';

class AttendanceSheetDebugger {
  /// Get detailed information about the attendance sheet structure
  static Future<Map<String, dynamic>> getAttendanceSheetStructure(String attendanceSheetUrl, String serviceAccountKey) async {
    try {
      print('=== GETTING ATTENDANCE SHEET STRUCTURE ===');
      print('Attendance Sheet URL: $attendanceSheetUrl');
      
      // Parse service account credentials
      final serviceAccountJson = json.decode(serviceAccountKey);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = _extractSpreadsheetId(attendanceSheetUrl);
      
      print('Spreadsheet ID: $spreadsheetId');
      
      // Get spreadsheet info
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      
      final result = {
        'title': spreadsheet.properties?.title,
        'spreadsheetId': spreadsheet.spreadsheetId,
        'sheetCount': spreadsheet.sheets?.length ?? 0,
        'sheets': <Map<String, dynamic>>[],
      };
      
      print('Spreadsheet title: ${spreadsheet.properties?.title}');
      print('Number of sheets: ${spreadsheet.sheets?.length ?? 0}');
      
      // Get info about each sheet
      if (spreadsheet.sheets != null) {
        for (int i = 0; i < spreadsheet.sheets!.length; i++) {
          final sheet = spreadsheet.sheets![i];
          final sheetInfo = {
            'index': i,
            'title': sheet.properties?.title,
            'sheetId': sheet.properties?.sheetId,
            'rowCount': sheet.properties?.gridProperties?.rowCount,
            'columnCount': sheet.properties?.gridProperties?.columnCount,
          };
          
          print('Sheet ${i + 1}:');
          print('  Title: ${sheet.properties?.title}');
          print('  ID: ${sheet.properties?.sheetId}');
          print('  Rows: ${sheet.properties?.gridProperties?.rowCount}');
          print('  Columns: ${sheet.properties?.gridProperties?.columnCount}');
          
          // Add null check before calling add
          (result['sheets'] as List).add(sheetInfo);
        }
      }
      
      client.close();
      return result;
    } catch (e) {
      print('Error getting attendance sheet structure: $e');
      rethrow;
    }
  }
  
  /// Check if a specific worksheet exists in the attendance sheet
  static Future<bool> doesWorksheetExist(String attendanceSheetUrl, String serviceAccountKey, String worksheetName) async {
    try {
      print('=== CHECKING IF WORKSHEET EXISTS ===');
      print('Worksheet name: $worksheetName');
      
      // Parse service account credentials
      final serviceAccountJson = json.decode(serviceAccountKey);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = _extractSpreadsheetId(attendanceSheetUrl);
      
      // Get spreadsheet info
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      
      bool exists = false;
      if (spreadsheet.sheets != null) {
        for (final sheet in spreadsheet.sheets!) {
          if (sheet.properties?.title == worksheetName) {
            exists = true;
            print('✅ Worksheet "$worksheetName" exists');
            break;
          }
        }
      }
      
      if (!exists) {
        print('❌ Worksheet "$worksheetName" does not exist');
        print('Available worksheets:');
        if (spreadsheet.sheets != null) {
          for (final sheet in spreadsheet.sheets!) {
            print('  - ${sheet.properties?.title}');
          }
        }
      }
      
      client.close();
      return exists;
    } catch (e) {
      print('Error checking worksheet existence: $e');
      return false;
    }
  }
  
  /// Get the header row of a specific worksheet
  static Future<List<String>> getWorksheetHeaders(String attendanceSheetUrl, String serviceAccountKey, String worksheetName) async {
    try {
      print('=== GETTING WORKSHEET HEADERS ===');
      print('Worksheet name: $worksheetName');
      
      // Parse service account credentials
      final serviceAccountJson = json.decode(serviceAccountKey);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = _extractSpreadsheetId(attendanceSheetUrl);
      
      // Determine range for the worksheet
      String range = '$worksheetName!1:1'; // First row of specific sheet
      
      print('Using range: $range');
      
      // Get header row
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
      );
      
      final values = response.values ?? [];
      final headers = <String>[];
      
      if (values.isNotEmpty) {
        final headerRow = values[0];
        print('Header row has ${headerRow.length} columns');
        
        for (int i = 0; i < headerRow.length; i++) {
          final headerValue = headerRow[i].toString().trim();
          headers.add(headerValue);
          print('Column ${i + 1}: "$headerValue"');
        }
      } else {
        print('No data found in header row');
      }
      
      client.close();
      return headers;
    } catch (e) {
      print('Error getting worksheet headers: $e');
      return [];
    }
  }
  
  /// Search for today's date column in a specific worksheet
  static Future<Map<String, dynamic>?> findDateColumnInWorksheet(
    String attendanceSheetUrl, 
    String serviceAccountKey, 
    String worksheetName,
    String dateString
  ) async {
    try {
      print('=== SEARCHING FOR DATE COLUMN IN WORKSHEET ===');
      print('Worksheet name: $worksheetName');
      print('Looking for date: $dateString');
      
      // Parse service account credentials
      final serviceAccountJson = json.decode(serviceAccountKey);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = _extractSpreadsheetId(attendanceSheetUrl);
      
      // Determine range (check first 100 columns)
      String range = '$worksheetName!1:1'; // First row of specific sheet
      
      print('Using range: $range');
      
      // Get header row
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
      );
      
      final values = response.values ?? [];
      
      if (values.isNotEmpty) {
        final headerRow = values[0];
        print('Header row has ${headerRow.length} columns');
        
        // Search for the date
        for (int i = 0; i < headerRow.length; i++) {
          final headerValue = headerRow[i].toString().trim();
          print('Checking column ${i + 1}: "$headerValue"');
          
          if (headerValue == dateString) {
            print('✅ Found date column at index $i');
            
            final result = {
              'found': true,
              'columnIndex': i,
              'columnLetter': _columnIndexToLetter(i),
              'headerValue': headerValue,
            };
            
            client.close();
            return result;
          }
        }
        
        print('❌ Date column not found in first row');
      } else {
        print('❌ No data found in header row');
      }
      
      client.close();
      return {
        'found': false,
        'message': 'Date column not found',
      };
    } catch (e) {
      print('Error searching for date column: $e');
      rethrow;
    }
  }
  
  static String _extractSpreadsheetId(String url) {
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regex.firstMatch(url);
    if (match == null) {
      throw Exception('Invalid Google Sheets URL');
    }
    return match.group(1)!;
  }
  
  static String _columnIndexToLetter(int index) {
    String result = '';
    int dividend = index + 1;
    
    while (dividend > 0) {
      int modulo = (dividend - 1) % 26;
      result = String.fromCharCode(65 + modulo) + result;
      dividend = (dividend - modulo) ~/ 26;
    }
    
    return result;
  }
}