import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import '../models/class_model.dart';
import '../services/sheet_data_service.dart';
import '../constants/app_constants.dart';
import '../services/hive_service.dart';
import '../services/control_sheet_service.dart';
import 'firebase_config_service.dart';

class UpdateCheckService {
  /// Check for updates in both master and attendance sheets
  static Future<UpdateCheckResult> checkForUpdates() async {
    try {
      print('🔍 Starting update check for master and attendance sheets...');
      
      // Get configuration from control sheet - read first batch to get master sheet URL
      final batchConfigs = await ControlSheetService.readBatchConfigs();
      if (batchConfigs.isEmpty) {
        print('No batches found in control sheet');
        return UpdateCheckResult.error(
          message: 'No batches found in control sheet',
        );
      }
      
      final firstBatch = batchConfigs.values.first;
      final masterSheetUrl = firstBatch.masterSheet?.link;
      final attendanceSheetUrl = firstBatch.attendanceSheet?.link;
      final serviceAccountKey = await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (masterSheetUrl == null || masterSheetUrl.isEmpty) {
        print('No master sheet URL configured in control sheet');
        return UpdateCheckResult.error(
          message: 'No master sheet URL configured in control sheet',
        );
      }
      
      if (serviceAccountKey.isEmpty) {
        print('Service account key not configured');
        return UpdateCheckResult.error(
          message: 'Service account key not configured',
        );
      }
      
      // Check master sheet updates
      final masterUpdateResult = await _checkSheetUpdates(
        sheetUrl: masterSheetUrl,
        serviceAccountKey: serviceAccountKey,
        sheetType: 'master',
      );
      
      if (!masterUpdateResult.isSuccess) {
        throw Exception('Failed to check master sheet updates: ${masterUpdateResult.message}');
      }
      
      // Check attendance sheet updates if configured
      SheetUpdateResult? attendanceUpdateResult;
      if (attendanceSheetUrl != null && attendanceSheetUrl.isNotEmpty) {
        attendanceUpdateResult = await _checkSheetUpdates(
          sheetUrl: attendanceSheetUrl,
          serviceAccountKey: serviceAccountKey,
          sheetType: 'attendance',
        );
        
        if (!attendanceUpdateResult.isSuccess) {
          print('⚠️ Warning: Failed to check attendance sheet updates: ${attendanceUpdateResult?.message}');
        }
      }
      
      return UpdateCheckResult.success(
        hasMasterUpdates: masterUpdateResult.hasUpdates ?? false,
        hasAttendanceUpdates: attendanceUpdateResult?.hasUpdates ?? false,
        masterSheetInfo: masterUpdateResult.sheetInfo,
        attendanceSheetInfo: attendanceUpdateResult?.sheetInfo,
        message: 'Update check completed successfully',
      );
    } catch (e) {
      print('❌ Error in checkForUpdates: $e');
      return UpdateCheckResult.error(
        message: 'Failed to check for updates: $e',
      );
    }
  }
  
  /// Check updates for a specific sheet
  static Future<SheetUpdateResult> _checkSheetUpdates({
    required String sheetUrl,
    required String serviceAccountKey,
    required String sheetType,
  }) async {
    try {
      print('🔍 Checking $sheetType sheet updates: $sheetUrl');
      
      // Parse service account credentials
      Map<String, dynamic> serviceAccountJson;
      try {
        serviceAccountJson = json.decode(serviceAccountKey);
      } catch (e) {
        throw Exception('Invalid service account JSON format: $e');
      }
      
      // Validate required fields
      final requiredFields = ['type', 'project_id', 'private_key_id', 'private_key', 'client_email', 'client_id', 'auth_uri', 'token_uri'];
      for (final field in requiredFields) {
        if (!serviceAccountJson.containsKey(field) || serviceAccountJson[field] == null) {
          throw Exception('Missing required field in service account key: $field');
        }
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
      final spreadsheetId = SheetDataService.extractSpreadsheetId(sheetUrl);
      
      // Get spreadsheet metadata to get sheet count and names
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      
      int totalWorksheets = 0;
      int totalRows = 0;
      final worksheetInfo = <String, int>{};
      
      if (spreadsheet.sheets != null) {
        totalWorksheets = spreadsheet.sheets!.length;
        
        // Count rows in each worksheet
        for (final sheet in spreadsheet.sheets!) {
          if (sheet.properties?.title != null) {
            final sheetName = sheet.properties!.title!;
            
            try {
              // Get basic info about the sheet without fetching all data
              final sheetId = sheet.properties!.sheetId;
              if (sheetId != null) {
                // Get row count using sheet properties
                final rowCount = sheet.properties!.gridProperties?.rowCount ?? 0;
                worksheetInfo[sheetName] = rowCount;
                totalRows += rowCount;
                print('📊 Worksheet "$sheetName" has approximately $rowCount rows');
              }
            } catch (e) {
              print('⚠️ Could not get row count for sheet "$sheetName": $e');
              worksheetInfo[sheetName] = 0;
            }
          }
        }
      }
      
      client.close();
      
      final sheetInfo = SheetInfo(
        worksheetCount: totalWorksheets,
        totalRows: totalRows,
        worksheetDetails: worksheetInfo,
      );
      
      print('✅ $sheetType sheet info: ${totalWorksheets} worksheets, ${totalRows} total rows');
      
      return SheetUpdateResult.success(
        hasUpdates: null, // We're not checking actual content changes, just structure
        sheetInfo: sheetInfo,
        message: 'Successfully checked $sheetType sheet updates',
      );
    } catch (e) {
      print('❌ Error checking $sheetType sheet updates: $e');
      return SheetUpdateResult.error(
        message: 'Failed to check $sheetType sheet updates: $e',
      );
    }
  }
  
  /// Compare local data with remote data to detect changes
  static Future<bool> hasMasterSheetChanged() async {
    try {
      print('🔍 Checking if master sheet has changed...');
      
      // Get configuration from control sheet - read first batch to get master sheet URL
      final batchConfigs = await ControlSheetService.readBatchConfigs();
      if (batchConfigs.isEmpty) {
        print('No batches found in control sheet');
        return false;
      }
      final firstBatch = batchConfigs.values.first;
      final masterSheetUrl = firstBatch.masterSheet?.link;
      final serviceAccountKey = await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (masterSheetUrl == null || masterSheetUrl.isEmpty) {
        print('No master sheet URL configured in control sheet');
        return false;
      }
      
      if (serviceAccountKey.isEmpty) {
        print('Service account key not configured');
        return false;
      }
      
      // Get local class count
      final localClasses = HiveService.getAllClasses();
      final localClassCount = localClasses.length;
      
      // Get remote sheet count
      final sheetResult = await SheetDataService.fetchAvailableSheets(
        googleSheetUrl: masterSheetUrl,
        serviceAccountKey: serviceAccountKey,
      );
      
      if (!sheetResult.isSuccess || sheetResult.sheetNames == null) {
        print('Failed to fetch available sheets');
        return false;
      }
      
      final remoteSheetCount = sheetResult.sheetNames!.length;
      
      print('📊 Local classes: $localClassCount, Remote sheets: $remoteSheetCount');
      
      // If counts don't match, there are updates
      if (localClassCount != remoteSheetCount) {
        print('🔄 Master sheet has changed: class count mismatch');
        return true;
      }
      
      // Check if any sheet names have changed
      final localSheetNames = localClasses.map((c) => c.className).toSet();
      final remoteSheetNames = sheetResult.sheetNames!.toSet();
      
      if (localSheetNames.difference(remoteSheetNames).isNotEmpty || 
          remoteSheetNames.difference(localSheetNames).isNotEmpty) {
        print('🔄 Master sheet has changed: sheet names mismatch');
        return true;
      }
      
      print('✅ No changes detected in master sheet structure');
      return false;
    } catch (e) {
      print('⚠️ Error checking master sheet changes: $e');
      return false;
    }
  }
}

/// Result class for update check operations
class UpdateCheckResult {
  final bool isSuccess;
  final bool hasMasterUpdates;
  final bool hasAttendanceUpdates;
  final SheetInfo? masterSheetInfo;
  final SheetInfo? attendanceSheetInfo;
  final String message;

  UpdateCheckResult._({
    required this.isSuccess,
    this.hasMasterUpdates = false,
    this.hasAttendanceUpdates = false,
    this.masterSheetInfo,
    this.attendanceSheetInfo,
    required this.message,
  });

  factory UpdateCheckResult.success({
    required bool hasMasterUpdates,
    required bool hasAttendanceUpdates,
    SheetInfo? masterSheetInfo,
    SheetInfo? attendanceSheetInfo,
    required String message,
  }) {
    return UpdateCheckResult._(
      isSuccess: true,
      hasMasterUpdates: hasMasterUpdates,
      hasAttendanceUpdates: hasAttendanceUpdates,
      masterSheetInfo: masterSheetInfo,
      attendanceSheetInfo: attendanceSheetInfo,
      message: message,
    );
  }

  factory UpdateCheckResult.error({
    required String message,
  }) {
    return UpdateCheckResult._(
      isSuccess: false,
      message: message,
    );
  }
}

/// Result class for individual sheet update checks
class SheetUpdateResult {
  final bool isSuccess;
  final bool? hasUpdates;
  final SheetInfo? sheetInfo;
  final String message;

  SheetUpdateResult._({
    required this.isSuccess,
    this.hasUpdates,
    this.sheetInfo,
    required this.message,
  });

  factory SheetUpdateResult.success({
    bool? hasUpdates,
    SheetInfo? sheetInfo,
    required String message,
  }) {
    return SheetUpdateResult._(
      isSuccess: true,
      hasUpdates: hasUpdates,
      sheetInfo: sheetInfo,
      message: message,
    );
  }

  factory SheetUpdateResult.error({
    required String message,
  }) {
    return SheetUpdateResult._(
      isSuccess: false,
      message: message,
    );
  }
}

/// Information about a sheet's structure
class SheetInfo {
  final int worksheetCount;
  final int totalRows;
  final Map<String, int> worksheetDetails;

  SheetInfo({
    required this.worksheetCount,
    required this.totalRows,
    required this.worksheetDetails,
  });
}