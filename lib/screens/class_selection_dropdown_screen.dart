import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/session_setup_widget.dart'; // Import SessionSetupWidget
import '../constants/theme.dart';
import '../providers/class_provider.dart';
import '../models/class_model.dart';
import '../models/session_model.dart' as session_model;

class ClassSelectionDropdownScreen extends StatelessWidget {
  const ClassSelectionDropdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get arguments to determine target route
    final String targetRoute = ModalRoute.of(context)!.settings.arguments as String? ?? '/class-details';
    
    return Scaffold(
      backgroundColor: AppTheme.darkNavyBlue,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.mediumSpacing),
            child: SessionSetupWidget(
              buttonText: targetRoute == '/student-search' 
                  ? 'Search Students' 
                  : (targetRoute == '/mock-interview' ? 'Start Interview' : 'View Details'),
              showSessionToggle: targetRoute == '/mock-interview' || targetRoute == '/scanner', // Only show toggle for interview/scanner
              onBack: () {
                Navigator.of(context).pop();
              },
              onStartSession: (classModel, combo, sessionType) {
                print('Class selected: ${classModel.className}, Session: $sessionType');
                
                // Set the active class asynchronously to avoid blocking navigation
                // The in-memory update in ClassProvider is synchronous, so ScannerScreen will see it
                final classProvider = context.read<ClassProvider>();
                classProvider.setActiveClass(classModel);
                
                // For student search, navigate directly to the search screen replacement
                if (targetRoute == '/student-search') {
                   // Replace current screen to avoid stacking
                   Navigator.pushReplacementNamed(context, '/student-search');
                } else {
                  // For other routes, navigate normally and replace this screen
                  Navigator.pushReplacementNamed(context, targetRoute);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
