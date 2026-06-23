// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'batch_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BatchConfig _$BatchConfigFromJson(Map<String, dynamic> json) => BatchConfig(
      batchId: json['batchId'] as String,
      masterSheet: json['masterSheet'] == null
          ? null
          : SheetConfig.fromJson(json['masterSheet'] as Map<String, dynamic>),
      attendanceSheet: json['attendanceSheet'] == null
          ? null
          : SheetConfig.fromJson(
              json['attendanceSheet'] as Map<String, dynamic>),
      mockInterviewSheet: json['mockInterviewSheet'] == null
          ? null
          : SheetConfig.fromJson(
              json['mockInterviewSheet'] as Map<String, dynamic>),
      departmentSheet: json['departmentSheet'] == null
          ? null
          : SheetConfig.fromJson(
              json['departmentSheet'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BatchConfigToJson(BatchConfig instance) =>
    <String, dynamic>{
      'batchId': instance.batchId,
      'masterSheet': instance.masterSheet,
      'attendanceSheet': instance.attendanceSheet,
      'mockInterviewSheet': instance.mockInterviewSheet,
      'departmentSheet': instance.departmentSheet,
    };

SheetConfig _$SheetConfigFromJson(Map<String, dynamic> json) => SheetConfig(
      link: json['link'] as String?,
      credentials: json['credentials'] as String?,
    );

Map<String, dynamic> _$SheetConfigToJson(SheetConfig instance) =>
    <String, dynamic>{
      'link': instance.link,
      'credentials': instance.credentials,
    };
