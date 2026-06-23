import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'services/control_sheet_service.dart';
import 'services/firebase_config_service.dart';
import 'widgets/scanner_widgets.dart';
import 'constants/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comprehensive Sheet Diagnostic',
      home: Scaffold(
        appBar: AppBar(title: const Text('Comprehensive Sheet Diagnostic')),
        body: const ComprehensiveSheetDiagnostic(),
      ),
    );
  }
}

class ComprehensiveSheetDiagnostic extends StatefulWidget {
  const ComprehensiveSheetDiagnostic({super.key});

  @override
  State<ComprehensiveSheetDiagnostic> createState() => _ComprehensiveSheetDiagnosticState();
}

class _ComprehensiveSheetDiagnosticState extends State<ComprehensiveSheetDiagnostic> {
  bool _isLoading = false;
  String _result = '';

  Future<void> _runComprehensiveDiagnostic() async {
      _appendResult('Step 7: Retrieving spreadsheet metadata...\n');
      try {
        final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
        _appendResult('✅ Successfully accessed Google Sheet\n');
        _appendResult('Spreadsheet title: "${spreadsheet.properties?.title}"\n');
        _appendResult('Spreadsheet ID: ${spreadsheet.spreadsheetId}\n');
        _appendResult('Sheet count: ${spreadsheet.sheets?.length ?? 0}\n\n');
        
        // List all sheet names
        if (spreadsheet.sheets != null) {
          _appendResult('Available sheets:\n');
          for (int i = 0; i < spreadsheet.sheets!.length; i++) {
            final sheet = spreadsheet.sheets![i];
            _appendResult('  ${i + 1}. "${sheet.properties?.title}" (ID: ${sheet.properties?.sheetId})\n');
          }
          _appendResult('\n');
        }
      } catch (e) {
        _appendResult('❌ ERROR: Failed to access spreadsheet: $e\n\n');
        client.close();
        _finishLoading();
        return;
      }
      
      // Step 8: Check for Login_Credentials sheet
      _appendResult('Step 8: Checking for Login_Credentials sheet...\n');
      bool loginCredentialsSheetExists = false;
      String? loginCredentialsSheetTitle;
      
      // Get spreadsheet again to check sheets
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      if (spreadsheet.sheets != null) {
        for (final sheet in spreadsheet.sheets!) {
          if (sheet.properties?.title == 'Login_Credentials') {
            loginCredentialsSheetExists = true;
            loginCredentialsSheetTitle = sheet.properties?.title;
            break;
          }
        }
      }
      
      if (loginCredentialsSheetExists) {
        _appendResult('✅ Login_Credentials sheet found\n');
        
        // Step 9: Try to read Login_Credentials sheet
        _appendResult('Step 9: Reading Login_Credentials sheet...\n');
        try {
          final response = await sheetsApi.spreadsheets.values.get(
            spreadsheetId,
            'Login_Credentials!A:C', // Read the first three columns
          );
          
          final values = response.values ?? [];
          _appendResult('✅ Successfully read Login_Credentials sheet\n');
          _appendResult('Rows found: ${values.length}\n');
          
          if (values.isNotEmpty) {
            _appendResult('Header row: ${values[0]}\n');
            
            if (values.length > 1) {
              _appendResult('Sample data rows:\n');
              for (int i = 1; i < values.length && i <= 3; i++) {
                _appendResult('  Row $i: ${values[i]}\n');
              }
            }
          }
        } catch (e) {
          _appendResult('❌ ERROR: Failed to read Login_Credentials sheet: $e\n\n');
        }
      } else {
        _appendResult('❌ Login_Credentials sheet NOT found\n');
        _appendResult('Please ensure your Google Sheet contains a sheet named exactly "Login_Credentials"\n\n');
      }
      
      // Close client
      client.close();
      _finishLoading();
      
    } catch (e, stackTrace) {
      _appendResult('❌ UNEXPECTED ERROR: $e\n');
      _appendResult('Stack trace: $stackTrace\n\n');
      _finishLoading();
    }
  }
  
  void _appendResult(String text) {
    setState(() {
      _result += text;
    });
  }
  
  void _finishLoading() {
    setState(() {
      _isLoading = false;
      _result += '\n=== DIAGNOSTIC COMPLETE ===\n';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientButton(
            isEnabled: !_isLoading,
            onPressed: _isLoading ? () {} : _runComprehensiveDiagnostic,
            child: _isLoading
                ? const CircularProgressIndicator()
                : Text('Run Comprehensive Diagnostic', style: TextStyle(color: AppTheme.buttonTextColor)),
          ),
          const SizedBox(height: 20),
          const Text(
            'This diagnostic will check:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text('1. Secrets configuration'),
          const Text('2. Service account credentials'),
          const Text('3. Google Sheets API authentication'),
          const Text('4. Spreadsheet access'),
          const Text('5. Login_Credentials sheet existence'),
          const Text('6. Login_Credentials sheet data'),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Text(_result),
            ),
          ),
        ],
      ),
    );
  }
}