import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Add this import for kDebugMode
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Add Hive import
import 'screens/splash_screen.dart'; // Add splash screen import
import 'screens/test_screen.dart';
import 'screens/sheet_debug_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/diagnostic_screen.dart'; // Add diagnostic screen import
import 'screens/student_search_screen.dart';
import 'screens/mock_interview_start_screen.dart';
import 'screens/mock_interview_screen.dart';
import 'screens/class_details_screen.dart';
import 'screens/login_screen.dart'; // Add login screen import
import 'screens/scanner_screen.dart'; // Add scanner screen import
import 'screens/test_combo_fetch_screen.dart'; // Add our new test screen import
import 'screens/combo_test_screen.dart'; // Add combo test screen import
import 'screens/batch_combo_dashboard_screen.dart'; // Add batch combo dashboard screen import
import 'screens/batch_selection_screen.dart'; // Add batch selection screen import
import 'screens/combo_selection_screen.dart'; // Add combo selection screen import
import 'screens/combo_selection_screen.dart'; // Add combo selection screen import
import 'screens/home_screen.dart'; // Add home screen import
import 'screens/class_selection_dropdown_screen.dart'; // Add new screen import
import 'screens/manage_classes_screen.dart'; // Add manage classes screen import
import 'models/class_model.dart';
import 'services/hive_service.dart';
import 'services/attendance_persistence_service.dart';
import 'services/app_lifecycle_service.dart';
import 'services/attendance_data_service.dart';
import 'providers/user_provider.dart';
import 'providers/sync_progress_provider.dart';
import 'services/auto_upload_service.dart';
import 'services/sync_service.dart';
import 'services/firebase_service.dart'; // Add Firebase service import
import 'services/connectivity_service.dart'; // Add connectivity service import
import 'services/hybrid_sync_service.dart'; // Add hybrid sync service import
import 'constants/app_constants.dart'; // Add app constants import
import 'constants/theme.dart'; // Add theme import
import 'firebase_options.dart'; // Add firebase options import
import 'providers/class_provider.dart'; // Add class provider import
import 'providers/attendance_provider.dart'; // Add attendance provider import
import 'providers/bottom_navigation_provider.dart'; // Add bottom navigation provider import

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Show a loading screen immediately to prevent white screen
  runApp(const LoadingApp());
  
  // Perform initialization in background
  _initializeAndRun();
}

Future<void> _initializeAndRun() async {
  try {
    // Initialize Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized successfully');
    } catch (e) {
      print('⚠️ Firebase initialization failed: $e');
    }
    
    // Initialize Firebase Realtime Database service
    try {
      await FirebaseService().init();
      print('✅ Firebase Realtime Database initialized');
    } catch (e) {
      print('⚠️ Firebase service init failed: $e');
    }
    
    // Initialize Connectivity monitoring
    try {
      await ConnectivityService().init();
      print('✅ Connectivity monitoring initialized');
    } catch (e) {
      print('⚠️ Connectivity init failed: $e');
    }
    
    // Initialize Hybrid Sync service
    try {
      await HybridSyncService().init();
      print('✅ Hybrid Sync service initialized');
    } catch (e) {
      print('⚠️ Hybrid Sync service init failed: $e');
    }
    
    // Initialize Hive with Flutter
    try {
      await Hive.initFlutter(); // Initialize Hive with Flutter first
      await HiveService.init();
      print('✅ Hive initialized successfully');
    } catch (e) {
      print('⚠️ Hive initialization failed: $e');
      // Continue anyway - the app should still work with reduced functionality
    }
    
    // Check and cleanup attendance data based on the 10:00 PM rule
    try {
      await AttendancePersistenceService.checkAndCleanupAttendanceData();
    } catch (e) {
      print('⚠️ Attendance persistence service init failed: $e');
    }
    
    // Initialize app lifecycle service
    try {
      AppLifecycleService().initialize();
    } catch (e) {
      print('⚠️ App lifecycle service init failed: $e');
    }
    
    if (kDebugMode) {
      print('✅ App initialized successfully');
      // Print attendance data summary for debugging
      try {
        await AttendanceDataService.printAttendanceSummary();
      } catch (e) {
        print('⚠️ Attendance data summary failed: $e');
      }
    }
  } catch (e) {
    // General initialization error - continue anyway with basic app
    if (kDebugMode) {
      print('General initialization error: $e');
    }
  }
  
  // Set system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const QRAttendanceApp());
}

// Simple loading widget to show immediately vs white screen
class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF040C1B), // AppTheme.appBackgroundColor
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Use a simple CircularProgressIndicator if assets aren't loaded yet
              const CircularProgressIndicator(
                color: Color(0xFF40C0FF), // AppTheme.primaryColor
              ),
              const SizedBox(height: 20),
              const Text(
                'SkillSync',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Arial', // Fallback font
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Initializing...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontFamily: 'Arial', // Fallback font
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QRAttendanceApp extends StatelessWidget {
  const QRAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClassProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) {
          final provider = UserProvider();
          // Initialize the provider asynchronously
          provider.initialize();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => AutoUploadService()),
        ChangeNotifierProvider(create: (_) => SyncService()),
        ChangeNotifierProvider(create: (_) => SyncProgressProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavigationProvider()), // Add Navigation Provider
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.darkTheme,
        // Start with splash screen as the initial route
        home: const SplashScreen(),
        // Add routes for our app
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/scanner': (context) => const ScannerScreen(), // Scanner screen as separate route
          '/test': (context) => const TestScreen(), // Add test screen route
          '/sheet-debug': (context) => const SheetDebugScreen(), // Add sheet debug screen route
          '/debug': (context) => const DebugScreen(), // Add debug screen route
          '/diagnostic': (context) => const DiagnosticScreen(), // Add diagnostic screen route
          '/student-search': (context) => StudentSearchScreen(), // Add student search screen route
          '/mock-interview': (context) => const MockInterviewStartScreen(), // Mock interview start screen route
          '/class-details': (context) => const ClassDetailsScreen(), // Add class details screen route
          '/test-combo-fetch': (context) => TestComboFetchScreen(), // Add our test combo fetch screen route
          '/combo-test': (context) => ComboTestScreen(), // Add combo test screen route
          '/batch-combo-dashboard': (context) => const BatchComboDashboardScreen(), // Add batch combo dashboard screen route
          '/batch-selection': (context) => const BatchSelectionScreen(), // Add batch selection screen route
          '/combo-selection': (context) => const ComboSelectionScreen(selectedBatch: ''), // Add combo selection screen route
          '/home': (context) => const HomeScreen(), // Add home screen route
          '/class-selection-dropdown': (context) => const ClassSelectionDropdownScreen(),
          '/manage-classes': (context) => const ManageClassesScreen(), // Add manage classes screen route
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}