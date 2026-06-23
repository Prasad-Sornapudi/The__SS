import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../providers/user_provider.dart';
import '../services/google_sheets_service.dart';
import '../services/attendance_sheet_service.dart';
import '../models/class_model.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/scanner_widgets.dart'; // Import GradientButton
import '../services/auto_class_service.dart'; // Import AutoClassService
import '../screens/home_screen.dart'; // Import HomeScreen

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _isUpdating = false;
  double _progress = 0.0;
  String _statusMessage = 'Checking for data...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadData();
    });
  }

  Future<void> _checkAndLoadData() async {
    final classProvider = context.read<ClassProvider>();
    
    // Check if we already have classes
    if (classProvider.hasClasses) {
      // If we have data, navigate to the main screen
      _navigateToMainScreen();
      return;
    }
    
    // If no data, automatically try to load from Google Sheets
    await _autoLoadData();
  }

  Future<void> _autoLoadData() async {
    setState(() {
      _isUpdating = true;
      _statusMessage = 'Connecting to Google Sheets...';
      _errorMessage = null;
    });

    try {
      final classProvider = context.read<ClassProvider>();
      
      setState(() {
        _progress = 0.2;
        _statusMessage = 'Fetching class data...';
      });
      
      // Fetch classes from Google Sheets
      final classes = await AutoClassService.fetchClassesFromSheets();
      
      setState(() {
        _progress = 0.6;
        _statusMessage = 'Saving data locally...';
      });
      
      // Save to storage
      await AutoClassService.saveClassesToStorage(classes);
      
      // Load classes into provider
      await classProvider.loadClasses();
      
      setState(() {
        _progress = 1.0;
        _statusMessage = 'Data loaded successfully!';
      });
      
      // Wait a moment to show success message
      await Future.delayed(const Duration(seconds: 1));
      
      // Navigate to main screen
      _navigateToMainScreen();
    } catch (e) {
      String errorMessage = 'Failed to load data: $e';
      
      // Handle specific network errors
      if (e.toString().contains('SocketException') || e.toString().contains('failed host lookup')) {
        errorMessage = 'Network connection failed. Please check your internet connection and try again.';
      } else if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        errorMessage = 'SSL certificate verification failed. Please check your network security settings.';
      } else if (e.toString().contains('Connection timed out')) {
        errorMessage = 'Connection timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('404') || e.toString().contains('not found')) {
        errorMessage = 'Google Sheet not found. Please check if the sheet URL is correct.';
      } else if (e.toString().contains('403') || e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check if the Google Sheet is shared with the service account.';
      }
      
      setState(() {
        _isUpdating = false;
        _errorMessage = errorMessage;
        _statusMessage = 'Update failed';
      });
    }
  }

  void _navigateToMainScreen() {
    // Navigate to the main app screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  void _continueWithoutData() {
    // Navigate to the main app screen without loading data
    _navigateToMainScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavyBlue,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(AppConstants.defaultPadding),
          padding: const EdgeInsets.all(AppConstants.largePadding),
          decoration: AppTheme.glassCard(
            borderRadius: AppConstants.defaultBorderRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _errorMessage != null ? Icons.error : Icons.sync,
                size: 80,
                color: _errorMessage != null ? AppTheme.errorColor : AppTheme.primaryColor,
              ),
              const SizedBox(height: AppConstants.largePadding),
              Text(
                _errorMessage != null ? 'Update Failed' : 'Updating Data',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.largePadding),
              if (_isUpdating && _errorMessage == null) ...[
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.glassBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  minHeight: 8,
                ),
                const SizedBox(height: AppConstants.defaultPadding),
                const Text(
                  'Please wait while we fetch your class data...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.defaultPadding),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: 120,
                      child: GradientButton(
                        onPressed: _autoLoadData, // This is fine
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.buttonTextColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: GradientButton(
                        onPressed: _continueWithoutData, // This is fine
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.buttonTextColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.smallPadding),
                const Text(
                  'Note: You can add classes manually in the settings later.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}