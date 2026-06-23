// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClassModelAdapter extends TypeAdapter<ClassModel> {
  @override
  final int typeId = 0;

  @override
  ClassModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClassModel(
      id: fields[0] as String,
      className: fields[1] as String,
      students: (fields[6] as List).cast<Student>(),
      classCode: fields[2] as String,
      sheetId: fields[3] as String,
      attendanceSheetName: fields[4] as String,
      googleSheetUrl: fields[10] as String?,
      sheetName: fields[11] as String?,
      csvFilePath: fields[14] as String?,
      serviceAccountKey: fields[5] as String,
      lastSyncTime: fields[7] as String?,
      lastAttendanceSyncTime: fields[8] as String?,
      createdAt: fields[12] as DateTime?,
      updatedAt: fields[9] as DateTime?,
      displayName: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ClassModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.className)
      ..writeByte(2)
      ..write(obj.classCode)
      ..writeByte(3)
      ..write(obj.sheetId)
      ..writeByte(4)
      ..write(obj.attendanceSheetName)
      ..writeByte(5)
      ..write(obj.serviceAccountKey)
      ..writeByte(6)
      ..write(obj.students)
      ..writeByte(7)
      ..write(obj.lastSyncTime)
      ..writeByte(8)
      ..write(obj.lastAttendanceSyncTime)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.googleSheetUrl)
      ..writeByte(11)
      ..write(obj.sheetName)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.displayName)
      ..writeByte(14)
      ..write(obj.csvFilePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StudentAdapter extends TypeAdapter<Student> {
  @override
  final int typeId = 1;

  @override
  Student read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Student(
      pinNumber: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      phone: fields[3] as String,
      securityCodes: (fields[4] as List).cast<String>(),
      branch: fields[5] as String,
      mobileNumber: fields[6] as String,
      combo: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Student obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.pinNumber)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.securityCodes)
      ..writeByte(5)
      ..write(obj.branch)
      ..writeByte(6)
      ..write(obj.mobileNumber)
      ..writeByte(7)
      ..write(obj.combo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClassModel _$ClassModelFromJson(Map<String, dynamic> json) => ClassModel(
      id: json['id'] as String,
      className: json['className'] as String,
      students: (json['students'] as List<dynamic>)
          .map((e) => Student.fromJson(e as Map<String, dynamic>))
          .toList(),
      classCode: json['classCode'] as String? ?? '',
      sheetId: json['sheetId'] as String? ?? '',
      attendanceSheetName: json['attendanceSheetName'] as String? ?? '',
      googleSheetUrl: json['googleSheetUrl'] as String?,
      sheetName: json['sheetName'] as String?,
      csvFilePath: json['csvFilePath'] as String?,
      serviceAccountKey: json['serviceAccountKey'] as String? ?? '',
      lastSyncTime: json['lastSyncTime'] as String?,
      lastAttendanceSyncTime: json['lastAttendanceSyncTime'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      displayName: json['displayName'] as String?,
    );

Map<String, dynamic> _$ClassModelToJson(ClassModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'className': instance.className,
      'classCode': instance.classCode,
      'sheetId': instance.sheetId,
      'attendanceSheetName': instance.attendanceSheetName,
      'serviceAccountKey': instance.serviceAccountKey,
      'students': instance.students,
      'lastSyncTime': instance.lastSyncTime,
      'lastAttendanceSyncTime': instance.lastAttendanceSyncTime,
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'googleSheetUrl': instance.googleSheetUrl,
      'sheetName': instance.sheetName,
      'createdAt': instance.createdAt?.toIso8601String(),
      'displayName': instance.displayName,
      'csvFilePath': instance.csvFilePath,
    };

Student _$StudentFromJson(Map<String, dynamic> json) => Student(
      pinNumber: json['pinNumber'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      securityCodes: (json['securityCodes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      branch: json['branch'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String? ?? '',
      combo: json['combo'] as String? ?? '',
    );

Map<String, dynamic> _$StudentToJson(Student instance) => <String, dynamic>{
      'pinNumber': instance.pinNumber,
      'name': instance.name,
      'email': instance.email,
      'phone': instance.phone,
      'securityCodes': instance.securityCodes,
      'branch': instance.branch,
      'mobileNumber': instance.mobileNumber,
      'combo': instance.combo,
    };
