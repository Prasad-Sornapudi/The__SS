import 'package:hive/hive.dart';

part 'session_model.g.dart';

@HiveType(typeId: 7)
class SessionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime sessionDate;

  @HiveField(2)
  final SessionType sessionType;

  @HiveField(3)
  final String classId;

  @HiveField(4)
  bool isSynced;

  @HiveField(5)
  bool isCleared;

  @HiveField(6)
  DateTime? lastSyncAttempt;

  @HiveField(7)
  int syncAttempts;

  @HiveField(8)
  String? lastSyncError;

  SessionModel({
    required this.id,
    required this.sessionDate,
    required this.sessionType,
    required this.classId,
    this.isSynced = false,
    this.isCleared = false,
    this.lastSyncAttempt,
    this.syncAttempts = 0,
    this.lastSyncError,
  });

  SessionModel copyWith({
    String? id,
    DateTime? sessionDate,
    SessionType? sessionType,
    String? classId,
    bool? isSynced,
    bool? isCleared,
    DateTime? lastSyncAttempt,
    int? syncAttempts,
    String? lastSyncError,
  }) {
    return SessionModel(
      id: id ?? this.id,
      sessionDate: sessionDate ?? this.sessionDate,
      sessionType: sessionType ?? this.sessionType,
      classId: classId ?? this.classId,
      isSynced: isSynced ?? this.isSynced,
      isCleared: isCleared ?? this.isCleared,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastSyncError: lastSyncError ?? this.lastSyncError,
    );
  }
}

@HiveType(typeId: 8)
enum SessionType {
  @HiveField(0)
  morning,

  @HiveField(1)
  afternoon,
}