class AppConstants {
  // App Information
  static const String appName = 'Skill Sync';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'A Flutter application for QR-based attendance scanning';

  // Navigation Routes
  static const String scannerRoute = '/scanner';
  static const String dashboardRoute = '/dashboard';
  static const String settingsRoute = '/settings';

  // Storage Keys
  static const String activeClassKey = 'activeClassId';
  static const String firstLaunchKey = 'isFirstLaunch';
  static const String themeKey = 'themeMode';
  static const String lastSyncKey = 'lastSyncTime';

  // File Types
  static const List<String> allowedCsvExtensions = ['csv', 'tsv'];
  static const List<String> allowedJsonExtensions = ['json'];

  // Google Sheets
  static const String defaultSheetName = 'Attendance';
  static const int maxRetries = 3;
  static const Duration syncTimeout = Duration(seconds: 30);

  // QR Scanner
  static const Duration scanDebounce = Duration(milliseconds: 500);
  static const double scannerAspectRatio = 1.0;
  static const int maxManualEntryLength = 50;

  // Attendance Session
  static const Duration duplicateScanWindow = Duration(milliseconds: 250); // Set to 1/4 second as requested
  static const int defaultUploadBatchSize = 50;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 32.0;

  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;

  static const double defaultElevation = 4.0;
  static const double smallElevation = 2.0;
  static const double largeElevation = 8.0;

  // Card Dimensions
  static const double summaryCardHeight = 120.0;
  static const double studentCardHeight = 80.0;
  static const double classCardHeight = 140.0;

  // List View
  static const double listItemHeight = 72.0;
  static const double listItemPadding = 16.0;
  static const int maxListItems = 100; // For performance

  // Snackbar
  static const Duration snackbarDuration = Duration(milliseconds: 800);
  static const Duration errorSnackbarDuration = Duration(seconds: 2);
  
  // Scan popup duration (increased for better readability per project specification)
  static const Duration scanPopupDuration = Duration(milliseconds: 2000); // Changed from 1200ms to 2000ms (2 seconds)

  // Validation
  static const int minClassNameLength = 3;
  static const int maxClassNameLength = 50;
  static const int minPinNumberLength = 5;
  static const int maxPinNumberLength = 20;

  // Error Messages
  static const String networkErrorMessage = 'Please check your internet connection and try again';
  static const String genericErrorMessage = 'Something went wrong. Please try again';
  static const String csvParseErrorMessage = 'Failed to parse CSV file. Please check the format';
  static const String permissionErrorMessage = 'Permission required to access this feature';
  static const String fileNotFoundMessage = 'Selected file not found';
  static const String invalidQrMessage = 'Invalid QR code format';
  static const String duplicateScanMessage = 'Please wait before scanning again';
  static const String studentNotFoundMessage = 'Student not found in class roster';

  // Success Messages
  static const String attendanceMarkedMessage = 'Attendance marked successfully';
  static const String dataUploadedMessage = 'Attendance data uploaded successfully';
  static const String classSavedMessage = 'Class configuration saved successfully';
  static const String csvImportedMessage = 'Student roster imported successfully';

  // Google Sheets API
  static const String sheetsScope = 'https://www.googleapis.com/auth/spreadsheets';
  static const String driveScope = 'https://www.googleapis.com/auth/drive.readonly';
  static const List<String> requiredScopes = [sheetsScope, driveScope];

  // Regular Expressions
  static const String pinNumberPattern = r'^[A-Za-z0-9]+$';
  static const String emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String mobilePattern = r'^\+?[\d\s\-\(\)]{7,15}$';
  static const String sheetUrlPattern = r'https://docs\.google\.com/spreadsheets/d/([a-zA-Z0-9-_]+)';

  // Date Formats
  static const String displayDateFormat = 'dd/MM/yyyy';
  static const String apiDateFormat = 'dd/MM/yyyy';
  static const String timestampFormat = 'dd/MM/yyyy HH:mm:ss';
  static const String columnDateFormat = 'dd/MM/yyyy'; // Google Sheets format

  // Bottom Navigation
  static const List<String> bottomNavLabels = ['Home', 'Dashboard', 'Settings'];
  
  // Import statement is needed in the file that uses these icons
  // static const List<IconData> bottomNavIcons = [
  //   Icons.qr_code_scanner,
  //   Icons.dashboard, 
  //   Icons.settings,
  // ];

  // Debug flags
  static const bool enableLogging = true;
  static const bool enableAnalytics = false; // Set to true in production
}