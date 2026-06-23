# Web App Integration for Google Sheets Reporting

## Overview
This document explains how the Flutter attendance app integrates with the provided Google Apps Script web app for Google Sheets reporting.

## Web App Details
- **URL**: https://script.google.com/macros/s/AKfycbxRTSfDZrJt9VV4fY33S0lHneW1Q97YbcbBXhaNCxTygtypAmvCl3n0YKvBdzabR_K0_w/exec
- **Functionality**: Processes jobs from Firebase Realtime Database and writes data to Google Sheets

## Integration Approach

### 1. Job Creation in Firebase
Our HybridSyncService creates jobs in the Firebase Realtime Database at the path `/outgoingToSheets` when session data needs to be reported to Google Sheets.

**Job Structure:**
```json
{
  "classId": "class_identifier",
  "jobType": "attendance",
  "timestamp": 1234567890,
  "data": {
    "date": "2023-10-15",
    "students": [
      {
        "pinNumber": "12345",
        "name": "Student Name",
        "status": "present",
        "scanTime": 1234567890123
      }
    ]
  }
}
```

### 2. Web App Processing
The Google Apps Script web app:
1. Monitors the `/outgoingToSheets` path in Firebase
2. Processes each job based on its type
3. For attendance jobs, updates the corresponding Google Sheet
4. Deletes processed jobs from Firebase

### 3. Triggering Job Processing
Our implementation can trigger the web app to process jobs immediately after creating them by sending a POST request with the action `processJobs`.

## Implementation Details

### HybridSyncService Integration
The HybridSyncService in our Flutter app:

1. **Creates Jobs**: When a session ends, attendance data is packaged into a job and written to `/outgoingToSheets` in Firebase
2. **Triggers Processing**: Optionally sends a POST request to the web app URL with `{"action": "processJobs"}` to trigger immediate processing

### FirebaseService Extension
We extended the FirebaseService with a `writeToPath` method that allows writing data to any path in Firebase Realtime Database:

```dart
Future<void> writeToPath(String path, dynamic data) async {
  if (!_isInitialized || _database == null) {
    print('⚠️ FirebaseService: Firebase not initialized, skipping write to path: $path');
    return;
  }

  try {
    print('FirebaseService: Writing data to path: $path');
    final ref = _database!.ref(path);
    await ref.set(data);
    print('✅ FirebaseService: Data written successfully to path: $path');
  } catch (e) {
    print('❌ FirebaseService: Failed to write data to path $path: $e');
    rethrow;
  }
}
```

## Benefits of This Approach

1. **Decoupled Architecture**: The Flutter app and Google Sheets processing are decoupled
2. **Reliability**: Jobs are stored in Firebase until processed, ensuring no data loss
3. **Scalability**: Multiple jobs can be queued and processed asynchronously
4. **Flexibility**: Supports different job types beyond attendance reporting
5. **Error Handling**: Failed jobs can be retried or investigated

## Web App Endpoints

The web app supports several actions via POST requests:

- `processJobs`: Process all pending jobs in Firebase
- `syncCredentials`: Sync login credentials
- `syncClasses`: Sync class data
- `testFirebaseConnection`: Test Firebase connection

## Data Flow

1. **Session End**: At 12:30 PM or 4:30 PM, HybridSyncService triggers session end sync
2. **Firestore Archive**: Attendance data is archived to Firestore
3. **Job Creation**: Attendance data is packaged into a job and written to `/outgoingToSheets` in Firebase
4. **Processing Trigger**: A POST request is sent to the web app to process jobs
5. **Google Sheets Update**: The web app processes the job and updates the appropriate Google Sheet
6. **Job Cleanup**: Processed jobs are deleted from Firebase

## Error Handling

- If job creation fails, the data remains in Firestore for manual recovery
- If web app processing fails, jobs remain in Firebase for retry
- All operations are logged for debugging and monitoring

## Future Enhancements

1. **Retry Mechanism**: Implement automatic retry for failed jobs
2. **Status Tracking**: Add more detailed status tracking for jobs
3. **Batch Processing**: Optimize for processing multiple jobs in a single request
4. **Error Notifications**: Send notifications for persistent failures