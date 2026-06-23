import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/class_model.dart';
import '../models/batch_config.dart';
import '../models/session_model.dart' as session_model;
import '../providers/class_provider.dart';
import '../constants/theme.dart';
import 'scanner_widgets.dart';
import '../services/control_sheet_service.dart';
import '../services/sheet_data_service.dart';
import '../services/firebase_service.dart';
import 'custom_dropdown.dart';

class SessionSetupWidget extends StatefulWidget {
  final VoidCallback onBack;
  final Function(ClassModel, String, session_model.SessionType) onStartSession; // Updated to include session type
  final bool showSessionToggle; // Add flag to control visibility of session toggle
  final String buttonText; // Restore buttonText field

  const SessionSetupWidget({
    Key? key,
    required this.onBack,
    required this.onStartSession,
    this.buttonText = 'Start Session',
    this.showSessionToggle = true, // Default to true
  }) : super(key: key);

  @override
  State<SessionSetupWidget> createState() => _SessionSetupWidgetState();
}

class _SessionSetupWidgetState extends State<SessionSetupWidget> {
  String? _selectedBatchId;
  String? _selectedCombo;
  List<String> _availableCombos = [];
  // Add session type selection (morning or afternoon)
  session_model.SessionType _selectedSessionType = session_model.SessionType.morning;

  @override
  void initState() {
    super.initState();
    _refreshClasses();
    
    // Initialize session type based on current time (Morning ends at 1:30 PM)
    final now = DateTime.now();
    final isAfterCutoff = now.hour > 13 || (now.hour == 13 && now.minute >= 30);
    _selectedSessionType = isAfterCutoff ? session_model.SessionType.afternoon : session_model.SessionType.morning;
  }

  Future<void> _refreshClasses() async {
    try {
      final classProvider = context.read<ClassProvider>();
      await classProvider.forceRefreshClasses();
      // If there's only one batch after refresh, auto-select it
      final classes = classProvider.classes;
      final uniqueBatches = classes.map((c) => c.sheetName ?? c.className).toSet().toList();
      
      if (mounted && uniqueBatches.length == 1) {
        setState(() {
          _onBatchSelected(uniqueBatches.first);
        });
      }
    } catch (e) {
      print('Error refreshing classes in SessionSetupWidget: $e');
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
      
    print('✅ Selected batch: "$batchId"');
    print('✅ Found ${combos.length} combos locally: $combos');

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

    // Print debug information about available classes
    if (classes.isNotEmpty) {
      print('🔍 Available classes:');
      for (int i = 0; i < classes.length; i++) {
        final c = classes[i];
        print('   $i. className: "${c.className}", sheetName: "${c.sheetName}", students: ${c.students.length}');
      }
    }

    return Container(
      margin: const EdgeInsets.all(AppTheme.largeSpacing),
      padding: const EdgeInsets.all(AppTheme.largeSpacing),
      decoration: BoxDecoration(
        gradient: AppTheme.appBackgroundGradient,
        borderRadius: BorderRadius.circular(12.0),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back Button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.onDarkNavy),
              onPressed: widget.onBack,
            ),
          ),
          
          const SizedBox(height: AppTheme.mediumSpacing),
          
          // Batch Dropdown
          _buildDropdown<String>(
            label: 'Batch Name',
            value: _selectedBatchId,
            items: uniqueBatches,
            itemLabel: (id) => id,
            onChanged: (val) => _onBatchSelected(val),
            hint: 'Choose a batch name...',
          ),
          
          const SizedBox(height: AppTheme.mediumSpacing),
          
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
          
          const SizedBox(height: AppTheme.extraLargeSpacing),
          
          // Session Type Toggle Switch and Start Session Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Session Type Toggle Switch (Conditionally visible)
              if (widget.showSessionToggle)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.onDarkNavy,
                      ),
                    ),
                    const SizedBox(height: AppTheme.smallSpacing),
                    GestureDetector(
                      onTap: () {
                        // Check time restriction
                        final now = DateTime.now();
                        final isAfterCutoff = now.hour > 13 || (now.hour == 13 && now.minute >= 30);
                        
                        // If trying to switch to Morning (AM) after 1:30 PM, block it
                        if (_selectedSessionType == session_model.SessionType.afternoon && isAfterCutoff) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Session Ended'),
                              content: const Text('AM Session has ended (Ends at 1:30 PM).\nYou cannot start a Morning session now.'),
                                actions: [
                                  SizedBox(
                                    width: 100,
                                    height: 40,
                                    child: GradientButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK', style: TextStyle(color: Colors.white)),
                                    ),
                                  ),
                                ],
                            ),
                          );
                          return;
                        }

                        setState(() {
                          _selectedSessionType = _selectedSessionType == session_model.SessionType.morning
                              ? session_model.SessionType.afternoon
                              : session_model.SessionType.morning;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AM',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _selectedSessionType == session_model.SessionType.morning
                                  ? Colors.yellow
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Simple toggle switch
                          Container(
                            width: 42,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 200),
                                  left: _selectedSessionType == session_model.SessionType.morning ? 3 : 25,
                                  top: 3,
                                  child: Container(
                                    width: 17,
                                    height: 17,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.buttonTextColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PM',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _selectedSessionType == session_model.SessionType.afternoon
                                  ? Colors.yellow
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else 
                const Spacer(), // Spacer to push button to right if toggle is hidden
              
              // Start Session Button with reduced width
              SizedBox(
                width: 150, // Reduced width
                child: GradientButton(
                  onPressed: () {
                    // Check if we have valid selections
                    if (_selectedBatchId != null && _selectedCombo != null) {
                      // Find the specific ClassModel for this batch and combo
                      try {
                        final selectedClass = classes.firstWhere(
                          (c) => (c.sheetName == _selectedBatchId || c.className == _selectedBatchId) && 
                                 c.className == _selectedCombo
                        );
                        widget.onStartSession(selectedClass, _selectedCombo!, _selectedSessionType);
                      } catch (e) {
                        print('Error finding selected class: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error starting session: $e')),
                        );
                      }
                    }
                    // If selections are invalid, we do nothing
                  },
                  isEnabled: (_selectedBatchId != null && _selectedCombo != null),
                  child: Text(widget.buttonText, style: const TextStyle(color: AppTheme.buttonTextColor)),
                ),
              ),
            ],
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isEnabled ? AppTheme.onDarkNavy : AppTheme.onDarkNavy.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: AppTheme.smallSpacing),
        // Use CustomDropdown instead of standard Container + DropdownButton
        CustomDropdown<T>(
          value: value,
          hintText: hint,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                style: const TextStyle(
                  color: Colors.white, // Ensure text is white in dropdown
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: isEnabled ? onChanged : null,
          isExpanded: true,
        ),
      ],
    );
  }
}