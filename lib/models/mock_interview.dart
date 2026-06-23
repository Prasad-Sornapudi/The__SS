import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mock_interview.g.dart';

@HiveType(typeId: 7)
@JsonSerializable()
class MockInterview {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String studentPinNumber;

  @HiveField(2)
  final String studentName;

  @HiveField(3)
  final DateTime interviewDate;

  @HiveField(4)
  final MockInterviewRound tr; // Technical Round

  @HiveField(5)
  final MockInterviewRound hr; // HR Round

  @HiveField(6)
  final MockInterviewRound mr; // Managerial Round

  @HiveField(7)
  final MockInterviewProfile profile;

  @HiveField(8)
  final MockInterviewCoding coding;

  MockInterview({
    required this.id,
    required this.studentPinNumber,
    required this.studentName,
    required this.interviewDate,
    required this.tr,
    required this.hr,
    required this.mr,
    required this.profile,
    required this.coding,
  });

  factory MockInterview.fromJson(Map<String, dynamic> json) => _$MockInterviewFromJson(json);
  Map<String, dynamic> toJson() => _$MockInterviewToJson(this);

  MockInterview copyWith({
    String? id,
    String? studentPinNumber,
    String? studentName,
    DateTime? interviewDate,
    MockInterviewRound? tr,
    MockInterviewRound? hr,
    MockInterviewRound? mr,
    MockInterviewProfile? profile,
    MockInterviewCoding? coding,
  }) {
    return MockInterview(
      id: id ?? this.id,
      studentPinNumber: studentPinNumber ?? this.studentPinNumber,
      studentName: studentName ?? this.studentName,
      interviewDate: interviewDate ?? this.interviewDate,
      tr: tr ?? this.tr,
      hr: hr ?? this.hr,
      mr: mr ?? this.mr,
      profile: profile ?? this.profile,
      coding: coding ?? this.coding,
    );
  }
}

@HiveType(typeId: 8)
@JsonSerializable()
class MockInterviewRound {
  // Technical Round metrics
  @HiveField(0)
  final String? problemSolving;
  
  @HiveField(1)
  final String? technicalKnowledge;
  
  @HiveField(2)
  final String? codingEfficiency;
  
  @HiveField(3)
  final String? systemDesign;
  
  @HiveField(4)
  final String? logicalReasoning;
  
  // HR Round metrics
  @HiveField(5)
  final String? communication;
  
  @HiveField(6)
  final String? confidence;
  
  @HiveField(7)
  final String? bodyLanguage;
  
  @HiveField(8)
  final String? attitude;
  
  @HiveField(9)
  final String? listening;
  
  // Managerial Round metrics
  @HiveField(10)
  final String? decisionMaking;
  
  @HiveField(11)
  final String? leadership;
  
  @HiveField(12)
  final String? teamwork;
  
  @HiveField(13)
  final String? stressHandling;
  
  @HiveField(14)
  final String? realScenarioProblemSolving;

  MockInterviewRound({
    // Technical Round
    this.problemSolving,
    this.technicalKnowledge,
    this.codingEfficiency,
    this.systemDesign,
    this.logicalReasoning,
    // HR Round
    this.communication,
    this.confidence,
    this.bodyLanguage,
    this.attitude,
    this.listening,
    // Managerial Round
    this.decisionMaking,
    this.leadership,
    this.teamwork,
    this.stressHandling,
    this.realScenarioProblemSolving,
  });

  factory MockInterviewRound.fromJson(Map<String, dynamic> json) => _$MockInterviewRoundFromJson(json);
  Map<String, dynamic> toJson() => _$MockInterviewRoundToJson(this);

  // Get all non-null metrics as a map
  Map<String, String> getMetrics() {
    final metrics = <String, String>{};
    
    // Technical Round
    if (problemSolving != null) metrics['Problem Solving'] = problemSolving!;
    if (technicalKnowledge != null) metrics['Technical Knowledge'] = technicalKnowledge!;
    if (codingEfficiency != null) metrics['Coding Efficiency'] = codingEfficiency!;
    if (systemDesign != null) metrics['System Design'] = systemDesign!;
    if (logicalReasoning != null) metrics['Logical Reasoning'] = logicalReasoning!;
    
    // HR Round
    if (communication != null) metrics['Communication'] = communication!;
    if (confidence != null) metrics['Confidence'] = confidence!;
    if (bodyLanguage != null) metrics['Body Language'] = bodyLanguage!;
    if (attitude != null) metrics['Attitude'] = attitude!;
    if (listening != null) metrics['Listening'] = listening!;
    
    // Managerial Round
    if (decisionMaking != null) metrics['Decision Making'] = decisionMaking!;
    if (leadership != null) metrics['Leadership'] = leadership!;
    if (teamwork != null) metrics['Teamwork'] = teamwork!;
    if (stressHandling != null) metrics['Stress Handling'] = stressHandling!;
    if (realScenarioProblemSolving != null) metrics['Real Scenario Problem Solving'] = realScenarioProblemSolving!;
    
    return metrics;
  }
}

@HiveType(typeId: 9)
@JsonSerializable()
class MockInterviewProfile {
  @HiveField(0)
  final String? gitHub;
  
  @HiveField(1)
  final String? linkedIn;
  
  @HiveField(2)
  final int? resumeScore;

  MockInterviewProfile({
    this.gitHub,
    this.linkedIn,
    this.resumeScore,
  });

  factory MockInterviewProfile.fromJson(Map<String, dynamic> json) => _$MockInterviewProfileFromJson(json);
  Map<String, dynamic> toJson() => _$MockInterviewProfileToJson(this);
}

@HiveType(typeId: 10)
@JsonSerializable()
class MockInterviewCoding {
  @HiveField(0)
  final int? leetCode;
  
  @HiveField(1)
  final int? codeChef;
  
  @HiveField(2)
  final String? geeksForGeeks;

  MockInterviewCoding({
    this.leetCode,
    this.codeChef,
    this.geeksForGeeks,
  });

  factory MockInterviewCoding.fromJson(Map<String, dynamic> json) => _$MockInterviewCodingFromJson(json);
  Map<String, dynamic> toJson() => _$MockInterviewCodingToJson(this);
}