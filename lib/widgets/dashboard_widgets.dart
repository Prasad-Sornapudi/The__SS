import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../providers/attendance_provider.dart';
import '../providers/class_provider.dart'; // Add this import
import '../providers/sync_progress_provider.dart'; // Add this import
import '../services/auto_upload_service.dart';
import '../services/google_sheets_service.dart';
import '../services/department_sheet_service.dart';
import '../services/hive_service.dart';
import '../services/enhanced_auto_sync_service.dart';
import '../models/attendance_record.dart';
import '../models/class_model.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/scanner_widgets.dart'; // Import GradientButton
import '../widgets/combo_dropdown.dart'; // Add this import

// New Dashboard Header Widget with enhanced features
class EnhancedDashboardHeader extends StatelessWidget {
  final ClassModel activeClass;
  final DateTime sessionDate;
  final Function(DateTime) onDateChanged;
  final Function(ClassModel?) onClassChanged;

  const EnhancedDashboardHeader({
    super.key,
    required this.activeClass,
    required this.sessionDate,
    required this.onDateChanged,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.defaultPadding, 
        0, 
        AppConstants.defaultPadding, 
        AppConstants.defaultPadding
      ),
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: AppTheme.glassContainer(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batch Selection Dropdown - Updated to show batches instead of individual classes
          Row(
            children: [
              Expanded(
                child: Consumer<ClassProvider>(
                  builder: (context, classProvider, child) {
                    // Extract unique batches from all classes
                    final uniqueBatches = classProvider.classes
                        .map((c) => c.sheetName ?? c.className)
                        .toSet()
                        .toList()
                      ..sort();
                    
                    // Find the currently selected batch
                    final currentBatch = activeClass.sheetName ?? activeClass.className;
                    
                    return CustomDropdown<String?>(
                      value: uniqueBatches.contains(currentBatch) ? currentBatch : null,
                      hintText: 'Select a batch',
                      items: uniqueBatches.map((batchName) {
                        return DropdownMenuItem<String>(
                          value: batchName,
                          child: Text(
                            batchName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newBatch) async {
                        if (newBatch != null) {
                          final classProvider = context.read<ClassProvider>();
                          final attendanceProvider = context.read<AttendanceProvider>();
                          final autoUploadService = context.read<AutoUploadService>();
                          final enhancedAutoSyncService = EnhancedAutoSyncService();
                          
                          // Find the first class in this batch to select as active
                          final firstClassInBatch = classProvider.classes.firstWhere(
                            (c) => (c.sheetName ?? c.className) == newBatch,
                            orElse: () => classProvider.classes.first,
                          );
                          
                          await classProvider.setActiveClass(firstClassInBatch);
                          // Always load attendance data for the newly selected class
                          await attendanceProvider.loadAttendanceForSession(
                              firstClassInBatch.id, attendanceProvider.sessionDate);
                          // Also set the active class ID in the attendance provider
                          attendanceProvider.setActiveClassId(firstClassInBatch.id);
                          
                          // Start auto-upload service with the new class
                          autoUploadService.startAutoUpload(firstClassInBatch, triggerSync: true);
                          
                          // DISABLED: Enhanced auto sync is now disabled
                          // enhancedAutoSyncService.startAutoSync(firstClassInBatch, triggerSync: true);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: AppConstants.smallPadding),
              Icon(
                Icons.school,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppConstants.smallPadding),
              Text(
                '${sessionDate.day}/${sessionDate.month}/${sessionDate.year}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Enhanced Summary Cards with Circular Progress Indicator
class EnhancedSummaryCards extends StatelessWidget {
  final AttendanceSessionSummary summary;
  final ClassModel activeClass;

  const EnhancedSummaryCards({
    super.key,
    required this.summary,
    required this.activeClass,
  });

  @override
  Widget build(BuildContext context) {
    final attendancePercentage = summary.totalStudents > 0 
        ? (summary.presentCount / summary.totalStudents) * 100 
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
      child: Column(
        children: [
          // Circular Progress Card with Combo Dropdown
          Container(
            width: double.infinity,
            decoration: AppTheme.glassCard(
              borderRadius: AppConstants.defaultBorderRadius,
            ),
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              children: [
                // Combo selection dropdown at the top
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 150,
                    child: ComboDropdown(activeClass: activeClass),
                  ),
                ),
                const SizedBox(height: AppConstants.defaultPadding),
                Text(
                  'Attendance Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppConstants.defaultPadding),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: Transform.rotate(
                                  angle: math.pi, // Rotate 180 degrees to start from bottom
                                  child: CircularProgressIndicator(
                                    value: attendancePercentage / 100,
                                    strokeWidth: 10,
                                    backgroundColor: AppTheme.glassBorder,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      attendancePercentage >= 75 
                                          ? AppTheme.successColor 
                                          : (attendancePercentage >= 50 
                                              ? AppTheme.warningColor 
                                              : AppTheme.errorColor),
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${attendancePercentage.toStringAsFixed(0)}%',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                                  Text(
                                    'Attendance',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatCard(
                            context,
                            'Total Students',
                            summary.totalStudents.toString(),
                            Icons.people,
                          ),
                          const SizedBox(height: AppConstants.smallPadding),
                          _buildStatCard(
                            context,
                            'Present',
                            summary.presentCount.toString(),
                            Icons.check_circle,
                            color: AppTheme.successColor,
                          ),
                          const SizedBox(height: AppConstants.smallPadding),
                          _buildStatCard(
                            context,
                            'Absent',
                            summary.absentCount.toString(),
                            Icons.cancel,
                            color: AppTheme.errorColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.smallPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppConstants.smallPadding),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color ?? Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  final String title;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  const _AttendanceStat({
    required this.title,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppConstants.smallPadding),
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// Sync Controls Widget
class _SyncControls extends StatefulWidget {
  final ClassModel activeClass;

  const _SyncControls({required this.activeClass});

  @override
  State<_SyncControls> createState() => _SyncControlsState();
}

class _SyncControlsState extends State<_SyncControls> {

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.glassCard(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          // Sync Now Button and Time Remaining
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  onPressed: () => _triggerSync(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync, size: 20, color: AppTheme.buttonTextColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Sync Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.buttonTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.defaultPadding),
              // Time remaining display
              Consumer<AutoUploadService>(
                builder: (context, autoUploadService, child) {
                  final timeRemaining = _getTimeUntilNextSync(autoUploadService);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.smallPadding,
                      vertical: AppConstants.smallPadding,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.glassBorder,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          timeRemaining,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSync(BuildContext context) async {
    final autoUploadService = context.read<AutoUploadService>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final enhancedAutoSyncService = EnhancedAutoSyncService(); // Get the singleton instance
    final syncProgressProvider = context.read<SyncProgressProvider>(); // Add this
    
    // Start sync progress
    syncProgressProvider.startSync('Syncing data...');
    
    try {
      // Trigger manual sync using enhanced auto sync service
      await enhancedAutoSyncService.triggerManualSync();
      
      // Complete sync progress
      syncProgressProvider.completeSync('Sync completed successfully');
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
      
      // DON'T refresh attendance data as it would override the comprehensive list
      // The syncWithCompleteUnionDisplay already updated the UI with the union of local and remote data
      // await attendanceProvider.loadAttendanceForSession(
      //   widget.activeClass.id, 
      //   attendanceProvider.sessionDate,
      // );
    } catch (e) {
      // Handle error
      syncProgressProvider.errorSync('Sync failed: $e');
      
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _getTimeUntilNextSync(AutoUploadService autoUploadService) {
    if (autoUploadService.lastUploadTime == null) {
      return 'No sync yet';
    }
    
    final lastSync = autoUploadService.lastUploadTime!;
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}

class UploadDialog extends StatefulWidget {
  final ClassModel activeClass;
  final List<AttendanceRecord> unsyncedRecords;
  final Function(List<String>) onUploadSuccess;
  final Function(String) onUploadError;

  const UploadDialog({
    super.key,
    required this.activeClass,
    required this.unsyncedRecords,
    required this.onUploadSuccess,
    required this.onUploadError,
  });

  @override
  State<UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<UploadDialog> {
  bool _isUploading = false;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _isTestingConnection = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        decoration: AppTheme.glassCard(
          borderRadius: AppConstants.defaultBorderRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_upload,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Text(
                  'Upload to Google Sheets',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'Upload ${widget.unsyncedRecords.length} attendance records to Google Sheets?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            if (_isUploading) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppTheme.glassBorder,
              ),
              const SizedBox(height: AppConstants.smallPadding),
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                ),
              ),
            ] else if (_isTestingConnection) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppConstants.smallPadding),
              const Text('Testing connection...'),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _testConnection,
                    child: const Text('Test Connection'),
                  ),
                  const SizedBox(width: AppConstants.smallPadding),
                  GradientButton(
                    onPressed: _startUpload,
                    child: const Text('Upload', style: TextStyle(color: AppTheme.buttonTextColor)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
    });

    try {
      print('=== TESTING GOOGLE SHEETS CONNECTION ===');
      print('Class model: ${widget.activeClass.className}');
      print('Class ID: ${widget.activeClass.id}');
      print('Service account key available: ${widget.activeClass.serviceAccountKey != null}');
      
      final result = await GoogleSheetsService.testGoogleSheetsConnection(widget.activeClass);
      
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
        
        if (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Sheets connection successful!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Sheets connection failed. Check logs for details.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Connection test error: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _startUpload() async {
    final attendanceProvider = context.read<AttendanceProvider>(); // Add this
    final syncProgressProvider = context.read<SyncProgressProvider>(); // Add this
    
    setState(() {
      _isUploading = true;
      _progress = 0.0;
      _statusMessage = 'Preparing upload...';
    });

    try {
      print('=== STARTING UPLOAD PROCESS (WEB APP APPROACH) ===');
      print('Class: ${widget.activeClass.className}');
      print('Unsynced records count: ${widget.unsyncedRecords.length}');
      
      // Debug unsynced records
      print('Unsynced records details:');
      for (int i = 0; i < widget.unsyncedRecords.length; i++) {
        final record = widget.unsyncedRecords[i];
        print('  Record $i: ${record.studentName} (${record.studentPinNumber}) - ${record.status} on ${record.sessionDate}');
      }
      
      // Start sync progress
      syncProgressProvider.startSync('Uploading attendance data directly to Google Sheets...');
      
      // Use the new direct Google Sheets approach
      final result = await attendanceProvider.syncDirectToGoogleSheets(
        classModel: widget.activeClass,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _statusMessage = 'Uploading to Google Sheets... ${(progress * 100).toInt()}%';
            });
            
            // Update sync progress provider
            syncProgressProvider.updateProgress(progress, 'Uploading to Google Sheets... ${(progress * 100).toInt()}%');
          }
        },
      );      if (result.isSuccess) {
        print('✅ Upload jobs created successfully');
        print('Processed record IDs: ${result.uploadedRecordIds}');
        widget.onUploadSuccess(result.uploadedRecordIds ?? []);
        
        // Complete sync progress
        syncProgressProvider.completeSync('Attendance data uploaded successfully to Google Sheets.');
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        print('❌ Upload jobs creation failed: ${result.message}');
        
        // Handle error in sync progress
        syncProgressProvider.errorSync('Direct Google Sheets upload failed: ${result.message}');
        
        throw Exception(result.message);
      }
    } catch (e, stackTrace) {
      print('Upload error: $e');
      print('Stack trace: $stackTrace');
      
      // Handle error in sync progress
      syncProgressProvider.errorSync('Direct Google Sheets upload error: $e');
      
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
      widget.onUploadError(e.toString());
    }
  }
}

// Upload Progress Widget
class UploadProgressWidget extends StatelessWidget {
  const UploadProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AutoUploadService>(
      builder: (context, autoUploadService, child) {
        // Determine if auto-upload service is active for display
        final isAutoUploadActive = autoUploadService.isUploading || 
            autoUploadService.lastUploadTime != null || 
            autoUploadService.lastUploadError != null;

        if (!isAutoUploadActive) {
          return const SizedBox.shrink();
        }

        final isUploading = autoUploadService.isUploading;
        final hasError = autoUploadService.lastUploadError != null;
        final statusMessage = _getStatusMessage(autoUploadService);
        final progressValue = autoUploadService.isUploading 
            ? autoUploadService.uploadProgress 
            : null; // Indeterminate for upload

        return Container(
          margin: const EdgeInsets.fromLTRB(
            AppConstants.defaultPadding, 
            0, 
            AppConstants.defaultPadding, 
            AppConstants.defaultPadding
          ),
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          decoration: AppTheme.glassCard(
            borderRadius: AppConstants.defaultBorderRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isUploading
                        ? Icons.cloud_upload
                        : (hasError ? Icons.error : Icons.cloud_done),
                    color: isUploading
                        ? AppTheme.primaryColor
                        : (hasError ? AppTheme.errorColor : AppTheme.successColor),
                    size: 24,
                  ),
                  const SizedBox(width: AppConstants.defaultPadding),
                  Expanded(
                    child: Text(
                      isUploading
                          ? 'Syncing to Google Sheets...'
                          : 'Sync Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (autoUploadService.totalUploaded > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.smallPadding, 
                        vertical: 4
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.successColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${autoUploadService.totalUploaded} uploaded',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              if (isUploading) ...[
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: AppTheme.glassBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  minHeight: 8,
                ),
                const SizedBox(height: AppConstants.defaultPadding),
              ],
              Text(
                statusMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: hasError
                      ? AppTheme.errorColor
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusMessage(AutoUploadService autoUploadService) {
    return autoUploadService.statusMessage;
  }
}

// No Active Class Widget
class NoActiveClassDashboard extends StatelessWidget {
  const NoActiveClassDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppConstants.defaultPadding),
        padding: const EdgeInsets.all(AppConstants.largePadding),
        // Removed glassCard decoration to place options directly on background
        // decoration: AppTheme.glassCard(
        //   borderRadius: AppConstants.defaultBorderRadius,
        // ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.class_,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppConstants.largePadding),
            Text(
              'No Active Class Selected',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'Please select a batch to get started',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.largePadding),
            Consumer<ClassProvider>(
              builder: (context, classProvider, child) {
                if (!classProvider.hasClasses) {
                  return Column(
                    children: [
                      Text(
                        'No classes available. Please add classes in Settings.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppConstants.defaultPadding),
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          onPressed: () {
                            // Navigate to settings tab
                            DefaultTabController.of(context).animateTo(2);
                          },
                          child: const Text(
                            'Go to Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.buttonTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Extract unique batches from all classes
                final uniqueBatches = classProvider.classes
                    .map((c) => c.sheetName ?? c.className)
                    .toSet()
                    .toList()
                  ..sort();

                // Show batch selection instead of individual classes
                return Column(
                  children: [
                    Text(
                      'Select a Batch',
                      style: GoogleFonts.agdasima(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),
                    // List of batches to select from
                    SizedBox(
                      height: 300, // Fixed height for the list
                      child: ListView.builder(
                        itemCount: uniqueBatches.length,
                        itemBuilder: (context, index) {
                          final batchName = uniqueBatches[index];
                          // Count total students in this batch
                          final totalStudents = classProvider.classes
                              .where((c) => (c.sheetName ?? c.className) == batchName)
                              .fold(0, (sum, classModel) => sum + classModel.students.length);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
                            decoration: BoxDecoration(
                              gradient: AppTheme.appBackgroundGradient,
                              borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                              border: Border.all(
                                color: const Color.fromARGB(255, 6, 30, 85),
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: -2,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ListTile(
                              title: Text(
                                batchName,
                                style: GoogleFonts.agdasima(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                '$totalStudents students',
                                style: GoogleFonts.agdasima(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: AppTheme.techwingyellow,
                                size: 16,
                              ),
                              onTap: () {
                                // Navigate to batch selection flow
                                Navigator.pushNamed(context, '/batch-selection');
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Dashboard Header Widget
class DashboardHeader extends StatelessWidget {
  final ClassModel activeClass;
  final DateTime sessionDate;
  final Function(DateTime) onDateChanged;
  final Function(ClassModel?) onClassChanged;

  const DashboardHeader({
    super.key,
    required this.activeClass,
    required this.sessionDate,
    required this.onDateChanged,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppConstants.defaultPadding, 
        0, 
        AppConstants.defaultPadding, 
        0
      ),
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: AppTheme.glassContainer(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Selection Dropdown
          Row(
            children: [
              Expanded(
                child: Consumer<ClassProvider>(
                  builder: (context, classProvider, child) {
                    return CustomDropdown<ClassModel?>(
                      value: classProvider.classes.contains(activeClass) ? activeClass : null,
                      hintText: 'Select a class',
                      items: classProvider.classes.isNotEmpty
                          ? classProvider.classes.map((classModel) {
                              return DropdownMenuItem<ClassModel>(
                                value: classModel,
                                child: Text(
                                  classModel.className,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList()
                          : [],
                      onChanged: (ClassModel? newClass) async {
                        if (newClass != null) {
                          final classProvider = context.read<ClassProvider>();
                          final attendanceProvider = context.read<AttendanceProvider>();
                          final autoUploadService = context.read<AutoUploadService>();
                          final enhancedAutoSyncService = EnhancedAutoSyncService(); // Get the singleton instance
                          
                          // Ensure attendance data is loaded for the selected class
                          await attendanceProvider.ensureAttendanceLoadedForClass(newClass.id, attendanceProvider.sessionDate);
                          await classProvider.setActiveClass(newClass);
                          // Also set the active class ID in the attendance provider
                          attendanceProvider.setActiveClassId(newClass.id);
                          
                          // Start auto-upload service with the new class
                          // Start auto-upload if configured with triggerSync: true to ensure proper initialization
                          autoUploadService.startAutoUpload(newClass, triggerSync: true);
                          
                          // DISABLED: Enhanced auto sync is now disabled
                          // Start enhanced auto sync with triggerSync: true to ensure proper initialization
                          // enhancedAutoSyncService.startAutoSync(newClass, triggerSync: true);
                          
                          onClassChanged(newClass);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: AppConstants.smallPadding),
              Icon(
                Icons.school,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppConstants.smallPadding),
              Text(
                '${sessionDate.day}/${sessionDate.month}/${sessionDate.year}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Summary Cards Widget
class SummaryCards extends StatelessWidget {
  final AttendanceSessionSummary summary;

  const SummaryCards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Present',
                  count: summary.presentCount,
                  total: summary.totalStudents,
                  color: AppTheme.successColor,
                  icon: Icons.check_circle,
                ),
              ),
              const SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: _SummaryCard(
                  title: 'Absent',
                  count: summary.absentCount,
                  total: summary.totalStudents,
                  color: AppTheme.errorColor,
                  icon: Icons.cancel,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.smallPadding),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Total',
                  count: summary.totalStudents,
                  total: summary.totalStudents,
                  color: AppTheme.primaryColor,
                  icon: Icons.people,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    
    return Container(
      height: 100,
      decoration: AppTheme.glassCard(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                if (title != 'Total')
                  Text(
                    '$percentage%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Present Students Tab
class PresentStudentsTab extends StatelessWidget {
  final List<AttendanceRecord> attendanceRecords;
  final String searchQuery;
  final Function(String) onRevokeAttendance;

  const PresentStudentsTab({
    super.key,
    required this.attendanceRecords,
    required this.searchQuery,
    required this.onRevokeAttendance,
  });

  // Helper method to get student branch by pin number
  String _getStudentBranch(BuildContext context, String pinNumber) {
    final classProvider = context.read<ClassProvider>();
    if (classProvider.hasActiveClass) {
      final student = classProvider.activeClass!.students.firstWhere(
        (student) => student.pinNumber == pinNumber,
        orElse: () => Student(
          name: 'Unknown',
          pinNumber: pinNumber,
          email: '',
          phone: '',
          branch: 'Unknown',
          mobileNumber: '',
          combo: '',
          securityCodes: [],
        ),
      );
      return student.branch;
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = attendanceRecords.where((record) {
      return record.studentName.toLowerCase().contains(searchQuery.toLowerCase()) ||
             record.studentPinNumber.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'No present students found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'Students who have been marked present will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: filteredRecords.length,
      itemBuilder: (context, index) {
        final record = filteredRecords[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.successColor,
                  child: Text(
                    record.studentName.isNotEmpty ? record.studentName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.studentName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pin: ${record.studentPinNumber}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'delete' || value == 'mark_absent') {
                      onRevokeAttendance(record.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'mark_absent',
                      child: Row(
                        children: [
                          Icon(Icons.undo, color: AppTheme.warningColor, size: 20),
                          SizedBox(width: 8),
                          Text('Mark as Absent'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: AppTheme.errorColor, size: 20),
                          SizedBox(width: 8),
                          Text('Delete Record'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Absent Students Tab
class AbsentStudentsTab extends StatelessWidget {
  final List<Student> absentStudents;
  final String searchQuery;

  const AbsentStudentsTab({
    super.key,
    required this.absentStudents,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final filteredStudents = absentStudents.where((student) {
      return student.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
             student.pinNumber.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cancel_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'No absent students found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'All students are marked as present',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: filteredStudents.length,
      itemBuilder: (context, index) {
        final student = filteredStudents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.errorColor,
                  child: Text(
                    student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pin: ${student.pinNumber}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.cancel,
                  color: AppTheme.errorColor,
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// All Students Tab
class AllStudentsTab extends StatelessWidget {
  final List<StudentAttendanceStatus> studentsWithStatus;
  final String searchQuery;

  const AllStudentsTab({
    super.key,
    required this.studentsWithStatus,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final filteredStudents = studentsWithStatus.where((studentStatus) {
      final student = studentStatus.student;
      return student.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
             student.pinNumber.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            Text(
              'No students found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'Try adjusting your search query',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: filteredStudents.length,
      itemBuilder: (context, index) {
        final studentStatus = filteredStudents[index];
        final student = studentStatus.student;
        final isPresent = studentStatus.isPresent;
        
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isPresent ? AppTheme.successColor : AppTheme.errorColor,
                  child: Text(
                    student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.defaultPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pin: ${student.pinNumber}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (studentStatus.attendanceRecord != null) ...[
                        // Removed the timestamp line to show only roll number
                      ],
                    ],
                  ),
                ),
                Icon(
                  isPresent ? Icons.check_circle : Icons.cancel,
                  color: isPresent ? AppTheme.successColor : AppTheme.errorColor,
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}