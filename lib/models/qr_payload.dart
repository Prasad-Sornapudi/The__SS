import 'dart:convert';

class QRPayload {
  final String pinNumber;
  final String? securityCode;
  final QRPayloadType type;

  QRPayload({
    required this.pinNumber,
    this.securityCode,
    required this.type,
  });

  factory QRPayload.parse(String qrData) {
    try {
      // Try to parse as JSON first
      final jsonData = json.decode(qrData);
      if (jsonData is Map<String, dynamic> && jsonData.containsKey('pinNumber')) {
        return QRPayload(
          pinNumber: jsonData['pinNumber'].toString(),
          securityCode: jsonData['securityCode']?.toString(),
          type: QRPayloadType.json,
        );
      }
    } catch (e) {
      // Not JSON, continue with other formats
    }

    // Clean the QR data
    final cleanedData = qrData.trim();
    
    // Check if it contains course info with security code pattern
    // Format: "AWS + GEN AI_CSE_SS01_3-1\n23551IA4611" or similar
    if (cleanedData.contains('\n')) {
      final lines = cleanedData.split('\n');
      if (lines.length >= 2) {
        // Course info on first line, security code on second line
        final courseInfo = lines[0].trim();
        final securityCode = lines[1].trim();
        
        // Validate security code format (alphanumeric, usually 6-15 characters)
        final securityCodePattern = RegExp(r'^[A-Z0-9]{6,15}$');
        if (securityCodePattern.hasMatch(securityCode)) {
          return QRPayload(
            pinNumber: securityCode,
            securityCode: securityCode,
            type: QRPayloadType.securityCode,
          );
        }
      }
    }
    
    // Check for embedded security codes in single line format
    // Look for patterns like course info + security code
    if (cleanedData.contains('_') && cleanedData.length > 10) {
      // Try to extract security code from the end of the string
      final securityCodePattern = RegExp(r'[A-Z0-9]{6,15}$');
      final match = securityCodePattern.firstMatch(cleanedData);
      if (match != null) {
        final code = match.group(0)!;
        // Ensure it has both letters and numbers
        if (code.contains(RegExp(r'[A-Z]')) && code.contains(RegExp(r'[0-9]'))) {
          return QRPayload(
            pinNumber: code,
            securityCode: code,
            type: QRPayloadType.securityCode,
          );
        }
      }
      
      // Alternative: split by underscore and look for security code pattern
      final parts = cleanedData.split('_');
      for (final part in parts.reversed) {
        final trimmedPart = part.trim();
        final securityCodePattern = RegExp(r'^[A-Z0-9]{6,15}$');
        if (securityCodePattern.hasMatch(trimmedPart) &&
            trimmedPart.contains(RegExp(r'[A-Z]')) && 
            trimmedPart.contains(RegExp(r'[0-9]'))) {
          return QRPayload(
            pinNumber: trimmedPart,
            securityCode: trimmedPart,
            type: QRPayloadType.securityCode,
          );
        }
      }
    }

    // Check if it contains a comma (various comma-separated formats)
    if (cleanedData.contains(',')) {
      final parts = cleanedData.split(',').map((p) => p.trim()).toList();
      
      if (parts.length >= 2) {
        // Handle format: YTRTSXQL,23551A4611,AWS + GENAI,CSC
        // First field is security code, second is roll number
        final securityCode = parts[0]; // YTRTSXQL
        final rollNumber = parts[1];   // 23551A4611
        
        return QRPayload(
          pinNumber: securityCode, // Use security code as primary identifier for lookup
          securityCode: securityCode,
          type: QRPayloadType.commaSeparated,
        );
      }
    }

    // Check if it's just a security code (alphanumeric, 6-15 chars, mix of letters and numbers)
    final securityCodePattern = RegExp(r'^[A-Z0-9]{6,15}$');
    if (securityCodePattern.hasMatch(cleanedData) && 
        cleanedData.contains(RegExp(r'[A-Z]')) && 
        cleanedData.contains(RegExp(r'[0-9]'))) {
      return QRPayload(
        pinNumber: cleanedData,
        securityCode: cleanedData,
        type: QRPayloadType.securityCode,
      );
    }

    // Assume it's a plain pin number
    return QRPayload(
      pinNumber: cleanedData,
      type: QRPayloadType.plain,
    );
  }

  bool isValid() {
    return pinNumber.isNotEmpty;
  }

  @override
  String toString() {
    return 'QRPayload(pinNumber: $pinNumber, securityCode: $securityCode, type: $type)';
  }
}

enum QRPayloadType {
  plain,          // Just pin number: "24555A0416"
  json,           // JSON format: {"pinNumber":"24555A0416"}
  commaSeparated, // Security code format: "YTRTSXQL,23551A4611,AWS + GENAI,CSC"
  securityCode,   // Security code based: "23551A05B4" or course info with security code
}

// Validation result for QR scanning
class QRValidationResult {
  final bool isValid;
  final String? studentName;
  final String? pinNumber;
  final bool isDuplicate;
  final String? message;
  final QRValidationStatus status;

  QRValidationResult({
    required this.isValid,
    this.studentName,
    this.pinNumber,
    this.isDuplicate = false,
    this.message,
    required this.status,
  });

  factory QRValidationResult.valid({
    required String studentName,
    required String pinNumber,
    bool isDuplicate = false,
  }) {
    return QRValidationResult(
      isValid: true,
      studentName: studentName,
      pinNumber: pinNumber,
      isDuplicate: isDuplicate,
      status: isDuplicate ? QRValidationStatus.duplicate : QRValidationStatus.valid,
      message: isDuplicate ? 'Attendance already marked - scan time updated' : 'Attendance marked successfully',
    );
  }

  factory QRValidationResult.invalid({
    required String message,
    String? pinNumber,
  }) {
    return QRValidationResult(
      isValid: false,
      pinNumber: pinNumber,
      status: QRValidationStatus.invalid,
      message: message,
    );
  }
  
  // Method to create a copy with a custom message
  QRValidationResult copyWithMessage(String newMessage) {
    return QRValidationResult(
      isValid: this.isValid,
      studentName: this.studentName,
      pinNumber: this.pinNumber,
      isDuplicate: this.isDuplicate,
      status: this.status,
      message: newMessage,
    );
  }
}

enum QRValidationStatus {
  valid,      // Green - Valid scan, marked present
  duplicate,  // Yellow - Already scanned
  invalid,    // Red - Invalid QR or student not found
}