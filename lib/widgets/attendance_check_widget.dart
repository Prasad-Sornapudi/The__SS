import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../services/google_sheets_service.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/scanner_widgets.dart'; // Import StrokeButton
import '../services/firebase_service.dart'; // Import FirebaseService

class AttendanceCheckWidget extends StatefulWidget {
  final ClassModel? activeClass;
  final AttendanceProvider attendanceProvider;
  final VoidCallback? onBack; // Add callback for back navigation

  const AttendanceCheckWidget({
    super.key,
    this.activeClass,
    required this.attendanceProvider,
    this.onBack, // Add optional back callback
  });

  @override
  State<AttendanceCheckWidget> createState() => _AttendanceCheckWidgetState();
}

class _AttendanceCheckWidgetState extends State<AttendanceCheckWidget> {
  final TextEditingController _rollNumberController = TextEditingController();
  final TextEditingController _dateSearchController = TextEditingController();
  bool _isLoading = false;
  String? _resultMessage;
  double? _attendancePercentage;
  List<AttendanceRecord> _attendanceHistory = [];
  List<AttendanceRecord> _filteredAttendanceHistory = [];

  ClassModel? _selectedClass; // Track selected class for attendance check
  
  // Batch/Combo Selection State
  String? _selectedBatchId;
  String? _selectedCombo;
  List<String> _availableCombos = [];

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.activeClass; // Initialize with active class
    
    // Initialize batch/combo dropdowns based on active class
    if (_selectedClass != null) {
      _selectedBatchId = _selectedClass!.sheetName ?? _selectedClass!.className;
      _selectedCombo = _selectedClass!.className;
      // We need to populate available combos for this batch in didChangeDependencies or build since we need provider
    }
  }
  
  // Helper to update _selectedClass based on batch/combo selection
  void _updateSelectedClass(List<ClassModel> classes) {
    if (_selectedBatchId != null && _selectedCombo != null) {
      try {
        final selected = classes.firstWhere(
          (c) => (c.sheetName == _selectedBatchId || c.className == _selectedBatchId) && 
                 c.className == _selectedCombo
        );
        _selectedClass = selected;
      } catch (e) {
        print('Error finding class for batch $_selectedBatchId and combo $_selectedCombo');
        _selectedClass = null; // Reset if invalid
      }
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize available combos if we have an active class and haven't populated them yet
    if (_selectedBatchId != null && _availableCombos.isEmpty) {
       final classProvider = Provider.of<ClassProvider>(context, listen: false);
       final classes = classProvider.classes;
       
       if (classes.isNotEmpty) {
         final combos = classes
            .where((c) => (c.sheetName == _selectedBatchId || c.className == _selectedBatchId))
            .map((c) => c.className)
            .toSet()
            .toList()
          ..sort();
          
         setState(() {
           _availableCombos = combos;
         });
       }
    }
  }

  @override
  void dispose() {
    _rollNumberController.dispose();
    _dateSearchController.dispose();
    super.dispose();
  }

  Future<void> _checkAttendancePercentage() async {
    final rollNumber = _rollNumberController.text.trim();
    
    // Ensure we have a selected class
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a class'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (rollNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a roll number'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _resultMessage = null;
      _attendancePercentage = null;
      _attendanceHistory.clear();
      _filteredAttendanceHistory.clear();
    });

    try {
      // Fetch attendance data from Firebase
      final firebaseService = FirebaseService();
      
      // Use the selected batch ID (e.g., "Skill_Sync01") which matches the Firebase structure
      // instead of the internal Class ID (e.g., "class_Skill_Sync01_ComboName")
      final batchId = _selectedBatchId ?? _selectedClass?.sheetName ?? _selectedClass?.className ?? '';
      
      final attendanceRecords = await firebaseService.getStudentAttendanceHistory(
        classId: batchId,
        studentPinNumber: rollNumber,
        studentCombo: _selectedCombo,
      );

      // Calculate attendance percentage
      final attendancePercentage = await firebaseService.calculateStudentAttendancePercentage(
        classId: batchId,
        studentPinNumber: rollNumber,
        studentCombo: _selectedCombo,
      );

      final presentCount = attendanceRecords.where((record) => record.status == AttendanceStatus.present).length;
      final totalCount = attendanceRecords.length;
      
      print('✅ Attendance check successful: $presentCount/$totalCount sessions (${attendancePercentage.toStringAsFixed(1)}%)');
      
      setState(() {
        _attendancePercentage = attendancePercentage;
        _resultMessage = 'Attendance: $presentCount/$totalCount sessions (${attendancePercentage.toStringAsFixed(1)}%)';
        _attendanceHistory = attendanceRecords;
        _filteredAttendanceHistory = List.from(_attendanceHistory);
        _isLoading = false;
      });
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance data retrieved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _resultMessage = 'Error checking attendance: $e';
        _isLoading = false;
      });
      
      // Show error in snackbar as well for better visibility
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking attendance: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  void _filterAttendanceByDate() {
    final query = _dateSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredAttendanceHistory = List.from(_attendanceHistory);
      });
      return;
    }

    // Try to parse the query as a specific date format
    DateTime? searchDate;
    
    // Try different date formats
    final formats = [
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'd/M/yyyy',
      'dd/M/yyyy',
      'd/MM/yyyy',
    ];
    
    for (final format in formats) {
      try {
        // Simple format parsing
        if (format == 'dd/MM/yyyy' && query.contains('/')) {
          final parts = query.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              searchDate = DateTime(year, month, day);
              break;
            }
          }
        } else if (format == 'dd-MM-yyyy' && query.contains('-')) {
          final parts = query.split('-');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              searchDate = DateTime(year, month, day);
              break;
            }
          }
        } else if (format == 'yyyy-MM-dd' && query.contains('-')) {
          final parts = query.split('-');
          if (parts.length == 3) {
            final year = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final day = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              searchDate = DateTime(year, month, day);
              break;
            }
          }
        } else if (format == 'MM/dd/yyyy' && query.contains('/')) {
          final parts = query.split('/');
          if (parts.length == 3) {
            final month = int.tryParse(parts[0]);
            final day = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              searchDate = DateTime(year, month, day);
              break;
            }
          }
        } else if (format == 'd/M/yyyy' && query.contains('/')) {
          final parts = query.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              searchDate = DateTime(year, month, day);
              break;
            }
          }
        } else if (format == 'dd/M/yyyy' && query.contains('/')) {
          final parts = query.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              searchDate = DateTime(year, month, day);
              break;
            }
          }
        } else if (format == 'd/MM/yyyy' && query.contains('/')) {
          final parts = query.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day != null && month != null && year != null) {
              searchDate = DateTime(year, month, day);
              break;
            }
          }
        }
      } catch (e) {
        // Continue to next format
        continue;
      }
    }

    if (searchDate != null) {
      // Create a non-nullable copy for use in the closure
      final nonNullSearchDate = searchDate;
      // Exact date match
      final filtered = _attendanceHistory.where((record) {
        return record.sessionDate.year == nonNullSearchDate.year &&
               record.sessionDate.month == nonNullSearchDate.month &&
               record.sessionDate.day == nonNullSearchDate.day;
      }).toList();

      setState(() {
        _filteredAttendanceHistory = filtered;
      });
    } else {
      // Partial match as fallback
      final filtered = _attendanceHistory.where((record) {
        final dateStr = '${record.sessionDate.day}/${record.sessionDate.month}/${record.sessionDate.year}';
        final dateStr2 = '${record.sessionDate.year}-${record.sessionDate.month.toString().padLeft(2, '0')}-${record.sessionDate.day.toString().padLeft(2, '0')}';
        final dateStr3 = '${record.sessionDate.month}/${record.sessionDate.day}/${record.sessionDate.year}';
        
        return dateStr.contains(query) || 
               dateStr2.contains(query) || 
               dateStr3.contains(query) ||
               record.sessionDate.day.toString().contains(query) ||
               record.sessionDate.month.toString().contains(query) ||
               record.sessionDate.year.toString().contains(query);
      }).toList();

      setState(() {
        _filteredAttendanceHistory = filtered;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: AppTheme.darkNavyBlue,
              surface: AppTheme.darkNavyBlue,
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor, // color of the text
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate = '${picked.day}/${picked.month}/${picked.year}';
      _dateSearchController.text = formattedDate;
      _filterAttendanceByDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavyBlue,
      appBar: AppBar(
        title: const Text('Check Attendance'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Use the callback if provided, otherwise use Navigator.pop
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            const Text(
              'Check Attendance Percentage',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            // Batch & Combo Selection (Replaced single class dropdown)
            Consumer<ClassProvider>(
              builder: (context, classProvider, child) {
                // Extract unique batches
                final classes = classProvider.classes;
                final uniqueBatches = classes.map((c) => c.sheetName ?? c.className).toSet().toList()..sort();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Batch Dropdown
                    _buildDropdown<String>(
                      label: 'Select Batch:',
                      value: _selectedBatchId,
                      items: uniqueBatches,
                      itemLabel: (batch) => batch,
                      hint: 'Choose a batch...',
                      onChanged: (String? batchId) {
                        if (batchId == null) return;
                        
                        // Filter combos for this batch
                        final combos = classes
                            .where((c) => (c.sheetName == batchId || c.className == batchId))
                            .map((c) => c.className)
                            .toSet()
                            .toList()
                          ..sort();
                          
                        setState(() {
                          _selectedBatchId = batchId;
                          _selectedCombo = null;
                          _availableCombos = combos;
                          _selectedClass = null; // Reset class until combo is picked
                          
                          // Auto-select if only one combo
                          if (_availableCombos.length == 1) {
                            _selectedCombo = _availableCombos.first;
                            _updateSelectedClass(classes);
                          }
                        });
                      },
                    ),
                    
                    const SizedBox(height: AppConstants.defaultPadding),
                    
                    // Combo Dropdown
                    _buildDropdown<String>(
                      label: 'Select Combo:',
                      value: _selectedCombo,
                      items: _availableCombos,
                      itemLabel: (combo) => combo,
                      hint: _selectedBatchId == null 
                          ? 'Select a batch first' 
                          : 'Choose a combo...',
                      isEnabled: _selectedBatchId != null && _availableCombos.isNotEmpty,
                      onChanged: (String? combo) {
                        setState(() {
                          _selectedCombo = combo;
                          _updateSelectedClass(classes);
                        });
                      },
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: AppConstants.defaultPadding),

            // Roll number input
            Container(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: BoxDecoration(
                color: AppTheme.darkNavyBlueLighter.withOpacity(0.7),
                borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Student Roll Number',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppConstants.smallPadding),
                  TextField(
                    controller: _rollNumberController,
                    decoration: InputDecoration(
                      labelText: 'Enter Roll Number',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: AppTheme.darkNavyBlue,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.person, color: AppTheme.primaryColor),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _checkAttendancePercentage(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            // Check button
            StrokeButton(
              isEnabled: !_isLoading,
              onPressed: _checkAttendancePercentage,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isLoading 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.onDarkNavy),
                          ),
                        )
                      : const Icon(Icons.search, color: AppTheme.onDarkNavy),
                  const SizedBox(width: 8),
                  const Text('Check Attendance', style: TextStyle(color: AppTheme.onDarkNavy)),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            // Result display
            if (_resultMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF05182C),
                      Color(0xFF082043),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resultMessage!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_attendancePercentage != null) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: _attendancePercentage! / 100,
                        backgroundColor: Colors.grey[700],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _attendancePercentage! >= 75
                              ? AppTheme.successColor
                              : _attendancePercentage! >= 50
                                  ? AppTheme.warningColor
                                  : AppTheme.errorColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_attendancePercentage!.toStringAsFixed(1)}% attendance',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
            ],

            // Date search input (only show when we have attendance history)
            if (_attendanceHistory.isNotEmpty) ...[
              const Text(
                'Search by Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppConstants.smallPadding),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dateSearchController,
                      decoration: InputDecoration(
                        hintText: 'Enter date (dd/mm/yyyy)',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Color(0xFF051F5B), // Using solid color for text field
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => _filterAttendanceByDate(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF02102B),
                          Color(0xFF041F61),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.date_range, color: AppTheme.darkNavyBlue),
                      onPressed: _selectDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkNavyBlue.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70),
                      onPressed: () {
                        _dateSearchController.clear();
                        setState(() {
                          _filteredAttendanceHistory = List.from(_attendanceHistory);
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.defaultPadding),
            ],

            // Attendance history
            if (_filteredAttendanceHistory.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Attendance History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${_filteredAttendanceHistory.length} records',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.smallPadding),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredAttendanceHistory.length,
                  itemBuilder: (context, index) {
                    final record = _filteredAttendanceHistory[index];
                    return Card(
                      color: Color(0xFF051F5B), // Using solid color for card background
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${record.sessionDate.day}/${record.sessionDate.month}/${record.sessionDate.year}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          record.status == AttendanceStatus.present ? 'Present' : 'Absent',
                          style: TextStyle(
                            color: record.status == AttendanceStatus.present
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        ),
                        trailing: Text(
                          record.displayTime,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (_attendanceHistory.isNotEmpty) ...[
              const Center(
                child: Text(
                  'No records match your search criteria',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }



  // Add this new method for showing class selection dialog
  void _showClassSelectionDialog(BuildContext context, ClassProvider classProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: AppTheme.darkNavyBlue,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select a Class',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(
                color: AppTheme.primaryColor,
                height: 1,
              ),
              // Class list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  itemCount: classProvider.classes.length,
                  itemBuilder: (context, index) {
                    final classModel = classProvider.classes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
                      decoration: BoxDecoration(
                        color: AppTheme.darkNavyBlueLighter.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                      ),
                      child: ListTile(
                        title: Text(
                          classModel.className,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${classModel.students.length} students',
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: AppTheme.primaryColor,
                          size: 16,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedClass = classModel;
                          });
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    required String hint,
    bool isEnabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlueLighter.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isEnabled ? Colors.white : Colors.white54,
            ),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          CustomDropdown<T>(
            value: value,
            hintText: hint,
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabel(item),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: isEnabled ? onChanged : (val) {},
          ),
        ],
      ),
    );
  }
}