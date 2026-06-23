import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/session_model.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/class_model.dart';
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/auto_upload_service.dart'; // Add this import
import '../services/enhanced_auto_sync_service.dart'; // Add this import
import '../services/csv_service.dart';
import '../services/sheet_data_service.dart';
import '../services/google_sheets_service.dart';
import '../services/hive_service.dart';
import '../services/department_sheet_service.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/scanner_widgets.dart';

class ClassListTile extends StatefulWidget {
  final ClassModel classModel;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ClassListTile({
    super.key,
    required this.classModel,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ClassListTile> createState() => _ClassListTileState();
}

class _ClassListTileState extends State<ClassListTile> {
  bool _isSyncing = false;

  Future<void> _syncClass() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      // Get all attendance records for today (including both present and absent)
      final today = DateTime.now();
      final todayRecords = HiveService.getAttendanceForClass(widget.classModel.id, DateTime(today.year, today.month, today.day));
      
      print('Found ${todayRecords.length} total attendance records for today for class ${widget.classModel.className}');
      
      if (todayRecords.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No attendance records for today for this class'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
        return;
      }

      final result = await GoogleSheetsService.uploadAttendance(
        classModel: widget.classModel,
        attendanceRecords: todayRecords,
        onProgress: (progress) {
          // Progress callback
        },
      );

      if (result.isSuccess) {
        // Mark all today's records as synced
        await HiveService.markAttendanceAsSynced(result.uploadedRecordIds ?? []);
        
        // Determine session type based on current time
        final now = DateTime.now();
        final isAm = now.hour < 12; // Simple AM/PM check
        final sessionType = isAm ? SessionType.morning : SessionType.afternoon;

        // Update department sheets with present roll numbers
        print('Updating department sheets for class ${widget.classModel.className}');
        final departmentUpdateError = await DepartmentSheetService.updateDepartmentSheets(
          classModel: widget.classModel,
          attendanceRecords: todayRecords,
          sessionType: sessionType,
        );
        
        if (departmentUpdateError == null) {
          print('✅ Department sheets updated successfully for class ${widget.classModel.className}');
        } else {
          print('⚠️ Failed to update department sheets for class ${widget.classModel.className}: $departmentUpdateError');
        }
        
        if (mounted) {
          String message = 'Synced ${result.uploadedRecordIds?.length ?? 0} records for ${widget.classModel.className}';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync failed: ${result.message}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: AppConstants.smallPadding,
      ),
      decoration: AppTheme.glassCard(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppConstants.defaultPadding),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.classModel.className,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (widget.isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${widget.classModel.students.length} students',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last updated: ${_formatDate(widget.classModel.updatedAt ?? DateTime.now())}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sync button for this class (bigger and more accessible)
            SizedBox(
              width: 120,
              child: GradientButton(
                isEnabled: !_isSyncing,
                onPressed: _isSyncing ? () {} : _syncClass,
                child: _isSyncing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.buttonTextColor),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sync, size: 20, color: AppTheme.buttonTextColor),
                          const SizedBox(width: 8),
                          Text(
                            _isSyncing ? 'Syncing...' : 'Sync Now',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.buttonTextColor),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    widget.onEdit();
                    break;
                  case 'delete':
                    widget.onDelete();
                    break;
                  case 'make_active':
                    final attendanceProvider = context.read<AttendanceProvider>(); // Get attendance provider
                    
                    // Ensure attendance data is loaded for the selected class
                    await attendanceProvider.ensureAttendanceLoadedForClass(widget.classModel.id, attendanceProvider.sessionDate);
                    context.read<ClassProvider>().setActiveClass(widget.classModel);
                    // Also set the active class ID in the attendance provider
                    attendanceProvider.setActiveClassId(widget.classModel.id);
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!widget.isActive)
                  const PopupMenuItem(
                    value: 'make_active',
                    child: ListTile(
                      leading: Icon(Icons.check_circle),
                      title: Text('Make Active'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: AppTheme.errorColor),
                    title: Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: widget.onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Format according to AppConstants.columnDateFormat (dd/MM/yyyy)
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class ClassFormDialog extends StatefulWidget {
  final ClassModel? classModel;

  const ClassFormDialog({super.key, this.classModel});

  @override
  State<ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<ClassFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  final _sheetUrlController = TextEditingController();
  final _batchSizeController = TextEditingController();

  String? _csvFilePath;
  String? _serviceAccountKey;
  List<Student> _students = [];
  bool _isLoading = false;
  // UploadType _selectedUploadType = UploadType.manualSync; // Removed - using Firebase real-time sync

  bool get isEditing => widget.classModel != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _populateFields();
    } else {
      _batchSizeController.text = AppConstants.defaultUploadBatchSize.toString();
    }
  }

  void _populateFields() {
    final classModel = widget.classModel!;
    _classNameController.text = classModel.className;
    _sheetUrlController.text = classModel.googleSheetUrl ?? '';
    // _batchSizeController.text = classModel.uploadBatchSize.toString(); // Removed - field doesn't exist
    // _selectedUploadType = classModel.uploadType; // Removed - using Firebase real-time sync
    _csvFilePath = classModel.csvFilePath;
    _serviceAccountKey = classModel.serviceAccountKey;
    _students = List.from(classModel.students);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing ? 'Edit Class' : 'Add Class',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: AppConstants.defaultPadding),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Class Name
                      TextFormField(
                        controller: _classNameController,
                        decoration: InputDecoration(
                          labelText: 'Class Name *',
                          hintText: 'e.g., CSE A Section',
                          filled: true,
                          fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                            borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                            borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Class name is required';
                          }
                          if (value.trim().length < AppConstants.minClassNameLength) {
                            return 'Class name must be at least ${AppConstants.minClassNameLength} characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppConstants.defaultPadding),

                      // Google Sheet URL
                      TextFormField(
                        controller: _sheetUrlController,
                        decoration: InputDecoration(
                          labelText: 'Google Sheet URL *',
                          hintText: 'https://docs.google.com/spreadsheets/d/...',
                          filled: true,
                          fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                            borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                            borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Google Sheet URL is required';
                          }
                          if (!RegExp(AppConstants.sheetUrlPattern).hasMatch(value)) {
                            return 'Invalid Google Sheet URL format';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppConstants.defaultPadding),

                      // Upload Batch Size - REMOVED (using Firebase real-time sync)
                      /*
                      TextFormField(
                        controller: _batchSizeController,
                        decoration: InputDecoration(
                          labelText: 'Upload Batch Size',
                          hintText: '50',
                          helperText: 'Number of records to upload at once (1-100)',
                          filled: true,
                          fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                            borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                            borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Batch size is required';
                          }
                          final size = int.tryParse(value);
                          if (size == null || size < 1 || size > 100) {
                            return 'Batch size must be between 1 and 100';
                          }
                          return null;
                        },
                      ),
                      */

                      // Upload Type Dropdown - REMOVED (using Firebase real-time sync)

                      const SizedBox(height: AppConstants.largePadding),

                      // Service Account Key File
                      _buildFileSection(
                        title: 'Google Service Account Key',
                        subtitle: 'JSON file containing service account credentials',
                        fileName: _serviceAccountKey != null ? 'Service Account Key Loaded' : null,
                        onTap: _pickServiceAccountKey,
                        icon: Icons.key,
                      ),

                      const SizedBox(height: AppConstants.defaultPadding),

                      // Student Data Source
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppConstants.defaultPadding),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.table_chart, size: 32),
                                const SizedBox(width: AppConstants.defaultPadding),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Student Roster Source',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Students can be loaded from CSV or Google Sheets',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.defaultPadding),
                            // Option 1: Load from CSV
                            if (_csvFilePath == null && _students.isEmpty)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFileSection(
                                      title: 'Load from CSV',
                                      subtitle: 'Upload a CSV file with student information',
                                      fileName: null,
                                      onTap: _pickCsvFile,
                                      icon: Icons.upload_file,
                                    ),
                                  ),
                                ],
                              ),

                            // Display loaded students info
                            if (_students.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(AppConstants.smallPadding),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppTheme.successColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
'Loaded from CSV: ${_students.length} students',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.successColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _students = [];
                                          _csvFilePath = null;
                                        });
                                      },
                                      icon: const Icon(Icons.refresh),
                                      tooltip: 'Reload student data',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Debug information for student data
                      if (_students.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Student Data Info:',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[300],
                                ),
                              ),
                              Text(
                                'Students loaded: ${_students.length}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (_students.isNotEmpty)
                                Text(
                                  'First student: ${_students.first.name} (${_students.first.pinNumber})',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              Text(
                                'Source: CSV File',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: AppConstants.largePadding),

                      // Status Section
                      if (_students.isNotEmpty || _serviceAccountKey != null)
                        Container(
                          padding: const EdgeInsets.all(AppConstants.defaultPadding),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ready to Save',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppTheme.successColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_students.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: AppTheme.successColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
'CSV loaded: ${_students.length} students',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              if (_serviceAccountKey != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: AppTheme.successColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Service account key loaded',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),

                      const SizedBox(height: AppConstants.largePadding),

                      // Students Preview
                      if (_students.isNotEmpty) ...[
                        Text(
                          'Student Preview (${_students.length} students)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppConstants.smallPadding),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                          ),
                          child: ListView.builder(
                            itemCount: _students.take(10).length,
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              return ListTile(
                                dense: true,
                                title: Text(student.name),
                                subtitle: Text(student.pinNumber),
                                trailing: Text(student.branch),
                              );
                            },
                          ),
                        ),
                        if (_students.length > 10)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'And ${_students.length - 10} more students...',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: AppTheme.primaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.smallPadding),
                GradientButton(
                  isEnabled: !_isLoading,
                  onPressed: _isLoading ? null : _saveClass,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Update' : 'Create', style: const TextStyle(color: AppTheme.buttonTextColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSection({
    required String title,
    required String subtitle,
    String? fileName,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: AppConstants.defaultPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fileName ?? subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fileName != null 
                            ? AppTheme.successColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                fileName != null ? Icons.check_circle : Icons.upload_file,
                color: fileName != null 
                    ? AppTheme.successColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickServiceAccountKey() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.allowedJsonExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String content;
        
        // Handle web vs mobile file reading
        if (kIsWeb || file.bytes != null) {
          // Web platform or bytes available - use bytes
          if (file.bytes == null) {
            throw Exception('File content not available');
          }
          content = String.fromCharCodes(file.bytes!);
        } else if (file.path != null) {
          // Mobile platform - use path
          final ioFile = File(file.path!);
          content = await ioFile.readAsString();
        } else {
          throw Exception('Unable to read file content');
        }
        
        // Validate JSON format
        final jsonData = json.decode(content);
        if (jsonData['type'] != 'service_account') {
          throw Exception('Invalid service account key file');
        }

        setState(() {
          _serviceAccountKey = content;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service account key loaded successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading service account key: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _pickCsvFile() async {
    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.allowedCsvExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        print('File selected: ${file.name}, size: ${file.size} bytes');
        
        CsvParseResult parseResult;
        
        // Handle web vs mobile file reading
        if (kIsWeb || file.bytes != null) {
          // Web platform or bytes available - use bytes and parse content directly
          if (file.bytes == null) {
            throw Exception('File content not available');
          }
          final content = String.fromCharCodes(file.bytes!);
          print('File content length: ${content.length} characters');
          print('First 200 characters: ${content.length > 200 ? content.substring(0, 200) : content}');
          parseResult = await CsvService.parseStudentCsvFromContent(content);
        } else if (file.path != null) {
          // Mobile platform - use path
          print('Using file path: ${file.path}');
          parseResult = await CsvService.parseStudentCsv(file.path!);
        } else {
          throw Exception('Unable to read file content');
        }

        print('Parse result success: ${parseResult.isSuccess}');
        if (parseResult.isSuccess) {
          print('Students parsed: ${parseResult.students?.length ?? 0}');
        } else {
          print('Parse error: ${parseResult.errorMessage}');
        }

        if (parseResult.isSuccess && parseResult.students != null && parseResult.students!.isNotEmpty) {
          setState(() {
            // For web platforms, store the file name; for mobile, store the full path
            _csvFilePath = kIsWeb ? file.name : (file.path ?? file.name);
            _students = parseResult.students!;
          });

          print('Students set in state: ${_students.length}');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('CSV loaded: ${_students.length} students'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        } else {
          // Clear any previous students if parsing failed
          setState(() {
            _students = [];
            _csvFilePath = null;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('CSV Error: ${parseResult.errorMessage ?? "Unknown error"}'),
                backgroundColor: AppTheme.errorColor,
                duration: AppConstants.errorSnackbarDuration,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Exception in _pickCsvFile: $e');
      // Clear any previous students if there was an exception
      setState(() {
        _students = [];
        _csvFilePath = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading CSV: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all required fields'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    if (_students.isEmpty) {
      print('Save validation failed: Students list is empty (${_students.length})');
      print('CSV file path: $_csvFilePath');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload a student roster CSV file'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    if (_serviceAccountKey == null || _serviceAccountKey!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload a service account key file'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    try {
      setState(() => _isLoading = true);

      final classProvider = context.read<ClassProvider>();
      final now = DateTime.now();

      final classModel = ClassModel(
        id: isEditing ? widget.classModel!.id : DateTime.now().millisecondsSinceEpoch.toString(),
        className: _classNameController.text.trim(),
        classCode: '', // Add missing parameter
        sheetId: '', // Add missing parameter
        googleSheetUrl: _sheetUrlController.text.trim(),
        serviceAccountKey: _serviceAccountKey ?? '',
        attendanceSheetName: '', // Add missing parameter
        csvFilePath: _csvFilePath,
        students: _students,
        // uploadBatchSize: int.parse(_batchSizeController.text), // Removed - field doesn't exist
        // uploadType: _selectedUploadType, // Removed - using Firebase real-time sync
        createdAt: isEditing ? widget.classModel!.createdAt : now,
        updatedAt: now,
      );

      // Debug information
      print('Attempting to save class with ${_students.length} students');
      print('CSV file path: $_csvFilePath');
      print('Service account key loaded: ${_serviceAccountKey != null}');

      final success = await classProvider.saveClass(classModel);
      
      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Class updated successfully' : 'Class created successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save class. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      print('Error saving class: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving class: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _sheetUrlController.dispose();
    _batchSizeController.dispose();
    super.dispose();
  }
}

// Helper Widgets for Settings Screen

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
          decoration: AppTheme.glassCard(borderRadius: 12),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(height: 1, color: AppTheme.glassBorder),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: Colors.white70),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right, color: Colors.white54)
              : null),
      onTap: onTap,
    );
  }
}

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    // This is a placeholder for the connection status.
    // In a real app, you might check ConnectivityResult or an implementation of ConnectivityService.
    return const ListTile(
      leading: Icon(Icons.wifi, color: AppTheme.successColor),
      title: Text('Online', style: TextStyle(color: Colors.white)),
      subtitle: Text('Connected to internet', style: TextStyle(color: Colors.white70)),
    );
  }
}
