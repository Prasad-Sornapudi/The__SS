import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert'; // For utf8 encode
import 'dart:io'; // Add dart:io
import 'package:path_provider/path_provider.dart'; // Add path_provider
import 'package:csv/csv.dart'; // Add csv
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'dart:async';
import '../providers/class_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/auto_upload_service.dart';
import '../services/google_sheets_service.dart';
import '../services/department_sheet_service.dart';
import '../services/hive_service.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../widgets/dashboard_widgets.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../services/data_persistence_test_service.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/combo_dropdown.dart';
import '../widgets/sync_progress_bar.dart';
import '../widgets/scanner_widgets.dart';
import '../models/session_model.dart';
import '../screens/combo_selection_screen.dart';
import '../layout/responsive_layout.dart'; // import
import '../screens/batch_selection_screen.dart'; // Add import

class DashboardScreen extends StatefulWidget {
  final bool startAutoSyncOnLoad;
  
  const DashboardScreen({
    super.key, 
    this.startAutoSyncOnLoad = false,
    this.isVisible = false, // Add isVisible parameter
  });

  final bool isVisible; // Add field

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late TabController _tabController;
  late PageController _pageController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Add session type state
  SessionType _currentSessionType = SessionType.morning;

  String? _lastActiveClassId;
  bool _isSyncing = false; // Track sync state locally

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController();
    
    // Initialize session type based on current time
    final now = DateTime.now();
    // Morning if < 13:30, Afternoon if >= 13:30
    final isAm = now.hour < 13 || (now.hour == 13 && now.minute < 30);
    _currentSessionType = isAm ? SessionType.morning : SessionType.afternoon;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() async {
    final classProvider = context.read<ClassProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    final autoUploadService = context.read<AutoUploadService>();
    
    await classProvider.loadClasses();
    
    // If no classes exist, try to auto-load from Google Sheets
    if (!classProvider.hasClasses) {
      await classProvider.autoLoadClassesFromSheets();
    }
    
    if (classProvider.hasActiveClass) {
      // Ensure attendance data is loaded for the active class
      await attendanceProvider.ensureAttendanceLoadedForClass(classProvider.activeClass!.id, attendanceProvider.sessionDate);
      // Set the active class ID in the attendance provider
      attendanceProvider.setActiveClassId(classProvider.activeClass!.id);
      
      // Start auto-upload if configured or if forced by parameter
      if (widget.startAutoSyncOnLoad) {
         autoUploadService.startAutoUpload(classProvider.activeClass!, triggerSync: true);
      } else {
         autoUploadService.startAutoUpload(classProvider.activeClass!);
      }
    }
  }

  /// Export scanned roll numbers as CSV
  Future<void> _exportScannedRollNumbers(BuildContext context, ClassModel activeClass) async {
    try {
      final attendanceProvider = context.read<AttendanceProvider>();
      
      // Get present students
      final presentStudents = attendanceProvider.getPresentStudents();
      
      if (presentStudents.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No scanned roll numbers to export'),
              backgroundColor: AppTheme.warningColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      // Create CSV data with enhanced columns
      final csvData = <List<String>>[
        ['Name of the Student', 'Pin-number', 'Branch', 'COMBO', 'Scan Time'], // Enhanced Header row
      ];
      
      // Add data rows with enriched student data
      for (final record in presentStudents) {
        // Find full student details from the class roster to get Branch and Combo
        // We look up by pin number
        final student = activeClass.students.firstWhere(
          (s) => s.pinNumber == record.studentPinNumber,
          orElse: () => Student.empty().copyWith(
            pinNumber: record.studentPinNumber,
            name: record.studentName,
          ),
        );

        csvData.add([
          record.studentName,
          record.studentPinNumber,
          student.branch,
          student.combo,
          record.displayTime,
        ]);
      }
      
      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvData);
      final fileName = 'attendance_${activeClass.className}_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (kIsWeb) {
        // Web-specific download logic
        try {
          final bytes = utf8.encode(csvString);
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = fileName;
          html.document.body!.children.add(anchor);
          anchor.click();
          html.document.body!.children.remove(anchor);
          html.Url.revokeObjectUrl(url);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloaded $fileName'),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          print('Web export error: $e');
          throw Exception('Failed to download file on web: $e');
        }
      } else {
        // Mobile/Native logic using Share Plus
        // Use temporary directory which is accessible
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$fileName';
        
        final file = File(filePath);
        await file.writeAsString(csvString);
        
        // Share the file
        final result = await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Attendance Export - ${activeClass.className}',
        );
        
        if (result.status == ShareResultStatus.success) {
           if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Export shared successfully'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error exporting CSV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting CSV: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSessionType() {
    final newType = _currentSessionType == SessionType.morning 
        ? SessionType.afternoon 
        : SessionType.morning;
        
    setState(() {
      _currentSessionType = newType;
    });

    // Trigger data reload for the new session type
    final classProvider = context.read<ClassProvider>();
    if (classProvider.hasActiveClass) {
      final attendanceProvider = context.read<AttendanceProvider>();
      // We use the current session date but override the time based on the new session type
      // Use loadAttendanceForSession to FORCE reload data for the new session type
      attendanceProvider.loadAttendanceForSession(
        classProvider.activeClass!.id,
        attendanceProvider.sessionDate,
        overrideSessionType: newType
      );
    }
  }

  void _onClassChanged(ClassModel newClass) {
    // When class changes, we should trigger immediate sync
    print('Class changed to: ${newClass.className}');
    
    // Start auto-upload service with the new class
    final autoUploadService = context.read<AutoUploadService>();
    autoUploadService.startAutoUpload(newClass);
  }



  @override
  Widget build(BuildContext context) {
    super.build(context); // Add this to make AutomaticKeepAliveClientMixin work
    return Scaffold(
      backgroundColor: AppTheme.darkNavyBlue,
      body: Consumer2<ClassProvider, AttendanceProvider>(
        builder: (context, classProvider, attendanceProvider, child) {
          // Listen for class changes
          if (classProvider.activeClass != null) {
            if (_lastActiveClassId != null && _lastActiveClassId != classProvider.activeClass!.id) {
              _lastActiveClassId = classProvider.activeClass!.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                 _onClassChanged(classProvider.activeClass!);
              });
            } else {
              _lastActiveClassId = classProvider.activeClass!.id;
            }
          }

          // If no active class, show Batch Selection directly (Embedded)
          if (!classProvider.hasActiveClass) {
             return const BatchSelectionView();
          }

          final activeClass = classProvider.activeClass!;
          final summary = attendanceProvider.getSessionSummary(activeClass);

          return ResponsiveLayout(
            mobileBody: _buildMobileDashboard(context, summary, activeClass, attendanceProvider),
            desktopBody: _buildDesktopDashboard(context, summary, activeClass, attendanceProvider),
            tabletBody: _buildDesktopDashboard(context, summary, activeClass, attendanceProvider),
          );
        },
      ),
    );
  }


// Separate widget to handle side-effects of navigation



  Widget _buildMobileDashboard(BuildContext context, AttendanceSessionSummary summary, ClassModel activeClass, AttendanceProvider attendanceProvider) {
    return Column(
      children: [
        // Top section with back button and dashboard heading
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding,
            vertical: AppConstants.smallPadding,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Back button (Left aligned)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.onDarkNavy),
                  onPressed: () {
                    final batchName = activeClass.sheetName ?? activeClass.className;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ComboSelectionScreen(
                          selectedBatch: batchName,
                          isFromDashboard: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Dashboard heading (Centered)
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onDarkNavy,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        
        // Second section: Circular bar + Sync options
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
          child: _buildAttendanceAndSyncSection(summary, activeClass),
        ),
        const SizedBox(height: AppConstants.defaultPadding),

        // Fourth section: Sync progress bar (NEW)
        const SyncProgressBar(),
        
        // Search section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
          child: _buildSearchSection(),
        ),
        const SizedBox(height: AppConstants.defaultPadding),

        // Fifth section: TabBarView with present/absent/all students tabs
        Expanded(
          child: Column(
            children: [
              // Tab header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
                child: _buildTabHeader(attendanceProvider, activeClass),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              // TabBarView content
              Expanded(
                child: _buildTabContent(attendanceProvider, activeClass),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopDashboard(BuildContext context, AttendanceSessionSummary summary, ClassModel activeClass, AttendanceProvider attendanceProvider) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Stats and Controls (Assigned width)
          SizedBox(
            width: 400,
            child: Column(
              children: [
                 // Header
                 Text(
                   'Dashboard',
                   style: TextStyle(
                     fontSize: 32,
                     fontWeight: FontWeight.bold,
                     color: AppTheme.onDarkNavy,
                   ),
                 ),
                 const SizedBox(height: AppConstants.defaultPadding),
                 
                 // Stats Card
                 _buildAttendanceAndSyncSection(summary, activeClass),
                 const SizedBox(height: AppConstants.defaultPadding),
                 
                 // Sync Progress
                 const SyncProgressBar(),
                 
                 // Search
                 _buildSearchSection(),
              ],
            ),
          ),
          
          const SizedBox(width: AppConstants.defaultPadding),
          
          // Right Column: Student List (Takes remaining space)
          Expanded(
            child: Column(
              children: [
                // Tab Header
                _buildTabHeader(attendanceProvider, activeClass),
                const SizedBox(height: AppConstants.defaultPadding),
                
                // Tab Content
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkNavyBlueLighter.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                    ),
                    child: _buildTabContent(attendanceProvider, activeClass),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildAttendanceAndSyncSection(AttendanceSessionSummary summary, ClassModel activeClass) {
    final attendancePercentage = summary.totalStudents > 0 
        ? (summary.presentCount / summary.totalStudents) * 100 
        : 0.0;

    return Container(
      height: 170, // Decreased height by 20% (to 170)
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlueLighter,
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
      ),
      child: Row(
        children: [
          // Vertical progress indicator with visible percentage label
          Container(
            width: 50, // Fixed width container
            padding: const EdgeInsets.all(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Very thin vertical progress bar (background)
                Container(
                  width: 6, // Thin bar
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Progress fill
                FractionallySizedBox(
                  heightFactor: attendancePercentage / 100.0,
                  alignment: Alignment.bottomCenter, // Align to bottom
                  child: Container(
                    width: 10,
                    decoration: BoxDecoration(
                      color: Colors.yellow,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Percentage label that's always visible
                Align(
                  alignment: Alignment.topCenter, // Always position at top
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.darkNavyBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${attendancePercentage.toInt()}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 0), // Reduced spacing to 4px
          // All controls in a single section with three rows
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12), // Set vertical padding to 12px
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // First row: Date and Session toggle switch (AM/PM)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Date display
                      Consumer<AttendanceProvider>(
                        builder: (context, attendanceProvider, child) {
                          final sessionDate = attendanceProvider.sessionDate;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            width: 110, // Width to prevent text wrapping
                            decoration: BoxDecoration(
                              color: AppTheme.darkNavyBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${sessionDate.day}/${sessionDate.month}/${sessionDate.year}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17, 
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(width: 16), // 16px horizontal space
                      
                      // Session toggle switch (AM/PM)
                      GestureDetector(
                        onTap: _toggleSessionType,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AM',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: _currentSessionType == SessionType.morning 
                                    ? Colors.yellow 
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Simple toggle switch
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
                                    left: _currentSessionType == SessionType.morning ? 4 : 29,
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
                            const SizedBox(width: 4),
                            Text(
                              'PM',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: _currentSessionType == SessionType.afternoon 
                                    ? Colors.yellow 
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 9), // Vertical spacing
                  
                  // Second row: Batch dropdown and Sync button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Batch dropdown
                      Consumer<ClassProvider>(
                        builder: (context, classProvider, child) {
                          // Extract unique batches from all classes
                          final uniqueBatches = classProvider.classes
                              .map((c) => c.sheetName ?? c.className)
                              .toSet()
                              .toList()
                              ..sort();
                          
                          // Find the currently selected batch
                          final currentBatch = activeClass.sheetName ?? activeClass.className;
                          
                          return SizedBox(
                            width: 200,
                            child: CustomDropdown<String?> (
                              value: uniqueBatches.contains(currentBatch) ? currentBatch : null,
                              hintText: 'Batch',
                              items: uniqueBatches.map((batchName) {
                                return DropdownMenuItem<String>(
                                  value: batchName,
                                  child: Text(
                                    batchName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newBatch) async {
                                if (newBatch != null) {
                                  // Find the first class in this batch to select as active
                                  final firstClassInBatch = classProvider.classes.firstWhere(
                                    (c) => (c.sheetName ?? c.className) == newBatch,
                                    orElse: () => classProvider.classes.first,
                                  );
                                  
                                  // Ensure attendance data is loaded for the selected class
                                  final attendanceProvider = context.read<AttendanceProvider>();
                                  // Use loadAttendanceForSession to FORCE reload data for the selected class and correct session
                                  await attendanceProvider.loadAttendanceForSession(
                                      firstClassInBatch.id, 
                                      attendanceProvider.sessionDate,
                                      overrideSessionType: _currentSessionType, // Pass current session type
                                  );
                                  await classProvider.setActiveClass(firstClassInBatch);
                                  // Also set the active class ID in the attendance provider
                                  attendanceProvider.setActiveClassId(firstClassInBatch.id);
                                  
                                  _onClassChanged(firstClassInBatch);
                                }
                              },
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(width: 16), // 16px horizontal space
                      
                      // Sync Now Button
                      Container(
                        height: 36,
                        width: 100,
                        decoration: BoxDecoration(
                          gradient: _isSyncing ? null : AppTheme.buttonGradient,
                          color: _isSyncing ? Colors.grey.withOpacity(0.2) : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: _isSyncing 
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                                ),
                              ),
                            )
                          : ElevatedButton(
                          onPressed: () => _triggerManualSync(context, activeClass),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Sync',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.buttonTextColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.sync, size: 12, color: AppTheme.buttonTextColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 9), // Vertical spacing
                  
                  // Third row: Combo dropdown and Export CSV button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Combo dropdown
                      SizedBox(
                        width: 200,
                        child: ComboDropdown(
                          activeClass: activeClass,
                          currentSessionType: _currentSessionType,
                        ),
                      ),
                      
                      const SizedBox(width: 16), // 16px horizontal space
                      
                      // Export CSV Button (Stroke/Secondary Button)
                      Container(
                        height: 36,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.yellow,
                            width: 1,
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: () => _exportScannedRollNumbers(context, activeClass),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'CSV',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.yellow,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.download, size: 12, color: Colors.yellow),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlueLighter,
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search Students...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withOpacity(0.7),
            size: 24,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: Icon(
                    Icons.clear,
                    color: Colors.white.withOpacity(0.7),
                    size: 24,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildTabHeader(AttendanceProvider attendanceProvider, ClassModel activeClass) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlueLighter,
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent, // Remove the white line below tabs
        labelColor: AppTheme.primaryColor, // Yellow color for active tab
        unselectedLabelColor: Colors.grey, // Grey color for inactive tabs
        indicator: const BoxDecoration(), // Remove indicator
        indicatorWeight: 0.0, // Remove indicator
        labelPadding: const EdgeInsets.symmetric(vertical: AppConstants.smallPadding),
        onTap: (index) {
          _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.ease);
        },
        tabs: [
          Tab(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${attendanceProvider.getPresentStudents().length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Present',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${attendanceProvider.getAbsentStudents(activeClass).length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Absent',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${attendanceProvider.getAllStudentsWithStatus(activeClass).length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(AttendanceProvider attendanceProvider, ClassModel activeClass) {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        _tabController.animateTo(index);
      },
      children: [
        // Present Students
        _buildPresentStudentsTab(attendanceProvider.getPresentStudents()),
        
        // Absent Students
        _buildAbsentStudentsTab(attendanceProvider.getAbsentStudents(activeClass)),
        
        // All Students
        _buildAllStudentsTab(attendanceProvider.getAllStudentsWithStatus(activeClass)),
      ],
    );
  }



  Future<void> _triggerManualSync(BuildContext context, ClassModel activeClass) async {
    final attendanceProvider = context.read<AttendanceProvider>();
    // final classProvider = context.read<ClassProvider>(); // Unused now
    
    // Set syncing state
    setState(() {
      _isSyncing = true;
    });

    try {
      // Ensure Hive boxes are open before proceeding
      if (!HiveService.areBoxesOpen) {
         print('Hive boxes are closed in _triggerManualSync, reopening...');
         await HiveService.reopenBoxes();
      }

      print('Starting SINGLE CLASS SYNC for "${activeClass.className}"');

      // 1. Ensure attendance is loaded for this class and session
      // We must force load to ensure we have the latest data for the specific session type (AM/PM)
      await attendanceProvider.ensureAttendanceLoadedForClass(
         activeClass.id, 
         attendanceProvider.sessionDate,
         overrideSessionType: _currentSessionType
      );
      
      // 2. Get local records
      final records = attendanceProvider.getAttendanceRecordsForClass(activeClass.id);
      print('Found ${records.length} records for ${activeClass.className}');
      
      if (records.isEmpty) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('No attendance records to sync for this class.'),
               backgroundColor: AppTheme.warningColor,
               duration: Duration(seconds: 2),
             ),
           );
         }
         return;
      }

      // 3. Upload to Main Attendance Sheet
      if (mounted) {
         ScaffoldMessenger.of(context).hideCurrentSnackBar();
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
               content: Text('Syncing ${activeClass.className}...'),
               backgroundColor: AppTheme.primaryColor,
               duration: const Duration(seconds: 1),
            )
         );
      }

      final result = await GoogleSheetsService.uploadAttendance(
         classModel: activeClass,
         attendanceRecords: records,
         onProgress: (progress) {},
      );
      
      // 4. Upload to Department Sheets
      await DepartmentSheetService.updateDepartmentSheets(
         classModel: activeClass,
         attendanceRecords: records,
         sessionType: _currentSessionType,
      );
      
      if (mounted) {
        String message;
        Color color;
        
        if (result.isSuccess) {
           message = 'Successfully synced ${activeClass.className}!';
           color = AppTheme.successColor;
        } else {
           message = 'Sync failed: ${result.message}';
           color = AppTheme.errorColor;
        }

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: color,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Sync error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync Error: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
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

  String _getStudentBranch(String pinNumber, BuildContext context) {
    final classProvider = context.read<ClassProvider>();
    if (classProvider.hasActiveClass) {
      final activeClass = classProvider.activeClass!;
      final student = activeClass.students.firstWhere(
        (s) => s.pinNumber == pinNumber,
        orElse: () => Student(
          name: 'Unknown',
          pinNumber: pinNumber,
          email: '',
          phone: '',
          branch: 'Unknown',
          mobileNumber: '',
          combo: '',
          securityCodes: [],
        ),
      );
      return student.branch;
    }
    return 'Unknown';
  }

  Widget _buildPresentStudentsTab(List<AttendanceRecord> presentStudents) {
    final filteredRecords = presentStudents.where((record) {
      return record.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             record.studentPinNumber.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredRecords.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.white70,
            ),
            SizedBox(height: 16),
            Text(
              'No present students found',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filteredRecords.length,
      separatorBuilder: (context, index) => const Divider(
        color: AppTheme.darkNavyBlueLighter,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final record = filteredRecords[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.studentName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pin: ${record.studentPinNumber} | Branch: ${_getStudentBranch(record.studentPinNumber, context)}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: AppTheme.errorColor, size: 20),
                onPressed: () {
                  // Revoke attendance functionality
                  final attendanceProvider = context.read<AttendanceProvider>();
                  attendanceProvider.revokeAttendance(record.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAbsentStudentsTab(List<Student> absentStudents) {
    final filteredStudents = absentStudents.where((student) {
      return student.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             student.pinNumber.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredStudents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cancel_outlined,
              size: 48,
              color: Colors.white70,
            ),
            SizedBox(height: 16),
            Text(
              'No absent students found',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filteredStudents.length,
      separatorBuilder: (context, index) => const Divider(
        color: AppTheme.darkNavyBlueLighter,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final student = filteredStudents[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pin: ${student.pinNumber} | Branch: ${student.branch}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.cancel, color: AppTheme.errorColor, size: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllStudentsTab(List<StudentAttendanceStatus> studentsWithStatus) {
    final filteredStudents = studentsWithStatus.where((studentStatus) {
      final student = studentStatus.student;
      return student.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             student.pinNumber.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredStudents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: Colors.white70,
            ),
            SizedBox(height: 16),
            Text(
              'No students found',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filteredStudents.length,
      separatorBuilder: (context, index) => const Divider(
        color: AppTheme.darkNavyBlueLighter,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final studentStatus = filteredStudents[index];
        final student = studentStatus.student;
        final isPresent = studentStatus.isPresent;
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pin: ${student.pinNumber} | Branch: ${student.branch}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (studentStatus.attendanceRecord != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Scanned: ${studentStatus.attendanceRecord!.displayTime}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                isPresent ? Icons.check_circle : Icons.cancel,
                color: isPresent ? AppTheme.successColor : AppTheme.errorColor,
                size: 20,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runComprehensiveTest(BuildContext context) async {
    final classProvider = context.read<ClassProvider>();
    
    if (!classProvider.hasActiveClass) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active class selected'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    
    final activeClass = classProvider.activeClass!;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Running comprehensive test...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    
    // Set up automatic close after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    try {
      final result = await GoogleSheetsService.runComprehensiveTest(activeClass);
      
      // Close loading dialog if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (context.mounted) {
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Test failed: ${result.message}'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test error: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }
  
  // NEW FUNCTION: Direct sheet update test to verify Google Sheets integration with actual update
  Future<void> _runDirectSheetUpdateTest(BuildContext context) async {
    final classProvider = context.read<ClassProvider>();
    
    if (!classProvider.hasActiveClass) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active class selected'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    
    final activeClass = classProvider.activeClass!;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Running direct sheet update test...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    
    // Set up automatic close after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    try {
      // Note: directSheetUpdateTest method has been removed
      print('directSheetUpdateTest method is not available');
      
      // Close loading dialog if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Direct sheet update test method is not available'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Direct sheet update test error: $e');
      print('Stack trace: $stackTrace');
      // Close loading dialog if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Direct sheet update test error: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }
  
  // NEW FUNCTION: Force update test to verify Google Sheets integration with actual update
  Future<void> _runForceUpdateTest(BuildContext context) async {
    final classProvider = context.read<ClassProvider>();
    
    if (!classProvider.hasActiveClass) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active class selected'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    
    final activeClass = classProvider.activeClass!;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Running force update test...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    
    // Set up automatic close after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    try {
      // Note: forceUpdateTest method has been removed
      print('forceUpdateTest method is not available');
      
      // Close loading dialog if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Force update test method is not available'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Force update test error: $e');
      print('Stack trace: $stackTrace');
      // Close loading dialog if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Force update test error: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }
  
  // NEW FUNCTION: Force test to verify Google Sheets integration with actual upload
  Future<void> _runForceTest(BuildContext context) async {
    final classProvider = context.read<ClassProvider>();
    
    if (!classProvider.hasActiveClass) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active class selected'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    
    final activeClass = classProvider.activeClass!;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Running force test...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    
    // Set up automatic close after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    try {
      // Note: forceTestAttendanceUpload method has been removed
      print('forceTestAttendanceUpload method is not available');
      
      // Close loading dialog if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Force test method is not available'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Force test error: $e');
      print('Stack trace: $stackTrace');
      // Close loading dialog if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Force test error: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }
  
  // NEW FUNCTION: Test data persistence
  Future<void> _testDataPersistence(BuildContext context) async {
    await DataPersistenceTestService.testDataPersistence();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data persistence test completed. Check console logs for details.'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
  
  // NEW FUNCTION: Force sync test to verify Google Sheets integration
  Future<void> _forceSyncTest(BuildContext context) async {
    final classProvider = context.read<ClassProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();
    
    if (!classProvider.hasActiveClass) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active class selected'),
            backgroundColor: AppTheme.errorColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    
    final activeClass = classProvider.activeClass!;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Running force sync test...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    
    // Set up automatic close after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    try {
      // Get current session records
      final currentSessionRecords = HiveService.getAttendanceForClass(
        activeClass.id, 
        attendanceProvider.sessionDate
      );
      
      // Close loading dialog if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (currentSessionRecords.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No attendance records found for current session'),
              backgroundColor: AppTheme.warningColor,
              duration: Duration(seconds: 1),
            ),
          );
        }
        return;
      }
      
      // Force mark all records as unsynced for testing
      for (final record in currentSessionRecords) {
        final updatedRecord = record.copyWith(isSyncedToSheet: false);
        await HiveService.saveAttendanceRecord(updatedRecord);
      }
      
      // Now sync using the attendance provider
      final result = await attendanceProvider.syncAllUnsyncedRecords(
        classModel: activeClass,
        onProgress: (progress) {
          // Progress callback
        },
      );
      
      if (context.mounted) {
        if (result.isSuccess) {
          final processedRecordIds = result.uploadedRecordIds ?? [];
          if (processedRecordIds.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Force sync test successful! Updated ${processedRecordIds.length} records in Google Sheets.'),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 1),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Force sync test completed. All records were already up to date in Google Sheets.'),
                backgroundColor: AppTheme.successColor,
                duration: Duration(seconds: 1),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Force sync test failed: ${result.message}'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Force sync test error: $e');
      print('Stack trace: $stackTrace');
      // Close loading dialog if still open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Force sync test error: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }
} // End of _DashboardScreenState

