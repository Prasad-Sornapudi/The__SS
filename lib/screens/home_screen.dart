import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:mobile_scanner/mobile_scanner.dart'; // Add mobile scanner import
import 'package:flutter_svg/flutter_svg.dart'; // Add SVG import
import 'package:wakelock_plus/wakelock_plus.dart'; // Add wakelock import
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode; // Add system chrome import
import '../widgets/scanner_widgets.dart'; // Import GradientButton and other widgets
import '../widgets/dashboard_widgets.dart';
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/user_provider.dart';
import '../providers/bottom_navigation_provider.dart'; // Add bottom navigation provider import
import '../models/class_model.dart';
import '../services/auto_upload_service.dart';
import '../services/enhanced_auto_sync_service.dart';
import '../services/background_sync_service.dart';
import '../services/google_sheets_service.dart'; // ADD THIS IMPORT
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/session_setup_widget.dart'; // Add SessionSetupWidget import
import '../models/session_model.dart' as session_model; // Add session model import
import '../screens/dashboard_screen.dart'; // Add dashboard screen import
import '../screens/settings_screen.dart'; // Add settings screen import
import '../screens/class_details_screen.dart'; // Add class details screen import
import '../widgets/curved_bottom_navigation.dart'; // Add curved bottom navigation import
import '../widgets/attendance_check_widget.dart'; // Add attendance check widget import
import '../widgets/web_qr_scanner.dart'; // Add web qr scanner import
import '../models/qr_payload.dart'; // Add QR validation result import
import '../models/attendance_record.dart'; // Add ScanMethod import
import '../widgets/unified_scanner_widget.dart'; // Add UnifiedScannerWidget import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Removed internal controller state as UnifiedScannerWidget handles it
  DateTime? _lastScanTime; // Add this line to track last scan time
  bool _isPopupShowing = false;
  OverlayEntry? _currentBannerOverlay;
  ScannerMode _scannerMode = ScannerMode.selection;

  bool _initialTabSet = false; // Flag to prevent overriding user selection
  late SvgPicture _logoImage; // Change type to SvgPicture
  bool _isLogoPreloaded = false;

  @override
  void initState() {
    super.initState();
    print('HomeScreen: initState called. Hash: ${hashCode}');
    WidgetsBinding.instance.addObserver(this);
    
    _enableWakeMode();
    _scannerMode = ScannerMode.selection;
    // _initializeScanner(); // Logic handled by UnifiedScannerWidget
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
    
    // Clear active class on startup to force session setup (User Request: First time for the day should show setup)
    await classProvider.setActiveClass(null);
    attendanceProvider.setActiveClassId(null);
    
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
  
  // State variables cleaned up
  
  // ... (existing code)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check for initial tab index from arguments
    if (!_initialTabSet) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('initialTabIndex')) {
        final initialIndex = args['initialTabIndex'] as int;
        // Update provider instead of local state
        WidgetsBinding.instance.addPostFrameCallback((_) {
           context.read<BottomNavigationProvider>().setIndex(initialIndex);
        });
      }
      _initialTabSet = true;
    }

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
    // Lifecycle handled by UnifiedScannerWidget now
  }

  // _initializeScanner removed - logic moved to UnifiedScannerWidget

  void _onItemTapped(int index) {
    context.read<BottomNavigationProvider>().setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider to trigger the deferred logic
    final navProvider = context.watch<BottomNavigationProvider>();
    final currentIndex = navProvider.currentIndex;

    return Scaffold(
      backgroundColor: const Color(0xFF040C1B), 
      extendBody: true, 
      
      // The Body uses the IMMEDIATE currentIndex. 
      // We wrap children in RepaintBoundary to isolate their heavy paints from the animation.
      body: PopScope(
            canPop: false, 
            onPopInvoked: (bool didPop) {
              if (didPop) return;
              
              if (currentIndex != 0) {
                 context.read<BottomNavigationProvider>().setIndex(0);
                 return;
              }
              
             if (_scannerMode == ScannerMode.scanning) {
                setState(() {
                  _scannerMode = ScannerMode.sessionSetup;
                });
              } else if (_scannerMode == ScannerMode.sessionSetup) {
                 setState(() {
                   _scannerMode = ScannerMode.selection;
                 });
              } else if (_scannerMode == ScannerMode.attendanceCheck) {
                 setState(() {
                   _scannerMode = ScannerMode.selection;
                 });
              } else if (_scannerMode == ScannerMode.selection) {
                 // Root handling
              }
            },
            child: IndexedStack(
              index: currentIndex, // Direct index
              children: [
                RepaintBoundary(
                  child: _buildScannerPage(isActive: currentIndex == 0),
                ),
                RepaintBoundary(
                    child: DashboardScreen(
                      startAutoSyncOnLoad: true, 
                      isVisible: currentIndex == 1, 
                    ),
                ),
                const RepaintBoundary(child: SettingsScreen()),
              ],
            ),
      ),
      
      // The Navigation Bar also uses the IMMEDIATE provider index
      bottomNavigationBar: Selector<BottomNavigationProvider, int>(
        selector: (_, provider) => provider.currentIndex,
        builder: (context, currentIndex, child) {
          return CurvedBottomNavigation(
            selectedIndex: currentIndex,
            onItemTapped: _onItemTapped,
          );
        },
      ),
    );
  }

  Widget _buildScannerPage({required bool isActive}) {
    return Container(
      color: const Color(0xFF040C1B), // Added background color to match dashboard
      child: Consumer2<ClassProvider, AttendanceProvider>(
        builder: (context, classProvider, attendanceProvider, child) {
          // Inner PopScope removed - global one handles it all
          return Builder(builder: (context) {
              // Show mode selection screen
              if (_scannerMode == ScannerMode.selection) {
                return _buildModeSelectionScreen(classProvider, attendanceProvider);
              }
          
          // Show session setup screen (Batch/Combo/Time selection)
          if (_scannerMode == ScannerMode.sessionSetup) {
            return SessionSetupWidget(
              onBack: () {
                setState(() {
                  _scannerMode = ScannerMode.selection;
                });
              },
              onStartSession: (selectedClass, selectedCombo, sessionType) async {
                print('Starting session for class: ${selectedClass.className} ($selectedCombo) - $sessionType');
                
                // Set active class
                await classProvider.setActiveClass(selectedClass);
                
                // Initialize attendance provider with session type
                // This ensures AM/PM logic is correctly applied
                await attendanceProvider.initialize(
                  selectedClass.id, 
                  DateTime.now(),
                  sessionType // Pass the session type (Morning/Afternoon)
                );
                
                // Switch to scanning mode
                setState(() {
                  _scannerMode = ScannerMode.scanning;
                });
              },
            );
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
            return UnifiedScannerWidget(
              isActive: isActive, // Propagate active state
              activeClass: classProvider.activeClass ?? classProvider.classes.first,
              attendanceProvider: attendanceProvider,
              onScan: (code) {
                // Apply debouncing logic
                final now = DateTime.now();
                if (_lastScanTime != null) {
                  final difference = now.difference(_lastScanTime!);
                  // Ensure at least 300ms between scans
                  if (difference.inMilliseconds < 300) {
                    return;
                  }
                }
                _lastScanTime = now;
                
                // Process the scan
                _processQRCode(
                  code, 
                  classProvider.activeClass ?? classProvider.classes.first, 
                  attendanceProvider
                );
              },
              onBack: () {
                setState(() {
                  _scannerMode = ScannerMode.sessionSetup;
                });
              },
              onSettings: () {
                Navigator.pushNamed(context, '/settings');
              },
              onClassChanged: (newClass) async {
                if (newClass != null) {
                  // Ensure attendance data is loaded for the selected class
                  await attendanceProvider.ensureAttendanceLoadedForClass(newClass.id, attendanceProvider.sessionDate);
                  await classProvider.setActiveClass(newClass);
                  // Also set the active class ID in the attendance provider
                  attendanceProvider.setActiveClassId(newClass.id);
                  setState(() {});
                }
              },
            );
          }

              // Default fallback
              return _buildModeSelectionScreen(classProvider, attendanceProvider);
            });
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
            GradientButton(
              onPressed: () {
                // Navigate to class selection screen
                Navigator.pushNamed(context, '/class-selection');
              },
              child: const Text('Select Class', style: TextStyle(color: AppTheme.buttonTextColor)),
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
          // Back button to return to mode selection
          Align(
            alignment: Alignment.centerLeft,
            child: GradientButton(
              onPressed: () {
                setState(() {
                  _scannerMode = ScannerMode.selection;
                });
              },
              child: const Icon(Icons.arrow_back, size: 20, color: AppTheme.buttonTextColor),
            ),
          ),
          const SizedBox(height: AppTheme.mediumSpacing),
          Text(
            'Select Active Class',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppTheme.mediumSpacing),
          
          if (classProvider.hasClasses) ...[
            // List of classes to select from - using the same interface as Class Details screen
            Expanded(
              child: ListView.builder(
                itemCount: classProvider.classes.length,
                itemBuilder: (context, index) {
                  final classModel = classProvider.classes[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.smallSpacing),
                    decoration: AppTheme.glassCard(),
                    child: ListTile(
                      title: Text(
                        classModel.className,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      subtitle: Text(
                        '${classModel.students.length} students',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: AppTheme.techwingyellow,
                        size: 16,
                      ),
                      onTap: () async {
                        // Ensure attendance data is loaded for the selected class
                        await attendanceProvider.ensureAttendanceLoadedForClass(classModel.id, attendanceProvider.sessionDate);
                        await classProvider.setActiveClass(classModel);
                        // Always load attendance data for the newly selected class
                        // This ensures we show the correct data for the selected class
                        await attendanceProvider.loadAttendanceForSession(classModel.id, attendanceProvider.sessionDate);
                        // Also set the active class ID in the attendance provider
                        attendanceProvider.setActiveClassId(classModel.id);
                        
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.mediumSpacing),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.midnightIndigo,
                    AppTheme.veryDarkNavy,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  tileMode: TileMode.clamp,
                ),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: AppTheme.warningColor.withOpacity(0.3),
                  width: 2,
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
          
          GradientButton(
            onPressed: () {
              // Navigate to settings to add classes
              DefaultTabController.of(context)?.animateTo(2);
            },
            child: const Text('Go to Settings', style: TextStyle(color: AppTheme.buttonTextColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectionScreen(ClassProvider classProvider, AttendanceProvider attendanceProvider) {
    // MODIFIED: This method now returns a Consumer with a Column, not a Scaffold.
    return Container(
      color: Color(0xFF040C1B), // Changed the Background color 
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
                              child: StrokeButton(
                                isEnabled: classProvider.hasClasses,
                                onPressed: () {
                                  setState(() {
                                    _scannerMode = ScannerMode.attendanceCheck;
                                  });
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.search, size: 20, color: AppTheme.onDarkNavy),
                                    const SizedBox(width: 8),
                                    const Text('Check', style: TextStyle(color: AppTheme.onDarkNavy)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.mediumSpacing),
                            Expanded(
                              child: GradientButton(
                                isEnabled: classProvider.hasClasses,
                                onPressed: () {
                                  setState(() {
                                    // SMART RESUME: If a class is already active, go straight to scanning
                                    if (classProvider.hasActiveClass) {
                                       _scannerMode = ScannerMode.scanning;
                                    } else {
                                       // Otherwise, go to session setup first
                                       _scannerMode = ScannerMode.sessionSetup;
                                    }
                                  });
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.qr_code_scanner, size: 20, color: AppTheme.buttonTextColor),
                                    const SizedBox(width: 8),
                                    const Text('Scan', style: TextStyle(color: AppTheme.buttonTextColor)),
                                  ],
                                ),
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GradientButton(
                                    onPressed: () {
                                      // Navigate to class selection screen by temporarily clearing active class
                                      final classProvider = context.read<ClassProvider>();
                                      classProvider.setActiveClass(null);
                                      Navigator.pushNamed(context, '/class-details');
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.school, size: 20, color: AppTheme.buttonTextColor),
                                        const SizedBox(width: 8),
                                        const Text('View Details', style: TextStyle(color: AppTheme.buttonTextColor)),
                                      ],
                                    ),
                                  ),
                                ],
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GradientButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/student-search');
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.search, size: 20, color: AppTheme.buttonTextColor),
                                        const SizedBox(width: 8),
                                        const Text('Search', style: TextStyle(color: AppTheme.buttonTextColor)),
                                      ],
                                    ),
                                  ),
                                ],
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GradientButton(
                                    onPressed: () {
                                      print('Navigating to mock interview start screen');
                                      Navigator.pushNamed(context, '/mock-interview');
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.work, size: 20, color: AppTheme.buttonTextColor),
                                        const SizedBox(width: 8),
                                        const Text('Start Interview', style: TextStyle(color: AppTheme.buttonTextColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: AppTheme.mediumSpacing),
                        
                        // ADD THIS NEW CARD FOR TESTING BACKGROUND SYNC
                        _buildModeCard(
                          context,
                          icon: Icons.sync,
                          title: 'Test Background Sync',
                          subtitle: 'Test background sync functionality (Debug only)',
                          actions: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GradientButton(
                                    onPressed: kDebugMode ? _testBackgroundSync : null,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.sync, size: 20, color: AppTheme.buttonTextColor),
                                        const SizedBox(width: 8),
                                        const Text('Test Sync', style: TextStyle(color: AppTheme.buttonTextColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: AppTheme.extraLargeSpacing),

                        if (!classProvider.hasClasses) ...[
                          Container(
                            padding: const EdgeInsets.all(AppTheme.mediumSpacing),
                            decoration: BoxDecoration(
                              gradient: AppTheme.appBackgroundGradient, // Use the same gradient as settings screen
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: const Color.fromARGB(255, 5, 78, 224),
                                width: 2,
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
                            child: GradientButton(
                              onPressed: () {
                                context.read<BottomNavigationProvider>().setIndex(2);
                              },
                              child: const Text('Go to Settings', style: TextStyle(color: AppTheme.buttonTextColor)),
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

  Future<void> _onQRDetected(
    BarcodeCapture capture,
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

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final qrData = barcodes.first.rawValue;
    if (qrData == null) return;

    await _processQRCode(qrData, activeClass, attendanceProvider);
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
        // Green color for successful scan
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case QRValidationStatus.duplicate:
        // Yellow color for duplicate scan
        backgroundColor = Colors.yellow;
        icon = Icons.warning;
        break;
      case QRValidationStatus.invalid:
        // Red color for student not found
        backgroundColor = Colors.red;
        icon = Icons.error;
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



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Timer removed
    _dismissCurrentBanner();
    _dismissCurrentPopup();
    _disableWakeMode();
    super.dispose();
  }

  void _enableWakeMode() async {
    try {
      await WakelockPlus.enable();
      print('Wakelock enabled - screen will stay on');
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      print('System UI mode set - screen will stay on');
    } catch (e) {
      print('Failed to enable wake mode: $e');
    }
  }

  void _disableWakeMode() async {
    try {
      await WakelockPlus.disable();
      print('Wakelock disabled - normal screen behavior restored');
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      print('System UI mode restored - normal screen behavior');
    } catch (e) {
      print('Failed to disable wake mode: $e');
    }
  }

  Future<void> _testCameraAccess() async {
    print('Testing camera access...');
    
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Camera Test'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('To test camera access:'),
              const SizedBox(height: 12),
              const Text('• Open browser developer tools (F12)'),
              const Text('• Go to Console tab'),
              const Text('• Look for camera-related errors'),
              const SizedBox(height: 12),
              const Text('Or try:'),
              const Text('• Visit: chrome://settings/content/camera'),
              const Text('• Check if this site is allowed'),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      final permission = await Permission.camera.status;
      print('Current camera permission: $permission');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera permission: ${permission.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ADD THIS NEW METHOD FOR TESTING BACKGROUND SYNC
  Future<void> _testBackgroundSync() async {
    try {
      // Check if background sync service is running
      final isRunning = await BackgroundSyncService.isServiceRunning();
      print('Background sync service is running: $isRunning');
      
      if (!isRunning) {
        // Try to start the service
        final started = await BackgroundSyncService.startService();
        print('Background sync service started: $started');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Background sync service ${started ? "started" : "failed to start"}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Background sync service is already running'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error testing background sync: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing background sync: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void setScannerMode(ScannerMode mode) {
    setState(() {
      _scannerMode = mode;
    });
  }

  ScannerMode getScannerMode() => _scannerMode;
}

enum ScannerMode {
  selection,
  sessionSetup, // Add session setup mode
  scanning,
  attendanceCheck,
}