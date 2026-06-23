import 'package:json_annotation/json_annotation.dart';
import 'package:hive/hive.dart';

part 'class_model.g.dart';



@HiveType(typeId: 0)
@JsonSerializable()
class ClassModel {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String className;
  
  @HiveField(2)
  final String classCode;
  
  @HiveField(3)
  final String sheetId;
  
  @HiveField(4)
  final String attendanceSheetName;
  
  @HiveField(5)
  final String serviceAccountKey;
  
  @HiveField(6)
  final List<Student> students;
  
  @HiveField(7)
  final String? lastSyncTime;
  
  @HiveField(8)
  final String? lastAttendanceSyncTime;
  
  @HiveField(9)
  final DateTime? updatedAt;
  
  @HiveField(10)
  final String? googleSheetUrl;
  
  @HiveField(11)
  final String? sheetName;
  
  @HiveField(12)
  final DateTime? createdAt;
  
  @HiveField(13)
  final String? displayName;
  
  @HiveField(14)
  final String? csvFilePath;

  ClassModel({
    required this.id,
    required this.className,
    required this.students,
    this.classCode = '',
    this.sheetId = '',
    this.attendanceSheetName = '',
    this.googleSheetUrl,
    this.sheetName,
    this.csvFilePath,
    this.serviceAccountKey = '',
    this.lastSyncTime,
    this.lastAttendanceSyncTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.displayName,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory ClassModel.fromJson(Map<String, dynamic> json) => _$ClassModelFromJson(json);

  Map<String, dynamic> toJson() => _$ClassModelToJson(this);

  ClassModel copyWith({
    String? id,
    String? className,
    String? classCode,
    String? sheetId,
    String? attendanceSheetName,
    String? serviceAccountKey,
    List<Student>? students,
    String? lastSyncTime,
    String? lastAttendanceSyncTime,
    DateTime? updatedAt,
    String? googleSheetUrl,
    String? sheetName,
    DateTime? createdAt,
    String? displayName,
    String? csvFilePath,
  }) {
    return ClassModel(
      id: id ?? this.id,
      className: className ?? this.className,
      classCode: classCode ?? this.classCode,
      sheetId: sheetId ?? this.sheetId,
      attendanceSheetName: attendanceSheetName ?? this.attendanceSheetName,
      serviceAccountKey: serviceAccountKey ?? this.serviceAccountKey,
      students: students ?? this.students,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastAttendanceSyncTime: lastAttendanceSyncTime ?? this.lastAttendanceSyncTime,
      updatedAt: updatedAt ?? this.updatedAt,
      googleSheetUrl: googleSheetUrl ?? this.googleSheetUrl,
      sheetName: sheetName ?? this.sheetName,
      createdAt: createdAt ?? this.createdAt,
      displayName: displayName ?? this.displayName,
      csvFilePath: csvFilePath ?? this.csvFilePath,
    );
  }
}

@HiveType(typeId: 1)
@JsonSerializable()
class Student {
  @HiveField(0)
  final String pinNumber;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String email;
  
  @HiveField(3)
  final String phone;
  
  @HiveField(4)
  final List<String> securityCodes;
  
  @HiveField(5)
  final String branch;
  
  @HiveField(6)
  final String mobileNumber;
  
  @HiveField(7)
  final String combo;

  Student({
    required this.pinNumber,
    required this.name,
    required this.email,
    required this.phone,
    this.securityCodes = const [],
    this.branch = '',
    this.mobileNumber = '',
    this.combo = '',
  });

  factory Student.fromJson(Map<String, dynamic> json) => _$StudentFromJson(json);

  Map<String, dynamic> toJson() => _$StudentToJson(this);

  Student copyWith({
    String? pinNumber,
    String? name,
    String? email,
    String? phone,
    List<String>? securityCodes,
    String? branch,
    String? mobileNumber,
    String? combo,
  }) {
    return Student(
      pinNumber: pinNumber ?? this.pinNumber,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      securityCodes: securityCodes ?? this.securityCodes,
      branch: branch ?? this.branch,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      combo: combo ?? this.combo,
    );
  }
  
  /// Create an empty student instance
  static Student empty() {
    return Student(
      pinNumber: '',
      name: '',
      email: '',
      phone: '',
      securityCodes: [],
      branch: '',
      mobileNumber: '',
      combo: '',
    );
  }
  
  // Factory method to create Student from CSV row
  factory Student.fromCsvRow(List<String> row, Map<String, int> headerMap) {
    // Get values based on header mapping, with fallback to column indices
    String getValue(String headerName, int defaultIndex) {
      if (headerMap.containsKey(headerName) && headerMap[headerName]! < row.length) {
        return row[headerMap[headerName]!].toString().trim();
      } else if (defaultIndex < row.length) {
        return row[defaultIndex].toString().trim();
      }
      return '';
    }
    
    // Parse security codes (columns 6 and 7)
    final securityCodes = <String>[];
    if (headerMap.containsKey('Sec-Codes') && headerMap['Sec-Codes']! < row.length) {
      final secCodesRaw = row[headerMap['Sec-Codes']!].toString().trim();
      securityCodes.addAll(secCodesRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    } else {
      // Fallback to columns 6 and 7
      if (row.length > 6) {
        final code1 = row[6].toString().trim();
        if (code1.isNotEmpty) securityCodes.add(code1);
      }
      if (row.length > 7) {
        final code2 = row[7].toString().trim();
        if (code2.isNotEmpty) securityCodes.add(code2);
      }
    }
    
    return Student(
      name: getValue('Name of the Student', 0),
      pinNumber: getValue('Pin-number', 1),
      branch: getValue('Branch', 2),
      email: getValue('Mail-id', 3),
      mobileNumber: getValue('Mobile Number', 4),
      combo: getValue('COMBO', 5),
      phone: '', // Not in CSV, set to empty
      securityCodes: securityCodes,
    );
  }

  /// Factory method to create Student from Firebase JSON
  factory Student.fromFirebaseJson(Map<String, dynamic> json) {
    // Parse security codes
    List<String> securityCodes = [];
    if (json['Sec-Codes'] != null) {
      final secCodesRaw = json['Sec-Codes'].toString();
      securityCodes = secCodesRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return Student(
      name: json['Name of the Student']?.toString() ?? '',
      pinNumber: json['Pin-number']?.toString() ?? '',
      branch: json['Branch']?.toString() ?? '',
      email: json['Mail-id']?.toString() ?? '',
      mobileNumber: json['Mobile Number']?.toString() ?? '',
      combo: json['COMBO']?.toString() ?? '',
      phone: '', // Not in Firebase export
      securityCodes: securityCodes,
    );
  }
}

// UploadType enum removed - replaced with Firebase real-time sync
