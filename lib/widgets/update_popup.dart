import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../providers/user_provider.dart';
import '../services/google_sheets_service.dart';
import '../services/attendance_sheet_service.dart';
import '../models/class_model.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/scanner_widgets.dart'; // Import GradientButton
import '../services/auto_class_service.dart'; // Import AutoClassService
import '../services/update_check_service.dart'; // Import UpdateCheckService

class UpdatePopup extends StatefulWidget {
  final VoidCallback onDismiss;
  
  const UpdatePopup({super.key, required this.onDismiss});

  @override
  State<UpdatePopup> createState() => _UpdatePopupState();
}

class _UpdatePopupState extends State<UpdatePopup> {
  bool _isChecking = true;
  bool _hasMasterUpdates = false;
  bool _hasAttendanceUpdates = false;
  SheetInfo? _masterSheetInfo;
  SheetInfo? _attendanceSheetInfo;
  String _statusMessage = 'Checking for updates...';
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      setState(() {
        _isChecking = true;
        _statusMessage = 'Checking for updates...';
      });

      final result = await UpdateCheckService.checkForUpdates();
      
      if (result.isSuccess) {
        final hasMasterChanged = await UpdateCheckService.hasMasterSheetChanged();
        
        setState(() {
          _isChecking = false;
          _hasMasterUpdates = hasMasterChanged;
          _hasAttendanceUpdates = result.hasAttendanceUpdates;
          _masterSheetInfo = result.masterSheetInfo;
          _attendanceSheetInfo = result.attendanceSheetInfo;
          _statusMessage = _hasMasterUpdates 
              ? 'Updates available in master sheet' 
              : 'No updates found';
        });
      } else {
        setState(() {
          _isChecking = false;
          _statusMessage = 'Failed to check updates: ${result.message}';
        });
      }
    } catch (e) {
      setState(() {
        _isChecking = false;
        _statusMessage = 'Error checking updates: $e';
      });
    }
  }

  Future<void> _updateNow() async {
    if (_isUpdating) return;
    
    try {
      setState(() {
        _isUpdating = true;
        _statusMessage = 'Updating classes from sheets...';
      });

      // Update classes from master sheet
      await AutoClassService.updateClassesFromSheets();
      
      // Refresh the class provider
      final classProvider = context.read<ClassProvider>();
      await classProvider.loadClasses();
      
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _statusMessage = 'Update completed successfully!';
        });
        
        // Close the popup after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _statusMessage = 'Update failed: $e';
        });
      }
    }
  }

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
                  Icons.update,
                  color: AppTheme.warningColor,
                  size: 24,
                ),
                const SizedBox(width: AppConstants.smallPadding),
                Text(
                  'Sheet Updates',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Status message
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Update info
            if (!_isChecking && (_hasMasterUpdates || _hasAttendanceUpdates)) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                  border: Border.all(
                    color: AppTheme.warningColor.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasMasterUpdates) ...[
                      const Row(
                        children: [
                          Icon(
                            Icons.school,
                            color: AppTheme.warningColor,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Master Sheet Updates Available',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_masterSheetInfo != null) ...[
                        Text(
                          '${_masterSheetInfo!.worksheetCount} worksheets, ${_masterSheetInfo!.totalRows} total rows',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                    if (_hasAttendanceUpdates) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.table_chart,
                            color: AppTheme.warningColor,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Attendance Sheet Updates Available',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_attendanceSheetInfo != null) ...[
                        Text(
                          '${_attendanceSheetInfo!.worksheetCount} worksheets, ${_attendanceSheetInfo!.totalRows} total rows',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
            ],
            
            // Loading indicator
            if (_isChecking) ...[
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
            ],
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isUpdating ? null : widget.onDismiss,
                  child: const Text('Later'),
                ),
                if ((_hasMasterUpdates || _hasAttendanceUpdates) && !_isChecking) ...[
                  const SizedBox(width: AppConstants.smallPadding),
                  GradientButton(
                    onPressed: _isUpdating ? null : _updateNow,
                    child: _isUpdating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.buttonTextColor),
                            ),
                          )
                        : const Text('Update Now', style: TextStyle(color: AppTheme.buttonTextColor)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}