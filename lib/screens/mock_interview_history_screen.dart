import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/mock_interview.dart';
import '../services/mock_interview_service.dart';
import '../screens/mock_interview_form_screen.dart';
import '../screens/mock_interview_detail_screen.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/scanner_widgets.dart';

class MockInterviewHistoryScreen extends StatefulWidget {
  final ClassModel selectedClass;
  final String rollNumber;
  
  const MockInterviewHistoryScreen({
    super.key,
    required this.selectedClass,
    required this.rollNumber,
  });

  @override
  State<MockInterviewHistoryScreen> createState() => _MockInterviewHistoryScreenState();
}

class _MockInterviewHistoryScreenState extends State<MockInterviewHistoryScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String? _studentName;
  List<Map<String, dynamic>> _historicalData = [];

  @override
  void initState() {
    super.initState();
    _fetchHistoricalData();
  }

  Future<void> _fetchHistoricalData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch both historical data and student name
      final data = await MockInterviewService.fetchMockInterviewDataByRollNumber(
        classModel: widget.selectedClass,
        rollNumber: widget.rollNumber,
      );
      
      setState(() {
        _historicalData = data;
        
        // Extract student name from the first record if available
        if (data.isNotEmpty && data.first.containsKey('studentName')) {
          _studentName = data.first['studentName'] as String?;
        }
      });
      
      if (data.isEmpty) {
        setState(() => _errorMessage = 'No historical data found for this roll number');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error fetching historical data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getStudentName() async {
    // Return the student name if we have it, otherwise use a default
    return _studentName ?? 'Student';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavyBlue,
      appBar: AppBar(
        title: const Text('Mock Interview History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Dashboard Styling
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: AppTheme.glassCard(
                borderRadius: AppConstants.defaultBorderRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_circle,
                        color: AppTheme.primaryColor,
                        size: 32,
                      ),
                      const SizedBox(width: AppConstants.smallPadding),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String>(
                              future: _getStudentName(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text(
                                    snapshot.data!,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                } else {
                                  return const Text(
                                    'Loading...',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Roll: ${widget.rollNumber}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.selectedClass.className,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Action Button with Enhanced Styling
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: GradientButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MockInterviewFormScreen(
                        selectedClass: widget.selectedClass,
                        rollNumber: widget.rollNumber,
                      ),
                    ),
                  );
                  
                  // If a new interview was saved, refresh the history
                  if (result == true) {
                    _fetchHistoricalData();
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppTheme.buttonTextColor),
                    SizedBox(width: 8),
                    Text(
                      'Take New Interview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.buttonTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                  border: Border.all(color: AppTheme.errorColor),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
            ],
            
            // Loading Indicator
            if (_isLoading) ...[
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
            ],
            
            // Historical Data Section - Only show dates
            if (!_isLoading && _historicalData.isNotEmpty) ...[
              const Text(
                'Previous Interviews',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              for (int i = 0; i < _historicalData.length; i++) ...[
                _buildDateCard(_historicalData[i]),
                if (i < _historicalData.length - 1) const SizedBox(height: AppConstants.defaultPadding),
              ],
            ] else if (!_isLoading && _historicalData.isEmpty && _errorMessage == null) ...[
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: AppTheme.glassCard(
                  borderRadius: AppConstants.defaultBorderRadius,
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(height: AppConstants.defaultPadding),
                    Text(
                      'No previous interviews found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: AppConstants.smallPadding),
                    Text(
                      'Take your first mock interview to get started',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard(Map<String, dynamic> data) {
    final date = data['date'] as String? ?? 'Unknown Date';
    
    return GestureDetector(
      onTap: () async {
        // Navigate to detail screen when date is clicked
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MockInterviewDetailScreen(
              selectedClass: widget.selectedClass,
              rollNumber: widget.rollNumber,
              studentName: _studentName ?? 'Student',
              interviewData: data,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        decoration: AppTheme.glassCard(
          borderRadius: AppConstants.defaultBorderRadius,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: AppConstants.smallPadding),
            Text(
              date,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.primaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
