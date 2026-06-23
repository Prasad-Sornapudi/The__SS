import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../models/batch_config.dart';
import '../services/firebase_service.dart';
import '../services/hive_service.dart';
import '../services/control_sheet_service.dart';
import '../services/sheet_data_service.dart';

class AutoClassService {
  static final FirebaseService firebaseService = FirebaseService();

  /// Fetch classes from Firebase with proper batch names from App_Control sheet
  /// Updated to use the new batch-tab-driven configuration
  static Future<List<ClassModel>> fetchClassesFromFirebase() async {
    try {
      print('=== FETCHING CLASSES FROM FIREBASE WITH BATCH NAMES ===');
      
      // 1. Get all batch configurations from Firebase
      final batchConfigs = await ControlSheetService.readBatchConfigs();
      print('📋 Found ${batchConfigs.length} batches in Firebase');
      
      if (batchConfigs.isEmpty) {
        print('⚠️ No batches found in Firebase');
        return [];
      }
      
      final classes = <ClassModel>[];
      
      // 2. Iterate through each batch
      for (final batchId in batchConfigs.keys) {
        final batchConfig = batchConfigs[batchId];
        print('🔍 Processing batch: "$batchId"');
        
        // 3. Fetch combos (classes) for this batch
        final combosMap = await firebaseService.fetchCombosForBatch(batchId);
        
        if (combosMap.isEmpty) {
          print('⚠️ No combos found for batch "$batchId"');
          continue;
        }

        // OPTIMIZATION: Resolve service account key ONCE per batch
        String? batchServiceAccountKey;
        if (batchConfig?.attendanceSheet?.credentials?.isNotEmpty == true) {
          batchServiceAccountKey = batchConfig!.attendanceSheet!.credentials;
        } else if (batchConfig?.masterSheet?.credentials?.isNotEmpty == true) {
          batchServiceAccountKey = batchConfig!.masterSheet!.credentials;
        } else {
             // Fallback: Get it from ControlSheetService (which likely hits Firebase/Cache)
             // We do this ONCE per batch, not per combo
             batchServiceAccountKey = await ControlSheetService.getBatchServiceAccountKey(batchId);
        }
        
        // 4. Process each combo
        for (final entry in combosMap.entries) {
          final comboName = entry.key;
          final students = entry.value;
          
          try {
            print('📚 Processing combo: "$comboName" (Batch: "$batchId")');
            
            // Determine sheet name (link) for attendance
            final attendanceSheetLink = batchConfig?.attendanceSheet?.link ?? '';
            
            // Create a consistent ID based on batchId and comboName
            final safeBatchId = batchId.replaceAll(RegExp(r'[.#$\[\]\/]'), '_');
            final safeComboName = comboName.replaceAll(RegExp(r'[.#$\[\]\/]'), '_');
            final classId = 'class_${safeBatchId}_$safeComboName';
            
            // Use the key resolved outside the loop
            
            // Create the actual class model with student data
            final classModel = ClassModel(
              id: classId,
              className: comboName, // The Combo Name (e.g., "Combo1")
              classCode: '', 
              sheetId: '', 
              googleSheetUrl: '', 
              serviceAccountKey: batchServiceAccountKey ?? '', 
              sheetName: batchId, // The Batch ID (e.g., "Skill_Sync01") - Used for grouping/display
              attendanceSheetName: attendanceSheetLink, // The actual sheet URL
              displayName: batchId, // Explicitly set display name to Batch ID
              students: students,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            
            classes.add(classModel);
            print('✅ Successfully created class "$comboName" (Batch: "$batchId") with ${students.length} students');
            
          } catch (e) {
            print('❌ Error processing combo "$comboName": $e');
            continue;
          }
        }
      }
      
      print('🎉 Finished processing all classes. Created ${classes.length} classes.');
      return classes;
    } catch (e) {
      print('❌ Error in fetchClassesFromFirebase: $e');
      throw Exception('Failed to fetch classes from Firebase: $e');
    }
  }

  // Deprecated: Old Sheet-based fetch, now redirects to Firebase
  static Future<List<ClassModel>> fetchClassesFromSheets() async {
    return fetchClassesFromFirebase();
  }
  
  /// Save classes to local storage
  static Future<void> saveClassesToStorage(List<ClassModel> classes) async {
    try {
      print('💾 Saving ${classes.length} classes to local storage...');
      
      // Ensure Hive boxes are open before proceeding
      if (!HiveService.areBoxesOpen) {
        print('Hive boxes are closed in saveClassesToStorage, reopening...');
        await HiveService.reopenBoxes();
      }
      
      // Clear existing classes
      final existingClasses = HiveService.getAllClasses();
      for (final classModel in existingClasses) {
        await HiveService.deleteClass(classModel.id);
      }
      
      // Save new classes
      for (final classModel in classes) {
        await HiveService.saveClass(classModel);
        print('✅ Saved class: ${classModel.className} (batch: "${classModel.sheetName}")');
      }
      
      print('🎉 Successfully saved all classes to storage');
    } catch (e) {
      print('❌ Error saving classes to storage: $e');
      rethrow;
    }
  }
  
  /// Update classes from Google Sheets (Now Firebase)
  static Future<void> updateClassesFromSheets() async {
    try {
      print('🔄 Updating classes from Firebase...');
      
      // Fetch classes from Firebase
      final classes = await fetchClassesFromSheets();
      
      // Save to storage
      await saveClassesToStorage(classes);
      
      print('✅ Successfully updated classes from Firebase');
    } catch (e) {
      print('❌ Error updating classes: $e');
      rethrow;
    }
  }
}