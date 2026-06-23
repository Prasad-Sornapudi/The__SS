import 'package:flutter/material.dart';
import '../services/sheet_diagnostic_service.dart';
import '../constants/theme.dart';
import '../widgets/scanner_widgets.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({Key? key}) : super(key: key);

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  bool _isRunning = false;
  SheetDiagnosticResult? _result;
  List<String> _logMessages = [];

  void _addLogMessage(String message) {
    setState(() {
      _logMessages.add(message);
    });
  }

  Future<void> _runDiagnostic() async {
    setState(() {
      _isRunning = true;
      _result = null;
      _logMessages = [];
    });

    _addLogMessage('Starting diagnostic...');
    
    try {
      final result = await SheetDiagnosticService.runControlSheetDiagnostic();
      
      setState(() {
        _result = result;
        _isRunning = false;
      });
      
      _addLogMessage(result.message);
      _addLogMessage(result.details);
      
    } catch (e) {
      setState(() {
        _isRunning = false;
      });
      
      _addLogMessage('❌ Diagnostic failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040C1B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF040C1B),
        title: const Text('Sheet Access Diagnostic'),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Sheet Access Diagnostic',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This tool will help diagnose issues with accessing your Google Sheet.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            
            // Run Diagnostic Button
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                onPressed: _isRunning ? () {} : _runDiagnostic,
                isEnabled: !_isRunning,
                child: _isRunning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Running Diagnostic...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.buttonTextColor,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Run Diagnostic',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.buttonTextColor,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Results Section
            if (_result != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _result!.success ? AppTheme.successColor : AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _result!.success ? Icons.check_circle : Icons.error,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _result!.success ? 'Diagnostic Passed' : 'Diagnostic Failed',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _result!.message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result!.details,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Log Messages
            const Text(
              'Diagnostic Log:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.glassBackground.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _logMessages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _logMessages[index],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}