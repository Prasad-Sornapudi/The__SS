# Department Sheet Feature Documentation

## Overview

The Department Sheet feature automatically updates Department Sheets in Google Sheets whenever class attendance is synced. This feature ensures that each department (CSE, ECE, EEE, CSM, CSD, etc.) has its own sub-sheet with attendance data organized by date and session.

## Feature Requirements

### Department Sheet Structure

1. **Departments Master Sheet** containing:
   - Department Sheet Name
   - Department Sheet Link
   - Department Sheet Credentials

2. **Each department** (CSE, ECE, EEE, CSM, CSD, etc.) has its own sub-sheet inside its Department Sheet.

3. **Each sub-sheet** contains:
   - Header row with dates (each column = one day)
   - Cells below each date column containing roll numbers of students present that day

### Morning & Afternoon Session Logic

- **Morning Session**: 9:30 AM – 12:30 PM
- **Afternoon Session**: 1:30 PM – 4:30 PM

When updating the Department Sheet:
1. If today's date column doesn't exist → create a new column with today's date
2. Based on current time:
   - If it's Morning, first insert "Morning" in a new cell, then append roll numbers below it
   - If it's Afternoon, leave one empty cell after morning entries, insert "Afternoon", and then append roll numbers below it

### Example Structure

```
03-11-25
Morning
Roll1
Roll2
Roll3

Afternoon
Roll4
Roll5
```

### Duplicate Handling

- Morning roll numbers should not repeat within the morning session
- Afternoon roll numbers should not repeat within the afternoon session
- However, morning roll numbers can appear again in the afternoon session (if students attend both)

### Multiple Syncs in Same Session

- Do not add "Morning" or "Afternoon" header again if it already exists
- Only append new, non-duplicate roll numbers for that session

## Implementation Details

### Services Updated

1. **DepartmentSheetService** - New service to handle department sheet updates
2. **SyncService** - Updated to call department sheet updates after attendance sync
3. **AttendanceProvider** - Updated to call department sheet updates after attendance sync
4. **DashboardWidgets** - Updated to call department sheet updates after attendance sync
5. **SettingsWidgets** - Updated to call department sheet updates after attendance sync
6. **AutoUploadService** - Updated to call department sheet updates after attendance sync
7. **EnhancedAutoSyncService** - Updated to call department sheet updates after attendance sync
8. **RobustSyncService** - Updated to call department sheet updates after attendance sync

### Data Flow

1. During class attendance sync (manual or automatic):
   - Identify each student's Department from the Master Sheet (Branch column)
   - Group roll numbers by department
   - Post roll numbers to the correct Department Sheet's sub-sheet under:
     - Today's date column
     - The correct session section (Morning or Afternoon)

2. Before inserting new roll numbers:
   - Read the existing column values under the session label
   - Add only roll numbers that are not already present within that session block

### Offline Handling

- If offline, store the department update (with date and session info) locally
- Automatically sync when internet is restored

### Sync Schedule

Department sheet sync follows the same schedule as attendance sync:
- Manual Sync
- Auto Sync (1 min, 10 min, 15 min, 30 min, etc.)

### Performance & Reliability

- Use batch updates for fewer Google Sheets API calls
- Ensure safe concurrent writes if multiple devices sync simultaneously
- Include retry logic and detailed error handling
- Securely use credentials from Departments Master Sheet for access

## Expected Outcome

After this feature implementation:

✅ Department Sheets automatically update on every attendance sync
✅ Each day's column will have clear Morning and Afternoon sections
✅ Roll numbers won't duplicate within a session
✅ Morning rolls can appear again in afternoon session (if needed)
✅ Offline sync and retry mechanisms ensure reliability
✅ Updates remain fast, consistent, and scalable

## Usage Examples

### Example 1: Basic Usage

```dart
final success = await DepartmentSheetService.updateDepartmentSheets(
  classModel: classModel,
  attendanceRecords: attendanceRecords,
);
```

### Example 2: Getting Current Session

```dart
final sessionType = DepartmentSheetService.getCurrentSession();
// Returns SessionType.morning or SessionType.afternoon
```

## Testing

The feature includes unit tests to verify:
- Session type detection
- DepartmentSheetInfo class creation
- Service import and instantiation

Integration tests verify that the service can be properly imported and used in the application.