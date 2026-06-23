// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mock_interview.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MockInterviewAdapter extends TypeAdapter<MockInterview> {
  @override
  final int typeId = 7;

  @override
  MockInterview read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MockInterview(
      id: fields[0] as String,
      studentPinNumber: fields[1] as String,
      studentName: fields[2] as String,
      interviewDate: fields[3] as DateTime,
      tr: fields[4] as MockInterviewRound,
      hr: fields[5] as MockInterviewRound,
      mr: fields[6] as MockInterviewRound,
      profile: fields[7] as MockInterviewProfile,
      coding: fields[8] as MockInterviewCoding,
    );
  }

  @override
  void write(BinaryWriter writer, MockInterview obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.studentPinNumber)
      ..writeByte(2)
      ..write(obj.studentName)
      ..writeByte(3)
      ..write(obj.interviewDate)
      ..writeByte(4)
      ..write(obj.tr)
      ..writeByte(5)
      ..write(obj.hr)
      ..writeByte(6)
      ..write(obj.mr)
      ..writeByte(7)
      ..write(obj.profile)
      ..writeByte(8)
      ..write(obj.coding);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MockInterviewAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MockInterviewRoundAdapter extends TypeAdapter<MockInterviewRound> {
  @override
  final int typeId = 8;

  @override
  MockInterviewRound read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MockInterviewRound(
      problemSolving: fields[0] as String?,
      technicalKnowledge: fields[1] as String?,
      codingEfficiency: fields[2] as String?,
      systemDesign: fields[3] as String?,
      logicalReasoning: fields[4] as String?,
      communication: fields[5] as String?,
      confidence: fields[6] as String?,
      bodyLanguage: fields[7] as String?,
      attitude: fields[8] as String?,
      listening: fields[9] as String?,
      decisionMaking: fields[10] as String?,
      leadership: fields[11] as String?,
      teamwork: fields[12] as String?,
      stressHandling: fields[13] as String?,
      realScenarioProblemSolving: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MockInterviewRound obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.problemSolving)
      ..writeByte(1)
      ..write(obj.technicalKnowledge)
      ..writeByte(2)
      ..write(obj.codingEfficiency)
      ..writeByte(3)
      ..write(obj.systemDesign)
      ..writeByte(4)
      ..write(obj.logicalReasoning)
      ..writeByte(5)
      ..write(obj.communication)
      ..writeByte(6)
      ..write(obj.confidence)
      ..writeByte(7)
      ..write(obj.bodyLanguage)
      ..writeByte(8)
      ..write(obj.attitude)
      ..writeByte(9)
      ..write(obj.listening)
      ..writeByte(10)
      ..write(obj.decisionMaking)
      ..writeByte(11)
      ..write(obj.leadership)
      ..writeByte(12)
      ..write(obj.teamwork)
      ..writeByte(13)
      ..write(obj.stressHandling)
      ..writeByte(14)
      ..write(obj.realScenarioProblemSolving);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MockInterviewRoundAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MockInterviewProfileAdapter extends TypeAdapter<MockInterviewProfile> {
  @override
  final int typeId = 9;

  @override
  MockInterviewProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MockInterviewProfile(
      gitHub: fields[0] as String?,
      linkedIn: fields[1] as String?,
      resumeScore: fields[2] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, MockInterviewProfile obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.gitHub)
      ..writeByte(1)
      ..write(obj.linkedIn)
      ..writeByte(2)
      ..write(obj.resumeScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MockInterviewProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MockInterviewCodingAdapter extends TypeAdapter<MockInterviewCoding> {
  @override
  final int typeId = 10;

  @override
  MockInterviewCoding read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MockInterviewCoding(
      leetCode: fields[0] as int?,
      codeChef: fields[1] as int?,
      geeksForGeeks: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MockInterviewCoding obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.leetCode)
      ..writeByte(1)
      ..write(obj.codeChef)
      ..writeByte(2)
      ..write(obj.geeksForGeeks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MockInterviewCodingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MockInterview _$MockInterviewFromJson(Map<String, dynamic> json) =>
    MockInterview(
      id: json['id'] as String,
      studentPinNumber: json['studentPinNumber'] as String,
      studentName: json['studentName'] as String,
      interviewDate: DateTime.parse(json['interviewDate'] as String),
      tr: MockInterviewRound.fromJson(json['tr'] as Map<String, dynamic>),
      hr: MockInterviewRound.fromJson(json['hr'] as Map<String, dynamic>),
      mr: MockInterviewRound.fromJson(json['mr'] as Map<String, dynamic>),
      profile: MockInterviewProfile.fromJson(
          json['profile'] as Map<String, dynamic>),
      coding:
          MockInterviewCoding.fromJson(json['coding'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MockInterviewToJson(MockInterview instance) =>
    <String, dynamic>{
      'id': instance.id,
      'studentPinNumber': instance.studentPinNumber,
      'studentName': instance.studentName,
      'interviewDate': instance.interviewDate.toIso8601String(),
      'tr': instance.tr,
      'hr': instance.hr,
      'mr': instance.mr,
      'profile': instance.profile,
      'coding': instance.coding,
    };

MockInterviewRound _$MockInterviewRoundFromJson(Map<String, dynamic> json) =>
    MockInterviewRound(
      problemSolving: json['problemSolving'] as String?,
      technicalKnowledge: json['technicalKnowledge'] as String?,
      codingEfficiency: json['codingEfficiency'] as String?,
      systemDesign: json['systemDesign'] as String?,
      logicalReasoning: json['logicalReasoning'] as String?,
      communication: json['communication'] as String?,
      confidence: json['confidence'] as String?,
      bodyLanguage: json['bodyLanguage'] as String?,
      attitude: json['attitude'] as String?,
      listening: json['listening'] as String?,
      decisionMaking: json['decisionMaking'] as String?,
      leadership: json['leadership'] as String?,
      teamwork: json['teamwork'] as String?,
      stressHandling: json['stressHandling'] as String?,
      realScenarioProblemSolving: json['realScenarioProblemSolving'] as String?,
    );

Map<String, dynamic> _$MockInterviewRoundToJson(MockInterviewRound instance) =>
    <String, dynamic>{
      'problemSolving': instance.problemSolving,
      'technicalKnowledge': instance.technicalKnowledge,
      'codingEfficiency': instance.codingEfficiency,
      'systemDesign': instance.systemDesign,
      'logicalReasoning': instance.logicalReasoning,
      'communication': instance.communication,
      'confidence': instance.confidence,
      'bodyLanguage': instance.bodyLanguage,
      'attitude': instance.attitude,
      'listening': instance.listening,
      'decisionMaking': instance.decisionMaking,
      'leadership': instance.leadership,
      'teamwork': instance.teamwork,
      'stressHandling': instance.stressHandling,
      'realScenarioProblemSolving': instance.realScenarioProblemSolving,
    };

MockInterviewProfile _$MockInterviewProfileFromJson(
        Map<String, dynamic> json) =>
    MockInterviewProfile(
      gitHub: json['gitHub'] as String?,
      linkedIn: json['linkedIn'] as String?,
      resumeScore: (json['resumeScore'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MockInterviewProfileToJson(
        MockInterviewProfile instance) =>
    <String, dynamic>{
      'gitHub': instance.gitHub,
      'linkedIn': instance.linkedIn,
      'resumeScore': instance.resumeScore,
    };

MockInterviewCoding _$MockInterviewCodingFromJson(Map<String, dynamic> json) =>
    MockInterviewCoding(
      leetCode: (json['leetCode'] as num?)?.toInt(),
      codeChef: (json['codeChef'] as num?)?.toInt(),
      geeksForGeeks: json['geeksForGeeks'] as String?,
    );

Map<String, dynamic> _$MockInterviewCodingToJson(
        MockInterviewCoding instance) =>
    <String, dynamic>{
      'leetCode': instance.leetCode,
      'codeChef': instance.codeChef,
      'geeksForGeeks': instance.geeksForGeeks,
    };
