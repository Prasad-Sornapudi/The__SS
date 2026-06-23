import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../providers/attendance_provider.dart';
import '../services/hive_service.dart';
import '../services/attendance_data_service.dart';

class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is going to background, ensure data is saved
        _savePendingData();
        break;
      case AppLifecycleState.resumed:
        // App is coming to foreground, nothing special needed
        break;
      case AppLifecycleState.detached:
        // App is being terminated, ensure data is saved
        _savePendingData();
        break;
      case AppLifecycleState.hidden:
        // App is hidden, ensure data is saved
        _savePendingData();
        break;
    }
  }

  DateTime? _lastCleanupTime;

  /// Save any pending data to ensure persistence
  Future<void> _savePendingData() async {
    try {
      // Throttle cleanup to run at most once per minute
      if (_lastCleanupTime != null && DateTime.now().difference(_lastCleanupTime!).inMinutes < 1) {
        if (kDebugMode) {
          print('AppLifecycleService: Skipping cleanup (throttled)');
        }
        return;
      }
      _lastCleanupTime = DateTime.now();

      // Force cleanup of old data
      await AttendanceDataService.cleanupOldData();
      
      // Don't close Hive boxes immediately as this can cause issues
      // The boxes will be closed when the app is fully terminated
      if (kDebugMode) {
        print('AppLifecycleService: Data cleanup performed, Hive boxes kept open for continued use');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AppLifecycleService: Error saving pending data: $e');
      }
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}