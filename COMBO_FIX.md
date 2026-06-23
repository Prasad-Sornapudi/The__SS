# Combo Fetching Fix

## Issue
The app was showing "no classes (COMBOS) available" even though the class data existed in Firebase. 

## Root Cause
The Firebase data structure stores combo data at:
```
batches/{batchId}/data/master
```

However, the app code was incorrectly looking for data at:
```
batches/{batchId}/data/master/classes
```

## Solution
Updated the following methods in `FirebaseService` to use the correct path:

1. `fetchCombosForBatch` - Changed path from `batches/{batchId}/data/master/classes` to `batches/{batchId}/data/master`
2. `fetchStudentsFromFirebase` - Changed path from `batches/{batchId}/data/master/classes` to `batches/{batchId}/data/master`
3. `updateStudent` - Changed path from `batches/{batchId}/data/master/classes/{comboName}` to `batches/{batchId}/data/master/{comboName}`

## Testing
Created test screens and widgets to verify the fix:
- `ComboTestScreen` - Full screen test interface
- `ComboTestWidget` - Reusable widget for testing in any screen

## How to Test
1. Run the app in debug mode
2. Navigate to the Debug Screen
3. Click "Test Combo Fetch" button
4. The app should now show the available combos and student counts

## Files Modified
- `lib/services/firebase_service.dart` - Updated path references
- `lib/main.dart` - Added route for combo test screen
- `lib/screens/debug_screen.dart` - Added button to access combo test
- `lib/screens/combo_test_screen.dart` - New test screen
- `lib/widgets/combo_test_widget.dart` - New reusable test widget