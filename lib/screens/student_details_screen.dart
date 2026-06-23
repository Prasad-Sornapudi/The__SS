import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../providers/user_provider.dart'; // Import UserProvider
import '../services/attendance_sheet_service.dart';
import '../models/student_details.dart'; // Keep for now, might be needed for attendance data
import '../models/class_model.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../services/google_sheets_service.dart'; // Import GoogleSheetsService
import '../models/class_model.dart'; // Import the Student model (from class_model.dart)
import '../widgets/scanner_widgets.dart'; // Import GradientButton
import '../services/firebase_service.dart'; // Import FirebaseService
import '../services/control_sheet_service.dart'; // Import ControlSheetService
import '../models/attendance_record.dart'; // Import AttendanceRecord and AttendanceStatus

class StudentDetailsScreen extends StatefulWidget {
  final Student student;
  final ClassModel classModel;

  const StudentDetailsScreen({super.key, required this.student, required this.classModel});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  StudentDetails? _studentDetails;
  ClassModel? _selectedClass;
  late Student _student; // Add this

  @override
  void initState() {
    super.initState();
    _student = widget.student; // Initialize here
    _selectedClass = widget.classModel;
    _fetchStudentAttendanceDetails();
  }

  Future<void> _fetchStudentAttendanceDetails() async {
    try {
      // Get attendance history from Firebase
      final firebaseService = FirebaseService();
      final attendanceRecords = await firebaseService.getStudentAttendanceHistory(
        classId: widget.classModel.id,
        studentPinNumber: _student.pinNumber,
      );

      // Calculate attendance percentage
      final attendancePercentage = await firebaseService.calculateStudentAttendancePercentage(
        classId: widget.classModel.id,
        studentPinNumber: _student.pinNumber,
      );

      setState(() {
        _studentDetails = StudentDetails(
          name: _student.name,
          rollNumber: _student.pinNumber,
          branch: _student.branch,
          email: _student.email,
          mobile: _student.mobileNumber,
          combo: _student.combo,
          attendancePercentage: attendancePercentage,
          attendedSessions: attendanceRecords.where((record) => record.status == AttendanceStatus.present).length,
          totalSessions: attendanceRecords.length,
        );
      });

      print('✅ Successfully loaded attendance data for student ${_student.pinNumber}');
    } catch (e) {
      print('❌ Error loading attendance data: $e');
      // Handle error, maybe show a snackbar or error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load attendance data: $e')),
        );
      }
    }
  }

  

  @override
  void dispose() {
    super.dispose();
  }

  void _showEditStudentDialog(ClassModel classModel, Student student, bool isAdmin) {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController(text: student.name);
    final _pinController = TextEditingController(text: student.pinNumber);
    final _emailController = TextEditingController(text: student.email);
    final _mobileController = TextEditingController(text: student.mobileNumber);
    final _branchController = TextEditingController(text: student.branch);
    final _comboController = TextEditingController(text: student.combo);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Student', overflow: TextOverflow.ellipsis),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name of the Student',
                      filled: true,
                      fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _pinController,
                    decoration: InputDecoration(
                      labelText: 'Pin Number',
                      filled: true,
                      fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                    ),
                    readOnly: true, // Always read-only
                  ),
                  TextFormField(
                    controller: _branchController,
                    decoration: InputDecoration(
                      labelText: 'Branch',
                      filled: true,
                      fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                    ),
                    readOnly: true, // Always read-only
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Mail ID',
                      filled: true,
                      fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _mobileController,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      filled: true,
                      fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a mobile number';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _comboController,
                    decoration: InputDecoration(
                      labelText: 'Combo',
                      filled: true,
                      fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                    ),
                    readOnly: true, // Always read-only
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Align(
              alignment: Alignment.centerRight,
              child: GradientButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.buttonTextColor)),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GradientButton(
                isEnabled: isAdmin,
                onPressedAsync: isAdmin
                    ? () async {
                        if (_formKey.currentState!.validate()) {
                          final updatedStudent = student.copyWith(
                            name: _nameController.text,
                            pinNumber: _pinController.text,
                            branch: _branchController.text,
                            email: _emailController.text,
                            mobileNumber: _mobileController.text,
                            combo: _comboController.text,
                          );

                          // First update in Firebase
                          try {
                            await FirebaseService().updateStudent(
                              batchId: classModel.sheetName ?? classModel.className,
                              comboName: updatedStudent.combo,
                              updatedStudent: updatedStudent,
                            );
                            print('✅ Student updated in Firebase successfully');
                          } catch (e) {
                            print('❌ Error updating student in Firebase: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update student in Firebase: $e')),
                            );
                            return;
                          }

                          // Then update in Google Sheets using the correct batch-specific service account key
                          final batchServiceAccountKey = await ControlSheetService.getBatchServiceAccountKey(
                            classModel.sheetName ?? classModel.className,
                          );
                          
                          if (batchServiceAccountKey == null || batchServiceAccountKey.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to get service account key for batch')),
                            );
                            return;
                          }
                          
                          // Using web app approach - update Firebase directly
                          await FirebaseService().updateStudent(
                            batchId: classModel.sheetName ?? classModel.className,
                            comboName: updatedStudent.combo,
                            updatedStudent: updatedStudent,
                          );
                          String? errorMessage = null; // No error since we're using Firebase

                          Navigator.of(context).pop();

                          if (errorMessage == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Student updated successfully')),
                            );
                            // Add a small delay to ensure Google Sheets has processed the update
                            await Future.delayed(const Duration(seconds: 2));
                            // Refresh the entire class data to ensure we have the latest data from Google Sheets
                            await Provider.of<ClassProvider>(context, listen: false).refreshClassesFromSheets();
                            // Update the local _studentDetails state with the newly updated student data
                            setState(() {
                              _student = updatedStudent;
                              _studentDetails = _studentDetails!.copyWith(
                                name: updatedStudent.name,
                                rollNumber: updatedStudent.pinNumber,
                                branch: updatedStudent.branch,
                                email: updatedStudent.email,
                                mobile: updatedStudent.mobileNumber,
                                combo: updatedStudent.combo,
                              );
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update student: $errorMessage')),
                            );
                          }
                        }
                      }
                    : null,
                child: const Text('Save', style: TextStyle(color: AppTheme.buttonTextColor)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context); // Get user provider to check if admin
    final isAdmin = userProvider.isAdmin; // Get isAdmin value
    
    return Scaffold(
      backgroundColor: const Color(0xFF040C1B), // Added background color to match dashboard
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Made app bar transparent to match dashboard
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _studentDetails == null
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dashboard Header
                  const Text(
                    'Student Information',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppConstants.defaultPadding),

                  // Student Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    decoration: AppTheme.glassCard(), // Changed to glassCard to match dashboard styling
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                              ),
                              child: const Icon(
                                Icons.school,
                                color: AppTheme.successColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: AppConstants.defaultPadding),
                            const Expanded(
                              child: Text(
                                'Student Details',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (isAdmin && _selectedClass != null) // Only show edit if admin and a class is selected
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                                onPressed: () => _showEditStudentDialog(_selectedClass!, _student, isAdmin), // Pass _student and isAdmin
                              ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),

                        // Student Information Grid
                        Container(
                          padding: const EdgeInsets.all(AppConstants.defaultPadding),
                          decoration: AppTheme.glassCard(), // Changed to glassCard to match dashboard styling
                          child: Column(
                            children: [
                              _buildDetailRow('Name', _studentDetails!.name),
                              const Divider(color: Colors.white24),
                              _buildDetailRow('Roll Number', _studentDetails!.rollNumber),
                              const Divider(color: Colors.white24),
                              _buildDetailRow('Branch', _studentDetails!.branch),
                              const Divider(color: Colors.white24),
                              _buildDetailRow('Email', _studentDetails!.email),
                              const Divider(color: Colors.white24),
                              _buildDetailRow('Mobile', _studentDetails!.mobile),
                              const Divider(color: Colors.white24),
                              _buildDetailRow('Combo', _studentDetails!.combo),
                              const Divider(color: Colors.white24),
                              _buildAttendanceRow(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Attendance Percentage Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _studentDetails!.attendancePercentage >= 75 
                      ? AppTheme.successColor.withOpacity(0.2)
                      : _studentDetails!.attendancePercentage >= 50 
                          ? AppTheme.warningColor.withOpacity(0.2)
                          : AppTheme.errorColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _studentDetails!.attendancePercentage >= 75 
                        ? AppTheme.successColor
                        : _studentDetails!.attendancePercentage >= 50 
                            ? AppTheme.warningColor
                            : AppTheme.errorColor,
                  ),
                ),
                child: Text(
                  '${_studentDetails!.attendancePercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _studentDetails!.attendancePercentage >= 75 
                        ? AppTheme.successColor
                        : _studentDetails!.attendancePercentage >= 50 
                            ? AppTheme.warningColor
                            : AppTheme.errorColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Sessions Info
              Text(
                '${_studentDetails!.attendedSessions}/${_studentDetails!.totalSessions} sessions',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}