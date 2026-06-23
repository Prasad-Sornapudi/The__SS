import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/class_model.dart';
import '../models/qr_payload.dart';
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/auto_upload_service.dart'; // Add this import
import '../services/enhanced_auto_sync_service.dart'; // Add this import
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_dropdown.dart';

class NoActiveClassWidget extends StatelessWidget {
  const NoActiveClassWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClassProvider>(
      builder: (context, classProvider, child) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 24),
                Text(
                  'No Active Class',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                
                // Class Selection Dropdown (if classes exist)
                if (classProvider.hasClasses) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    decoration: BoxDecoration(
                      color: AppTheme.darkNavyBlue.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                      border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Select Active Class',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomDropdown<ClassModel?>(
                          value: classProvider.activeClass,
                          hintText: 'Select a class to continue',
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
                          onChanged: (ClassModel? selectedClass) async {
                            if (selectedClass != null) {
                              final attendanceProvider = context.read<AttendanceProvider>(); // Get attendance provider
                              
                              // Ensure attendance data is loaded for the selected class
                              await attendanceProvider.ensureAttendanceLoadedForClass(selectedClass.id, attendanceProvider.sessionDate);
                              await classProvider.setActiveClass(selectedClass);
                              // Also set the active class ID in the attendance provider
                              attendanceProvider.setActiveClassId(selectedClass.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class PermissionErrorWidget extends StatelessWidget {
  final String? error;
  final VoidCallback? onRetry;

  const PermissionErrorWidget({
    super.key,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 24),
              Text(
                'Camera Access Required',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                error ?? 'Camera access is needed to scan QR codes',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              if (kIsWeb) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Web Browser Instructions',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Look for camera permission prompt in browser\n'
                        '• Click "Allow" when prompted for camera access\n'
                        '• Check browser address bar for camera icon\n'
                        '• Ensure no other apps are using your camera\n'
                        '• Try refreshing the page if camera fails to load',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GradientButton(
                    onPressed: onRetry ?? () {},
                    isEnabled: onRetry != null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh, color: AppTheme.buttonTextColor),
                        const SizedBox(width: 8),
                        const Text('Try Again', style: TextStyle(color: AppTheme.buttonTextColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showCameraTestDialog(context),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Test Camera'),
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        _showManualEntryHelp(context);
                      },
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Manual Entry'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCameraTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Test & Troubleshooting'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kIsWeb) ...[
                const Text('Web Browser Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('• Check browser address bar for camera icon'),
                const Text('• Look for permission prompt and click "Allow"'),
                const Text('• Visit chrome://settings/content/camera to check permissions'),
                const Text('• Ensure HTTPS connection (camera requires secure connection)'),
                const Text('• Close other apps that might be using camera (Zoom, Skype, etc.)'),
                const SizedBox(height: 16),
                const Text('Developer Debug:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('• Open browser developer tools (F12)'),
                const Text('• Check Console tab for camera errors'),
                const Text('• Look for "NotAllowedError" or "NotFoundError"'),
              ] else ...[
                const Text('Mobile Device Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('• Go to device Settings > Apps > This App > Permissions'),
                const Text('• Enable Camera permission'),
                const Text('• Restart the app after enabling permission'),
              ],
            ],
          ),
        ),
        actions: [
          Align(
            alignment: Alignment.centerRight,
            child: GradientButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: AppTheme.buttonTextColor)),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualEntryHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual QR Code Entry'),
        content: const Text(
          'If camera access is not available, you can manually enter QR codes or student PIN numbers in the scanner screen using the "Manual Entry" button.',
        ),
        actions: [
          Align(
            alignment: Alignment.centerRight,
            child: GradientButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: AppTheme.buttonTextColor)),
            ),
          ),
        ],
      ),
    );
  }
}

class ClassSelectionHeader extends StatelessWidget {
  final ClassModel activeClass;
  final Function(ClassModel?) onClassChanged;

  const ClassSelectionHeader({
    super.key,
    required this.activeClass,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ClassProvider>(
      builder: (context, classProvider, child) {
        return Container(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          decoration: BoxDecoration(
            gradient: AppTheme.appBackgroundGradient, // Use the same gradient as settings screen
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: const Color.fromARGB(255, 6, 30, 85),
              width: 2.0, // Stroke width of cards
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
          child: Row(
            children: [
              Icon(
                Icons.class_,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomDropdown<ClassModel?>(
                      value: activeClass,
                      hintText: 'Select active class',
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
                          // Ensure attendance data is loaded for the selected class
                          final attendanceProvider = context.read<AttendanceProvider>();
                          await attendanceProvider.ensureAttendanceLoadedForClass(newClass.id, attendanceProvider.sessionDate);
                        }
                        onClassChanged(newClass);
                      },
                    ),
                    Text(
                      '${activeClass.students.length} students',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanArea = screenSize.width * 0.7;

    return Stack(
      children: [
        // Dark overlay
        Container(
          color: AppTheme.darkNavyBlue.withOpacity(0.5),
        ),
        
        // Clear scanning area
        Center(
          child: Container(
            width: scanArea,
            height: scanArea,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.primaryColor,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        ),

        // Corner decorations
        Center(
          child: SizedBox(
            width: scanArea,
            height: scanArea,
            child: Stack(
              children: [
                // Top-left corner
                Positioned(
                  top: -2,
                  left: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppTheme.secondaryColor, width: 4),
                        left: BorderSide(color: AppTheme.secondaryColor, width: 4),
                      ),
                    ),
                  ),
                ),
                
                // Top-right corner
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppTheme.secondaryColor, width: 4),
                        right: BorderSide(color: AppTheme.secondaryColor, width: 4),
                      ),
                    ),
                  ),
                ),
                
                // Bottom-left corner
                Positioned(
                  bottom: -2,
                  left: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.secondaryColor, width: 4),
                        left: BorderSide(color: AppTheme.secondaryColor, width: 4),
                      ),
                    ),
                  ),
                ),
                
                // Bottom-right corner
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.secondaryColor, width: 4),
                        right: BorderSide(color: AppTheme.secondaryColor, width: 4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Removed instruction text as requested
      ],
    );
  }
}

class ManualEntryButton extends StatelessWidget {
  final Function(String) onManualEntry;

  const ManualEntryButton({
    super.key,
    required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GradientButton(
        onPressed: () => _showManualEntryDialog(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard, color: AppTheme.buttonTextColor),
            const SizedBox(width: 8),
            const Text('Manual Entry', style: TextStyle(color: AppTheme.buttonTextColor)),
          ],
        ),
      ),
    );
  }

  void _showManualEntryDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the student pin number or security code manually:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., 24555A0416',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  onManualEntry(value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              StrokeButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.onDarkNavy)),
              ),
              const SizedBox(width: 8),
              GradientButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) {
                    Navigator.of(context).pop();
                    onManualEntry(value);
                  }
                },
                child: const Text('Submit', style: TextStyle(color: AppTheme.buttonTextColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// New widget for manual attendance marking by entering roll numbers
class AddManuallyButton extends StatelessWidget {
  final Function(List<String>) onAddManually;

  const AddManuallyButton({
    super.key,
    required this.onAddManually,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GradientButton(
        onPressed: () => _showAddManuallyDialog(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: AppTheme.buttonTextColor),
            const SizedBox(width: 8),
            const Text('Add Manually', style: TextStyle(color: AppTheme.buttonTextColor)),
          ],
        ),
      ),
    );
  }

  void _showAddManuallyDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Attendance Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter one or multiple roll numbers (comma or space-separated):',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., 24555A0416, 24555A0417, 24555A0418',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              StrokeButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.onDarkNavy)),
              ),
              const SizedBox(width: 8),
              GradientButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) {
                    Navigator.of(context).pop();
                    // Parse roll numbers (support both comma and space separated)
                    final rollNumbers = value
                        .split(RegExp(r'[, ]+')) // Split by comma or space
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    onAddManually(rollNumbers);
                  }
                },
                child: const Text('Mark Present', style: TextStyle(color: AppTheme.buttonTextColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// New compact popup positioned at the top of screen with glass morphism
class CompactScanResultBanner extends StatelessWidget {
  final QRValidationResult result;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback? onTap;

  const CompactScanResultBanner({
    super.key,
    required this.result,
    required this.backgroundColor,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 100, // Increased distance from top to ensure it's outside camera area
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor, // Use the passed background color
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: AppTheme.darkNavyBlue, // Dark blue icon
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.studentName != null) ...[
                      Text(
                        result.studentName!,
                        style: const TextStyle(
                          color: AppTheme.darkNavyBlue, // Dark blue text
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      result.message ?? 'Scan result',
                      style: const TextStyle(
                        color: AppTheme.darkNavyBlue, // Dark blue text
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.close,
                size: 16,
                color: AppTheme.darkNavyBlue.withOpacity(0.7), // Dark blue close icon
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Stroke Button Widget
class StrokeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Future<void> Function()? onPressedAsync;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final OutlinedBorder shape;
  final bool isEnabled;
  final Color strokeColor;
  final double strokeWidth;

  const StrokeButton({
    super.key,
    this.onPressed,
    this.onPressedAsync,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(30.0)),
    ),
    this.isEnabled = true,
    this.strokeColor = AppTheme.techwingyellow,
    this.strokeWidth = 2.0,
  }) : assert(onPressed != null || onPressedAsync != null, 'Either onPressed or onPressedAsync must be provided'),
       assert(!(onPressed != null && onPressedAsync != null), 'Cannot provide both onPressed and onPressedAsync');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(
          color: isEnabled ? strokeColor : AppTheme.onDarkNavyTertiary,
          width: strokeWidth,
        ),
      ),
      child: ElevatedButton(
        onPressed: isEnabled 
            ? () {
                if (onPressed != null) {
                  onPressed!();
                } else if (onPressedAsync != null) {
                  onPressedAsync!();
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: padding,
          shape: shape,
          elevation: 0,
          foregroundColor: isEnabled ? AppTheme.onDarkNavy : AppTheme.onDarkNavyTertiary,
        ),
        child: child,
      ),
    );
  }
}

// Custom Gradient Button Widget
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Future<void> Function()? onPressedAsync;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final OutlinedBorder shape;
  final bool isEnabled;
  
  const GradientButton({
    super.key,
    this.onPressed,
    this.onPressedAsync,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(30.0)),
    ),
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isEnabled ? AppTheme.buttonGradient : AppTheme.appBackgroundGradient,
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(
          color: AppTheme.techwingyellow,
          width: 1.0,
        ),
      ),
      child: ElevatedButton(
        onPressed: isEnabled 
            ? () {
                if (onPressed != null) {
                  onPressed!();
                } else if (onPressedAsync != null) {
                  onPressedAsync!();
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: padding,
          shape: shape,
          elevation: 0,
          foregroundColor: AppTheme.buttonTextColor,
        ),
        child: child,
      ),
    );
  }
}
