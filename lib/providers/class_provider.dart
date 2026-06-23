import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../services/hive_service.dart';
import '../services/auto_class_service.dart';
import '../services/enhanced_auto_sync_service.dart';
import '../providers/attendance_provider.dart';

class ClassProvider extends ChangeNotifier {
  List<ClassModel> _classes = [];
  ClassModel? _activeClass;
  bool _isLoading = false;
  String? _error;
  bool _hasLoadedFromSheet = false; // New flag to track if classes have been loaded from sheet
  // Flag to prevent multiple concurrent auto-load attempts
  bool _isAutoLoading = false;
  // Flag to prevent multiple concurrent refresh attempts
  bool _isRefreshing = false;

  // Getters
  List<ClassModel> get classes => _classes;
  ClassModel? get activeClass => _activeClass;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasClasses => _classes.isNotEmpty;
  bool get hasActiveClass => _activeClass != null;
  bool get isRefreshing => _isRefreshing;

  // Initialize provider
  Future<void> initialize() async {
    await loadClasses();
    await loadActiveClass();
  }

  // Load all classes from storage
  Future<void> loadClasses() async {
    try {
      _setLoading(true);
      _classes = HiveService.getAllClasses();
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load classes: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Automatically load classes from Google Sheets only if not already loaded
  Future<void> autoLoadClassesFromSheets() async {
    // Check if already loading to prevent multiple concurrent calls
    if (_isAutoLoading) {
      print('Auto-load already in progress, skipping duplicate call');
      return;
    }
    
    // NOTE: Removed the check for _hasLoadedFromSheet to ensure we always get fresh data
    // This ensures batch names are always up-to-date from Firebase
    
    try {
      _isAutoLoading = true;
      _setLoading(true);
      
      // Fetch classes from Google Sheets
      final classes = await AutoClassService.fetchClassesFromFirebase();
      
      // Save to storage
      await AutoClassService.saveClassesToStorage(classes);
      
      // Update local list
      _classes = classes;
      _hasLoadedFromSheet = true; // Mark that we've loaded from sheet

      // If there's an active class, update it to the new instance from the auto-loaded list
      if (_activeClass != null) {
        _activeClass = _classes.firstWhere((c) => c.id == _activeClass!.id, orElse: () => _activeClass!); // Fallback to old if not found
      }
      notifyListeners();
      
      print('✅ Successfully auto-loaded ${classes.length} classes from Google Sheets');
    } catch (e) {
      print('❌ Error auto-loading classes from sheets: $e');
      _setError('Failed to auto-load classes from Google Sheets: $e');
    } finally {
      _isAutoLoading = false;
      _setLoading(false);
    }
  }

  // Force refresh classes from Google Sheets
  Future<void> refreshClassesFromSheets() async {
    // Check if already refreshing to prevent multiple concurrent calls
    if (_isRefreshing) {
      print('Refresh already in progress, skipping duplicate call');
      return;
    }
    
    try {
      _isRefreshing = true;
      _setLoading(true);
      
      print('🔄 Starting class refresh from Google Sheets...');
      
      // Fetch classes from Google Sheets
      final classes = await AutoClassService.fetchClassesFromSheets();
      
      print('✅ Fetched ${classes.length} classes from Google Sheets');
      
      // Print details about all classes for debugging
      for (int classIndex = 0; classIndex < classes.length && classIndex < 3; classIndex++) {
        final classModel = classes[classIndex];
        print('🔍 Class $classIndex: ${classModel.className} (ID: ${classModel.id})');
        if (classModel.students.isNotEmpty) {
          print('🔍 First 3 students in class ${classModel.className}:');
          for (int i = 0; i < classModel.students.length && i < 3; i++) {
            final student = classModel.students[i];
            print('   ${i + 1}. ${student.name} (${student.pinNumber})');
          }
        }
      }
      
      // Save to storage
      await AutoClassService.saveClassesToStorage(classes);
      
      print('💾 Saved classes to storage');
      
      // Update local list
      _classes = classes;
      _hasLoadedFromSheet = true; // Mark that we've loaded from sheet

      // If there's an active class, update it to the new instance from the refreshed list
      // Use className to identify the active class instead of ID since IDs might change
      if (_activeClass != null) {
        final activeClassName = _activeClass!.className;
        print('🔍 Looking for active class with name: $activeClassName');
        
        try {
          final updatedActiveClass = _classes.firstWhere(
            (c) => c.className == activeClassName,
          );
          _activeClass = updatedActiveClass;
          
          print('🔄 Updated active class with fresh data');
          print('🔄 Active class ID changed from ${_activeClass?.id} to ${updatedActiveClass.id}');
        } catch (e) {
          print('⚠️ Active class not found in refreshed data, keeping current active class');
          // Keep the current active class if not found in refreshed data
        }
        if (_activeClass != null && _activeClass!.students.isNotEmpty) {
          print('🔍 Active class now has ${_activeClass!.students.length} students');
          print('🔍 First 3 students in active class:');
          for (int i = 0; i < _activeClass!.students.length && i < 3; i++) {
            final student = _activeClass!.students[i];
            print('   ${i + 1}. ${student.name} (${student.pinNumber})');
          }
        }
      }
      
      _clearError();
      notifyListeners();
      
      print('✅ Successfully refreshed ${classes.length} classes from Google Sheets');
    } catch (e) {
      print('❌ Error refreshing classes from sheets: $e');
      _setError('Failed to refresh classes from Google Sheets: $e');
    } finally {
      _isRefreshing = false;
      _setLoading(false);
    }
  }
  
  // Force refresh classes (public method)
  Future<void> forceRefreshClasses() async {
    await refreshClassesFromSheets();
  }

  // Load active class from storage
  Future<void> loadActiveClass() async {
    try {
      final activeClassId = HiveService.activeClassId;
      if (activeClassId != null) {
        _activeClass = HiveService.getClass(activeClassId);
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to load active class: $e');
    }
  }

  // Save a new or updated class
  Future<bool> saveClass(ClassModel classModel, {bool notify = true, bool clearCache = true}) async {
    try {
      _setLoading(true);
      
      // Validate class before saving
      final validationError = validateClass(classModel);
      if (validationError != null) {
        _setError(validationError);
        return false;
      }
      
      print('ClassProvider: Attempting to save class ${classModel.className} with ID: ${classModel.id}');
      
      // Ensure Hive boxes are open before proceeding
      if (!HiveService.areBoxesOpen) {
        print('Hive boxes are closed in saveClass, reopening...');
        await HiveService.reopenBoxes();
      }
      
      await HiveService.saveClass(classModel);
      print('ClassProvider: Class saved to HiveService successfully');
      
      if (clearCache) {
        // Clear attendance cache for this class to force reload of student data
        AttendanceProvider().clearAttendanceRecordsForClass(classModel.id);
      }
      
      // Update local list
      final index = _classes.indexWhere((c) => c.id == classModel.id);
      if (index >= 0) {
        _classes[index] = classModel;
        print('ClassProvider: Updated existing class in local list');
      } else {
        _classes.add(classModel);
        print('ClassProvider: Added new class to local list');
      }
      
      // Update active class if it's the same
      if (_activeClass?.className == classModel.className) {
        _activeClass = classModel;
        print('ClassProvider: Updated active class');
      }
      
      _clearError();
      if (notify) {
        notifyListeners();
      }
      print('ClassProvider: Save operation completed successfully');
      return true;
    } catch (e, stackTrace) {
      print('ClassProvider: Error saving class: $e');
      print('ClassProvider: Stack trace: $stackTrace');
      _setError('Failed to save class: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a class
  Future<bool> deleteClass(String classId) async {
    try {
      _setLoading(true);
      await HiveService.deleteClass(classId);
      
      // Update local list
      _classes.removeWhere((c) => c.id == classId);
      
      // Clear active class if it was deleted
      // Find the class by ID to get its className
      ClassModel? deletedClass;
      try {
        deletedClass = _classes.firstWhere((c) => c.id == classId);
      } catch (e) {
        // Class not found
        deletedClass = null;
      }
      if (deletedClass != null && _activeClass?.className == deletedClass.className) {
        _activeClass = null;
        await HiveService.setActiveClassId(null);
      }
      
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete class: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Set active class
  Future<void> setActiveClass(ClassModel? classModel) async {
    try {
      final previousClassId = _activeClass?.id;
      _activeClass = classModel;
      await HiveService.setActiveClassId(classModel?.id);
      
      // If class has changed, notify listeners immediately
      // Use className for comparison since IDs might change during refresh
      final previousClassName = _activeClass != null ? _activeClass!.className : null;
      final newClassName = classModel?.className;
      if (previousClassName != newClassName) {
        print('Class changed from $previousClassName to $newClassName');
        notifyListeners();
      } else {
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to set active class: $e');
    }
  }
  
  // Notify listeners that class has changed and immediate sync is needed
  void _notifyClassChanged(ClassModel newClass) {
    // This will be handled by the dashboard screen which listens to class changes
    print('Class changed to: ${newClass.className}, notifying for immediate sync');
  }

  // Get class by ID
  ClassModel? getClassById(String id) {
    try {
      return _classes.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Update students in a class
  Future<bool> updateClassStudents(String classId, List<Student> students) async {
    try {
      final classModel = getClassById(classId);
      if (classModel == null) return false;

      final updatedClass = classModel.copyWith(
        students: students,
        updatedAt: DateTime.now(),
      );

      return await saveClass(updatedClass);
    } catch (e) {
      _setError('Failed to update class students: $e');
      return false;
    }
  }

  // Update a specific student in a class
  Future<bool> updateStudentInClass(String classId, Student updatedStudent) async {
    try {
      final classModel = getClassById(classId);
      if (classModel == null) return false;

      // Find and replace the specific student
      final students = List<Student>.from(classModel.students);
      final index = students.indexWhere((student) => student.pinNumber == updatedStudent.pinNumber);
      if (index != -1) {
        students[index] = updatedStudent;
      } else {
        // If student not found, add the new student
        students.add(updatedStudent);
      }

      final updatedClass = classModel.copyWith(
        students: students,
        updatedAt: DateTime.now(),
      );

      return await saveClass(updatedClass);
    } catch (e) {
      _setError('Failed to update student in class: $e');
      return false;
    }
  }

  // Search classes by name
  List<ClassModel> searchClasses(String query) {
    if (query.isEmpty) return _classes;
    
    return _classes.where((c) => c.className.toLowerCase().contains(query.toLowerCase())).toList();
  }

  // Private methods for state management
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    print('ClassProvider Error: $message');
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Validate class model
  String? validateClass(ClassModel classModel) {
    if (classModel.className.isEmpty) {
      return 'Class name cannot be empty';
    }
    if (classModel.sheetName?.isEmpty ?? true) {
      return 'Sheet name cannot be empty';
    }
    return null;
  }
}