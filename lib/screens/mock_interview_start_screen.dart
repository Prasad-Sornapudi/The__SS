import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../models/class_model.dart';
import '../screens/mock_interview_history_screen.dart';
import '../screens/mock_interview_form_screen.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/scanner_widgets.dart';

class MockInterviewStartScreen extends StatefulWidget {
  const MockInterviewStartScreen({super.key});

  @override
  State<MockInterviewStartScreen> createState() => _MockInterviewStartScreenState();
}

class _MockInterviewStartScreenState extends State<MockInterviewStartScreen> {
  String? _selectedBatchId;
  String? _selectedCombo;
  List<String> _availableCombos = [];
  String _rollNumber = '';
  final TextEditingController _rollNumberController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _refreshClasses();
  }

  @override
  void dispose() {
    _rollNumberController.dispose();
    super.dispose();
  }

  Future<void> _refreshClasses() async {
    try {
      final classProvider = context.read<ClassProvider>();
      // If there's only one batch, auto-select it
      final classes = classProvider.classes;
      final uniqueBatches = classes.map((c) => c.sheetName ?? c.className).toSet().toList();
      
      if (mounted && uniqueBatches.length == 1) {
        setState(() {
          _onBatchSelected(uniqueBatches.first);
        });
      }
    } catch (e) {
      print('Error refreshing classes in MockInterviewStartScreen: $e');
    }
  }

  void _onBatchSelected(String? batchId) {
    if (batchId == null) return;
    
    final classProvider = context.read<ClassProvider>();
    final classes = classProvider.classes;
    
    // Filter combos locally from the already loaded classes
    final combos = classes
        .where((c) => (c.sheetName == batchId || c.className == batchId))
        .map((c) => c.className)
        .toSet() // Deduplicate just in case
        .toList()
      ..sort();
      
    setState(() {
      _selectedBatchId = batchId;
      _selectedCombo = null;
      _availableCombos = combos;
      
      // Auto-select if only one combo
      if (_availableCombos.length == 1) {
        _selectedCombo = _availableCombos.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = context.watch<ClassProvider>();
    final classes = classProvider.classes;
    
    // Extract unique batches
    final uniqueBatches = classes.map((c) => c.sheetName ?? c.className).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFF040C1B),
      appBar: AppBar(
        title: const Text('Mock Interview'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mock Interview',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            const Text(
              'Enter student details to begin or view history',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: AppConstants.largePadding),
            
            // Batch Dropdown
            _buildDropdown<String>(
              label: 'Batch Name',
              value: _selectedBatchId,
              items: uniqueBatches,
              itemLabel: (id) => id,
              onChanged: (val) => _onBatchSelected(val),
              hint: 'Choose a batch name...',
            ),
            
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Combo Dropdown
            _buildDropdown<String>(
              label: 'Combo Selection',
              value: _selectedCombo,
              items: _availableCombos,
              itemLabel: (c) => c,
              onChanged: (val) {
                setState(() {
                  _selectedCombo = val;
                });
              },
              hint: _selectedBatchId == null 
                  ? 'Select a batch first' 
                  : (_availableCombos.isEmpty ? 'No combos available' : 'Choose a combo...'),
              isEnabled: _selectedBatchId != null && _availableCombos.isNotEmpty,
            ),

            const SizedBox(height: AppConstants.defaultPadding),
            
            // Roll Number Input
            _buildRollNumberInput(),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Action Buttons
            _buildActionButtons(classes),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                  border: Border.all(color: AppTheme.errorColor),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
            ],
          ],
        ),
      ),
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

  Widget _buildRollNumberInput() {
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
            decoration: const InputDecoration(
              labelText: 'Enter roll number',
              labelStyle: TextStyle(color: Colors.white70),
              filled: true,
              fillColor: AppTheme.darkNavyBlue,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppConstants.defaultBorderRadius)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) => setState(() => _rollNumber = value),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(List<ClassModel> classes) {
    final bool canProceed = _selectedBatchId != null && _selectedCombo != null && _rollNumber.isNotEmpty;

    return Column(
      children: [
        GradientButton(
          onPressed: canProceed
              ? () async {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });

                  try {
                    // Find the specific ClassModel for this batch and combo
                    final selectedClass = classes.firstWhere(
                      (c) => (c.sheetName == _selectedBatchId || c.className == _selectedBatchId) && 
                             c.className == _selectedCombo,
                      orElse: () => throw Exception('Selected class not found'),
                    );

                    // Validate that the student exists in the selected class
                    final student = selectedClass.students.firstWhere(
                      (s) => s.pinNumber == _rollNumber,
                      orElse: () => throw Exception('Student not found in selected class'),
                    );

                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MockInterviewFormScreen(
                            selectedClass: selectedClass,
                            rollNumber: _rollNumber,
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _errorMessage = e.toString();
                      });
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                }
              : null,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.play_arrow, color: AppTheme.buttonTextColor),
                    SizedBox(width: 8),
                    Text('Start Interview', style: TextStyle(color: AppTheme.buttonTextColor)),
                  ],
                ),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        OutlinedButton(
          onPressed: canProceed
              ? () {
                  try {
                    // Find the specific ClassModel for this batch and combo
                    final selectedClass = classes.firstWhere(
                      (c) => (c.sheetName == _selectedBatchId || c.className == _selectedBatchId) && 
                             c.className == _selectedCombo,
                      orElse: () => throw Exception('Selected class not found'),
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MockInterviewHistoryScreen(
                          selectedClass: selectedClass,
                          rollNumber: _rollNumber,
                        ),
                      ),
                    );
                  } catch (e) {
                    setState(() {
                      _errorMessage = e.toString();
                    });
                  }
                }
              : null,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.primaryColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
            ),
          ),
          child: const Text(
            'View History',
            style: TextStyle(color: AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }
}