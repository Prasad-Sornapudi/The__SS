import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:flutter/src/widgets/basic.dart' show AlwaysStoppedAnimation;
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/class_model.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/curved_bottom_navigation.dart';
import '../screens/dashboard_screen.dart';
import '../screens/home_screen.dart';
import '../providers/bottom_navigation_provider.dart'; // Add this import

class ComboSelectionScreen extends StatefulWidget {
  final String selectedBatch;
  final bool isFromDashboard;
  
  const ComboSelectionScreen({
    super.key, 
    required this.selectedBatch,
    this.isFromDashboard = false,
  });

  @override
  State<ComboSelectionScreen> createState() => _ComboSelectionScreenState();
}

class _ComboSelectionScreenState extends State<ComboSelectionScreen> {
  late String _selectedBatch;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize with widget's selectedBatch as default
    _selectedBatch = widget.selectedBatch;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only run this once to avoid infinite loops
    if (!_isInitialized) {
      // Get batch name from arguments
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _selectedBatch = args?['selectedBatch'] as String? ?? widget.selectedBatch;
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavyBlue,
      appBar: AppBar(
        title: Text('Select Combo - $_selectedBatch'),
        backgroundColor: AppTheme.darkNavyBlue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.isFromDashboard) {
              Navigator.pushReplacementNamed(context, '/batch-selection');
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Consumer2<ClassProvider, AttendanceProvider>(
        builder: (context, classProvider, attendanceProvider, child) {
          try {
            if (classProvider.classes.isEmpty) {
              return const Center(
                child: Text(
                  'No classes available',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }

            return _buildComboSelectionView(classProvider, attendanceProvider);
          } catch (e) {
            print('Error in ComboSelectionScreen: $e');
            return Center(
              child: Text(
                'Error: $e',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }
        },
      ),
      bottomNavigationBar: CurvedBottomNavigation(
        selectedIndex: 1, // Dashboard is selected
        onItemTapped: (index) {
          switch (index) {
            case 0: // Home/Scanner
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/home', 
                (route) => false,
                arguments: {'initialTabIndex': 0}
              );
              break;
            case 1: // Dashboard (current screen)
              // Already on dashboard flow
              break;
            case 2: // Settings
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/home', 
                (route) => false,
                arguments: {'initialTabIndex': 2}
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildComboSelectionView(ClassProvider classProvider, AttendanceProvider attendanceProvider) {
    // Get all classes in the selected batch
    final batchClasses = classProvider.classes
        .where((c) => (c.sheetName ?? c.className) == _selectedBatch)
        .toList();

    // Extract unique combos from the batch
    final uniqueCombos = batchClasses
        .map((c) => c.className)
        .toSet()
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppConstants.defaultPadding),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth > 1200) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth > 800) {
                  crossAxisCount = 3;
                }
                
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppConstants.defaultPadding,
                    mainAxisSpacing: AppConstants.defaultPadding,
                    childAspectRatio: 0.75, // Significantly increased height to prevent overflow
                  ),
              itemCount: uniqueCombos.length,
              itemBuilder: (context, index) {
                final comboName = uniqueCombos[index];
                
                // Find the class for this combo
                final comboClass = batchClasses.firstWhere(
                  (c) => c.className == comboName,
                  orElse: () => batchClasses.first,
                );
                
                // Save the original active class ID
                final originalActiveClassId = attendanceProvider.activeClassId;
                int presentCount = 0;
                int absentCount = 0;
                int totalStudents = 0;
                double attendancePercentage = 0.0;
                
                try {
                  // Temporarily set active class to calculate attendance for this combo
                  attendanceProvider.setActiveClassId(comboClass.id);
                  
                  // Calculate attendance for this combo
                  final summary = attendanceProvider.getSessionSummary(comboClass);
                  totalStudents = comboClass.students.length;
                  presentCount = summary.presentCount;
                  absentCount = summary.absentCount;
                  attendancePercentage = totalStudents > 0 
                      ? (presentCount / totalStudents) * 100 
                      : 0.0;
                } finally {
                  // Always restore original active class
                  attendanceProvider.setActiveClassId(originalActiveClassId);
                }

                return _buildComboCard(
                  comboName: comboName,
                  totalStudents: totalStudents,
                  presentCount: presentCount,
                  absentCount: absentCount,
                  attendancePercentage: attendancePercentage,
                  onTap: () async {
                    try {
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.techwingyellow),
                          ),
                        ),
                      );

                      // Update providers
                      attendanceProvider.setActiveClassId(comboClass.id);
                      classProvider.setActiveClass(comboClass);

                      // Force ensure data is loaded before navigating
                      // This ensures the dashboard doesn't show "loading" state
                      await attendanceProvider.ensureAttendanceLoadedForClass(
                        comboClass.id, 
                        attendanceProvider.sessionDate
                      );

                      // Hide loading indicator
                      if (context.mounted) {
                        Navigator.of(context).pop(); 
                      }

                      if (!context.mounted) return;

                      // Update global navigation index to Dashboard (1)
                      // This ensures when we pop back to HomeScreen, it shows the Dashboard tab
                      if (context.mounted) {
                        context.read<BottomNavigationProvider>().setIndex(1);
                      }

                      // Navigate back to the main dashboard
                      // Use popUntil to go back to the existing HomeScreen instead of pushing a new one
                      // This prevents HomeScreen.initState from running again and clearing the active class
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      
                      // If we need to switch tabs, we might need a global key or provider, 
                      // but since we are modifying the active class, the HomeScreen should likely 
                      // stay on the current tab or default. 
                      // The user's request specific to "dashboard flow" usually implies they want to handle it there.
                      // If we really need to force the tab switch, we would need to access HomeScreen state.
                      // For now, returning to root is safer than reloading.
                    } catch (e) {
                      // Hide loading indicator if showing
                      if (context.mounted) {
                        Navigator.of(context).pop(); 
                      }
                      
                      print('Error selecting combo: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                );
              },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComboCard({
    required String comboName,
    required int totalStudents,
    required int presentCount,
    required int absentCount,
    required double attendancePercentage,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.glassCard(),
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.techwingyellow.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group,
                color: AppTheme.techwingyellow,
                size: 30,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              comboName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              '$totalStudents students',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Attendance",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "${attendancePercentage.toInt()}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: attendancePercentage / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.techwingyellow),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMiniStat('P', presentCount.toString(), AppTheme.successColor),
                _buildMiniStat('A', absentCount.toString(), AppTheme.errorColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}