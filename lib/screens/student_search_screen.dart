import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../models/class_model.dart';
import '../models/student_details.dart';
import '../services/google_sheets_service.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import './student_edit_screen.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/scanner_widgets.dart'; // Import GradientButton

class StudentSearchScreen extends StatefulWidget {
  StudentSearchScreen({super.key});

  @override
  State<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends State<StudentSearchScreen> {
  final _searchController = TextEditingController();
  bool _searchAllBatches = true;
  bool _searchAllCombos = true;
  String? _selectedBatch;
  ClassModel? _selectedClass;
  bool _isLoading = false;
  Student? _studentResult;
  ClassModel? _foundInClass;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Set the initial selected class and batch if classes are available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final classProvider = context.read<ClassProvider>();
      if (classProvider.classes.isNotEmpty) {
        setState(() {
          _selectedClass = classProvider.classes.first;
          _selectedBatch = classProvider.classes.first.sheetName ?? classProvider.classes.first.className;
        });
      }
    });
  }

  Future<void> _searchStudent() async {
    if (_searchController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a roll number to search.';
        _studentResult = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _studentResult = null;
    });

    final rollNumber = _searchController.text.trim();
    final classProvider = context.read<ClassProvider>();
    Student? foundStudent;
    ClassModel? foundInClass;

    if (_searchAllBatches && _searchAllCombos) {
      // Search in all classes
      for (var classModel in classProvider.classes) {
        try {
          foundStudent = classModel.students.firstWhere((s) => s.pinNumber == rollNumber);
          foundInClass = classModel;
          break; // Stop searching once found
        } catch (e) {
          // Not found in this class, continue
        }
      }
    } else if (!_searchAllBatches && _selectedBatch != null) {
      // Search only in the selected batch
      for (var classModel in classProvider.classes.where((c) => (c.sheetName ?? c.className) == _selectedBatch!)) {
        try {
          foundStudent = classModel.students.firstWhere((s) => s.pinNumber == rollNumber);
          foundInClass = classModel;
          break; // Stop searching once found
        } catch (e) {
          // Not found in this class, continue
        }
      }
    } else if (!_searchAllCombos && _selectedClass != null) {
      // Search only in the selected combo (if we have a selected class)
      try {
        foundStudent = _selectedClass!.students.firstWhere((s) => s.pinNumber == rollNumber);
        foundInClass = _selectedClass;
      } catch (e) {
        // Not found in the selected class
      }
    }

    if (foundStudent != null && foundInClass != null) {
      // Set the found class as active before navigating to student edit screen
      await classProvider.setActiveClass(foundInClass!);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentEditScreen(
            student: foundStudent!,
            classModel: foundInClass!,
          ),
        ),
      );
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'Student with roll number "$rollNumber" not found.';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040C1B), // Added background color to match dashboard
      appBar: AppBar(
        title: const Text('Student Search'),
        backgroundColor: Colors.transparent, // Made app bar transparent to match dashboard
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.mediumSpacing),
        children: [
          _buildSearchCard(),
          const SizedBox(height: AppTheme.mediumSpacing),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            _buildErrorCard(_errorMessage!)
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      decoration: AppTheme.glassCard(), // Changed from glassContainer() to glassCard() to match dashboard
      padding: const EdgeInsets.all(AppTheme.mediumSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Enter Student Roll Number',
              filled: true,
              fillColor: AppTheme.darkNavyBlue.withOpacity(0.5), // 50% opacity
              suffixIcon: const Icon(Icons.search),
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: AppTheme.mediumSpacing),
          _buildSwitchTile(
            'Search in all batches',
            _searchAllBatches,
            (bool value) {
              setState(() {
                _searchAllBatches = value;
                // Reset selections when toggling
                if (value) {
                  _selectedBatch = null;
                  _selectedClass = null;
                }
              });
            },
          ),
          const SizedBox(height: 8),
          _buildSwitchTile(
            'Search in all combos',
            _searchAllCombos,
            (bool value) {
              setState(() {
                _searchAllCombos = value;
                // Reset selection when toggling
                if (value) {
                  _selectedClass = null;
                }
              });
            },
          ),
          if (!_searchAllBatches || !_searchAllCombos)
            Consumer<ClassProvider>(
              builder: (context, classProvider, child) {
                // Extract unique batches
                final uniqueBatches = classProvider.classes
                    .map((c) => c.sheetName ?? c.className)
                    .toSet()
                    .toList()
                  ..sort();
                  
                return Column(
                  children: [
                    if (!_searchAllBatches)
                      // Batch Dropdown
                      CustomDropdown<String>(
                        value: _selectedBatch,
                        hintText: 'Select a Batch',
                        items: uniqueBatches.map((batchName) {
                          return DropdownMenuItem<String>(
                            value: batchName,
                            child: Text(
                              batchName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newBatch) {
                          setState(() {
                            _selectedBatch = newBatch;
                            // Auto-select the first class in this batch
                            if (newBatch != null) {
                              final firstClassInBatch = classProvider.classes.firstWhere(
                                (c) => (c.sheetName ?? c.className) == newBatch,
                                orElse: () => classProvider.classes.first,
                              );
                              _selectedClass = firstClassInBatch;
                            } else {
                              _selectedClass = null;
                            }
                          });
                        },
                      ),
                    if (!_searchAllBatches && !_searchAllCombos && _selectedBatch != null)
                      const SizedBox(height: AppTheme.smallSpacing),
                    if (!_searchAllCombos)
                      // Combo Dropdown
                      CustomDropdown<ClassModel>(
                        value: _selectedClass,
                        hintText: 'Select a Combo',
                        items: classProvider.classes
                            .where((c) => _selectedBatch == null || (c.sheetName ?? c.className) == _selectedBatch)
                            .map((classModel) {
                              return DropdownMenuItem<ClassModel>(
                                value: classModel,
                                child: Text(
                                  classModel.className,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                        onChanged: (ClassModel? newValue) {
                          setState(() {
                            _selectedClass = newValue;
                          });
                        },
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: AppTheme.largeSpacing),
          GradientButton(
            onPressed: _searchStudent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search, color: AppTheme.buttonTextColor),
                const SizedBox(width: 8),
                const Text('Search', style: TextStyle(color: AppTheme.buttonTextColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      decoration: AppTheme.glassCard(), // Changed from Card to Container with glassCard styling to match dashboard
      padding: const EdgeInsets.all(AppTheme.mediumSpacing),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor),
          const SizedBox(width: AppTheme.smallSpacing),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        color: Colors.transparent, // Ensure hit test works
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white, // Assuming dark theme text color
                fontSize: 16,
              ),
            ),
            // Custom Switch matching dashboard style
            Container(
              width: 50,
              height: 25,
              decoration: BoxDecoration(
                color: AppTheme.darkNavyBlue,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: value ? 29 : 4,
                    top: 4,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: const BoxDecoration(
                        color: AppTheme.techwingyellow,
                        shape: BoxShape.circle,
                      ),
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
}