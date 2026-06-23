import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../services/control_sheet_service.dart';
import '../services/google_sheets_service.dart';
import '../services/sheet_data_service.dart';
import '../utils/sheet_debugger.dart';
import '../utils/attendance_sheet_debugger.dart'; // Add this import
import '../constants/theme.dart';
import '../widgets/scanner_widgets.dart';

class SheetDebugScreen extends StatefulWidget {
  const SheetDebugScreen({super.key});

  @override
  State<SheetDebugScreen> createState() => _SheetDebugScreenState();
}

class _SheetDebugScreenState extends State<SheetDebugScreen> {
  String _status = 'Ready';
  bool _isProcessing = false;
  String _detailedOutput = '';
  Map<String, dynamic>? _sheetInfo;
  Map<String, dynamic>? _columnInfo;
  Map<String, dynamic>? _dateColumnInfo;

  Future<void> _runSheetStructureTest() async {
    setState(() {
      _isProcessing = true;
      _status = 'Getting sheet structure...';
      _detailedOutput = 'Starting sheet structure analysis...\n';
    });

    try {
      final classProvider = context.read<ClassProvider>();
      
      if (!classProvider.hasActiveClass) {
        setState(() {
          _status = 'No active class';
          _isProcessing = false;
          _detailedOutput += '❌ No active class selected\n';
        });
        return;
      }

      final activeClass = classProvider.activeClass!;
      _detailedOutput += 'Analyzing class: ${activeClass.className}\n';
      _detailedOutput += 'Sheet name: ${activeClass.sheetName}\n';
      
      // Get attendance sheet URL from control sheet for this specific class
      final classAttendanceSheetUrl = await ControlSheetService.getAttendanceSheetUrlForBatch(activeClass.sheetName ?? activeClass.className);
      if (classAttendanceSheetUrl == null || classAttendanceSheetUrl.isEmpty) {
        setState(() {
          _status = 'No sheet URL configured';
          _isProcessing = false;
          _detailedOutput += '❌ No attendance sheet URL configured in control sheet. All sheet details must be configured in the App_Control sheet.\n';
        });
        return;
      }
      
      _detailedOutput += 'Sheet URL: $classAttendanceSheetUrl\n';
      
      // Use embedded service account key if available
      String serviceAccountKey = activeClass.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        setState(() {
          _status = 'No service account key';
          _isProcessing = false;
          _detailedOutput += '❌ No service account key found\n';
        });
        return;
      }
      
      // Get sheet structure info
      final sheetInfo = await SheetDebugger.getSheetStructureInfo(
        classAttendanceSheetUrl,
        serviceAccountKey,
      );
      
      setState(() {
        _sheetInfo = sheetInfo;
        _status = 'Sheet structure retrieved';
        _detailedOutput += '\n✅ Sheet structure retrieved successfully\n';
        _detailedOutput += 'Title: ${sheetInfo['title']}\n';
        _detailedOutput += 'ID: ${sheetInfo['spreadsheetId']}\n';
        _detailedOutput += 'Sheet count: ${sheetInfo['sheetCount']}\n';
        
        if (sheetInfo['sheets'] != null && (sheetInfo['sheets'] as List).isNotEmpty) {
          _detailedOutput += '\nSheets:\n';
          for (final sheet in sheetInfo['sheets'] as List) {
            _detailedOutput += '  - ${sheet['title']} (ID: ${sheet['sheetId']})\n';
          }
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error';
        _isProcessing = false;
        _detailedOutput += '\n❌ Error: $e\n';
      });
    }
  }

  Future<void> _runColumnAnalysis() async {
    setState(() {
      _isProcessing = true;
      _status = 'Analyzing columns...';
      _detailedOutput += '\n--- Column Analysis ---\n';
    });

    try {
      final classProvider = context.read<ClassProvider>();
      
      if (!classProvider.hasActiveClass) {
        setState(() {
          _status = 'No active class';
          _isProcessing = false;
          _detailedOutput += '❌ No active class selected\n';
        });
        return;
      }

      final activeClass = classProvider.activeClass!;
      
      // Get attendance sheet URL from control sheet for this specific class
      final classAttendanceSheetUrl = await ControlSheetService.getAttendanceSheetUrlForBatch(activeClass.sheetName ?? activeClass.className);
      if (classAttendanceSheetUrl == null || classAttendanceSheetUrl.isEmpty) {
        setState(() {
          _status = 'No sheet URL configured';
          _isProcessing = false;
          _detailedOutput += '❌ No attendance sheet URL configured in control sheet. All sheet details must be configured in the App_Control sheet.\n';
        });
        return;
      }
      
      // Use embedded service account key if available
      String serviceAccountKey = activeClass.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        setState(() {
          _status = 'No service account key';
          _isProcessing = false;
          _detailedOutput += '❌ No service account key found\n';
        });
        return;
      }
      
      // Get column info
      final columnInfo = await SheetDebugger.getColumnInfo(
        classAttendanceSheetUrl,
        serviceAccountKey,
        sheetName: activeClass.sheetName,
      );
      
      setState(() {
        _columnInfo = columnInfo;
        _status = 'Column analysis complete';
        _detailedOutput += '✅ Column analysis completed\n';
        _detailedOutput += 'Range: ${columnInfo['range']}\n';
        
        if (columnInfo['columns'] != null && (columnInfo['columns'] as List).isNotEmpty) {
          _detailedOutput += '\nColumns:\n';
          for (final column in columnInfo['columns'] as List) {
            _detailedOutput += '  ${column['letter']}: ${column['value']}\n';
          }
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error';
        _isProcessing = false;
        _detailedOutput += '\n❌ Error: $e\n';
      });
    }
  }

  Future<void> _searchForTodayColumn() async {
    setState(() {
      _isProcessing = true;
      _status = 'Searching for today\'s date column...';
      _detailedOutput += '\n--- Date Column Search ---\n';
    });

    try {
      final classProvider = context.read<ClassProvider>();
      
      if (!classProvider.hasActiveClass) {
        setState(() {
          _status = 'No active class';
          _isProcessing = false;
          _detailedOutput += '❌ No active class selected\n';
        });
        return;
      }

      final activeClass = classProvider.activeClass!;
      
      // Get today's date in the format used by the app
      final now = DateTime.now();
      final dateString = '${now.month}/${now.day}/${now.year}';
      _detailedOutput += 'Searching for date: $dateString\n';
      
      // Get attendance sheet URL from control sheet for this specific class
      final classAttendanceSheetUrl = await ControlSheetService.getAttendanceSheetUrlForBatch(activeClass.sheetName ?? activeClass.className);
      if (classAttendanceSheetUrl == null || classAttendanceSheetUrl.isEmpty) {
        setState(() {
          _status = 'No sheet URL configured';
          _isProcessing = false;
          _detailedOutput += '❌ No attendance sheet URL configured in control sheet. All sheet details must be configured in the App_Control sheet.\n';
        });
        return;
      }
      
      // Use embedded service account key if available
      String serviceAccountKey = activeClass.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        setState(() {
          _status = 'No service account key';
          _isProcessing = false;
          _detailedOutput += '❌ No service account key found\n';
        });
        return;
      }
      
      // Search for date column
      final dateColumnInfo = await SheetDebugger.findDateColumn(
        classAttendanceSheetUrl,
        serviceAccountKey,
        dateString,
        sheetName: activeClass.sheetName,
      );
      
      setState(() {
        _dateColumnInfo = dateColumnInfo;
        _status = dateColumnInfo!['found'] ? 'Date column found!' : 'Date column not found';
        
        if (dateColumnInfo['found']) {
          _detailedOutput += '✅ Date column found!\n';
          _detailedOutput += 'Column: ${dateColumnInfo['columnLetter']}\n';
          _detailedOutput += 'Header value: ${dateColumnInfo['headerValue']}\n';
          _detailedOutput += '\n🎉 You should look in column ${dateColumnInfo['columnLetter']} of your Google Sheet for today\'s attendance data!\n';
        } else {
          _detailedOutput += '❌ Date column not found\n';
          _detailedOutput += '${dateColumnInfo['message']}\n';
          _detailedOutput += '\nThis might mean:\n';
          _detailedOutput += '1. The date column hasn\'t been created yet\n';
          _detailedOutput += '2. The date format is different\n';
          _detailedOutput += '3. You\'re looking at the wrong sheet\n';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Error';
        _isProcessing = false;
        _detailedOutput += '\n❌ Error: $e\n';
      });
    }
  }

  // New function to debug attendance sheet specifically
  Future<void> _debugAttendanceSheet() async {
    setState(() {
      _isProcessing = true;
      _status = 'Debugging attendance sheet...';
      _detailedOutput += '\n--- Attendance Sheet Debug ---\n';
    });

    try {
      final classProvider = context.read<ClassProvider>();
      
      if (!classProvider.hasActiveClass) {
        setState(() {
          _status = 'No active class';
          _isProcessing = false;
          _detailedOutput += '❌ No active class selected\n';
        });
        return;
      }

      final activeClass = classProvider.activeClass!;
      _detailedOutput += 'Debugging attendance for class: ${activeClass.className}\n';
      _detailedOutput += 'Target worksheet: ${activeClass.sheetName}\n';
      
      // Get attendance sheet URL from control sheet for this specific class
      final classAttendanceSheetUrl = await ControlSheetService.getAttendanceSheetUrlForBatch(activeClass.sheetName ?? activeClass.className);
      if (classAttendanceSheetUrl == null || classAttendanceSheetUrl.isEmpty) {
        setState(() {
          _status = 'No sheet URL configured';
          _isProcessing = false;
          _detailedOutput += '❌ No attendance sheet URL configured in control sheet. All sheet details must be configured in the App_Control sheet.\n';
        });
        return;
      }
      
      _detailedOutput += 'Attendance Sheet URL: $classAttendanceSheetUrl\n';
      
      // Use embedded service account key if available
      String serviceAccountKey = activeClass.serviceAccountKey ?? await SheetDataService.getEmbeddedServiceAccountKey();
      
      if (serviceAccountKey.isEmpty) {
        setState(() {
          _status = 'No service account key';
          _isProcessing = false;
          _detailedOutput += '❌ No service account key found\n';
        });
        return;
      }
      
      // 1. Get attendance sheet structure
      _detailedOutput += '\n1. Getting attendance sheet structure...\n';
      final sheetStructure = await AttendanceSheetDebugger.getAttendanceSheetStructure(
        classAttendanceSheetUrl,
        serviceAccountKey,
      );
      
      _detailedOutput += '✅ Sheet title: ${sheetStructure['title']}\n';
      _detailedOutput += '✅ Sheet count: ${sheetStructure['sheetCount']}\n';
      
      if (sheetStructure['sheets'] != null && (sheetStructure['sheets'] as List).isNotEmpty) {
        _detailedOutput += 'Available worksheets:\n';
        for (final sheet in sheetStructure['sheets'] as List) {
          _detailedOutput += '  - ${sheet['title']}\n';
        }
      }
      
      // 2. Check if target worksheet exists
      _detailedOutput += '\n2. Checking if target worksheet exists...\n';
      if (activeClass.sheetName != null && activeClass.sheetName!.isNotEmpty) {
        final worksheetExists = await AttendanceSheetDebugger.doesWorksheetExist(
          classAttendanceSheetUrl,
          serviceAccountKey,
          activeClass.sheetName!,
        );
        
        if (worksheetExists) {
          _detailedOutput += '✅ Target worksheet "${activeClass.sheetName}" exists\n';
        } else {
          _detailedOutput += '❌ Target worksheet "${activeClass.sheetName}" does not exist\n';
          _detailedOutput += 'The system will try to create it or use the default sheet\n';
        }
      } else {
        _detailedOutput += 'ℹ️ No specific worksheet specified, using default sheet\n';
      }
      
      // 3. Get today's date and search for it
      final now = DateTime.now();
      final dateString = '${now.month}/${now.day}/${now.year}';
      _detailedOutput += '\n3. Searching for today\'s date column ($dateString)...\n';
      
      // Search in the specified worksheet or default
      String targetWorksheet = activeClass.sheetName ?? 'Sheet1';
      if (targetWorksheet.isEmpty) {
        targetWorksheet = 'Sheet1';
      }
      
      _detailedOutput += 'Searching in worksheet: $targetWorksheet\n';
      
      final dateColumnResult = await AttendanceSheetDebugger.findDateColumnInWorksheet(
        classAttendanceSheetUrl,
        serviceAccountKey,
        targetWorksheet,
        dateString,
      );
      
      if (dateColumnResult != null && dateColumnResult['found']) {
        _detailedOutput += '✅ Date column found!\n';
        _detailedOutput += '   Column: ${dateColumnResult['columnLetter']}\n';
        _detailedOutput += '   Header value: ${dateColumnResult['headerValue']}\n';
        _detailedOutput += '\n🎉 You should look in column ${dateColumnResult['columnLetter']} of the "$targetWorksheet" worksheet for today\'s attendance data!\n';
      } else {
        _detailedOutput += '❌ Date column not found in "$targetWorksheet" worksheet\n';
        _detailedOutput += 'This could mean:\n';
        _detailedOutput += '1. The date column hasn\'t been created yet (will be created on first attendance upload)\n';
        _detailedOutput += '2. You\'re looking in the wrong worksheet\n';
        _detailedOutput += '3. There was an error during the upload process\n';
      }
      
      setState(() {
        _status = 'Attendance sheet debug completed';
        _isProcessing = false;
        _detailedOutput += '\n--- Debug Completed ---\n';
      });
    } catch (e) {
      setState(() {
        _status = 'Error';
        _isProcessing = false;
        _detailedOutput += '\n❌ Error: $e\n';
      });
    }
  }

  Future<void> _runAllTests() async {
    await _runSheetStructureTest();
    await Future.delayed(const Duration(seconds: 1));
    await _runColumnAnalysis();
    await Future.delayed(const Duration(seconds: 1));
    await _searchForTodayColumn();
    
    setState(() {
      _isProcessing = false;
      _status = 'All tests completed';
      _detailedOutput += '\n--- All Tests Completed ---\n';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sheet Debugger'),
        backgroundColor: const Color(0xFF040C1B),
      ),
      body: Container(
        color: const Color(0xFF040C1B),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              // Action buttons
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GradientButton(
                    onPressed: _isProcessing ? () {} : _runSheetStructureTest,
                    isEnabled: !_isProcessing,
                    child: const Text('Sheet Structure', style: TextStyle(color: AppTheme.buttonTextColor)),
                  ),
                  GradientButton(
                    onPressed: _isProcessing ? () {} : _runColumnAnalysis,
                    isEnabled: !_isProcessing,
                    child: const Text('Column Analysis', style: TextStyle(color: AppTheme.buttonTextColor)),
                  ),
                  GradientButton(
                    onPressed: _isProcessing ? () {} : _searchForTodayColumn,
                    isEnabled: !_isProcessing,
                    child: const Text('Find Today\'s Column', style: TextStyle(color: AppTheme.buttonTextColor)),
                  ),
                  GradientButton(
                    onPressed: _isProcessing ? () {} : _debugAttendanceSheet,
                    isEnabled: !_isProcessing,
                    child: const Text('Debug Attendance Sheet', style: TextStyle(color: AppTheme.buttonTextColor)),
                  ),
                  GradientButton(
                    onPressed: _isProcessing ? () {} : _runAllTests,
                    isEnabled: !_isProcessing,
                    child: const Text('Run All Tests', style: TextStyle(color: AppTheme.buttonTextColor)),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              const Text(
                'Debug Output:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              
              // Output area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkNavyBlueLighter,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SelectableText(
                        _detailedOutput,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}