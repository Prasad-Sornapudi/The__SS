import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import '../services/sheet_data_service.dart';
import '../constants/app_constants.dart';

/// Utility function to properly format sheet names for Google Sheets API
/// Wraps ALL sheet names in single quotes to avoid parsing issues
String _formatSheetName(String? sheetName) {
  if (sheetName == null || sheetName.isEmpty) {
    return '';
  }
  
  // ALWAYS quote sheet names to avoid parsing issues
  // Escape any single quotes in the sheet name
  final escapedSheetName = sheetName.replaceAll("'", "''");
  return "'$escapedSheetName'";
}

/// Utility function to create a properly formatted range with sheet name
String _createRangeWithSheet(String? sheetName, String rangeSuffix) {
  if (sheetName == null || sheetName.isEmpty) {
    return rangeSuffix;
  }
  
  final formattedSheetName = _formatSheetName(sheetName);
  return '$formattedSheetName!$rangeSuffix';
}

class SheetDebugger {
  /// Get detailed information about the Google Sheet structure
  static Future<Map<String, dynamic>> getSheetStructureInfo(String sheetUrl, String serviceAccountKey) async {
    try {
      print('=== GETTING SHEET STRUCTURE INFO ===');
      print('Sheet URL: $sheetUrl');
      
      // Parse service account credentials
      final serviceAccountJson = json.decode(serviceAccountKey);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = _extractSpreadsheetId(sheetUrl);
      
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
          
          // Fix: Add null check before calling add
          (result['sheets'] as List).add(sheetInfo);
        }
      }
      
      client.close();
      return result;
    } catch (e) {
      print('Error getting sheet structure: $e');
      rethrow;
    }
  }
  
  /// Get column information for a specific sheet
  static Future<Map<String, dynamic>> getColumnInfo(String sheetUrl, String serviceAccountKey, {String? sheetName}) async {
    try {
      print('=== GETTING COLUMN INFO ===');
      print('Sheet URL: $sheetUrl');
      print('Sheet name: $sheetName');
      
      // Parse service account credentials
      final serviceAccountJson = json.decode(serviceAccountKey);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = _extractSpreadsheetId(sheetUrl);
      
      // Determine range
      String range = '1:1'; // First row of all sheets
      if (sheetName != null && sheetName.isNotEmpty) {
        range = _createRangeWithSheet(sheetName, '1:1'); // First row of specific sheet
      }
      
      print('Using range: $range');
      
      // Get header row
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
      );
      
      final values = response.values ?? [];
      final result = {
        'range': response.range,
        'columns': <Map<String, dynamic>>[],
      };
      
      if (values.isNotEmpty) {
        final headerRow = values[0];
        print('Header row has ${headerRow.length} columns');
        
        for (int i = 0; i < headerRow.length; i++) {
          final columnInfo = {
            'index': i,
            'letter': _columnIndexToLetter(i),
            'value': headerRow[i].toString(),
          };
          
          print('Column ${i + 1} (${_columnIndexToLetter(i)}): ${headerRow[i]}');
          // Fix: Add null check before calling add
          (result['columns'] as List).add(columnInfo);
        }
      }
      
      client.close();
      return result;
    } catch (e) {
      print('Error getting column info: $e');
      rethrow;
    }
  }
  
  /// Search for today's date column
  static Future<Map<String, dynamic>?> findDateColumn(String sheetUrl, String serviceAccountKey, String dateString, {String? sheetName}) async {
    try {
      print('=== SEARCHING FOR DATE COLUMN ===');
      print('Looking for date: $dateString');
      print('Sheet URL: $sheetUrl');
      print('Sheet name: $sheetName');
      
      // Parse service account credentials
      final serviceAccountJson = json.decode(serviceAccountKey);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Authenticate
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = _extractSpreadsheetId(sheetUrl);
      
      // Determine range (check first 100 columns)
      String range = '1:1'; // First row
      if (sheetName != null && sheetName.isNotEmpty) {
        range = _createRangeWithSheet(sheetName, '1:1');
      }
      
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
          print('Checking column ${i + 1} (${_columnIndexToLetter(i)}): "$headerValue"');
          
          if (headerValue == dateString) {
            print('✅ Found date column! Column: ${_columnIndexToLetter(i)}');
            
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