# Testing Checklist for Attendance App Fixes

## Pre-Testing Setup
- [ ] Ensure moto g35 5G is connected and detected by Flutter
- [ ] App builds and deploys successfully to the device
- [ ] Google Sheets integration is properly configured
- [ ] At least 2 classes with students are available

## Test Case 1: Class Data Persistence
**Objective:** Verify attendance data stays when switching between classes

### Steps:
1. [ ] Open the app on moto g35 5G
2. [ ] Select Class A from the dashboard
3. [ ] Mark 3-5 students as present in Class A
4. [ ] Note which students are marked present
5. [ ] Switch to Class B from the class selection dropdown
6. [ ] Mark 2-3 students as present in Class B
7. [ ] Note which students are marked present
8. [ ] Switch back to Class A
9. [ ] Verify the same students from step 4 are still marked present
10. [ ] Switch to Class B again
11. [ ] Verify the same students from step 7 are still marked present

### Expected Results:
- [ ] Class A attendance data persists when switching to Class B
- [ ] Class B attendance data persists when switching back to Class A
- [ ] No data mixing between classes
- [ ] All UI elements update correctly when switching classes

## Test Case 2: Google Sheets Row Indexing
**Objective:** Verify attendance status is applied to correct roll numbers

### Steps:
1. [ ] Select a class with known student roll numbers
2. [ ] Mark specific students (e.g., roll numbers 23551A0245, 23551A04F2) as present
3. [ ] Sync the attendance data to Google Sheets
4. [ ] Open the Google Sheet in a browser
5. [ ] Verify that the exact roll numbers marked present in the app are marked as "Present" in the sheet
6. [ ] Pay special attention to the reported issue:
   - [ ] If row 37's roll number is present, verify row 37 shows as present (not row 38)
   - [ ] Check that there's no off-by-one error in row indexing

### Expected Results:
- [ ] Attendance status is applied to the exact roll numbers that were marked present
- [ ] No incorrect roll numbers are marked as present
- [ ] Row indexing is accurate between the app and Google Sheets
- [ ] No off-by-one errors in row numbering

## Test Case 3: Data Synchronization Integrity
**Objective:** Verify that sync process correctly handles existing data

### Steps:
1. [ ] Mark some students as present in the app
2. [ ] Manually mark different students as present in Google Sheets
3. [ ] Perform a sync operation from the app
4. [ ] Check that:
   - [ ] Students marked as present in the app remain present
   - [ ] Students marked as present in Google Sheets remain present
   - [ ] No conflicts occur where app data overrides existing sheet data unnecessarily

### Expected Results:
- [ ] Sync preserves existing data from both sources
- [ ] Present integrity rule is maintained (present students stay present)
- [ ] No data loss occurs during sync

## Test Case 4: Session Date Handling
**Objective:** Verify that attendance data is correctly associated with session dates

### Steps:
1. [ ] Set session date to today
2. [ ] Mark students as present
3. [ ] Change session date to yesterday
4. [ ] Mark different students as present
5. [ ] Verify that each session date maintains its own attendance records
6. [ ] Switch between session dates and verify data persistence

### Expected Results:
- [ ] Each session date maintains independent attendance records
- [ ] No data mixing between different session dates
- [ ] All attendance data persists when switching between dates

## Post-Testing Verification
- [ ] All test cases pass successfully
- [ ] No crashes or errors observed
- [ ] Performance is acceptable
- [ ] User experience is smooth and intuitive

## Troubleshooting Notes
If any issues are observed:
1. Check the debug logs for error messages
2. Verify that the attendance provider is correctly tracking active classes
3. Confirm that row indexing in Google Sheets service is accurate
4. Ensure that class switching logic is properly implemented in all UI components

## Success Criteria
- [ ] Class data persistence works correctly
- [ ] Google Sheets row indexing is accurate
- [ ] Attendance synchronization preserves existing data
- [ ] No performance degradation
- [ ] All existing functionality remains intact