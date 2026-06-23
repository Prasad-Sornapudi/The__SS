import 'dart:convert';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import '../models/class_model.dart';
import '../models/batch_config.dart';
import '../models/class_sheet_data.dart';
import '../constants/app_constants.dart';
import 'firebase_config_service.dart';

/// Data models for control sheet data
class LoginCredentials {
  final String name;
  final String username;
  final String password;
  final String role;
  
  LoginCredentials({
    required this.name, 
    required this.username, 
    required this.password,
    required this.role,
  });
}

class ControlSheetService {
  // Cache for login credentials
  static List<LoginCredentials>? _cachedCredentials;
  static DateTime? _lastCredentialsLoadTime;
  
  /// Get cached login credentials if available and not expired
  static Future<List<LoginCredentials>> getCachedLoginCredentials() async {
    // If we have cached credentials and they were loaded less than 5 minutes ago, return them
    if (_cachedCredentials != null && 
        _lastCredentialsLoadTime != null && 
        DateTime.now().difference(_lastCredentialsLoadTime!).inMinutes < 5) {
      return _cachedCredentials!;
    }
    
    // Otherwise, return empty list
    return [];
  }
  
  /// Read Login_Credentials from Firebase RTDB (replaces secret files)
  static Future<List<LoginCredentials>> readLoginCredentials() async {
    try {
      print('=== READING LOGIN CREDENTIALS FROM FIREBASE RTDB ===');
      
      // Use Firebase Config Service instead of encrypted secrets
      final credentials = await FirebaseConfigService.readLoginCredentials();
      
      if (credentials.isEmpty) {
        print('⚠️ No login credentials found in Firebase');
        print('   This might be because:');
        print('   1. Firebase path sync/sheetSync/loginCredentials/credentials is empty');
        print('   2. Control sheet has not synced to Firebase yet');
        print('   3. Firebase security rules are blocking access');
      } else {
        print('✅ Successfully loaded ${credentials.length} login credentials from Firebase');
        
        // Cache the credentials
        _cachedCredentials = credentials;
        _lastCredentialsLoadTime = DateTime.now();
      }
      
      return credentials;
      
    } catch (e, stackTrace) {
      print('❌ Error in readLoginCredentials: $e');
      print('Stack trace: $stackTrace');
      
      // Return empty list to allow login in debug mode
      return [];
    }
  }
  
  /// Read batch configurations from Firebase (replaces old classes data)
  static Future<Map<String, BatchConfig>> readBatchConfigs() async {
    try {
      print('=== READING BATCH CONFIGURATIONS FROM FIREBASE RTDB ===');
      
      // Use Firebase Config Service to read batch configurations
      final batchConfigs = await FirebaseConfigService.readBatchConfigs();
      
      if (batchConfigs.isEmpty) {
        print('⚠️ No batch configurations found in Firebase');
      } else {
        print('✅ Successfully loaded ${batchConfigs.length} batch configurations from Firebase');
      }
      
      return batchConfigs;
      
    } catch (e, stackTrace) {
      print('❌ Error in readBatchConfigs: $e');
      print('Stack trace: $stackTrace');
      return {};
    }
  }
  
  /// Get master sheet URL for a specific batch from configuration
  static Future<String?> getMasterSheetUrlForBatch(String batchId) async {
    try {
      print('🔍 Looking for master sheet URL for batch: "$batchId"');
      final batchConfigs = await readBatchConfigs();
      print('📋 Found ${batchConfigs.length} batch configurations');
      
      final batchConfig = batchConfigs[batchId];
      if (batchConfig != null && batchConfig.masterSheet != null) {
        print('✅ Found master sheet URL for batch "$batchId": ${batchConfig.masterSheet!.link}');
        return batchConfig.masterSheet!.link;
      }
      
      print('❓ No master sheet URL found for batch: "$batchId"');
      return null;
    } catch (e, stackTrace) {
      print('💥 Error getting master sheet URL for batch $batchId: $e');
      print('📜 Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Get attendance sheet URL for a specific batch from configuration
  static Future<String?> getAttendanceSheetUrlForBatch(String batchId) async {
    try {
      print('🔍 Looking for attendance sheet URL for batch: "$batchId"');
      final batchConfigs = await readBatchConfigs();
      print('📋 Found ${batchConfigs.length} batch configurations');
      
      final batchConfig = batchConfigs[batchId];
      if (batchConfig != null && batchConfig.attendanceSheet != null) {
        print('✅ Found attendance sheet URL for batch "$batchId": ${batchConfig.attendanceSheet!.link}');
        return batchConfig.attendanceSheet!.link;
      }
      
      print('❓ No attendance sheet URL found for batch: "$batchId"');
      return null;
    } catch (e, stackTrace) {
      print('💥 Error getting attendance sheet URL for batch $batchId: $e');
      print('📜 Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Get mock interview sheet URL for a specific batch from configuration
  static Future<String?> getMockInterviewSheetUrlForBatch(String batchId) async {
    try {
      print('🔍 Looking for mock interview sheet URL for batch: "$batchId"');
      final batchConfigs = await readBatchConfigs();
      print('📋 Found ${batchConfigs.length} batch configurations');
      
      final batchConfig = batchConfigs[batchId];
      if (batchConfig != null && batchConfig.mockInterviewSheet != null) {
        print('✅ Found mock interview sheet URL for batch "$batchId": ${batchConfig.mockInterviewSheet!.link}');
        return batchConfig.mockInterviewSheet!.link;
      }
      
      print('❓ No mock interview sheet URL found for batch: "$batchId"');
      return null;
    } catch (e, stackTrace) {
      print('💥 Error getting mock interview sheet URL for batch $batchId: $e');
      print('📜 Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Get department sheet URL for a specific batch from configuration
  static Future<String?> getDepartmentSheetUrlForBatch(String batchId) async {
    try {
      print('🔍 Looking for department sheet URL for batch: "$batchId"');
      final batchConfigs = await readBatchConfigs();
      print('📋 Found ${batchConfigs.length} batch configurations');
      
      final batchConfig = batchConfigs[batchId];
      if (batchConfig != null && batchConfig.departmentSheet != null) {
        print('✅ Found department sheet URL for batch "$batchId": ${batchConfig.departmentSheet!.link}');
        return batchConfig.departmentSheet!.link;
      }
      
      print('❓ No department sheet URL found for batch: "$batchId"');
      return null;
    } catch (e, stackTrace) {
      print('💥 Error getting department sheet URL for batch $batchId: $e');
      print('📜 Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Get service account key for a specific batch from configuration
  static Future<String?> getBatchServiceAccountKey(String batchId) async {
    try {
      final batchConfigs = await readBatchConfigs();
      final batchConfig = batchConfigs[batchId];
      
      if (batchConfig != null) {
        // Try to get specific credentials for attendance sheet first
        if (batchConfig.attendanceSheet != null && 
            batchConfig.attendanceSheet!.credentials != null && 
            batchConfig.attendanceSheet!.credentials!.isNotEmpty) {
          return batchConfig.attendanceSheet!.credentials;
        }
        
        // Try to get specific credentials for master sheet
        if (batchConfig.masterSheet != null && 
            batchConfig.masterSheet!.credentials != null && 
            batchConfig.masterSheet!.credentials!.isNotEmpty) {
          return batchConfig.masterSheet!.credentials;
        }
      }
      
      // Otherwise, fall back to control sheet service account from Firebase
      return await FirebaseConfigService.readServiceAccountJson();
    } catch (e) {
      print('Error getting service account key for batch $batchId: $e');
      return null;
    }
  }
  
  /// Get mock interview service account key for a specific batch from configuration
  static Future<String?> getMockInterviewServiceAccountKey(String batchId) async {
    try {
      print('🔍 Looking for mock interview service account key for batch: "$batchId"');
      final batchConfigs = await readBatchConfigs();
      print('📋 Found ${batchConfigs.length} batch configurations for service account key lookup');
      
      final batchConfig = batchConfigs[batchId];
      if (batchConfig != null) {
        // Try to get specific credentials for mock interview sheet
        if (batchConfig.mockInterviewSheet != null && 
            batchConfig.mockInterviewSheet!.credentials != null && 
            batchConfig.mockInterviewSheet!.credentials!.isNotEmpty) {
          print('✅ Found specific mock interview service account key for batch: "$batchId"');
          return batchConfig.mockInterviewSheet!.credentials;
        }
      }
      
      // Otherwise, fall back to control sheet service account from Firebase
      final fallbackKey = await FirebaseConfigService.readServiceAccountJson();
      if (fallbackKey != null) {
        print('🔄 Using fallback service account key from Firebase for batch: "$batchId"');
        return fallbackKey;
      }
      
      print('❓ No service account key found for batch: "$batchId"');
      return null;
    } catch (e, stackTrace) {
      print('💥 Error getting mock interview service account key for batch $batchId: $e');
      print('📜 Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Get department sheet service account key for a specific batch from configuration
  static Future<String?> getDepartmentSheetServiceAccountKey(String batchId) async {
    try {
      print('🔍 Looking for department sheet service account key for batch: "$batchId"');
      final batchConfigs = await readBatchConfigs();
      print('📋 Found ${batchConfigs.length} batch configurations for service account key lookup');
      
      final batchConfig = batchConfigs[batchId];
      if (batchConfig != null) {
        // Try to get specific credentials for department sheet
        if (batchConfig.departmentSheet != null && 
            batchConfig.departmentSheet!.credentials != null && 
            batchConfig.departmentSheet!.credentials!.isNotEmpty) {
          print('✅ Found specific department sheet service account key for batch: "$batchId"');
          return batchConfig.departmentSheet!.credentials;
        }
      }
      
      // Otherwise, fall back to control sheet service account from Firebase
      final fallbackKey = await FirebaseConfigService.readServiceAccountJson();
      if (fallbackKey != null) {
        print('🔄 Using fallback service account key from Firebase for batch: "$batchId"');
        return fallbackKey;
      }
      
      print('❓ No service account key found for batch: "$batchId"');
      return null;
    } catch (e, stackTrace) {
      print('💥 Error getting department sheet service account key for batch $batchId: $e');
      print('📜 Stack trace: $stackTrace');
      return null;
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
  
  /// Get batch names from App_Control sheet tab names
  /// This method dynamically reads all tab names from the control sheet
  /// and filters out the Login_Credentials tab to get batch names
  static Future<List<String>> getBatchNamesFromControlSheet() async {
    try {
      print('=== GETTING BATCH NAMES FROM CONTROL SHEET TABS ===');
      
      // Get control sheet URL from Firebase
      final controlSheetUrl = await FirebaseConfigService.readControlSheetUrl();
      if (controlSheetUrl == null || controlSheetUrl.isEmpty) {
        print('❌ No control sheet URL found in Firebase');
        return [];
      }
      
      // Get service account key from Firebase
      final serviceAccountJson = await FirebaseConfigService.readServiceAccountJson();
      if (serviceAccountJson == null || serviceAccountJson.isEmpty) {
        print('❌ No service account key found in Firebase');
        return [];
      }
      
      // Parse service account credentials
      final serviceAccountMap = json.decode(serviceAccountJson);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountMap);
      
      // Authenticate with Google Sheets API
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(controlSheetUrl);
      
      // Get spreadsheet metadata to read tab names
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      final sheetNames = spreadsheet.sheets
          ?.map((sheet) => sheet.properties?.title ?? '')
          .where((name) => name.isNotEmpty && name != 'Login_Credentials')
          .toList() ?? [];
      
      print('✅ Found ${sheetNames.length} batch tabs in control sheet: $sheetNames');
      return sheetNames;
      
    } catch (e, stackTrace) {
      print('❌ Error getting batch names from control sheet: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
  
  /// Read batch configuration from a specific batch tab in App_Control
  /// This replaces the old Classes tab approach with individual batch tabs
  static Future<BatchConfig?> readBatchConfigFromTab(String batchId) async {
    try {
      print('=== READING BATCH CONFIG FROM TAB: $batchId ===');
      
      // Get control sheet URL from Firebase
      final controlSheetUrl = await FirebaseConfigService.readControlSheetUrl();
      if (controlSheetUrl == null || controlSheetUrl.isEmpty) {
        print('❌ No control sheet URL found in Firebase');
        return null;
      }
      
      // Get service account key from Firebase
      final serviceAccountJson = await FirebaseConfigService.readServiceAccountJson();
      if (serviceAccountJson == null || serviceAccountJson.isEmpty) {
        print('❌ No service account key found in Firebase');
        return null;
      }
      
      // Parse service account credentials
      final serviceAccountMap = json.decode(serviceAccountJson);
      final credentials = ServiceAccountCredentials.fromJson(serviceAccountMap);
      
      // Authenticate with Google Sheets API
      final client = await clientViaServiceAccount(
        credentials,
        AppConstants.requiredScopes,
      );
      
      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheetId = extractSpreadsheetId(controlSheetUrl);
      
      // Read the specific batch tab (batchId is the tab name)
      final range = '$batchId!A:B'; // Read first two columns
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
      );
      
      final values = response.values;
      if (values == null || values.isEmpty) {
        print('⚠️ No data found in batch tab: $batchId');
        return null;
      }
      
      // Parse the configuration data from the tab
      SheetConfig? masterSheet;
      SheetConfig? attendanceSheet;
      SheetConfig? mockInterviewSheet;
      SheetConfig? departmentSheet;
      
      // Process each row in the tab
      for (final row in values) {
        if (row.length >= 2) {
          final key = row[0]?.toString().trim() ?? '';
          final value = row[1]?.toString().trim() ?? '';
          
          if (key.isNotEmpty && value.isNotEmpty) {
            switch (key) {
              case 'Master_Sheet_Link':
                masterSheet = SheetConfig(
                  link: value,
                  credentials: null, // Will be set separately or use fallback
                );
                break;
              case 'Master_Sheet_Credentials':
                if (masterSheet != null) {
                  masterSheet = SheetConfig(
                    link: masterSheet.link,
                    credentials: value,
                  );
                }
                break;
              case 'Attendance_Sheet_Link':
                attendanceSheet = SheetConfig(
                  link: value,
                  credentials: null,
                );
                break;
              case 'Attendance_Sheet_Credentials':
                if (attendanceSheet != null) {
                  attendanceSheet = SheetConfig(
                    link: attendanceSheet.link,
                    credentials: value,
                  );
                }
                break;
              case 'Mock_Interview_Sheet_Link':
                mockInterviewSheet = SheetConfig(
                  link: value,
                  credentials: null,
                );
                break;
              case 'Mock_Interview_Sheet_Credentials':
                if (mockInterviewSheet != null) {
                  mockInterviewSheet = SheetConfig(
                    link: mockInterviewSheet.link,
                    credentials: value,
                  );
                }
                break;
              case 'Department_Sheet_Link':
                departmentSheet = SheetConfig(
                  link: value,
                  credentials: null,
                );
                break;
              case 'Department_Sheet_Credentials':
                if (departmentSheet != null) {
                  departmentSheet = SheetConfig(
                    link: departmentSheet.link,
                    credentials: value,
                  );
                }
                break;
            }
          }
        }
      }
      
      final batchConfig = BatchConfig(
        batchId: batchId,
        masterSheet: masterSheet,
        attendanceSheet: attendanceSheet,
        mockInterviewSheet: mockInterviewSheet,
        departmentSheet: departmentSheet,
      );
      
      print('✅ Successfully read batch config from tab: $batchId');
      return batchConfig;
      
    } catch (e, stackTrace) {
      print('❌ Error reading batch config from tab $batchId: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}