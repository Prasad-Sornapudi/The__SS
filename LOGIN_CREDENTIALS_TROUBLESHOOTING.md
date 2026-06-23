# Login Credentials Access Troubleshooting

## Problem
The app cannot access the Login_Credentials sheet in the Google Sheets control document.

## Common Causes and Solutions

### 1. Missing Login_Credentials Sheet
**Problem**: The Google Sheet doesn't contain a sheet tab named exactly "Login_Credentials"
**Solution**:
1. Open your control Google Sheet
2. Create a new sheet tab named exactly "Login_Credentials" (case-sensitive)
3. Add these column headers in the first row:
   - Column A: Name
   - Column B: User_Name
   - Column C: Password
4. Add at least one row of test data:
   - Row 2, Column A: Admin User
   - Row 2, Column B: admin
   - Row 2, Column C: password123

### 2. Incorrect Control Sheet URL
**Problem**: The control sheet URL in the secrets points to the wrong spreadsheet
**Solution**:
1. Check the control sheet URL in your secret files
2. Ensure it points to the correct Google Sheet that contains the Login_Credentials tab
3. Make sure the URL format is correct:
   `https://docs.google.com/spreadsheets/d/YOUR_SPREADSHEET_ID/edit`

### 3. Service Account Permissions
**Problem**: The service account doesn't have editor permissions on the Google Sheet
**Solution**:
1. Find the service account email in your service_account.json file (look for `client_email`)
2. Share your Google Sheet with this email address
3. Grant "Editor" permissions (not just "Viewer")

### 4. Network/Authentication Issues
**Problem**: Network connectivity or authentication problems
**Solution**:
1. Ensure you have a stable internet connection
2. Check that your service account key is valid and not expired
3. Verify that your device's time/date settings are correct

## Diagnostic Tools

### Run Diagnostic from Login Screen
In debug mode, the login screen has a "Run Sheet Diagnostic" button that will provide detailed information about what's happening.

### Run Comprehensive Diagnostic
Navigate to `/comprehensive-diagnostic` route to run a detailed diagnostic that checks:
1. Secrets configuration
2. Service account credentials
3. Google Sheets API authentication
4. Spreadsheet access
5. Login_Credentials sheet existence
6. Login_Credentials sheet data

## Testing in Debug Mode
In debug mode, you can log in with any credentials if the Login_Credentials sheet is not accessible. This is intended for development/testing purposes only.

## Verification Steps
After making changes:
1. Restart the app
2. Go to the login screen
3. Click "Sync Credentials" button
4. Check if the credentials load successfully
5. Try logging in with the credentials you added to the sheet

## Contact Support
If you continue to have issues:
1. Run the comprehensive diagnostic
2. Take a screenshot of the results
3. Contact the development team with the diagnostic information