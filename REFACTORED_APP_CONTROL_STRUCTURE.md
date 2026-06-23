# Refactored App_Control Google Sheet Structure

This document summarizes the changes made to refactor the App_Control Google Sheet structure to support a batch-tab-driven configuration approach.

## Overview

The refactored structure moves away from the old "Classes" tab approach to a more scalable model where each batch has its own tab in the App_Control sheet. This makes the system more flexible and easier to maintain.

## New Structure

### 1. App_Control Sheet – New Structure

**Tabs:**
- `Login_Credentials` (structure remains the same)
- Individual batch tabs (one per batch):
  - `Skill_Sync01`
  - `Skill_Sync02`
  - etc.

**Key Changes:**
- Removed the old "Classes" tab
- Each batch now has its own tab named after the batch identifier
- The tab name itself serves as the Batch Identifier
- No "Batch Name" column anywhere in the structure

### 2. Batch Tab Column Structure (Configuration Only)

Each Batch Tab contains exactly the following configuration columns:

| Column Name | Description |
|-------------|-------------|
| `Master_Sheet_Link` | URL to the Master Google Sheet |
| `Master_Sheet_Credentials` | Service account credentials for Master Sheet |
| `Attendance_Sheet_Link` | URL to the Attendance Google Sheet |
| `Attendance_Sheet_Credentials` | Service account credentials for Attendance Sheet |
| `Mock_Interview_Sheet_Link` | URL to the Mock Interview Google Sheet |
| `Mock_Interview_Sheet_Credentials` | Service account credentials for Mock Interview Sheet |
| `Department_Sheet_Link` | URL to the Department Google Sheet |
| `Department_Sheet_Credentials` | Service account credentials for Department Sheet |

**Rules:**
- If any link or credential cell is empty, that feature is not available for the batch
- No student data exists in App_Control
- This spreadsheet acts as a read-only configuration source

### 3. Master / Attendance / Mock Sheet References

**Master sheet fixed first 7 columns:**
1. Student Name
2. PIN Number (globally unique)
3. Branch
4. Mail ID
5. Mobile Number
6. COMBO
7. Sec-Code (globally unique and immutable)

**Combos:**
- Combos are tabs inside Master, Attendance, and Mock Interview sheets
- The same combo tab names must exist across all three sheets
- Attendance and Mock sheets are logically children of the Master sheet, aligned using PIN and Sec-Code

## Code Changes

### 1. New Models

Created `ClassSheetData` model to represent the old Classes tab structure for backward compatibility.

### 2. Updated Services

#### ControlSheetService
- Added `getBatchNamesFromControlSheet()` to dynamically load batch names from App_Control tab names
- Added `readBatchConfigFromTab(String batchId)` to read batch configuration from a specific batch tab
- Updated existing methods to work with the new batch-tab-driven configuration

#### FirebaseConfigService
- Updated imports to include the new `ClassSheetData` model
- Maintained existing batch configuration reading functionality

#### AutoClassService
- Updated `fetchClassesFromFirebase()` to use the new batch-tab-driven configuration
- Replaced old Classes tab approach with individual batch tabs

#### AttendanceSheetService
- Updated `_getAttendancePercentage()` to use batch-based approach instead of class-based approach

#### UpdateCheckService
- Updated `checkForUpdates()` and `hasMasterSheetChanged()` to work with batch configurations

### 3. Updated Tests

- Updated integration tests to verify batch configuration reading instead of classes data reading

## Benefits

1. **Scalability**: Adding a new batch is as simple as adding a new tab
2. **Flexibility**: Each batch can have its own configuration
3. **Maintainability**: Configuration is centralized and easy to manage
4. **Reliability**: App and Firebase automatically adapt to structure changes
5. **Compatibility**: Existing attendance and mock systems continue functioning with no behavioral changes

## Migration Path

1. Create individual tabs for each batch in the App_Control sheet
2. Move configuration data from the old "Classes" tab to individual batch tabs
3. Remove the old "Classes" tab
4. Update the Firebase configuration to match the new structure
5. Test the refactored implementation

## Firebase Structure Update

The Firebase structure was updated to align with the new batch-tab-driven configuration:

```
/batches
  /{batchId}   // Example: Skill_Sync01 (from App_Control tab name)
    config:
      masterSheet: { link, credentials }
      attendanceSheet: { link, credentials }
      mockSheet: { link, credentials }
      departmentSheet: { link, credentials }
```

**Rules:**
- Batch ID always equals the App_Control tab name
- Firebase configuration should be refreshed whenever App_Control changes
- Attendance, mock interview, and department data schemas remain unchanged

## Conclusion

This refactored structure makes the App_Control Google Sheet more scalable and maintainable. The system now dynamically adapts to changes in the sheet structure, making it easier to add new batches and configure features on a per-batch basis.