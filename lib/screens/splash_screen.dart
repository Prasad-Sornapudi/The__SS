import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/control_sheet_service.dart';
import '../constants/theme.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart'; // Add this import
import '../providers/user_provider.dart'; // Add this import
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/class_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _lottieError = false;
  LottieComposition? _composition;

  @override
  void initState() {
    super.initState();
    _loadLottieComposition();
    // Delay _initializeApp until after the first frame to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _loadLottieComposition() async {
    try {
      // Preload the Lottie composition to avoid flickering
      final composition = await AssetLottie('assets/Splash_Screen.json').load();
      if (mounted) {
        setState(() {
          _composition = composition;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Lottie composition load error: $e');
      }
      if (mounted) {
        setState(() {
          _lottieError = true;
        });
      }
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize UserProvider to load persisted user data
      final userProvider = context.read<UserProvider>();
      await userProvider.loadUser(); // Use loadUser instead of initialize to avoid notifyListeners during build

      // Start credential loading in the background immediately
      final credentialFuture = ControlSheetService.readLoginCredentials();
      
      // Start background data fetch
      // We wrap it in a future that handles errors so one failure doesn't block the other
      final dataFetchFuture = _startBackgroundDataFetch();
      
      // Wait for everything: Credentials, Animation, AND Data Fetch
      // Minimum 4 seconds for animation
      print('Splash: Waiting for tasks to complete...');
      await Future.wait<void>([
        credentialFuture,
        Future.delayed(const Duration(seconds: 4)),
        dataFetchFuture,
      ]);
      print('Splash: All tasks completed!');
      
      // Check if widget is still mounted before navigation
      if (!mounted) return;
      
      // Check if user is already logged in
      if (userProvider.isLoggedIn) {
        // Navigate to Home Screen (Main Scanner/Dashboard)
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Navigate to login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during splash initialization: $e');
      }
      
      // Even if there's an error, proceed to login screen
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  Future<void> _startBackgroundDataFetch() async {
    print('Splash: ${DateTime.now()} Starting background data fetch...');
    final classProvider = Provider.of<ClassProvider>(context, listen: false);
    
    try {
      // 1. Load Classes ONLY
      await classProvider.loadClasses();
      
      // If no classes found locally, try to auto-load from sheets
      if (!classProvider.hasClasses) {
        print('Splash: No classes found locally, attempting to auto-load...');
        await classProvider.autoLoadClassesFromSheets();
      }
      
      print('Splash: Classes loaded. Count: ${classProvider.classes.length}');
      
      // Aggressively pre-fetch attendance for ALL classes in the background
      // This satisfies the requirement "data should be loaded starting from the app opening"
      final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
      final sessionDate = attendanceProvider.sessionDate;
      
      print('Splash: Triggering background fetch for all ${classProvider.classes.length} classes...');
      for (final classModel in classProvider.classes) {
        // Fire and forget - don't await individually to allow parallelism
        attendanceProvider.ensureAttendanceLoadedForClass(classModel.id, sessionDate);
      }
      
    } catch (e) {
      print('Splash: Error in background data fetch: $e');
      // Non-fatal error, let the app proceed
    }
    print('Splash: ${DateTime.now()} Background data fetch init completed');
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the splash screen takes up the full screen immediately
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF040C1B),
        body: Builder(
          builder: (context) {
            if (_composition != null && !_lottieError) {
              return _buildLottieSplash();
            } else {
              return _buildFallbackSplash();
            }
          },
        ),
      ),
    );
  }

  Widget _buildLottieSplash() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9, // 90% of screen width
        height: MediaQuery.of(context).size.height * 0.9, // 90% of screen height
        child: Lottie(
          composition: _composition!,
          fit: BoxFit.contain,
          repeat: false, // Play once
          animate: true,
        ),
      ),
    );
  }

  Widget _buildFallbackSplash() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9, // 90% of screen width
        height: MediaQuery.of(context).size.height * 0.9, // 90% of screen height
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}