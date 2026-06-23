import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../models/class_model.dart';
import '../widgets/settings_widgets.dart'; // Import ClassListTile, ClassFormDialog
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/scanner_widgets.dart'; // For GradientButton
import '../services/google_sheets_service.dart';
import '../services/department_sheet_service.dart';
import '../services/hive_service.dart';
import '../providers/attendance_provider.dart';
import '../models/session_model.dart'; // For SessionType

class ManageClassesScreen extends StatefulWidget {
  const ManageClassesScreen({super.key});

  @override
  State<ManageClassesScreen> createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040C1B),
      appBar: AppBar(
        title: const Text('Manage Classes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<ClassProvider>(
        builder: (context, classProvider, child) {
          if (classProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (classProvider.classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.class_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No classes added yet',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    onPressed: () => _showAddClassDialog(context),
                    child: const Text('Add Class', style: TextStyle(color: AppTheme.buttonTextColor)),
                  ),
                ],
              ),
            );
          }

          // Group classes by Sheet Name (Batch)
          final Map<String, List<ClassModel>> groupedClasses = {};
          for (var cls in classProvider.classes) {
            final batchName = cls.sheetName ?? 'Uncategorized'; // Fallback if no sheetName
            groupedClasses.putIfAbsent(batchName, () => []).add(cls);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            itemCount: groupedClasses.length,
            itemBuilder: (context, index) {
              final batchName = groupedClasses.keys.elementAt(index);
              final batchClasses = groupedClasses[batchName]!;

              return Container(
                margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    // Batch Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppConstants.defaultBorderRadius),
                          topRight: Radius.circular(AppConstants.defaultBorderRadius),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_shared, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              batchName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Sync All Combos Button
                          GradientButton(
                            onPressed: () => _syncBatch(context, batchClasses, batchName),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync, size: 16, color: AppTheme.buttonTextColor),
                                SizedBox(width: 4),
                                Text(
                                  'Sync All Combos',
                                  style: TextStyle(fontSize: 12, color: AppTheme.buttonTextColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // TODO: Add Morning/Afternoon Auto Sync Switches here if needed (Data source?)
                    // For now, we just list the classes
                    
                    // List of Classes in this Batch
                    ...batchClasses.map((classModel) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ClassListTile(
                        classModel: classModel,
                        isActive: classProvider.activeClass?.id == classModel.id,
                        onTap: () {
                           _showClassDetails(context, classModel);
                        },
                        onEdit: () => _showEditClassDialog(context, classModel),
                        onDelete: () => _confirmDeleteClass(context, classModel),
                      ),
                    )),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClassDialog(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  // Batch Sync Implementation
  Future<void> _syncBatch(BuildContext context, List<ClassModel> batchClasses, String batchName) async {
    final attendanceProvider = context.read<AttendanceProvider>();
    
    // Determine session type (simple AM/PM check for now as done in individual sync)
    final now = DateTime.now();
    final isAm = now.hour < 12;
    final sessionType = isAm ? SessionType.morning : SessionType.afternoon;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (!HiveService.areBoxesOpen) {
         await HiveService.reopenBoxes();
      }

      int successCount = 0;
      int failCount = 0;
      List<String> failedClasses = [];

      for (final classModel in batchClasses) {
         try {
            await attendanceProvider.ensureAttendanceLoadedForClass(
               classModel.id, 
               attendanceProvider.sessionDate,
               overrideSessionType: sessionType
            );
            
            final records = attendanceProvider.getAttendanceRecordsForClass(classModel.id);
            
            if (records.isEmpty) {
               successCount++; // Treat empty as success (nothing to sync)
               continue;
            }

            await GoogleSheetsService.uploadAttendance(
               classModel: classModel,
               attendanceRecords: records,
               onProgress: (_) {},
            );
            
            await DepartmentSheetService.updateDepartmentSheets(
               classModel: classModel,
               attendanceRecords: records,
               sessionType: sessionType,
            );
            
            successCount++;

         } catch (e) {
            print('Failed to sync ${classModel.className}: $e');
            failCount++;
            failedClasses.add(classModel.className);
         }
      }

      if (context.mounted) {
         Navigator.pop(context); // Close loading
         
         String message;
         Color color;
         if (failCount == 0) {
            message = 'Successfully synced all classes in $batchName!';
            color = AppTheme.successColor;
         } else if (successCount > 0) {
            message = 'Synced $successCount classes. Failed: ${failedClasses.join(", ")}';
            color = AppTheme.warningColor;
         } else {
            message = 'Sync failed for all classes in $batchName.';
            color = AppTheme.errorColor;
         }

         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: color),
         );
      }
    } catch (e) {
      if (context.mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error syncing batch: $e'), backgroundColor: AppTheme.errorColor),
         );
      }
    }
  }

  void _showAddClassDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ClassFormDialog(),
    );
  }

  void _showEditClassDialog(BuildContext context, ClassModel classModel) {
    showDialog(
      context: context,
      builder: (context) => ClassFormDialog(classModel: classModel),
    );
  }

  void _confirmDeleteClass(BuildContext context, ClassModel classModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
          'Are you sure you want to delete "${classModel.className}"? '
          'This will also delete all associated attendance records.',
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          GradientButton(
            onPressedAsync: () async {
              Navigator.of(context).pop();
              await _deleteClass(context, classModel);
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.buttonTextColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClass(BuildContext context, ClassModel classModel) async {
    final classProvider = context.read<ClassProvider>();
    final success = await classProvider.deleteClass(classModel.id);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Class deleted successfully'
                : 'Failed to delete class',
          ),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
          duration: AppConstants.snackbarDuration,
        ),
      );
    }
  }

  void _showClassDetails(BuildContext context, ClassModel classModel) {
      // Re-using logic from SettingsScreen for consistency or adapting it
      // Implementing a simple dialog for now
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(classModel.className),
          content: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Students: ${classModel.students.length}'),
               const SizedBox(height: 8),
               Text('Sheet URL: ${classModel.googleSheetUrl ?? "Not set"}'),
             ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
             GradientButton(
                onPressed: () {
                   context.read<ClassProvider>().setActiveClass(classModel);
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Active class set to ${classModel.className}'), backgroundColor: AppTheme.successColor),
                   );
                },
                child: const Text('Set Active', style: TextStyle(color: AppTheme.buttonTextColor)),
             ),
          ],
        ),
      );
  }
}
