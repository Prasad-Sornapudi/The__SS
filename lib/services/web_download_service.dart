import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class WebDownloadService {
  /// Downloads content as a file on Web.
  /// Does nothing on mobile.
  static Future<void> downloadFile({
    required String fileName,
    required String content,
    String mimeType = 'text/csv',
  }) async {
    if (!kIsWeb) return;

    try {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
        
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Error downloading file on web: $e');
      rethrow;
    }
  }

  /// Downloads binary data as a file on Web
  static Future<void> downloadBytes({
    required String fileName,
    required List<int> bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    if (!kIsWeb) return;

    try {
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
        
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint('Error downloading bytes on web: $e');
      rethrow;
    }
  }
}
