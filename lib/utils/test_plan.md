# Comprehensive Test Plan for Attendance App Fixes

## Overview
This test plan verifies that the critical issues with attendance data persistence and row indexing have been resolved.

## Test Cases

### 1. Class Data Persistence Test
**Objective:** Verify that attendance data stays when switching between classes

**Steps:**
1. Open the app and select Class A
2. Mark 3 students as present in Class A
3. Switch to Class B
4. Mark 2 students as present in Class B
5. Switch back to Class A
6. Verify that the 3 students originally marked present in Class A are still shown as present
7. Switch to Class B
8. Verify that the 2 students originally marked present in Class B are still shown as present

**Expected Result:** 
- Attendance data for each class should persist when switching between classes
- No data should be lost or mixed between classes

### 2. Google Sheets Row Indexing Test
**Objective:** Verify that attendance status is applied to the correct roll numbers

**Steps:**
1. Select a class and mark several students as present
2. Sync the attendance data to Google Sheets
3. Verify in Google Sheets that the correct roll numbers are marked as present
4. Check that no incorrect roll numbers are marked as present
5. Specifically verify the issue reported:
   - If row 37's roll number is present, ensure row 37 shows as present (not row 38)

**Expected Result:**
- Attendance status should be applied to the exact roll numbers that were marked present
- No off-by-one errors should occur
- Row indexing should be accurate between the app and Google Sheets

### 3. Comprehensive Attendance Sync Test
**Objective:** Verify that the sync process correctly handles existing data

**Steps:**
1. Mark some students as present in the app
2. Manually mark different students as present in Google Sheets
3. Perform a sync operation
4. Verify that:
   - Students marked as present in the app remain present
   - Students marked as present in Google Sheets remain present
   - No conflicts occur where app data overrides existing sheet data unnecessarily

**Expected Result:**
- Sync should preserve existing data from both sources
- Present integrity rule should be maintained (present students stay present)
- No data loss should occur during sync

### 4. Session Date Handling Test
**Objective:** Verify that attendance data is correctly associated with session dates

**Steps:**
1. Set session date to today
2. Mark students as present
3. Change session date to yesterday
4. Mark different students as present
5. Verify that each session date maintains its own attendance records
6. Switch between session dates and verify data persistence

**Expected Result:**
- Each session date should maintain independent attendance records
- No data mixing between different session dates

### 5. Class Switching Performance Test
**Objective:** Verify that class switching is responsive and doesn't cause delays

**Steps:**
1. Create multiple classes with 50+ students each
2. Mark attendance for students in each class
3. Rapidly switch between classes multiple times
4. Measure response time for class switching
5. Check for any UI freezes or delays

**Expected Result:**
- Class switching should be instantaneous or nearly so
- No UI freezes or significant delays should occur
- All attendance data should load correctly for each class

## Debugging Tools

### 1. Attendance Debug Utilities
The `AttendanceDebugUtils` class provides helper methods for:
- Debugging class switching and data persistence
- Debugging attendance record creation and indexing
- Debugging Google Sheets row mapping
- Debugging attendance data synchronization

### 2. Enhanced Logging
All critical operations now include detailed logging:
- Class switching operations
- Attendance record creation and modification
- Google Sheets API interactions
- Data synchronization processes

## Verification Checklist

### Before Testing
- [ ] All code changes have been implemented
- [ ] No syntax errors in any files
- [ ] Debug utilities are available
- [ ] Test plan is understood by all team members

### During Testing
- [ ] Execute all test cases in order
- [ ] Document any issues or unexpected behavior
- [ ] Use debug utilities when troubleshooting
- [ ] Verify logging output for accuracy

### After Testing
- [ ] All test cases pass successfully
- [ ] No data loss or corruption observed
- [ ] Performance is acceptable
- [ ] User experience is smooth and intuitive

## Rollback Plan
If critical issues are discovered during testing:
1. Revert to the previous stable version
2. Document the specific issues found
3. Address the root causes
4. Retest with the fixes

## Success Criteria
- [ ] Class data persistence works correctly
- [ ] Google Sheets row indexing is accurate
- [ ] Attendance synchronization preserves existing data
- [ ] No performance degradation
- [ ] All existing functionality remains intact