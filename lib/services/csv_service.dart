import 'dart:io';
import 'package:csv/csv.dart';
import '../models/class_model.dart';

class CsvService {
  static const List<String> requiredHeaders = [
    'Name of the Student',
    'Pin-number',
    'Branch',
    'Mail-id',
    'Mobile Number',
    'COMBO',
    'Sec-Codes',
  ];

  static Future<CsvParseResult> parseStudentCsv(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return CsvParseResult.error('File does not exist');
      }

      final contents = await file.readAsString();
      return parseStudentCsvFromContent(contents);
    } catch (e) {
      return CsvParseResult.error('Failed to read CSV file: $e');
    }
  }

  static Future<CsvParseResult> parseStudentCsvFromContent(String contents) async {
    try {
      // Detect delimiter (comma or tab)
      final String delimiter = _detectDelimiter(contents);
      
      // Parse CSV
      final List<List<dynamic>> csvData = const CsvToListConverter()
          .convert(contents, fieldDelimiter: delimiter);

      if (csvData.isEmpty) {
        return CsvParseResult.error('CSV file is empty');
      }

      // Get headers from first row
      final List<String> headers = csvData[0].map((e) => e.toString().trim()).toList();
      
      // Validate headers
      final HeaderValidationResult headerValidation = _validateHeaders(headers);
      if (!headerValidation.isValid) {
        return CsvParseResult.error(
          'Invalid CSV headers. ${headerValidation.message}\n'
          'Expected headers: ${requiredHeaders.join(', ')}\n'
          'Found headers: ${headers.join(', ')}'
        );
      }

      // Parse student data
      final List<Student> students = [];
      final List<String> errors = [];

      for (int i = 1; i < csvData.length; i++) {
        try {
          final List<String> row = csvData[i].map((e) => e.toString().trim()).toList();
          
          // Skip empty rows
          if (row.every((cell) => cell.isEmpty)) {
            continue;
          }

          // Ensure row has enough columns
          while (row.length < headers.length) {
            row.add('');
          }

          final student = Student.fromCsvRow(row, headerValidation.headerMap);
          
          // Validate student data
          final studentValidation = _validateStudent(student, i + 1);
          if (studentValidation.isValid) {
            students.add(student);
          } else {
            errors.add('Row ${i + 1}: ${studentValidation.message}');
          }
        } catch (e) {
          errors.add('Row ${i + 1}: Error parsing data - $e');
        }
      }

      if (students.isEmpty) {
        return CsvParseResult.error(
          'No valid student records found.\nErrors:\n${errors.join('\n')}'
        );
      }

      return CsvParseResult.success(
        students: students,
        totalRows: csvData.length - 1,
        validRows: students.length,
        errors: errors,
        headerMap: headerValidation.headerMap,
      );

    } catch (e) {
      return CsvParseResult.error('Failed to parse CSV content: $e');
    }
  }

  static String _detectDelimiter(String content) {
    // Count commas and tabs in the first few lines
    final lines = content.split('\n').take(5).toList();
    int commaCount = 0;
    int tabCount = 0;

    for (final line in lines) {
      commaCount += line.split(',').length - 1;
      tabCount += line.split('\t').length - 1;
    }

    // Return the delimiter with higher count
    return tabCount > commaCount ? '\t' : ',';
  }

  static HeaderValidationResult _validateHeaders(List<String> headers) {
    final Map<String, int> headerMap = {};
    final List<String> missingHeaders = [];

    // Create case-insensitive header mapping
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].trim();
      headerMap[header] = i;
    }

    // Check for required headers (case-insensitive)
    for (final requiredHeader in requiredHeaders) {
      bool found = false;
      for (final header in headers) {
        if (header.toLowerCase().trim() == requiredHeader.toLowerCase().trim()) {
          headerMap[requiredHeader] = headers.indexOf(header);
          found = true;
          break;
        }
      }
      if (!found) {
        missingHeaders.add(requiredHeader);
      }
    }

    if (missingHeaders.isNotEmpty) {
      return HeaderValidationResult(
        isValid: false,
        message: 'Missing required headers: ${missingHeaders.join(', ')}',
        headerMap: {},
      );
    }

    return HeaderValidationResult(
      isValid: true,
      message: 'Headers are valid',
      headerMap: headerMap,
    );
  }

  static StudentValidationResult _validateStudent(Student student, int rowNumber) {
    final List<String> errors = [];

    if (student.name.isEmpty) {
      errors.add('Name is required');
    }

    if (student.pinNumber.isEmpty) {
      errors.add('Pin-number is required');
    }

    if (student.email.isNotEmpty && !_isValidEmail(student.email)) {
      errors.add('Invalid email format');
    }

    if (student.mobileNumber.isNotEmpty && !_isValidMobileNumber(student.mobileNumber)) {
      errors.add('Invalid mobile number format');
    }

    if (student.securityCodes.isEmpty || student.securityCodes.every((code) => code.isEmpty)) {
      errors.add('At least one security code is required');
    }

    return StudentValidationResult(
      isValid: errors.isEmpty,
      message: errors.join(', '),
    );
  }

  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  static bool _isValidMobileNumber(String mobile) {
    final mobileRegex = RegExp(r'^\+?[\d\s\-\(\)]{7,15}$');
    return mobileRegex.hasMatch(mobile.replaceAll(' ', ''));
  }

  // Generate sample CSV for reference
  static String generateSampleCsv() {
    final headers = requiredHeaders.join(',');
    final sampleData = [
      'John Doe,24555A0416,CSE,john.doe@example.com,+91 9876543210,CSE-A,ABC123,DEF456',
      'Jane Smith,24555A0417,ECE,jane.smith@example.com,+91 9876543211,ECE-B,XYZ789,PQR012',
      'Bob Johnson,24555A0418,MECH,bob.johnson@example.com,+91 9876543212,MECH-A,LMN345,OPQ678',
    ];

    return '$headers\n${sampleData.join('\n')}';
  }
}

class CsvParseResult {
  final bool isSuccess;
  final List<Student>? students;
  final int? totalRows;
  final int? validRows;
  final List<String>? errors;
  final String? errorMessage;
  final Map<String, int>? headerMap;

  CsvParseResult._({
    required this.isSuccess,
    this.students,
    this.totalRows,
    this.validRows,
    this.errors,
    this.errorMessage,
    this.headerMap,
  });

  factory CsvParseResult.success({
    required List<Student> students,
    required int totalRows,
    required int validRows,
    required List<String> errors,
    required Map<String, int> headerMap,
  }) {
    return CsvParseResult._(
      isSuccess: true,
      students: students,
      totalRows: totalRows,
      validRows: validRows,
      errors: errors,
      headerMap: headerMap,
    );
  }

  factory CsvParseResult.error(String errorMessage) {
    return CsvParseResult._(
      isSuccess: false,
      errorMessage: errorMessage,
    );
  }

  String get summary {
    if (!isSuccess) {
      return 'Error: $errorMessage';
    }

    final buffer = StringBuffer();
    buffer.writeln('Successfully parsed $validRows out of $totalRows student records');
    
    if (errors != null && errors!.isNotEmpty) {
      buffer.writeln('\nWarnings/Errors:');
      for (final error in errors!.take(5)) {
        buffer.writeln('• $error');
      }
      if (errors!.length > 5) {
        buffer.writeln('• ... and ${errors!.length - 5} more');
      }
    }

    return buffer.toString();
  }
}

class HeaderValidationResult {
  final bool isValid;
  final String message;
  final Map<String, int> headerMap;

  HeaderValidationResult({
    required this.isValid,
    required this.message,
    required this.headerMap,
  });
}

class StudentValidationResult {
  final bool isValid;
  final String message;

  StudentValidationResult({
    required this.isValid,
    required this.message,
  });
}