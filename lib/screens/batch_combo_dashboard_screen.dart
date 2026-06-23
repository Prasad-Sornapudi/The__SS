import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';

class BatchComboDashboardScreen extends StatefulWidget {
  const BatchComboDashboardScreen({super.key});

  @override
  State<BatchComboDashboardScreen> createState() => _BatchComboDashboardScreenState();
}

class _BatchComboDashboardScreenState extends State<BatchComboDashboardScreen> {
  String? _selectedBatch;
  String? _selectedCombo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavyBlue,
      appBar: AppBar(
        title: const Text('Statistical Dashboard'),
        backgroundColor: AppTheme.darkNavyBlue,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<ClassProvider, AttendanceProvider>(
        builder: (context, classProvider, attendanceProvider, child) {
          if (classProvider.classes.isEmpty) {
            return const Center(
              child: Text(
                'No classes available',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          // If no batch is selected, show batch cards
          if (_selectedBatch == null) {
            return _buildBatchSelectionView(classProvider, attendanceProvider);
          }

          // If batch is selected but no combo is selected, show combo cards
          if (_selectedCombo == null) {
            return _buildComboSelectionView(classProvider, attendanceProvider);
          }

          // If both batch and combo are selected, show statistical dashboard
          return _buildStatisticalDashboardView(classProvider, attendanceProvider);
        },
      ),
    );
  }

  Widget _buildBatchSelectionView(ClassProvider classProvider, AttendanceProvider attendanceProvider) {
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
                    childAspectRatio: 1.2,
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
  
                    return _buildBatchCard(
                      batchName: batchName,
                      totalStudents: totalStudents,
                      presentCount: presentCount,
                      absentCount: absentCount,
                      attendancePercentage: attendancePercentage,
                      onTap: () {
                        setState(() {
                          _selectedBatch = batchName;
                        });
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
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedBatch = null;
                  });
                },
              ),
              const SizedBox(width: AppConstants.smallPadding),
              Text(
                'Select Combo - $_selectedBatch',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
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
                    childAspectRatio: 1.2,
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
                      onTap: () {
                        setState(() {
                          _selectedCombo = comboName;
                        });
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

  Widget _buildStatisticalDashboardView(ClassProvider classProvider, AttendanceProvider attendanceProvider) {
    // Get the selected combo class
    final comboClass = classProvider.classes.firstWhere(
      (c) => (c.sheetName ?? c.className) == _selectedBatch && c.className == _selectedCombo,
      orElse: () => classProvider.classes.first,
    );

    // Set this class as active
    attendanceProvider.setActiveClassId(comboClass.id);
    
    // Navigate back to the main dashboard with the selected batch and combo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
    
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.techwingyellow),
      ),
    );
  }

  Widget _buildBatchCard({
    required String batchName,
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
            Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: attendancePercentage / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.techwingyellow),
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
            Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: attendancePercentage / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.techwingyellow),
                ),
                Text(
                  "${attendancePercentage.toInt()}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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

  Widget _buildStatCard(String title, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
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

  Widget _buildDetailedStatCard(String title, String value, IconData icon, {Color? color}) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlue.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color ?? Colors.white, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color ?? Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(AttendanceRecord record, bool isPresent) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlue.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
      ),
      padding: const EdgeInsets.all(AppConstants.smallPadding),
      child: Row(
        children: [
          Icon(
            isPresent ? Icons.check_circle : Icons.cancel,
            color: isPresent ? AppTheme.successColor : AppTheme.errorColor,
            size: 20,
          ),
          const SizedBox(width: AppConstants.smallPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  record.studentPinNumber,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isPresent) ...[
            Text(
              record.displayTime,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStudentTileForAbsent(Student student) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlue.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
      ),
      padding: const EdgeInsets.all(AppConstants.smallPadding),
      child: Row(
        children: [
          const Icon(
            Icons.cancel,
            color: AppTheme.errorColor,
            size: 20,
          ),
          const SizedBox(width: AppConstants.smallPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  student.pinNumber,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}