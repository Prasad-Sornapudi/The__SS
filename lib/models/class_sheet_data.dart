/// Represents data from the old Classes tab in App_Control sheet
/// This model is being kept for backward compatibility during the transition
class ClassSheetData {
  /// The batch name (from Batch_Name column)
  final String batchName;
  
  /// Master sheet name
  final String masterSheetName;
  
  /// Master sheet link
  final String masterSheetLink;
  
  /// Master sheet credentials
  final String? masterSheetCredentials;
  
  /// Attendance sheet name
  final String attendanceSheetName;
  
  /// Attendance sheet link
  final String attendanceSheetLink;
  
  /// Attendance sheet credentials
  final String? attendanceSheetCredentials;
  
  /// Mock interview sheet name
  final String? mockInterviewSheetName;
  
  /// Mock interview sheet link
  final String? mockInterviewSheetLink;
  
  /// Mock interview sheet credentials
  final String? mockInterviewSheetCredentials;
  
  /// Department sheet name
  final String? departmentSheetName;
  
  /// Department sheet link
  final String? departmentSheetLink;
  
  /// Department sheet credentials
  final String? departmentSheetCredentials;

  ClassSheetData({
    required this.batchName,
    required this.masterSheetName,
    required this.masterSheetLink,
    this.masterSheetCredentials,
    required this.attendanceSheetName,
    required this.attendanceSheetLink,
    this.attendanceSheetCredentials,
    this.mockInterviewSheetName,
    this.mockInterviewSheetLink,
    this.mockInterviewSheetCredentials,
    this.departmentSheetName,
    this.departmentSheetLink,
    this.departmentSheetCredentials,
  });
}