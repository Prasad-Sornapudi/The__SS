import 'dart:async';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/class_provider.dart';
import '../providers/user_provider.dart';
import '../models/class_model.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/scanner_widgets.dart'; // Import GradientButton and StrokeButton
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../services/auto_upload_service.dart';
import '../models/session_model.dart'; // Import SessionType
import '../screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Batch-Specific Auto Sync State (Web Only)
  final Map<String, TimeOfDay> _batchMorningTimes = {};
  final Map<String, bool> _batchMorningEnabled = {};

  final Map<String, TimeOfDay> _batchAfternoonTimes = {};
  final Map<String, bool> _batchAfternoonEnabled = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final classProvider = context.read<ClassProvider>();
      await classProvider.loadClasses();
      await _loadScheduledSyncSettings(); // Load saved scheduler settings
      
      // If no classes exist, try to auto-load from Google Sheets
      if (!classProvider.hasClasses) {
        await classProvider.autoLoadClassesFromSheets();
      }
    });
  }

  // Helper getters for dropdowns
  List<String> _getUniqueBatches(List<ClassModel> classes) {
    return classes
        .map((c) => c.sheetName ?? c.className)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()..sort();
  }

  Future<void> _loadScheduledSyncSettings() async {
    if (!kIsWeb) return; // Only for web

    final prefs = await SharedPreferences.getInstance();
    final classProvider = context.read<ClassProvider>();
    final batches = _getUniqueBatches(classProvider.classes);
    
    setState(() {
      for (final batchId in batches) {
        // Morning Settings
        final mHour = prefs.getInt('batch_${batchId}_morning_hour');
        final mMinute = prefs.getInt('batch_${batchId}_morning_minute');
        // ENABLED BY DEFAULT
        final mEnabled = prefs.getBool('batch_${batchId}_morning_enabled') ?? true;
        
        if (mHour != null && mMinute != null) {
          _batchMorningTimes[batchId] = TimeOfDay(hour: mHour, minute: mMinute);
        } else {
          // Default to 10:50 AM
          _batchMorningTimes[batchId] = const TimeOfDay(hour: 10, minute: 50);
        }
        _batchMorningEnabled[batchId] = mEnabled;

        // Afternoon Settings
        final aHour = prefs.getInt('batch_${batchId}_afternoon_hour');
        final aMinute = prefs.getInt('batch_${batchId}_afternoon_minute');
        // ENABLED BY DEFAULT
        final aEnabled = prefs.getBool('batch_${batchId}_afternoon_enabled') ?? true;

        if (aHour != null && aMinute != null) {
          _batchAfternoonTimes[batchId] = TimeOfDay(hour: aHour, minute: aMinute);
        } else {
          // Default to 2:45 PM (14:45)
          _batchAfternoonTimes[batchId] = const TimeOfDay(hour: 14, minute: 45);
        }
        _batchAfternoonEnabled[batchId] = aEnabled;
      }
    });

    // Notify the service to sync up with these loaded/default values
    if (mounted) {
       context.read<AutoUploadService>().reloadScheduledSettings();
    }
  }

  Future<void> _saveBatchSettings(String batchId) async {
    if (!kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    
    // Save Morning
    final mTime = _batchMorningTimes[batchId];
    if (mTime != null) {
      await prefs.setInt('batch_${batchId}_morning_hour', mTime.hour);
      await prefs.setInt('batch_${batchId}_morning_minute', mTime.minute);
    }
    await prefs.setBool('batch_${batchId}_morning_enabled', _batchMorningEnabled[batchId] ?? false);

    // Save Afternoon
    final aTime = _batchAfternoonTimes[batchId];
    if (aTime != null) {
      await prefs.setInt('batch_${batchId}_afternoon_hour', aTime.hour);
      await prefs.setInt('batch_${batchId}_afternoon_minute', aTime.minute);
    }
    await prefs.setBool('batch_${batchId}_afternoon_enabled', _batchAfternoonEnabled[batchId] ?? false);
    
    // Notify Service to Reload
    if (mounted) {
      context.read<AutoUploadService>().reloadScheduledSettings();
    }
  }

  Future<void> _syncAllClassesForToday(BuildContext context, {String? explicitBatchId}) async {
    final autoUploadService = context.read<AutoUploadService>();
    if (explicitBatchId == null) return;

    // Ask user for session type
    final sessionType = await showDialog<SessionType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Session to Sync'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, SessionType.morning),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Morning (AM)'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, SessionType.afternoon),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Afternoon (PM)'),
            ),
          ),
        ],
      )
    );

    if (sessionType != null) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Triggering Manual Batch Sync... Check Console/Status.'))
       );
       autoUploadService.triggerBatchSyncNow(explicitBatchId, sessionType);
    }
  }

  // Add this method for logout functionality
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          GradientButton(
            onPressedAsync: () async {
              // Dismiss the dialog
              Navigator.of(context).pop();
              
              // Show a loading indicator while logging out
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Dialog(
                  backgroundColor: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Logging out and resyncing credentials...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
              
              try {
                // Clear user data
                final userProvider = context.read<UserProvider>();
                userProvider.clearUser();
                
                // Clear saved credentials
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('saved_username');
                await prefs.remove('saved_password');
                await prefs.remove('saved_display_name');
                
                // Dismiss the loading dialog
                if (mounted) {
                  Navigator.of(context).pop();
                  
                  // Navigate to login screen
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              } catch (e) {
                // Dismiss the loading dialog
                if (mounted) {
                  Navigator.of(context).pop();
                  
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Logout', style: TextStyle(color: AppTheme.buttonTextColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<UserProvider, ClassProvider>(
        builder: (context, userProvider, classProvider, child) {
          if (classProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return CustomScrollView(
            slivers: [
              // User Profile Section
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(AppConstants.defaultPadding),
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
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
                  child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center, // Vertically center all elements
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              shape: BoxShape.circle, // Circular avatar look
                            ),
                            child: const Icon(
                              Icons.person,
                              color: AppTheme.primaryColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16), // Increased spacing
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min, // Hug content
                              children: [
                                Text(
                                  userProvider.userDisplayName ?? 'User',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (userProvider.userName != null && userProvider.userName != userProvider.userDisplayName)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      userProvider.userName!,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.techwingyellow.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.techwingyellow.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    userProvider.role?.toUpperCase() ?? 'USER',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.techwingyellow,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          StrokeButton(
                            onPressed: _logout,
                            strokeColor: AppTheme.techwingyellow,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.logout, size: 18, color: AppTheme.techwingyellow),
                                SizedBox(width: 8),
                                Text('Logout', style: TextStyle(color: AppTheme.techwingyellow)),
                              ],
                            ),
                          ),
                        ],
                      ),
                ),
              ),

               // Sync Control Section

               if (kIsWeb) // Web Auto Sync Scheduler Widget
                SliverToBoxAdapter(
                  child: Consumer<ClassProvider>(
                    builder: (context, classProvider, child) {
                      final batches = _getUniqueBatches(classProvider.classes);
                      
                      if (batches.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: [
                          SettingsSection(
                            title: 'Batch Auto Sync Schedules (Web)',
                            children: batches.map((batchId) {
                                final mTime = _batchMorningTimes[batchId];
                                final mEnabled = _batchMorningEnabled[batchId] == true;
                                final aTime = _batchAfternoonTimes[batchId];
                                final aEnabled = _batchAfternoonEnabled[batchId] == true;
                                
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    dividerColor: Colors.transparent,
                                  ),
                                  child: ExpansionTile(
                                    backgroundColor: Colors.transparent,
                                    collapsedBackgroundColor: Colors.transparent,
                                    iconColor: AppTheme.primaryColor,
                                    collapsedIconColor: Colors.white70,
                                    title: Text(
                                      batchId, 
                                      style: const TextStyle(
                                        color: Colors.white, 
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      )
                                    ),
                                    subtitle: Text(
                                      (mEnabled ? 'AM: ${mTime?.format(context) ?? "Set"}  ' : '') +
                                      (aEnabled ? 'PM: ${aTime?.format(context) ?? "Set"}' : '') +
                                      (!mEnabled && !aEnabled ? 'Not Scheduled' : ''),
                                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 16.0, bottom: 8.0, right: 8.0),
                                        child: Column(
                                          children: [
                                            // Morning Schedule
                                            SettingsTile(
                                              title: 'Morning Sync',
                                              subtitle: mEnabled
                                                  ? 'Scheduled at ${mTime?.format(context) ?? "Not set"}'
                                                  : 'Schedule morning sync for $batchId',
                                              icon: Icons.wb_sunny_outlined,
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                    if (mEnabled)
                                                      IconButton(
                                                        icon: const Icon(Icons.edit, color: Colors.white70),
                                                        onPressed: () async {
                                                          final time = await showTimePicker(
                                                            context: context,
                                                            initialTime: mTime ?? const TimeOfDay(hour: 10, minute: 50),
                                                          );
                                                          if (time != null) {
                                                            setState(() {
                                                              _batchMorningTimes[batchId] = time;
                                                            });
                                                            _saveBatchSettings(batchId);
                                                          }
                                                        },
                                                        tooltip: 'Change Time',
                                                      ),
                                                    Switch(
                                                      value: mEnabled,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _batchMorningEnabled[batchId] = value;
                                                          // Set default time if enabled and no time set
                                                          if (value && _batchMorningTimes[batchId] == null) {
                                                            _batchMorningTimes[batchId] = const TimeOfDay(hour: 10, minute: 50);
                                                          }
                                                        });
                                                        _saveBatchSettings(batchId);
                                                        
                                                        if (value && mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('$batchId Morning Sync enabled')),
                                                          );
                                                        }
                                                      },
                                                      activeColor: AppTheme.primaryColor,
                                                    ),
                                                  ],
                                                ),
                                                onTap: () async {
                                                  final time = await showTimePicker(
                                                    context: context,
                                                    initialTime: mTime ?? const TimeOfDay(hour: 10, minute: 50),
                                                  );
                                                  if (time != null) {
                                                    setState(() {
                                                      _batchMorningTimes[batchId] = time;
                                                      _batchMorningEnabled[batchId] = true;
                                                    });
                                                    _saveBatchSettings(batchId);
                                                  }
                                                },
                                              ),

                                              const SizedBox(height: 8),

                                              // Afternoon Schedule
                                              SettingsTile(
                                                title: 'Afternoon Sync',
                                                subtitle: aEnabled
                                                    ? 'Scheduled at ${aTime?.format(context) ?? "Not set"}'
                                                    : 'Schedule afternoon sync for $batchId',
                                                icon: Icons.nights_stay_outlined,
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (aEnabled)
                                                      IconButton(
                                                        icon: const Icon(Icons.edit, color: Colors.white70),
                                                        onPressed: () async {
                                                          final time = await showTimePicker(
                                                            context: context,
                                                            initialTime: aTime ?? const TimeOfDay(hour: 14, minute: 45),
                                                          );
                                                          if (time != null) {
                                                            setState(() {
                                                              _batchAfternoonTimes[batchId] = time;
                                                            });
                                                            _saveBatchSettings(batchId);
                                                          }
                                                        },
                                                        tooltip: 'Change Time',
                                                      ),
                                                    Switch(
                                                      value: aEnabled,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _batchAfternoonEnabled[batchId] = value;
                                                          // Set default time if enabled and no time set
                                                          if (value && _batchAfternoonTimes[batchId] == null) {
                                                            _batchAfternoonTimes[batchId] = const TimeOfDay(hour: 14, minute: 45);
                                                          }
                                                        });
                                                        _saveBatchSettings(batchId);
                                                        if (value && mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('$batchId Afternoon Sync enabled')),
                                                          );
                                                        }
                                                      },
                                                      activeColor: AppTheme.primaryColor,
                                                    ),
                                                  ],
                                                ),
                                                onTap: () async {
                                                  final time = await showTimePicker(
                                                    context: context,
                                                    initialTime: aTime ?? const TimeOfDay(hour: 14, minute: 45),
                                                  );
                                                if (time != null) {
                                                  setState(() {
                                                    _batchAfternoonTimes[batchId] = time;
                                                    _batchAfternoonEnabled[batchId] = true;
                                                  });
                                                  _saveBatchSettings(batchId);
                                                }
                                              },
                                            ),

                                            const Divider(color: Colors.white24, height: 24),
                                            
                                            // Manual Sync Button
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: GradientButton(
                                                  onPressed: () => _syncAllClassesForToday(context, explicitBatchId: batchId),
                                                  child: const Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.cloud_upload, color: AppTheme.buttonTextColor),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Sync All Combos in Batch',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppTheme.buttonTextColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ),


              // Add extra spacing at the bottom to allow scrolling past expanded items
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
    );
  }
}