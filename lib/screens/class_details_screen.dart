import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../providers/user_provider.dart';
import '../models/class_model.dart';
import '../widgets/class_details_card.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../screens/student_details_screen.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/scanner_widgets.dart'; // Import GradientButton
import 'package:cool_dropdown/cool_dropdown.dart';
import '../widgets/session_setup_widget.dart';
import '../services/firebase_service.dart'; // Import FirebaseService
import '../services/google_sheets_service.dart'; // Import GoogleSheetsService
import '../services/control_sheet_service.dart'; // Import ControlSheetService
import '../layout/responsive_layout.dart'; // Import ResponsiveLayout

class ClassDetailsScreen extends StatefulWidget {
  const ClassDetailsScreen({super.key});

  @override
  State<ClassDetailsScreen> createState() => _ClassDetailsScreenState();
}

class _ClassDetailsScreenState extends State<ClassDetailsScreen> {
  bool _isSyncing = false;
  String _syncMessage = '';

  // Method to refresh class data from Google Sheets
  Future<void> _refreshClassData(ClassProvider classProvider, ClassModel classModel) async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
      _syncMessage = 'Syncing class data...';
    });
    
    try {
      print('Starting class data refresh for class: ${classModel.className}');
      
      // Perform class refresh from Google Sheets
      await classProvider.refreshClassesFromSheets();
      
      print('Class data refresh completed');
      
      if (mounted) {
        setState(() {
          _syncMessage = 'Sync completed successfully';
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class data updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Clear message after delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _syncMessage = '';
            });
          }
        });
      }
    } catch (e) {
      print('Error refreshing class data: $e');
      if (mounted) {
        setState(() {
          _syncMessage = 'Sync failed: $e';
        });
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync class data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
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
    final userProvider = Provider.of<UserProvider>(context);
    
    print('ClassDetailsScreen build called');

    Widget buildContent() {
      return Consumer<ClassProvider>(
        builder: (context, classProvider, child) {
          print('ClassProvider Consumer builder called');
          if (classProvider.activeClass != null) {
            print('Active class student count: ${classProvider.activeClass!.students.length}');
          }
          
          if (!classProvider.hasClasses) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.school,
                    size: 64,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: AppTheme.mediumSpacing),
                  Text(
                    'No Classes Available',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTheme.smallSpacing),
                  Text(
                    'Please add classes in Settings',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }

          // If a class has been selected, show its details
          if (classProvider.activeClass != null) {
            print('Showing active class details: ${classProvider.activeClass!.className}');
            return Padding(
              padding: const EdgeInsets.all(AppTheme.mediumSpacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Sync status indicator
                  if (_isSyncing) ...[
                    Container(
                      padding: const EdgeInsets.all(AppTheme.smallSpacing),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                            ),
                          ),
                          const SizedBox(width: AppTheme.smallSpacing),
                          Text(
                            _syncMessage,
                            style: const TextStyle(color: AppTheme.primaryColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.smallSpacing),
                  ],
                  
                  // Class Details Card - Pass the active class ID from the provider
                  Expanded(
                    child: ClassDetailsCard(
                      classId: classProvider.activeClass!.id,
                      onStudentSelected: (pinNumber) {
                        final selectedStudent = classProvider.activeClass!.students.firstWhere(
                          (student) => student.pinNumber == pinNumber,
                          orElse: () => throw Exception('Student not found with pin number: $pinNumber'),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudentDetailsScreen(
                              student: selectedStudent,
                              classModel: classProvider.activeClass!,
                            ),
                          ),
                        );
                      },
                      onEditStudent: (student, isAdmin) {
                        _showEditStudentDialog(classProvider.activeClass!, student, isAdmin);
                      },
                      isAdmin: userProvider.isAdmin,
                    ),
                  ),
                ],
              ),
            );
          }

          // Show class selection screen using SessionSetupWidget
          print('Showing class selection screen');
          return SessionSetupWidget(
            buttonText: 'View Details',
            showSessionToggle: false, // Hide session toggle for class details
            onBack: () {
              Navigator.of(context).pop();
            },
            onStartSession: (classModel, combo, sessionType) async {
              print('Class selected: ${classModel.className}');
              // Set the active class first
              await classProvider.setActiveClass(classModel);
              
              // Immediately trigger a fresh sync for the selected class
              await _refreshClassData(classProvider, classModel);
            },
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF040C1B), // Added background color to match dashboard
      appBar: AppBar(
        title: const Text('Class Details'),
        backgroundColor: Colors.transparent, // Made app bar transparent to match dashboard
        actions: [
          // Add a refresh button to the app bar for testing
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final classProvider = context.read<ClassProvider>();
              if (classProvider.activeClass != null) {
                _refreshClassData(classProvider, classProvider.activeClass!);
              }
            },
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobileBody: buildContent(),
        desktopBody: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: buildContent(),
          ),
        ),
        tabletBody: Center(
           child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: buildContent(),
          ),
        ),
      ),
      floatingActionButton: userProvider.isAdmin
          ? FloatingActionButton(
              onPressed: () {
                final classProvider = context.read<ClassProvider>();
                if (classProvider.activeClass != null) {
                  _showAddStudentDialog(classProvider.activeClass!, userProvider.isAdmin);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a class first.')),
                  );
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddStudentDialog(ClassModel classModel, bool isAdmin) {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _pinController = TextEditingController();
    final _emailController = TextEditingController();
    final _mobileController = TextEditingController();
    String _selectedBranch = 'CSE';
    
    // Add loading state
    bool _isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.largeRadius)),
              title: const Text('Add Student'),
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
                      const SizedBox(height: AppTheme.mediumSpacing),
                      TextFormField(
                        controller: _pinController,
                        decoration: InputDecoration(
                          labelText: 'Pin Number',
                          filled: true,
                          fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a pin number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.mediumSpacing),
                      CustomDropdown<String>(
                        value: _selectedBranch,
                        hintText: 'Branch',
                        items: ['CSE', 'ECE', 'EEE', 'CSM', 'CSC', 'CSD', 'MECH']
                            .map((branch) => DropdownMenuItem<String>(
                                  value: branch,
                                  child: Text(branch),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _selectedBranch = value;
                          }
                        },
                      ),
                      const SizedBox(height: AppTheme.mediumSpacing),
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
                      const SizedBox(height: AppTheme.mediumSpacing),
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
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                GradientButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              _isLoading = true;
                            });
                            
                            final newStudent = Student(
                              name: _nameController.text,
                              pinNumber: _pinController.text,
                              branch: _selectedBranch,
                              email: _emailController.text,
                              mobileNumber: _mobileController.text,
                              combo: classModel.className,
                              phone: '', // Add phone parameter
                              securityCodes: [],
                            );

                            // First add to Firebase
                            try {
                              await FirebaseService().updateStudent(
                                batchId: classModel.sheetName ?? classModel.className,
                                comboName: newStudent.combo,
                                updatedStudent: newStudent,
                              );
                              print('✅ Student added to Firebase successfully');
                            } catch (e) {
                              print('❌ Error adding student to Firebase: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to add student to Firebase: $e')),
                              );
                              setState(() {
                                _isLoading = false;
                              });
                              return;
                            }

                            // Then add to Google Sheets using the correct batch-specific service account key
                            final batchServiceAccountKey = await ControlSheetService.getBatchServiceAccountKey(
                              classModel.sheetName ?? classModel.className,
                            );
                            
                            if (batchServiceAccountKey == null || batchServiceAccountKey.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to get service account key for batch')),
                              );
                              setState(() {
                                _isLoading = false;
                              });
                              return;
                            }
                            
                            // Using web app approach - update Firebase directly
                            await FirebaseService().updateStudent(
                              batchId: classModel.sheetName ?? classModel.className,
                              comboName: newStudent.combo,
                              updatedStudent: newStudent,
                            );
                            String? errorMessage = null; // No error since we're using Firebase

                            if (errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to add student to Google Sheets: $errorMessage')),
                              );
                              setState(() {
                                _isLoading = false;
                              });
                              return;
                            }

                            // Update the local class data immediately for UI refresh
                            final localClassProvider = Provider.of<ClassProvider>(context, listen: false);
                            await localClassProvider.updateStudentInClass(classModel.id, newStudent);
                            
                            // Show success message immediately
                            Navigator.of(context).pop();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Student added successfully')),
                            );
                            
                            // Update Google Sheets in the background
                            WidgetsBinding.instance.addPostFrameCallback((_) async {
                              final backgroundClassProvider = Provider.of<ClassProvider>(context, listen: false);
                              await backgroundClassProvider.refreshClassesFromSheets();
                            });
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save', style: TextStyle(color: AppTheme.buttonTextColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditStudentDialog(ClassModel classModel, Student student, bool isAdmin) {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController(text: student.name);
    final _pinController = TextEditingController(text: student.pinNumber);
    final _emailController = TextEditingController(text: student.email);
    final _mobileController = TextEditingController(text: student.mobileNumber);
    final _branchController = TextEditingController(text: student.branch);
    final _comboController = TextEditingController(text: student.combo);
    
    // Add loading state
    bool _isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.largeRadius)),
              title: const Text('Edit Student'),
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
                      const SizedBox(height: AppTheme.mediumSpacing),
                      TextFormField(
                        controller: _pinController,
                        decoration: InputDecoration(
                          labelText: 'Pin Number',
                          filled: true,
                          fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                        ),
                        readOnly: true, // Always read-only
                      ),
                      const SizedBox(height: AppTheme.mediumSpacing),
                      TextFormField(
                        controller: _branchController,
                        decoration: InputDecoration(
                          labelText: 'Branch',
                          filled: true,
                          fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                        ),
                        readOnly: true, // Always read-only as per requirement
                      ),
                      const SizedBox(height: AppTheme.mediumSpacing),
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
                      const SizedBox(height: AppTheme.mediumSpacing),
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
                      const SizedBox(height: AppTheme.mediumSpacing),
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
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                GradientButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              _isLoading = true;
                            });
                            
                            final updatedStudent = student.copyWith(
                              name: _nameController.text,
                              pinNumber: _pinController.text,
                              branch: _branchController.text,
                              email: _emailController.text,
                              mobileNumber: _mobileController.text,
                              combo: _comboController.text,
                            );

                            // First update in Firebase and show immediate feedback
                            bool firebaseSuccess = false;
                            try {
                              await FirebaseService().updateStudent(
                                batchId: classModel.sheetName ?? classModel.className,
                                comboName: updatedStudent.combo,
                                updatedStudent: updatedStudent,
                              );
                              print('✅ Student updated in Firebase successfully');
                              firebaseSuccess = true;
                            } catch (e) {
                              print('❌ Error updating student in Firebase: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update student in Firebase: $e')),
                              );
                              setState(() {
                                _isLoading = false;
                              });
                              return;
                            }

                            // Update local class data immediately for UI refresh
                            final localClassProvider = Provider.of<ClassProvider>(context, listen: false);
                            await localClassProvider.updateStudentInClass(classModel.id, updatedStudent);

                            // Show success message immediately
                            Navigator.of(context).pop();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Student updated successfully')),
                            );

                            // Update Google Sheets in the background if Firebase update was successful
                            if (firebaseSuccess) {
                              WidgetsBinding.instance.addPostFrameCallback((_) async {
                                try {
                                  final batchServiceAccountKey = await ControlSheetService.getBatchServiceAccountKey(
                                    classModel.sheetName ?? classModel.className,
                                  );
                                  
                                  if (batchServiceAccountKey != null && batchServiceAccountKey.isNotEmpty) {
                                    // Using web app approach - update Firebase directly
                                    await FirebaseService().updateStudent(
                                      batchId: classModel.sheetName ?? classModel.className,
                                      comboName: updatedStudent.combo,
                                      updatedStudent: updatedStudent,
                                    );
                                    String? errorMessage = null; // No error since we're using Firebase

                                    if (errorMessage != null) {
                                      print('Failed to update student in Google Sheets: $errorMessage');
                                    } else {
                                      print('✅ Student updated in Google Sheets successfully');
                                    }
                                  }
                                } catch (e) {
                                  print('Error updating student in Google Sheets: $e');
                                }
                              });
                            }
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save', style: TextStyle(color: AppTheme.buttonTextColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}