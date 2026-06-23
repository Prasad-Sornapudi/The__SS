import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/class_model.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import './combo_selection_screen.dart';
import '../widgets/curved_bottom_navigation.dart';

class BatchSelectionScreen extends StatefulWidget {
  final String? initialBatch;
  
  const BatchSelectionScreen({super.key, this.initialBatch});

  @override
  State<BatchSelectionScreen> createState() => _BatchSelectionScreenState();
}

class _BatchSelectionScreenState extends State<BatchSelectionScreen> {
  // Removed _selectedBatch state as we now navigate to a new screen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavyBlue,
      appBar: AppBar(
        title: const Text('Select Batch'),
        backgroundColor: AppTheme.darkNavyBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove the back button as per requirements
      ),
      body: const BatchSelectionView(),
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
}

class BatchSelectionView extends StatelessWidget {
  const BatchSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ClassProvider, AttendanceProvider>(
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

          // Extract unique batches
          final uniqueBatches = classProvider.classes
              .map((c) => c.sheetName ?? c.className)
              .toSet()
              .toList()
            ..sort();

          return Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a Batch',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppConstants.defaultPadding),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Determine proper grid count based on available width
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
                          childAspectRatio: 0.75,
                        ),
                        itemCount: uniqueBatches.length,
                        itemBuilder: (context, index) {
                          final batchName = uniqueBatches[index];
                          
                          // Get all classes in this batch
                          final batchClasses = classProvider.classes
                              .where((c) => (c.sheetName ?? c.className) == batchName)
                              .toList();
                          
                          // Calculate total students in batch
                          final totalStudents = batchClasses.fold(0, (sum, classModel) => sum + classModel.students.length);
                          
                          // Calculate attendance for the batch with improved error handling
                          int presentCount = 0;
                          int absentCount = 0;
                          
                          // Save the original active class ID
                          final originalActiveClassId = attendanceProvider.activeClassId;
                          
                          try {
                            // Temporarily set active class to calculate attendance for each class in batch
                            for (final classModel in batchClasses) {
                              // Set this class as active temporarily
                              attendanceProvider.setActiveClassId(classModel.id);
                              
                              // Get attendance summary
                              final summary = attendanceProvider.getSessionSummary(classModel);
                              presentCount += summary.presentCount;
                              absentCount += summary.absentCount;
                            }
                          } finally {
                            // Always restore original active class
                            attendanceProvider.setActiveClassId(originalActiveClassId);
                          }
                          
                          final attendancePercentage = totalStudents > 0 
                              ? (presentCount / totalStudents) * 100 
                              : 0.0;
    
                          return _BatchCard(
                            batchName: batchName,
                            totalStudents: totalStudents,
                            presentCount: presentCount,
                            absentCount: absentCount,
                            attendancePercentage: attendancePercentage,
                            onTap: () {
                              // Navigate to Combo Selection Screen with selected batch
                              try {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ComboSelectionScreen(selectedBatch: batchName),
                                  ),
                                );
                              } catch (e) {
                                print('Error navigating to combo selection screen: $e');
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
                    }
                  ),
                ),
              ],
            ),
          );
        } catch (e) {
          print('Error in BatchSelectionView: $e');
          return Center(
            child: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          );
        }
      },
    );
  }
}

class _BatchCard extends StatelessWidget {
  final String batchName;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final double attendancePercentage;
  final VoidCallback onTap;

  const _BatchCard({
    required this.batchName,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.attendancePercentage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                Icons.business,
                color: AppTheme.techwingyellow,
                size: 30,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              batchName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              '$totalStudents students',
              style: const TextStyle(
                fontSize: 14,
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