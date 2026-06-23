# Robust Synchronization System Usage Example

## Overview

This document provides a practical example of how to use the Robust Synchronization System in the Skill Sync application.

## Starting the Robust Sync Service

To start the robust synchronization service, you can use the following code:

```dart
import 'package:skill_sync/services/robust_sync_service.dart';

// Get the singleton instance
final syncService = RobustSyncService();

// Start the robust sync service
syncService.startRobustSyncService();

// Set a custom sync interval (optional)
syncService.setSyncInterval(60); // Sync every 60 seconds

// Force a sync on the next cycle (optional)
syncService.forceNextSync();
```

## Manual Sync Trigger

To manually trigger a synchronization:

```dart
// Trigger a manual sync
await syncService.triggerManualSync();
```

## Integration with Existing Services

The robust synchronization system has been integrated into the existing services:

### Auto Upload Service

The [AutoUploadService](file:///c%3A/Prasad%20007/Skill_Sync%20App/App%20with%20logins/Agent%20QR/lib/services/auto_upload_service.dart#L9-L149) now uses the robust synchronization approach:

```dart
// In auto_upload_service.dart
final result = await GoogleSheetsService.uploadAttendance(
  classModel: _currentClass!,
  attendanceRecords: unsyncedRecords,
  onProgress: (progress) {
    _uploadProgress = progress;
    notifyListeners();
  },
);
```

### Sync Service

The [SyncService](file:///c%3A/Prasad%20007/Skill_Sync%20App/App%20with%20logins/Agent%20QR/lib/services/sync_service.dart#L7-L162) has been updated to use robust synchronization:

```dart
// In sync_service.dart
final result = await GoogleSheetsService.uploadAttendance(
  classModel: classModel,
  attendanceRecords: todayRecords,
  onProgress: (progress) {
    // Progress callback
    print('Sync progress: ${(progress * 100).toInt()}%');
  },
);
```

## Key Benefits in Practice

### 1. Self-Healing Date Columns

The system automatically creates missing date columns:

```dart
// If today's date column is missing, it will be automatically created
final columnIndex = await _findOrCreateDateColumnWithValidation(
  sheetsApi: sheetsApi,
  spreadsheetId: spreadsheetId,
  date: DateTime.now(),
  sheetName: classModel.sheetName,
);
```

### 2. Union-Based Merging

Attendance data is merged intelligently:

```dart
// Existing attendance data is retrieved
final existingAttendance = await _getExistingAttendanceForDate(/* parameters */);

// All students are processed with union-based merging
final allStudentsData = await _prepareAllStudentsAttendanceData(
  classModel: classModel,
  attendanceRecords: records,
  existingAttendance: existingAttendance,
);
```

### 3. Present Integrity Protection

The system ensures Present entries are never overwritten:

```dart
// Critical Rule: Present Integrity
if (existingStatus == 'present') {
  // Student already marked as present, keep as present (don't override)
  attendanceStatus = 'Present';
} else if (isPresentInRecords) {
  // Student is present in local records
  attendanceStatus = 'Present';
} else {
  // Student is absent
  attendanceStatus = 'Absent';
}
```

## Monitoring Sync Status

You can monitor the sync status using the provided getters:

```dart
// Check if sync is in progress
bool isSyncing = syncService.isSyncing;

// Get the last sync error
String? lastError = syncService.lastSyncError;

// Get the last sync time
DateTime? lastSync = syncService.lastSyncTime;

// Get a human-readable status message
String status = syncService.statusMessage;
```

## Disposing the Service

When you're done with the service, make sure to dispose of it:

```dart
// Stop the sync service and clean up resources
syncService.stopRobustSyncService();
syncService.dispose();
```

## Testing the System

To test the robust synchronization system, you can run:

```bash
flutter test test/robust_sync_test.dart
```

## Conclusion

The Robust Synchronization System provides a reliable, self-healing approach to attendance data synchronization that works seamlessly across multiple devices and handles various edge cases gracefully. It ensures data consistency while protecting important attendance records from accidental overwrites.