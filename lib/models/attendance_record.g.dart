// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendanceRecordAdapter extends TypeAdapter<AttendanceRecord> {
  @override
  final int typeId = 4;

  @override
  AttendanceRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttendanceRecord(
      id: fields[0] as String,
      classId: fields[1] as String,
      studentPinNumber: fields[2] as String,
      studentName: fields[3] as String,
      scanTime: fields[4] as DateTime,
      status: fields[5] as AttendanceStatus,
      scannedCode: fields[6] as String?,
      scanMethod: fields[7] as ScanMethod,
      sessionDate: fields[8] as DateTime,
      isSyncedToSheet: fields[9] as bool,
      isSyncedToFirebase: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceRecord obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.classId)
      ..writeByte(2)
      ..write(obj.studentPinNumber)
      ..writeByte(3)
      ..write(obj.studentName)
      ..writeByte(4)
      ..write(obj.scanTime)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.scannedCode)
      ..writeByte(7)
      ..write(obj.scanMethod)
      ..writeByte(8)
      ..write(obj.sessionDate)
      ..writeByte(9)
      ..write(obj.isSyncedToSheet)
      ..writeByte(10)
      ..write(obj.isSyncedToFirebase);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AttendanceStatusAdapter extends TypeAdapter<AttendanceStatus> {
  @override
  final int typeId = 5;

  @override
  AttendanceStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttendanceStatus.present;
      case 1:
        return AttendanceStatus.absent;
      case 2:
        return AttendanceStatus.duplicate;
      default:
        return AttendanceStatus.present;
    }
  }

  @override
  void write(BinaryWriter writer, AttendanceStatus obj) {
    switch (obj) {
      case AttendanceStatus.present:
        writer.writeByte(0);
        break;
      case AttendanceStatus.absent:
        writer.writeByte(1);
        break;
      case AttendanceStatus.duplicate:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScanMethodAdapter extends TypeAdapter<ScanMethod> {
  @override
  final int typeId = 6;

  @override
  ScanMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ScanMethod.qr;
      case 1:
        return ScanMethod.qrCamera;
      case 2:
        return ScanMethod.manual;
      default:
        return ScanMethod.qr;
    }
  }

  @override
  void write(BinaryWriter writer, ScanMethod obj) {
    switch (obj) {
      case ScanMethod.qr:
        writer.writeByte(0);
        break;
      case ScanMethod.qrCamera:
        writer.writeByte(1);
        break;
      case ScanMethod.manual:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AttendanceRecord _$AttendanceRecordFromJson(Map<String, dynamic> json) =>
    AttendanceRecord(
      id: json['id'] as String,
      classId: json['classId'] as String,
      studentPinNumber: json['studentPinNumber'] as String,
      studentName: json['studentName'] as String,
      scanTime: DateTime.parse(json['scanTime'] as String),
      status: $enumDecode(_$AttendanceStatusEnumMap, json['status']),
      scannedCode: json['scannedCode'] as String?,
      scanMethod: $enumDecode(_$ScanMethodEnumMap, json['scanMethod']),
      sessionDate: DateTime.parse(json['sessionDate'] as String),
      isSyncedToSheet: json['isSyncedToSheet'] as bool? ?? false,
      isSyncedToFirebase: json['isSyncedToFirebase'] as bool? ?? false,
    );

Map<String, dynamic> _$AttendanceRecordToJson(AttendanceRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'classId': instance.classId,
      'studentPinNumber': instance.studentPinNumber,
      'studentName': instance.studentName,
      'scanTime': instance.scanTime.toIso8601String(),
      'status': _$AttendanceStatusEnumMap[instance.status]!,
      'scannedCode': instance.scannedCode,
      'scanMethod': _$ScanMethodEnumMap[instance.scanMethod]!,
      'sessionDate': instance.sessionDate.toIso8601String(),
      'isSyncedToSheet': instance.isSyncedToSheet,
      'isSyncedToFirebase': instance.isSyncedToFirebase,
    };

const _$AttendanceStatusEnumMap = {
  AttendanceStatus.present: 'present',
  AttendanceStatus.absent: 'absent',
  AttendanceStatus.duplicate: 'duplicate',
};

const _$ScanMethodEnumMap = {
  ScanMethod.qr: 'qr',
  ScanMethod.qrCamera: 'qrCamera',
  ScanMethod.manual: 'manual',
};
