# Session Sync System

## Overview

The Session Sync System is a comprehensive attendance management system that organizes attendance tracking into defined time sessions (Morning and Afternoon) and ensures proper synchronization, preservation, and clearance of attendance data according to strict rules.

**NOTE: As of the latest update, session timing restrictions have been removed. Users can now select either Morning or Afternoon session manually without time restrictions.**

## Session Rules

### Time Definitions

- **Morning Session**: Available for selection at any time
- **Afternoon Session**: Available for selection at any time

## Core Components

### 1. Local Data Storage

All attendance data is immediately stored locally on the device upon scanning:

- **Immediate Persistence**: Data saved as soon as it's scanned
- **Complete Records**: Includes student info, class, session, and timestamp
- **Preservation**: Data remains until verified sync completion
- **No Premature Deletion**: Nothing deleted until sync verification

### 2. Multi-Device Synchronization

The system handles concurrent access from multiple devices:

- **Union-Based Merging**: Combines data from all devices without duplicates
- **Present Integrity**: Once marked "Present", status is never downgraded
- **Conflict Resolution**: Intelligent handling of concurrent updates
- **Data Consistency**: Ensures all devices see the same final data

### 3. Background Sync (Two-Cycle Rule)

When the app goes to background with auto-sync enabled:

- **Exactly Two Cycles**: Performs only two background sync operations
- **Early Termination**: Stops if no data changes detected
- **Reset on Foreground**: Two-cycle rule resets when app returns to foreground
- **Cross-Platform**: Works on Android, iOS, and Web

### 4. Sync Priority and Cutoff Management

At each session cutoff time:

- **Sync Priority**: Syncing always takes precedence over clearing
- **Conditional Clearance**: Data cleared only after successful sync
- **Pending Block**: New scanning blocked until pending sync completes
- **Cross-Device Detection**: Automatically detects when other devices have synced

### 5. Pending Sync Enforcement

When unsynced data exists:

- **Non-Cancelable Dialog**: User cannot dismiss until sync completes
- **Mandatory Sync**: New scanning disabled until data is synced
- **Retry Options**: Immediate retry and pending data viewing
- **Clear Messaging**: Informative error messages

### 6. Web App Support

For web versions:

- **Direct Updates**: Immediate sheet updates when online
- **Offline Storage**: Local caching when disconnected
- **Auto-Retry**: Automatic sync when connectivity restored
- **Background Rule**: Two-cycle rule applies when supported

### 7. Verification and Clearance

After sync operations:

- **Read-Back Verification**: Confirm data correctly stored in sheets
- **Conditional Clearance**: Local data cleared only after verification
- **Session-Based Clearance**: Clear data for entire session period
- **Success Confirmation**: User feedback on successful operations

### 8. Logging and Monitoring

Comprehensive tracking of all sync operations:

- **Operation Logging**: Detailed logs of all sync attempts
- **Error Tracking**: Timestamped error messages with context
- **Performance Metrics**: Success rates and timing statistics
- **Debug Interface**: In-app screen for log viewing

## Implementation Details

### Session Selection

Users can now manually select between Morning and Afternoon sessions without time restrictions:

```dart
// Session selection is now manual
OutlinedButton(
  onPressed: () {
    setState(() {
      _selectedSessionType = SessionType.morning;
    });
  },
  child: Text('Morning'),
)

OutlinedButton(
  onPressed: () {
    setState(() {
      _selectedSessionType = SessionType.afternoon;
    });
  },
  child: Text('Afternoon'),
)
```

### Background Sync Logic

```dart
void _performBackgroundSync() async {
  // Limit to two cycles
  if (_backgroundSyncCount >= maxBackgroundSyncCycles) {
    _stopBackgroundSync();
    return;
  }
  
  // Check for unsynced data
  if (!await _hasUnsyncedData()) {
    _stopBackgroundSync();
    return;
  }
  
  // Perform sync
  await performSessionSync();
  _backgroundSyncCount++;
}
```

### Pending Sync Dialog

The non-cancelable dialog enforces sync completion:

```dart
return WillPopScope(
  onWillPop: () async => false, // Prevent dismissal
  child: AlertDialog(
    title: Text('Pending Sync Required'),
    content: Text('Please sync before continuing'),
    actions: [
      ElevatedButton(
        onPressed: onRetrySync,
        child: Text('Retry Sync Now'),
      ),
      OutlinedButton(
        onPressed: onViewPending,
        child: Text('View Pending'),
      ),
    ],
  ),
);
```