// ScannerScreen.dart (Modified)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Add this import for SVG support
// import 'package:mobile_scanner/mobile_scanner.dart'; // REMOVED
// import 'package:permission_handler/permission_handler.dart'; // REMOVED
// import 'package:wakelock_plus/wakelock_plus.dart'; // REMOVED
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/user_provider.dart';
import '../services/auto_upload_service.dart'; // Add this import
import '../services/enhanced_auto_sync_service.dart'; // Add this import
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../models/qr_payload.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/scanner_widgets.dart';
import '../widgets/web_qr_scanner.dart';
import '../widgets/attendance_check_widget.dart';
import '../widgets/curved_bottom_navigation.dart';
import '../widgets/class_details_card.dart'; // Add this import
import '../widgets/custom_dropdown.dart';
import '../widgets/session_setup_widget.dart'; // Add this import
import '../widgets/unified_scanner_widget.dart'; // Add unified scanner widget import
import 'settings_screen.dart';
import 'home_screen.dart';
import '../layout/responsive_layout.dart'; // import

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  DateTime? _lastScanTime; // Add this line to track last scan time
  bool _isPopupShowing = false;
  OverlayEntry? _currentBannerOverlay;
  ScannerMode _scannerMode = ScannerMode.selection;
  int _currentIndex = 0;
  late SvgPicture _logoImage; // Change type to SvgPicture
  bool _isLogoPreloaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // _enableWakeMode(); // Handled by UnifiedScannerWidget
    _scannerMode = ScannerMode.selection;
    // _initializeScanner(); // Metadata handled by UnifiedScannerWidget
    // Initialize with a default SVG image to avoid late initialization error
    _logoImage = SvgPicture.asset(
      'assets/images/Techwing.svg',
      height: 48,
      fit: BoxFit.contain,
      // Ensure colors are preserved
      colorFilter: null,
    );
    
    // Initialize data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }
  
  void _initializeData() async {
    final classProvider = context.read<ClassProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    
    await classProvider.loadClasses();
    
    // If no classes exist, try to auto-load from Google Sheets
    if (!classProvider.hasClasses) {
      await classProvider.autoLoadClassesFromSheets();
    }
    
    // If we have an active class, initialize the attendance provider with it
    if (classProvider.hasActiveClass) {
      await attendanceProvider.initialize(
        classProvider.activeClass!.id, 
        attendanceProvider.sessionDate
      );
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload logo once after dependencies are ready
    if (!_isLogoPreloaded) {
      _preloadLogo();
      _isLogoPreloaded = true;
    }
  }

  // Preload the logo image to avoid loading delays
  void _preloadLogo() {
    final logoImage = SvgPicture.asset(
      'assets/images/Techwing.svg',
      height: 48,
      fit: BoxFit.contain,
      // Use highest quality rendering
      color: null,
      colorFilter: null,
      allowDrawingOutsideViewBox: true,
      matchTextDirection: false,
      clipBehavior: Clip.none,
      // Add additional parameters for better rendering
      excludeFromSemantics: false,
    );
    
    // For SVG, we don't need precaching as it's handled differently
    // Just replace the widget
    setState(() {
      _logoImage = logoImage;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lifecycle handling moved to UnifiedScannerWidget
  }

  /* 
  Future<void> _initializeScanner() ... REMOVED 
  */

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) {
        // Scanner initialization handled by UnifiedScannerWidget
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _buildScannerPage(),
      const HomeScreen(), // Dashboard tab index
      const SettingsScreen(),
    ];

    return Scaffold(
      // FIX 1: Set the Scaffold's background to match the main content background color
      // This prevents the black solid color from appearing in the extended area.
      backgroundColor: AppTheme.darkNavyBlue, 
      
      // FIX 2: This is the key property for floating the bottom bar.
      extendBody: true, 
      
      // FIX 3: Removed the Stack and Positioned widgets from the body.
      // The body now occupies the entire screen and scrolls underneath the nav bar.
      body: _pages[_currentIndex],
      
      bottomNavigationBar: CurvedBottomNavigation(
        selectedIndex: _currentIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  Widget _buildScannerPage() {
    return Container(
      color: AppTheme.darkNavyBlue, // Added background color to match dashboard
      child: Consumer2<ClassProvider, AttendanceProvider>(
        builder: (context, classProvider, attendanceProvider, child) {
          // Show mode selection screen
          if (_scannerMode == ScannerMode.selection) {
            return _buildModeSelectionScreen(classProvider, attendanceProvider);
          }
          
          // Show class selection if no active class and user has selected an action
          if (!classProvider.hasActiveClass && (_scannerMode == ScannerMode.scanning || _scannerMode == ScannerMode.attendanceCheck)) {
            return _buildClassSelectionScreen(classProvider, attendanceProvider);
          }

          // Show attendance check widget
          if (_scannerMode == ScannerMode.attendanceCheck) {
            return AttendanceCheckWidget(
              activeClass: classProvider.activeClass ?? classProvider.classes.first, // Fallback to first class if no active class
              attendanceProvider: attendanceProvider,
              onBack: () {
                // Set scanner mode back to selection when back button is pressed
                setState(() {
                  _scannerMode = ScannerMode.selection;
                });
              },
            );
          }

          // Show scanner for scanning mode
          if (_scannerMode == ScannerMode.scanning) {
            return ResponsiveLayout(
              mobileBody: UnifiedScannerWidget(
                activeClass: classProvider.activeClass ?? classProvider.classes.first,
                attendanceProvider: attendanceProvider,
                onScan: (code) => _onScan(code, classProvider.activeClass ?? classProvider.classes.first, attendanceProvider),
                onBack: () {
                   setState(() {
                      _scannerMode = ScannerMode.selection;
                   });
                },
                onSettings: () {
                   Navigator.pushNamed(context, '/settings');
                },
                onClassChanged: (newClass) async {
                  if (newClass != null) {
                    await attendanceProvider.ensureAttendanceLoadedForClass(newClass.id, attendanceProvider.sessionDate);
                    await classProvider.setActiveClass(newClass);
                    attendanceProvider.setActiveClassId(newClass.id);
                  }
                },
              ),
              desktopBody: _buildDesktopScanner(context, classProvider, attendanceProvider),
              tabletBody: _buildDesktopScanner(context, classProvider, attendanceProvider),
            );
          }

          // Default fallback
          return _buildModeSelectionScreen(classProvider, attendanceProvider);
        },
      ),
    );
  }

  Widget _buildClassDisplayHeader(ClassModel activeClass) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.mediumSpacing),
      decoration: AppTheme.glassContainer(),
      child: Row(
        children: [
          const Icon(
            Icons.class_,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: AppTheme.mediumSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeClass.className,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${activeClass.students.length} students',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
            onPressed: () {
              // Navigate to class selection screen
              Navigator.pushNamed(context, '/class-selection');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveClassScreen(ClassProvider classProvider, AttendanceProvider attendanceProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.largeSpacing),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppTheme.largeSpacing),
            Text(
              'No Active Class Selected',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.mediumSpacing),
            Text(
              'Please select a class to continue',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.extraLargeSpacing),
            ElevatedButton(
              onPressed: () {
                // Navigate to class selection screen
                Navigator.pushNamed(context, '/class-selection');
              },
              child: const Text('Select Class'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSelectionScreen(ClassProvider classProvider, AttendanceProvider attendanceProvider) {
    // MODIFIED: This method now returns a Column, not a Scaffold.
    return Padding(
      padding: const EdgeInsets.all(AppTheme.largeSpacing),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Select Active Class',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppTheme.extraLargeSpacing),
          
          if (classProvider.hasClasses) ...[
            CustomDropdown<ClassModel?>(
              value: null, // No initial value
              hintText: 'Select a class to continue',
              onChanged: (ClassModel? selectedClass) async {
                if (selectedClass != null) {
                  final autoUploadService = context.read<AutoUploadService>();
                  final enhancedAutoSyncService = EnhancedAutoSyncService(); // Get the singleton instance
                  
                  // Ensure attendance data is loaded for the selected class
                  await attendanceProvider.ensureAttendanceLoadedForClass(selectedClass.id, attendanceProvider.sessionDate);
                  await classProvider.setActiveClass(selectedClass);
                  // Always load attendance data for the newly selected class
                  // This ensures we show the correct data for the selected class
                  await attendanceProvider.loadAttendanceForSession(selectedClass.id, attendanceProvider.sessionDate);
                  // Also set the active class ID in the attendance provider
                  attendanceProvider.setActiveClassId(selectedClass.id);
                  
                  // Start auto-upload service with the new class
                  // Start auto-upload if configured with triggerSync: true to ensure proper initialization
                  autoUploadService.startAutoUpload(selectedClass, triggerSync: true);
                  
                  // DISABLED: Enhanced auto sync is now disabled
                  // Start enhanced auto sync with triggerSync: true to ensure proper initialization
                  // enhancedAutoSyncService.startAutoSync(selectedClass, triggerSync: true);
                  
                  if (mounted) {
                    setState(() {});
                  }
                }
              },
              items: classProvider.classes.map((classModel) {
                return DropdownMenuItem<ClassModel>(
                  value: classModel,
                  child: Text(
                    classModel.className,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.extraLargeSpacing),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.mediumSpacing),
              decoration: AppTheme.glassCard().copyWith( // Changed from glassContainer() to glassCard() to match dashboard
                border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'No Classes Available',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.warningColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.smallSpacing),
                  Text(
                    'Go to Settings to add classes',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.mediumSpacing),
          ],
          
          ElevatedButton(
            onPressed: () {
              // Navigate to settings to add classes
              DefaultTabController.of(context)?.animateTo(2);
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectionScreen(ClassProvider classProvider, AttendanceProvider attendanceProvider) {
    // MODIFIED: This method now returns a Consumer with a Column, not a Scaffold.
    return Container(
      color: AppTheme.darkNavyBlue, // Added background color to match dashboard
      child: Consumer<UserProvider?>(
        builder: (context, userProvider, child) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.mediumSpacing),
                child: Center(
                  // Use preloaded logo image
                  child: _logoImage,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.mediumSpacing),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppTheme.largeSpacing),
                        
                        if (userProvider?.isLoggedIn == true) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Hi,',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppTheme.onDarkNavySecondary,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                style: Theme.of(context).textTheme.headlineMedium,
                                children: [
                                  TextSpan(
                                    text: '${userProvider!.userDisplayName?.isNotEmpty == true ? userProvider!.userDisplayName : userProvider!.userName}',
                                  ),
                                  TextSpan(
                                    text: ' garu',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.normal,
                                      color: AppTheme.onDarkNavySecondary,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          const SizedBox(height: AppTheme.largeSpacing),
                        ],
                        
                        if (userProvider?.isLoggedIn != true) ...[
                          Text(
                            'Attendance Scanner',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: AppTheme.largeSpacing),
                        ],
                        
                        _buildModeCard(
                          context,
                          icon: Icons.assignment,
                          title: 'Attendance',
                          subtitle: 'Scan QR codes or check attendance records',
                          actions: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: classProvider.hasClasses ? () {
                                  setState(() {
                                    _scannerMode = ScannerMode.attendanceCheck;
                                  });
                                } : null,
                                icon: const Icon(Icons.search, size: 20),
                                label: const Text('Check'),
                              ),
                            ),
                            const SizedBox(width: AppTheme.mediumSpacing),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: classProvider.hasClasses ? () {
                                  setState(() {
                                    _scannerMode = ScannerMode.scanning;
                                  });
                                } : () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: classProvider.hasClasses ? AppTheme.primaryColor : AppTheme.onDarkNavyTertiary,
                                  foregroundColor: classProvider.hasClasses ? AppTheme.darkNavyBlue : AppTheme.onDarkNavySecondary,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30.0),
                                  ),
                                ),
                                icon: const Icon(Icons.qr_code_scanner, size: 20),
                                label: const Text('Scan'),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: AppTheme.mediumSpacing),
                        
                        _buildModeCard(
                          context,
                          icon: Icons.school,
                          title: 'Class Details',
                          subtitle: 'View and manage class information and student details',
                          actions: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Show SessionSetupWidget in a dialog instead of navigating
                                  _showSessionSetupDialog(context, '/class-details');
                                },
                                icon: const Icon(Icons.school, size: 20),
                                label: const Text('View Details'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: AppTheme.darkNavyBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: AppTheme.mediumSpacing),
                        
                        _buildModeCard(
                          context,
                          icon: Icons.search,
                          title: 'Student Details',
                          subtitle: 'Search for student information by roll number',
                          actions: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Show SessionSetupWidget in a dialog for student search
                                  _showSessionSetupDialog(context, '/student-search');
                                },
                                icon: const Icon(Icons.search, size: 20),
                                label: const Text('Search'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: AppTheme.darkNavyBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: AppTheme.mediumSpacing),
                        
                        _buildModeCard(
                          context,
                          icon: Icons.work,
                          title: 'Mock Interviews',
                          subtitle: 'Conduct and manage mock interviews for students',
                          actions: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Show SessionSetupWidget in a dialog for mock interviews
                                  _showSessionSetupDialog(context, '/mock-interview');
                                },
                                icon: const Icon(Icons.work, size: 20),
                                label: const Text('Start Interview'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: AppTheme.darkNavyBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: AppTheme.extraLargeSpacing),

                        if (!classProvider.hasClasses) ...[
                          Container(
                            padding: const EdgeInsets.all(AppTheme.mediumSpacing),
                            decoration: AppTheme.glassCard().copyWith( // Changed from glassContainer() to glassCard() to match dashboard
                              border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'No Classes Available',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.smallSpacing),
                                Text(
                                  'Go to Settings to add classes before scanning',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.mediumSpacing),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _currentIndex = 2;
                                });
                              },
                              child: const Text('Go to Settings'),
                            ),
                          ),
                        ],
                        // Added extra space to push content up and clear the bottom bar area
                        const SizedBox(height: 100), 
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required List<Widget> actions}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.mediumSpacing),
      decoration: AppTheme.glassCard(), // Changed from glassContainer() to glassCard() to match dashboard
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.mediumRadius),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppTheme.mediumSpacing),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.mediumSpacing),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppTheme.mediumSpacing),
          Row(
            children: actions,
          ),
        ],
      ),
    );
  }

  Future<void> _onScan(
    String code,
    ClassModel activeClass,
    AttendanceProvider attendanceProvider,
  ) async {
    // Add debouncing logic to limit scan frequency
    final now = DateTime.now();
    if (_lastScanTime != null) {
      final difference = now.difference(_lastScanTime!);
      // Ensure at least 300ms between scans (limits to ~3 scans per second)
      if (difference.inMilliseconds < 300) {
        return;
      }
    }
    _lastScanTime = now;

    await _processQRCode(code, activeClass, attendanceProvider);
  }

  Future<void> _processQRCode(
    String qrData,
    ClassModel activeClass,
    AttendanceProvider attendanceProvider,
  ) async {
    try {
      final result = await attendanceProvider.processQRScan(
        qrData,
        activeClass,
        scanMethod: ScanMethod.qrCamera,
      );

      if (mounted) {
        _showScanResult(result);
      }
    } catch (e) {
      if (mounted) {
        _showScanResult(QRValidationResult.invalid(
          message: 'Error processing QR code: $e',
        ));
      }
    }
  }

  Future<void> _processManualEntry(
    String code,
    ClassModel activeClass,
    AttendanceProvider attendanceProvider,
  ) async {
    await _processQRCode(code, activeClass, attendanceProvider);
  }

  void _showScanResult(QRValidationResult result) {
    Color backgroundColor;
    final iconColor = Colors.white;
    IconData icon;
    
    switch (result.status) {
      case QRValidationStatus.valid:
        // Smooth Green for successful scan
        backgroundColor = const Color(0xFF4CAF50); // Green 500
        icon = Icons.check_circle;
        break;
      case QRValidationStatus.duplicate:
        // Smooth Yellow/Amber for duplicate scan
        backgroundColor = const Color(0xFFFFC107); // Amber 500
        icon = Icons.warning_amber_rounded;
        break;
      case QRValidationStatus.invalid:
        // Smooth Red for student not found
        backgroundColor = const Color(0xFFEF5350); // Red 400
        icon = Icons.error_outline;
        break;
    }

    _showScanOverlay(result, backgroundColor, icon);
  }

  void _showScanOverlay(QRValidationResult result, Color backgroundColor, IconData icon) {
    _dismissCurrentBanner();
    
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      
      _isPopupShowing = true;
      
      _currentBannerOverlay = OverlayEntry(
        builder: (context) => CompactScanResultBanner(
          result: result,
          backgroundColor: backgroundColor,
          icon: icon,
          onTap: _dismissCurrentBanner,
        ),
      );
      
      Overlay.of(context).insert(_currentBannerOverlay!);

      Future.delayed(AppConstants.scanPopupDuration, () {
        if (mounted) {
          _dismissCurrentBanner();
        }
      });
    });
  }
  
  void _dismissCurrentBanner() {
    _isPopupShowing = false;
    
    if (_currentBannerOverlay != null) {
      try {
        _currentBannerOverlay!.remove();
      } catch (e) {
        print('Error removing banner overlay: $e');
      } finally {
        _currentBannerOverlay = null;
      }
    }
  }

  void _dismissCurrentPopup() {
    _dismissCurrentBanner();
  }

  /* 
  void _toggleFlash() ... REMOVED
  void _switchCamera() ... REMOVED
  */

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissCurrentBanner();
    _dismissCurrentPopup();
    super.dispose();
  }

  /* 
  _enableWakeMode() ... REMOVED
  _disableWakeMode() ... REMOVED
  _testCameraAccess() ... REMOVED
  */

  void setScannerMode(ScannerMode mode) {
    setState(() {
      _scannerMode = mode;
    });
  }

  ScannerMode getScannerMode() => _scannerMode;

  // Add this method to show the SessionSetupWidget in a dialog
  void _showSessionSetupDialog(BuildContext context, String targetRoute) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: SessionSetupWidget(
            buttonText: targetRoute == '/student-search' 
                ? 'Search Students' 
                : (targetRoute == '/mock-interview' ? 'Start Interview' : 'View Details'),
            onBack: () {
              Navigator.of(context).pop();
            },
            onStartSession: (classModel, combo, sessionType) async {
              print('Class selected: ${classModel.className}, Session: $sessionType');
              // Close the dialog
              Navigator.of(context).pop();
              // Set the active class
              final classProvider = context.read<ClassProvider>();
              await classProvider.setActiveClass(classModel);
              // For student search, navigate directly to the search screen
              if (targetRoute == '/student-search') {
                Navigator.pushNamed(context, '/student-search');
              } else {
                // For other routes, navigate normally
                Navigator.pushNamed(context, targetRoute);
              }
            },
          ),
        );
      },
    );
  }
  Widget _buildRecentScansList(AttendanceProvider attendanceProvider) {
    // Get recent records for the current session, sorted by scan time (newest first)
    final recentRecords = attendanceProvider.attendanceRecords
        .where((r) => r.status == AttendanceStatus.present && r.sessionDate == attendanceProvider.sessionDate)
        .toList()
      ..sort((a, b) => b.scanTime.compareTo(a.scanTime)); // Descending order
      
    if (recentRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlue.withOpacity(0.9),
        border: Border(
          top: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.history, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Recently Scanned (${recentRecords.length})',
                  style: const TextStyle(
                    color: AppTheme.onDarkNavySecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              scrollDirection: Axis.horizontal,
              itemCount: recentRecords.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final record = recentRecords[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(bottom: 12), // Margin for shadow
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.glassGradient,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.studentPinNumber,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        record.studentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            record.displayTime,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                            ),
                          ),
                          Icon(
                            record.isSyncedToSheet ? Icons.cloud_done : Icons.cloud_upload_outlined,
                            size: 12,
                            color: record.isSyncedToSheet ? AppTheme.successColor : Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildDesktopScanner(BuildContext context, ClassProvider classProvider, AttendanceProvider attendanceProvider) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.mediumSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Scanner and Controls
          Expanded(
            flex: 2,
            child: UnifiedScannerWidget(
              activeClass: classProvider.activeClass ?? classProvider.classes.first,
              attendanceProvider: attendanceProvider,
              onScan: (code) => _onScan(code, classProvider.activeClass ?? classProvider.classes.first, attendanceProvider),
              onBack: () {
                 setState(() {
                    _scannerMode = ScannerMode.selection;
                 });
              },
              onSettings: () {
                 Navigator.pushNamed(context, '/settings');
              },
              onClassChanged: (newClass) async {
                  if (newClass != null) {
                    await attendanceProvider.ensureAttendanceLoadedForClass(newClass.id, attendanceProvider.sessionDate);
                    await classProvider.setActiveClass(newClass);
                    attendanceProvider.setActiveClassId(newClass.id);
                  }
                },
            ),
          ),
          
          const SizedBox(width: AppTheme.largeSpacing),
          
          // Right: Recent Scans (Fixed Width)
          SizedBox(
            width: 400,
            child: _buildRecentScansList(attendanceProvider),
          ),
        ],
      ),
    );
  }
}

enum ScannerMode {
  selection,
  scanning,
  attendanceCheck,
}