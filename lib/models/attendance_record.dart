import 'package:json_annotation/json_annotation.dart';
import 'package:hive/hive.dart';
import 'class_model.dart'; // Import Student model

part 'attendance_record.g.dart';

@HiveType(typeId: 4)
@JsonSerializable()
class AttendanceRecord extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String classId;

  @HiveField(2)
  String studentPinNumber;

  @HiveField(3)
  String studentName;

  @HiveField(4)
  DateTime scanTime;

  @HiveField(5)
  AttendanceStatus status;

  @HiveField(6)
  String? scannedCode; // The actual QR code content that was scanned

  @HiveField(7)
  ScanMethod scanMethod;

  @HiveField(8)
  DateTime sessionDate; // Date of the attendance session

  @HiveField(9)
  bool isSyncedToSheet;
  
  @HiveField(10)
  bool isSyncedToFirebase; // Track Firebase sync separately from Sheets

  AttendanceRecord({
    required this.id,
    required this.classId,
    required this.studentPinNumber,
    required this.studentName,
    required this.scanTime,
    required this.status,
    this.scannedCode,
    required this.scanMethod,
    required this.sessionDate,
    this.isSyncedToSheet = false,
    this.isSyncedToFirebase = false,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => _$AttendanceRecordFromJson(json);
  Map<String, dynamic> toJson() => _$AttendanceRecordToJson(this);

  AttendanceRecord copyWith({
    String? id,
    String? classId,
    String? studentPinNumber,
    String? studentName,
    DateTime? scanTime,
    AttendanceStatus? status,
    String? scannedCode,
    ScanMethod? scanMethod,
    DateTime? sessionDate,
    bool? isSyncedToSheet,
    bool? isSyncedToFirebase,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      studentPinNumber: studentPinNumber ?? this.studentPinNumber,
      studentName: studentName ?? this.studentName,
      scanTime: scanTime ?? this.scanTime,
      status: status ?? this.status,
      scannedCode: scannedCode ?? this.scannedCode,
      scanMethod: scanMethod ?? this.scanMethod,
      sessionDate: sessionDate ?? this.sessionDate,
      isSyncedToSheet: isSyncedToSheet ?? this.isSyncedToSheet,
      isSyncedToFirebase: isSyncedToFirebase ?? this.isSyncedToFirebase,
    );
  }

  // Convert AttendanceRecord to Student
  Student toStudent() {
    return Student(
      pinNumber: studentPinNumber,
      name: studentName,
      email: '', // Default empty
      phone: '', // Default empty
      branch: '', // Default empty
      mobileNumber: '', // Default empty
      combo: '', // Default empty
      securityCodes: [], // Default empty
    );
  }

  String get displayTime {
    return '${scanTime.hour.toString().padLeft(2, '0')}:${scanTime.minute.toString().padLeft(2, '0')}';
  }
}

@HiveType(typeId: 5)
enum AttendanceStatus {
  @HiveField(0)
  present,
  
  @HiveField(1)
  absent,
  
  @HiveField(2)
  duplicate,
}

@HiveType(typeId: 6)
enum ScanMethod {
  @HiveField(0)
  qr, // QR code scan (alias for qrCamera)
  
  @HiveField(1)
  qrCamera, // Legacy name, same as qr
  
  @HiveField(2)
  manual,
}

// Helper class for attendance session summary
class AttendanceSessionSummary {
  final String classId;
  final DateTime sessionDate;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final List<AttendanceRecord> presentStudents;
  final List<String> absentStudents; // Pin numbers of absent students

  AttendanceSessionSummary({
    required this.classId,
    required this.sessionDate,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.presentStudents,
    required this.absentStudents,
  });

  double get attendancePercentage => totalStudents > 0 ? (presentCount / totalStudents) * 100 : 0.0;
}