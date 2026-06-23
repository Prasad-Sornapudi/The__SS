import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/auto_upload_service.dart';
import '../services/enhanced_auto_sync_service.dart';
import '../models/class_model.dart';
import '../models/session_model.dart';
import '../widgets/custom_dropdown.dart';
import '../constants/theme.dart';

class ComboDropdown extends StatefulWidget {
  final ClassModel activeClass;
  final SessionType? currentSessionType;
  
  const ComboDropdown({
    super.key,
    required this.activeClass,
    this.currentSessionType,
  });

  @override
  State<ComboDropdown> createState() => _ComboDropdownState();
}

class _ComboDropdownState extends State<ComboDropdown> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.darkNavyBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.onDarkNavyTertiary),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ),
      );
    }

    return Consumer<ClassProvider>(
      builder: (context, classProvider, child) {
        // Extract combos for the current batch
        final currentBatch = widget.activeClass.sheetName ?? widget.activeClass.className;
        final combosInBatch = classProvider.classes
            .where((c) => (c.sheetName ?? c.className) == currentBatch)
            .map((c) => c.className)
            .toSet()
            .toList()
          ..sort();
        
        return CustomDropdown<String?>(
          value: combosInBatch.contains(widget.activeClass.className) ? widget.activeClass.className : null,
          hintText: 'Select combo',
          items: combosInBatch.map((comboName) {
            return DropdownMenuItem<String>(
              value: comboName,
              child: Text(
                comboName,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (String? newCombo) async {
            if (newCombo != null) {
              setState(() => _isLoading = true);
              
              try {
                final classProvider = context.read<ClassProvider>();
                final attendanceProvider = context.read<AttendanceProvider>();
                final autoUploadService = context.read<AutoUploadService>();
                
                // Find the class with this combo name
                final selectedClass = classProvider.classes.firstWhere(
                  (c) => c.className == newCombo,
                  orElse: () => widget.activeClass,
                );
                
                // Ensure attendance data is loaded for the selected class
                // Use loadAttendanceForSession to FORCE reload data for the newly selected combo
                await attendanceProvider.loadAttendanceForSession(
                    selectedClass.id, 
                    attendanceProvider.sessionDate,
                    overrideSessionType: widget.currentSessionType,
                );
                await classProvider.setActiveClass(selectedClass);
                // Also set the active class ID in the attendance provider
                attendanceProvider.setActiveClassId(selectedClass.id);
                
                // Start auto-upload service with the new class
                autoUploadService.startAutoUpload(selectedClass, triggerSync: true);
                
              } catch (e) {
                print('Error switching combo: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load combo: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            }
          },
        );
      },
    );
  }
}