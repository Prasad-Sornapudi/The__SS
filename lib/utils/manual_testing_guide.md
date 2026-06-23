# Manual Testing Guide for Class Data Persistence Fix

## Overview
This guide provides instructions for manually testing the class data persistence fix to ensure that attendance data is properly retained when switching between classes.

## Prerequisites
1. The app must be running on a device or emulator
2. At least two classes must be configured in the app
3. Each class should have students enrolled

## Test Procedure

### Test 1: Basic Class Data Persistence

#### Steps:
1. Open the app and navigate to the Scanner screen
2. Select Class A from the class selection dropdown/header
3. Mark 3-5 students as present in Class A (you can use manual entry if needed)
4. Note which students you marked as present
5. Switch to Class B from the class selection dropdown/header
6. Mark 2-3 students as present in Class B
7. Note which students you marked as present
8. Switch back to Class A
9. Verify that the same students from step 4 are still marked present
10. Switch to Class B
11. Verify that the same students from step 7 are still marked present

#### Expected Results:
- Attendance data for each class should persist when switching between classes
- No data should be lost or mixed between classes
- The UI should correctly update to show the appropriate attendance data for the selected class

### Test 2: Dashboard Screen Class Switching

#### Steps:
1. Navigate to the Dashboard screen
2. Select Class A from the class selection dropdown
3. Note the attendance summary numbers (Present, Absent, Total)
4. Switch to Class B from the class selection dropdown
5. Note the attendance summary numbers
6. Switch back to Class A and verify the attendance summary numbers match step 3
7. Switch to Class B and verify the attendance summary numbers match step 5

#### Expected Results:
- Class switching in the dashboard screen should preserve attendance data for each class
- Attendance summary numbers should update correctly for each class

### Test 3: Multiple Rapid Class Switching

#### Steps:
1. Open the app and select Class A
2. Mark 2 students as present in Class A
3. Switch to Class B and mark 3 students as present
4. Switch to Class C (if available) and mark 1 student as present
5. Rapidly switch between the classes several times:
   - Class A → Class B → Class C → Class A → Class B → Class C
6. After each switch, verify that the correct attendance data is displayed

#### Expected Results:
- Attendance data for all classes should persist through multiple rapid switches
- No data loss should occur
- UI should update correctly and quickly

### Test 4: Data Persistence Across App Sessions

#### Steps:
1. Open the app and select Class A
2. Mark 3 students as present in Class A
3. Switch to Class B and mark 2 students as present
4. Close the app completely (force stop if necessary)
5. Reopen the app
6. Select Class A and verify the 3 students are still present
7. Select Class B and verify the 2 students are still present

#### Expected Results:
- Attendance data should persist across app sessions
- Data should be correctly loaded from storage when the app restarts

## Debugging Information

If any issues are observed during testing:

1. **Check the debug logs**: Look for messages related to:
   - "AttendanceProvider: Active class ID changed to:"
   - "Loaded X attendance records for class"
   - "Attendance data already loaded for class"

2. **Verify the attendance provider**: Ensure that:
   - The `_classAttendanceRecords` map is correctly storing data for each class
   - The `ensureAttendanceLoadedForClass` method is being called before class switches
   - The `setActiveClassId` method is being called correctly

3. **Check class switching points**: Ensure that all class switching points in the app are using the new approach:
   - Scanner screen class selection dropdown
   - Scanner screen ClassSelectionHeader widget
   - Dashboard screen class selection dropdown
   - Dashboard widgets class selection dropdown

## Success Criteria

- [ ] Class data persistence works correctly in all test cases
- [ ] No data loss occurs when switching between classes
- [ ] No data mixing occurs between different classes
- [ ] UI updates correctly to show the appropriate attendance data for the selected class
- [ ] Performance is not degraded when switching classes
- [ ] All existing functionality remains intact

## Troubleshooting

### Issue: Attendance data is lost when switching classes
**Solution**: 
1. Verify that `ensureAttendanceLoadedForClass` is being called before each class switch
2. Check that the `_classAttendanceRecords` map is correctly storing data for each class
3. Ensure that `loadAttendanceForSession` is being called after setting the active class

### Issue: UI doesn't update correctly when switching classes
**Solution**:
1. Verify that `notifyListeners()` is being called in the AttendanceProvider
2. Check that the Consumer widgets are correctly listening to changes in the providers
3. Ensure that `setActiveClassId` is being called to update the active class

### Issue: Performance is degraded when switching classes
**Solution**:
1. Verify that `ensureAttendanceLoadedForClass` is not unnecessarily reloading data
2. Check that the HiveService calls are efficient
3. Ensure that there are no unnecessary rebuilds in the UI

## Conclusion

This manual testing guide should help verify that the class data persistence fix is working correctly. If all tests pass, the issue with attendance data not staying when changing classes should be resolved.