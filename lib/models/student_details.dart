class StudentDetails {
  final String name;
  final String rollNumber;
  final String branch;
  final String email;
  final String mobile;
  final String combo;
  final double attendancePercentage;
  final int totalSessions;
  final int attendedSessions;

  StudentDetails({
    required this.name,
    required this.rollNumber,
    required this.branch,
    required this.email,
    required this.mobile,
    required this.combo,
    this.attendancePercentage = 0.0,
    this.totalSessions = 0,
    this.attendedSessions = 0,
  });

  StudentDetails copyWith({
    String? name,
    String? rollNumber,
    String? branch,
    String? email,
    String? mobile,
    String? combo,
    double? attendancePercentage,
    int? totalSessions,
    int? attendedSessions,
  }) {
    return StudentDetails(
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
      branch: branch ?? this.branch,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      combo: combo ?? this.combo,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
      totalSessions: totalSessions ?? this.totalSessions,
      attendedSessions: attendedSessions ?? this.attendedSessions,
    );
  }

  @override
  String toString() {
    return 'StudentDetails(name: $name, rollNumber: $rollNumber, branch: $branch, email: $email, mobile: $mobile, combo: $combo, attendancePercentage: $attendancePercentage%, totalSessions: $totalSessions, attendedSessions: $attendedSessions)';
  }
}