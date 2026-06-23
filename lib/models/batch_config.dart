import 'package:json_annotation/json_annotation.dart';

part 'batch_config.g.dart';

/// Represents configuration data for a single batch from App_Control sheet
@JsonSerializable()
class BatchConfig {
  /// The batch identifier (tab name in App_Control sheet)
  final String batchId;
  
  /// Master sheet configuration
  final SheetConfig? masterSheet;
  
  /// Attendance sheet configuration
  final SheetConfig? attendanceSheet;
  
  /// Mock interview sheet configuration
  final SheetConfig? mockInterviewSheet;
  
  /// Department sheet configuration
  final SheetConfig? departmentSheet;

  BatchConfig({
    required this.batchId,
    this.masterSheet,
    this.attendanceSheet,
    this.mockInterviewSheet,
    this.departmentSheet,
  });

  factory BatchConfig.fromJson(Map<String, dynamic> json) => _$BatchConfigFromJson(json);
  Map<String, dynamic> toJson() => _$BatchConfigToJson(this);
}

/// Represents configuration for a single sheet
@JsonSerializable()
class SheetConfig {
  /// The Google Sheet URL
  final String? link;
  
  /// Service account credentials for accessing the sheet
  final String? credentials;

  SheetConfig({
    this.link,
    this.credentials,
  });

  factory SheetConfig.fromJson(Map<String, dynamic> json) => _$SheetConfigFromJson(json);
  Map<String, dynamic> toJson() => _$SheetConfigToJson(this);
}