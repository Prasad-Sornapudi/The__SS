import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/class_model.dart';
import '../models/batch_config.dart';
import '../models/class_sheet_data.dart';
import 'control_sheet_service.dart';

/// Firebase Configuration Service
/// Reads app configuration from Firebase Realtime Database
/// Replaces the encrypted secret files system
class FirebaseConfigService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  /// Read login credentials from Firebase RTDB
  /// Path: sync/sheetSync/loginCredentials/credentials (matches Apps Script)
  static Future<List<LoginCredentials>> readLoginCredentials() async {
    try {
      print('=== READING LOGIN CREDENTIALS FROM FIREBASE RTDB ===');
      
      // Primary path: sync/sheetSync/loginCredentials/credentials (from Apps Script line 706)
      final ref = _database.ref('sync/sheetSync/loginCredentials/credentials');
      final snapshot = await ref.get();
      
      if (!snapshot.exists) {
        print('⚠️ No login credentials found at path: sync/sheetSync/loginCredentials/credentials');
        print('   Make sure your Apps Script has synced the Login_Credentials sheet to Firebase');
        return [];
      }
      
      return _parseLoginCredentials(snapshot);
      
    } catch (e, stackTrace) {
      print('❌ Error reading login credentials from Firebase: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
  
  /// Parse login credentials from Firebase snapshot
  static List<LoginCredentials> _parseLoginCredentials(DataSnapshot snapshot) {
    final credentials = <LoginCredentials>[];
    final data = snapshot.value;
    
    print('📊 Login credentials data type: ${data.runtimeType}');
    
    if (data is Map) {
      print('📋 Found ${data.length} credential entries in Firebase');
      
      data.forEach((key, value) {
        print('📋 Processing credential key: $key');
        
        if (value is Map) {
          try {
            final name = value['name']?.toString() ?? value['Name']?.toString() ?? '';
            final username = value['username']?.toString() ?? value['User_Name']?.toString() ?? '';
            final password = value['password']?.toString() ?? value['Password']?.toString() ?? '';
            final role = value['role']?.toString() ?? value['Role']?.toString() ?? 'User';
            
            if (username.isNotEmpty && password.isNotEmpty) {
              print('👤 Adding credential: Name="$name", Username="$username", Password length=${password.length}, Role="$role"');
              
              credentials.add(LoginCredentials(
                name: name,
                username: username,
                password: password,
                role: role,
              ));
            } else {
              print('⚠️ Skipping credential $key due to missing username or password');
            }
          } catch (e) {
            print('⚠️ Error parsing credential $key: $e');
          }
        } else if (value is List) {
          // Handle array format (e.g., row data from sheets)
          print('📋 Processing credential as array: $value');
          if (value.length >= 4) {
            final name = value[0]?.toString() ?? '';
            final username = value[1]?.toString() ?? '';
            final password = value[2]?.toString() ?? '';
            final role = value[3]?.toString() ?? 'User';
            
            if (username.isNotEmpty && password.isNotEmpty) {
              print('👤 Adding credential: Name="$name", Username="$username", Password length=${password.length}, Role="$role"');
              
              credentials.add(LoginCredentials(
                name: name,
                username: username,
                password: password,
                role: role,
              ));
            }
          }
        }
      });
    } else if (data is List) {
      // Handle if the entire dataset is an array
      print('📋 Login credentials stored as array with ${data.length} entries');
      
      for (int i = 0; i < data.length; i++) {
        final row = data[i];
        print('📋 Processing row $i: $row');
        
        if (row is List && row.length >= 4) {
          final name = row[0]?.toString() ?? '';
          final username = row[1]?.toString() ?? '';
          final password = row[2]?.toString() ?? '';
          final role = row[3]?.toString() ?? 'User';
          
          if (username.isNotEmpty && password.isNotEmpty) {
            print('👤 Adding credential: Name="$name", Username="$username", Password length=${password.length}, Role="$role"');
            
            credentials.add(LoginCredentials(
              name: name,
              username: username,
              password: password,
              role: role,
            ));
          }
        } else if (row is Map) {
          final name = row['name']?.toString() ?? row['Name']?.toString() ?? '';
          final username = row['username']?.toString() ?? row['User_Name']?.toString() ?? '';
          final password = row['password']?.toString() ?? row['Password']?.toString() ?? '';
          final role = row['role']?.toString() ?? row['Role']?.toString() ?? 'User';
          
          if (username.isNotEmpty && password.isNotEmpty) {
            credentials.add(LoginCredentials(
              name: name,
              username: username,
              password: password,
              role: role,
            ));
          }
        }
      }
    }
    
    print('✅ Successfully parsed ${credentials.length} login credentials from Firebase');
    return credentials;
  }
  
  /// Read service account JSON from Firebase RTDB
  /// Path: sync/sheetConfig/serviceAccountJson
  static Future<String?> readServiceAccountJson() async {
    try {
      print('🔐 Reading service account from Firebase RTDB...');
      
      final ref = _database.ref('sync/sheetConfig/serviceAccountJson');
      final snapshot = await ref.get();
      
      if (!snapshot.exists) {
        print('❌ No service account found in Firebase at path: sync/sheetConfig/serviceAccountJson');
        return null;
      }
      
      final serviceAccountJson = snapshot.value as String?;
      
      if (serviceAccountJson == null || serviceAccountJson.isEmpty) {
        print('❌ Service account JSON is empty');
        return null;
      }
      
      print('✅ Service account JSON loaded from Firebase (length: ${serviceAccountJson.length})');
      return serviceAccountJson;
      
    } catch (e, stackTrace) {
      print('❌ Error reading service account from Firebase: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Read control sheet URL from Firebase RTDB
  /// Path: sync/sheetConfig/googleSheetUrl
  static Future<String?> readControlSheetUrl() async {
    try {
      print('📄 Reading control sheet URL from Firebase RTDB...');
      
      final ref = _database.ref('sync/sheetConfig/googleSheetUrl');
      final snapshot = await ref.get();
      
      if (!snapshot.exists) {
        print('❌ No control sheet URL found in Firebase');
        return null;
      }
      
      final url = snapshot.value as String?;
      
      if (url == null || url.isEmpty) {
        print('❌ Control sheet URL is empty');
        return null;
      }
      
      print('✅ Control sheet URL loaded from Firebase: $url');
      return url;
      
    } catch (e, stackTrace) {
      print('❌ Error reading control sheet URL from Firebase: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Read classes data from Firebase RTDB
  /// Path: sync/sheetSync/classes/classes (matches Apps Script line 735)
  static Future<List<ClassSheetData>> readClassesData() async {
    try {
      print('=== READING CLASSES DATA FROM FIREBASE RTDB ===');
      
      // Primary path: sync/sheetSync/classes/classes (from Apps Script)
      final ref = _database.ref('sync/sheetSync/classes/classes');
      final snapshot = await ref.get();
      
      if (!snapshot.exists) {
        print('⚠️ No classes data found at path: sync/sheetSync/classes/classes');
        print('   Make sure your Apps Script has synced the Classes sheet to Firebase');
        return [];
      }
      
      return _parseClassesData(snapshot);
      
    } catch (e, stackTrace) {
      print('❌ Error reading classes data from Firebase: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
  
  /// Parse classes data from Firebase snapshot
  static List<ClassSheetData> _parseClassesData(DataSnapshot snapshot) {
    final classesList = <ClassSheetData>[];
    final data = snapshot.value;
    
    print('📊 Classes data type: ${data.runtimeType}');
    
    if (data is Map) {
      print('📋 Found ${data.length} class entries in Firebase');
      
      data.forEach((key, value) {
        // Skip login_credentials entry
        if (key == 'login_credentials') {
          print('⏭️ Skipping login_credentials entry');
          return;
        }
        
        print('📋 Processing class key: $key');
        
        if (value is Map) {
          try {
            final classData = ClassSheetData(
              batchName: value['batchName']?.toString() ?? value['Batch_Name']?.toString() ?? key.toString(),
              masterSheetName: value['masterSheetName']?.toString() ?? value['Master_Sheet_Name']?.toString() ?? '',
              masterSheetLink: value['masterSheetLink']?.toString() ?? value['Master_Sheet_Link']?.toString() ?? '',
              masterSheetCredentials: value['masterSheetCredentials']?.toString() ?? value['Master_Sheet_Credentials']?.toString(),
              attendanceSheetName: value['attendanceSheetName']?.toString() ?? value['Attendance_Sheet_Name']?.toString() ?? '',
              attendanceSheetLink: value['attendanceSheetLink']?.toString() ?? value['Attendance_Sheet_Link']?.toString() ?? '',
              attendanceSheetCredentials: value['attendanceSheetCredentials']?.toString() ?? value['Attendance_Sheet_Credentials']?.toString(),
              mockInterviewSheetName: value['mockInterviewSheetName']?.toString() ?? value['Mock_Interview_Sheet_Name']?.toString(),
              mockInterviewSheetLink: value['mockInterviewSheetLink']?.toString() ?? value['Mock_Interview_Sheet_Link']?.toString(),
              mockInterviewSheetCredentials: value['mockInterviewSheetCredentials']?.toString() ?? value['Mock_Interview_Sheet_Credentials']?.toString(),
              departmentSheetName: value['departmentSheetName']?.toString() ?? value['Department_Sheet_Name']?.toString(),
              departmentSheetLink: value['departmentSheetLink']?.toString() ?? value['Department_Sheet_Link']?.toString(),
              departmentSheetCredentials: value['departmentSheetCredentials']?.toString() ?? value['Department_Sheet_Credentials']?.toString(),
            );
            
            print('Class Data: ${classData.batchName}');
            classesList.add(classData);
          } catch (e) {
            print('⚠️ Error parsing class $key: $e');
          }
        } else if (value is List && value.length >= 7) {
          // Handle array format
          try {
            final classData = ClassSheetData(
              batchName: value[0]?.toString() ?? '',
              masterSheetName: value[1]?.toString() ?? '',
              masterSheetLink: value[2]?.toString() ?? '',
              masterSheetCredentials: value.length > 3 ? value[3]?.toString() : null,
              attendanceSheetName: value.length > 4 ? value[4]?.toString() ?? '' : '',
              attendanceSheetLink: value.length > 5 ? value[5]?.toString() ?? '' : '',
              attendanceSheetCredentials: value.length > 6 ? value[6]?.toString() : null,
              mockInterviewSheetName: value.length > 7 ? value[7]?.toString() : null,
              mockInterviewSheetLink: value.length > 8 ? value[8]?.toString() : null,
              mockInterviewSheetCredentials: value.length > 9 ? value[9]?.toString() : null,
              departmentSheetName: value.length > 10 ? value[10]?.toString() : null,
              departmentSheetLink: value.length > 11 ? value[11]?.toString() : null,
              departmentSheetCredentials: value.length > 12 ? value[12]?.toString() : null,
            );
            
            print('Class Data: ${classData.batchName}');
            classesList.add(classData);
          } catch (e) {
            print('⚠️ Error parsing class array $key: $e');
          }
        }
      });
    } else if (data is List) {
      print('📋 Classes data stored as array with ${data.length} entries');
      
      for (int i = 0; i < data.length; i++) {
        final row = data[i];
        
        if (row is List && row.length >= 7) {
          try {
            final classData = ClassSheetData(
              batchName: row[0]?.toString() ?? '',
              masterSheetName: row[1]?.toString() ?? '',
              masterSheetLink: row[2]?.toString() ?? '',
              masterSheetCredentials: row.length > 3 ? row[3]?.toString() : null,
              attendanceSheetName: row.length > 4 ? row[4]?.toString() ?? '' : '',
              attendanceSheetLink: row.length > 5 ? row[5]?.toString() ?? '' : '',
              attendanceSheetCredentials: row.length > 6 ? row[6]?.toString() : null,
              mockInterviewSheetName: row.length > 7 ? row[7]?.toString() : null,
              mockInterviewSheetLink: row.length > 8 ? row[8]?.toString() : null,
              mockInterviewSheetCredentials: row.length > 9 ? row[9]?.toString() : null,
              departmentSheetName: row.length > 10 ? row[10]?.toString() : null,
              departmentSheetLink: row.length > 11 ? row[11]?.toString() : null,
              departmentSheetCredentials: row.length > 12 ? row[12]?.toString() : null,
            );
            
            classesList.add(classData);
          } catch (e) {
            print('⚠️ Error parsing class row $i: $e');
          }
        } else if (row is Map) {
          // Handle Map objects inside the list
          try {
            print('Processing class map row: $row');
            final classData = ClassSheetData(
              batchName: row['batchName']?.toString() ?? row['Batch_Name']?.toString() ?? '',
              masterSheetName: row['masterSheetName']?.toString() ?? row['Master_Sheet_Name']?.toString() ?? '',
              masterSheetLink: row['masterSheetLink']?.toString() ?? row['Master_Sheet_Link']?.toString() ?? '',
              masterSheetCredentials: row['masterSheetCredentials']?.toString() ?? row['Master_Sheet_Credentials']?.toString(),
              attendanceSheetName: row['attendanceSheetName']?.toString() ?? row['Attendance_Sheet_Name']?.toString() ?? '',
              attendanceSheetLink: row['attendanceSheetLink']?.toString() ?? row['Attendance_Sheet_Link']?.toString() ?? '',
              attendanceSheetCredentials: row['attendanceSheetCredentials']?.toString() ?? row['Attendance_Sheet_Credentials']?.toString(),
              mockInterviewSheetName: row['mockInterviewSheetName']?.toString() ?? row['Mock_Interview_Sheet_Name']?.toString(),
              mockInterviewSheetLink: row['mockInterviewSheetLink']?.toString() ?? row['Mock_Interview_Sheet_Link']?.toString(),
              mockInterviewSheetCredentials: row['mockInterviewSheetCredentials']?.toString() ?? row['Mock_Interview_Sheet_Credentials']?.toString(),
              departmentSheetName: row['departmentSheetName']?.toString() ?? row['Department_Sheet_Name']?.toString(),
              departmentSheetLink: row['departmentSheetLink']?.toString() ?? row['Department_Sheet_Link']?.toString(),
              departmentSheetCredentials: row['departmentSheetCredentials']?.toString() ?? row['Department_Sheet_Credentials']?.toString(),
            );
            
            print('Class Data from Map in List: ${classData.batchName}');
            classesList.add(classData);
          } catch (e) {
            print('⚠️ Error parsing class map in row $i: $e');
          }
        } else {
          print('⚠️ Row $i is neither List nor Map: ${row.runtimeType} - $row');
        }
      }
    }
    
    print('✅ Successfully parsed ${classesList.length} classes from Firebase');
    return classesList;
  }
  
  /// Read batch configurations from Firebase RTDB
  /// Path: /batches/{batchId}/config
  static Future<Map<String, BatchConfig>> readBatchConfigs() async {
    try {
      print('=== READING BATCH CONFIGURATIONS FROM FIREBASE RTDB ===');
      
      // Path: batches (root level for batch configurations)
      final ref = _database.ref('batches');
      final snapshot = await ref.get();
      
      if (!snapshot.exists) {
        print('⚠️ No batch configurations found at path: batches');
        return {};
      }
      
      return _parseBatchConfigs(snapshot);
      
    } catch (e, stackTrace) {
      print('❌ Error reading batch configurations from Firebase: $e');
      print('Stack trace: $stackTrace');
      return {};
    }
  }
  
  /// Parse batch configurations from Firebase snapshot
  static Map<String, BatchConfig> _parseBatchConfigs(DataSnapshot snapshot) {
    final batchConfigs = <String, BatchConfig>{};
    final data = snapshot.value;
    
    print('📊 Batch configs data type: ${data.runtimeType}');
    
    if (data is Map) {
      print('📋 Found ${data.length} batch entries in Firebase');
      
      data.forEach((batchId, value) {
        // Skip non-batch entries
        if (batchId == 'sync' || batchId == 'sheetConfig' || batchId == 'sheetSync') {
          print('⏭️ Skipping non-batch entry: $batchId');
          return;
        }
        
        print('📋 Processing batch: $batchId');
        
        if (value is Map && value.containsKey('config')) {
          try {
            final configData = value['config'] as Map?;
            if (configData == null) {
              print('⚠️ No config data found for batch: $batchId');
              return;
            }
            
            SheetConfig? masterSheet;
            SheetConfig? attendanceSheet;
            SheetConfig? mockInterviewSheet;
            SheetConfig? departmentSheet;
            
            // Parse master sheet config
            if (configData['masterSheet'] is Map) {
              final masterData = configData['masterSheet'] as Map;
              masterSheet = SheetConfig(
                link: masterData['link']?.toString(),
                credentials: masterData['credentials']?.toString(),
              );
            }
            
            // Parse attendance sheet config
            if (configData['attendanceSheet'] is Map) {
              final attendanceData = configData['attendanceSheet'] as Map;
              attendanceSheet = SheetConfig(
                link: attendanceData['link']?.toString(),
                credentials: attendanceData['credentials']?.toString(),
              );
            }
            
            // Parse mock interview sheet config
            if (configData['mockSheet'] is Map) {
              final mockData = configData['mockSheet'] as Map;
              mockInterviewSheet = SheetConfig(
                link: mockData['link']?.toString(),
                credentials: mockData['credentials']?.toString(),
              );
            }
            
            // Parse department sheet config
            if (configData['departmentSheet'] is Map) {
              final departmentData = configData['departmentSheet'] as Map;
              departmentSheet = SheetConfig(
                link: departmentData['link']?.toString(),
                credentials: departmentData['credentials']?.toString(),
              );
            }
            
            final batchConfig = BatchConfig(
              batchId: batchId.toString(),
              masterSheet: masterSheet,
              attendanceSheet: attendanceSheet,
              mockInterviewSheet: mockInterviewSheet,
              departmentSheet: departmentSheet,
            );
            
            print('✅ Batch config loaded: $batchId');
            batchConfigs[batchId.toString()] = batchConfig;
          } catch (e) {
            print('⚠️ Error parsing batch config $batchId: $e');
          }
        }
      });
    }
    
    print('✅ Successfully parsed ${batchConfigs.length} batch configurations from Firebase');
    return batchConfigs;
  }

  /// Get complete configuration from Firebase
  /// Returns service account and control sheet URL
  static Future<FirebaseConfigData?> readConfiguration() async {
    try {
      print('=== READING COMPLETE CONFIGURATION FROM FIREBASE ===');
      
      final serviceAccountJson = await readServiceAccountJson();
      final controlSheetUrl = await readControlSheetUrl();
      
      if (serviceAccountJson == null || controlSheetUrl == null) {
        print('❌ Incomplete configuration in Firebase');
        return null;
      }
      
      print('✅ Configuration loaded successfully from Firebase');
      return FirebaseConfigData(
        serviceAccountJson: serviceAccountJson,
        controlSheetUrl: controlSheetUrl,
      );
      
    } catch (e) {
      print('❌ Error reading configuration from Firebase: $e');
      return null;
    }
  }
}

/// Data class to hold Firebase configuration
class FirebaseConfigData {
  final String serviceAccountJson;
  final String controlSheetUrl;
  
  FirebaseConfigData({
    required this.serviceAccountJson,
    required this.controlSheetUrl,
  });
}
