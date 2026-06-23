import 'package:flutter/material.dart';
import 'package:cool_dropdown/cool_dropdown.dart';
import 'package:cool_dropdown/models/cool_dropdown_item.dart';
import '../models/class_model.dart';
import '../models/mock_interview.dart';
import '../services/mock_interview_service.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/scanner_widgets.dart';

typedef DropdownItem<T> = CoolDropdownItem<T>;

class MockInterviewFormScreen extends StatefulWidget {
  final ClassModel selectedClass;
  final String rollNumber;
  
  const MockInterviewFormScreen({
    super.key,
    required this.selectedClass,
    required this.rollNumber,
  });

  @override
  State<MockInterviewFormScreen> createState() => _MockInterviewFormScreenState();
}

class _MockInterviewFormScreenState extends State<MockInterviewFormScreen> {
  DateTime _interviewDate = DateTime.now();
  String _studentName = '';
  
  // Text editing controllers
  final TextEditingController _studentNameController = TextEditingController();
  
  // Technical Round metrics (1-5 scale)
  int? _problemSolving;
  int? _technicalKnowledge;
  int? _codingEfficiency;
  int? _systemDesign;
  int? _logicalReasoning;
  
  // HR Round metrics (1-5 scale)
  int? _communication;
  int? _confidence;
  int? _bodyLanguage;
  int? _attitude;
  int? _listening;
  
  // Managerial Round metrics (1-5 scale)
  int? _decisionMaking;
  int? _leadership;
  int? _teamwork;
  int? _stressHandling;
  int? _realScenarioProblemSolving;
  
  // Profile metrics
  String? _gitHub;
  String? _linkedIn;
  int? _resumeScore;
  
  // Coding metrics
  int? _leetCode;
  int? _codeChef; // 1-7 star rating
  String? _geeksForGeeks;
  
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _statusOptions = ['Inactive', 'Active', 'Strong'];
  final List<String> _gfgOptions = ['Beginner', 'Intermediate', 'Contributor', 'Expert'];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavyBlue,
      appBar: AppBar(
        title: const Text('New Mock Interview'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mock Interview Evaluation',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),
            Text(
              'Roll Number: ${widget.rollNumber}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            Text(
              'Class: ${widget.selectedClass.className}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: AppConstants.largePadding),
            
            // Student Information
            _buildStudentInfo(),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Interview Date
            _buildInterviewDate(),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Technical Round Section
            _buildRoundSection(
              title: 'Technical Round (TR)',
              icon: Icons.code,
              color: AppTheme.primaryColor,
              children: [
                _buildRatingSlider('Problem-Solving Ability', _problemSolving, (value) => setState(() => _problemSolving = value)),
                _buildRatingSlider('Technical Knowledge', _technicalKnowledge, (value) => setState(() => _technicalKnowledge = value)),
                _buildRatingSlider('Coding Efficiency', _codingEfficiency, (value) => setState(() => _codingEfficiency = value)),
                _buildRatingSlider('System Design Understanding', _systemDesign, (value) => setState(() => _systemDesign = value)),
                _buildRatingSlider('Logical Reasoning', _logicalReasoning, (value) => setState(() => _logicalReasoning = value)),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // HR Round Section
            _buildRoundSection(
              title: 'HR Round (HR)',
              icon: Icons.people,
              color: AppTheme.successColor,
              children: [
                _buildRatingSlider('Communication Skills', _communication, (value) => setState(() => _communication = value)),
                _buildRatingSlider('Confidence', _confidence, (value) => setState(() => _confidence = value)),
                _buildRatingSlider('Body Language', _bodyLanguage, (value) => setState(() => _bodyLanguage = value)),
                _buildRatingSlider('Attitude', _attitude, (value) => setState(() => _attitude = value)),
                _buildRatingSlider('Listening Skills', _listening, (value) => setState(() => _listening = value)),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Managerial Round Section
            _buildRoundSection(
              title: 'Managerial Round (MR)',
              icon: Icons.leaderboard,
              color: AppTheme.warningColor,
              children: [
                _buildRatingSlider('Decision-Making Ability', _decisionMaking, (value) => setState(() => _decisionMaking = value)),
                _buildRatingSlider('Leadership Quality', _leadership, (value) => setState(() => _leadership = value)),
                _buildRatingSlider('Teamwork/Collaboration', _teamwork, (value) => setState(() => _teamwork = value)),
                _buildRatingSlider('Stress Handling', _stressHandling, (value) => setState(() => _stressHandling = value)),
                _buildRatingSlider('Real-Scenario Problem-Solving', _realScenarioProblemSolving, (value) => setState(() => _realScenarioProblemSolving = value)),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Profile Section
            _buildProfileSection(),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Coding Section
            _buildCodingSection(),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Action Buttons
            _buildActionButtons(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfo() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlueLighter.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Student Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          TextField(
            controller: _studentNameController,
            decoration: const InputDecoration(
              labelText: 'Student Name',
              labelStyle: TextStyle(color: Colors.white70),
              filled: true,
              fillColor: AppTheme.darkNavyBlue,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppConstants.defaultBorderRadius)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) => setState(() => _studentName = value),
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewDate() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlueLighter.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Interview Date',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_interviewDate.day}/${_interviewDate.month}/${_interviewDate.year}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _interviewDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _interviewDate = picked);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoundSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlueLighter.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppConstants.defaultPadding),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRatingSlider(String label, int? value, Function(int?) onChanged) {
    int currentValue = value ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryColor,
                    inactiveTrackColor: AppTheme.darkNavyBlueLighter,
                    thumbColor: AppTheme.primaryColor,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    tickMarkShape: const RoundSliderTickMarkShape(),
                    activeTickMarkColor: AppTheme.primaryColor,
                    inactiveTickMarkColor: AppTheme.darkNavyBlueLighter,
                  ),
                  child: Slider(
                    value: currentValue.toDouble(),
                    min: 0,
                    max: 5,
                    divisions: 5,
                    label: currentValue == 0 ? 'Not Rated' : currentValue.toString(),
                    onChanged: (double newValue) {
                      int intValue = newValue.toInt();
                      if (intValue == 0) {
                        onChanged(null); // Not rated
                      } else {
                        onChanged(intValue);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Display current rating
              Container(
                width: 100,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.darkNavyBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentValue == 0 ? 'Not Rated' : currentValue.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlueLighter.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: AppTheme.primaryColor),
              SizedBox(width: AppConstants.defaultPadding),
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          _buildStatusDropdown('GitHub', _gitHub, (value) => setState(() => _gitHub = value)),
          const SizedBox(height: AppConstants.smallPadding),
          _buildStatusDropdown('LinkedIn', _linkedIn, (value) => setState(() => _linkedIn = value)),
          const SizedBox(height: AppConstants.smallPadding),
          // Resume Score with slider
          _buildSliderInput(
            label: 'Resume Score (0-100)',
            value: _resumeScore?.toDouble() ?? 0,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (value) => setState(() => _resumeScore = value.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderInput({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryColor,
                    inactiveTrackColor: AppTheme.darkNavyBlueLighter,
                    thumbColor: AppTheme.primaryColor,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    tickMarkShape: const RoundSliderTickMarkShape(),
                    activeTickMarkColor: AppTheme.primaryColor,
                    inactiveTickMarkColor: AppTheme.darkNavyBlueLighter,
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    label: value.toInt().toString(),
                    onChanged: onChanged,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Display current value
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.darkNavyBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(String label, String? value, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          CustomDropdown<String?>(
            value: value,
            hintText: 'Select status',
            items: _statusOptions.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCodingSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlueLighter.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.computer, color: AppTheme.primaryColor),
              SizedBox(width: AppConstants.defaultPadding),
              Text(
                'Coding',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          // LeetCode Problems Solved with numeric input
          _buildNumericInput(
            label: 'LeetCode Problems Solved',
            value: _leetCode?.toString() ?? '',
            hintText: 'Enter number of problems solved',
            onChanged: (value) {
              if (value.isEmpty) {
                setState(() => _leetCode = null);
              } else {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() => _leetCode = parsed);
                }
              }
            },
          ),
          const SizedBox(height: AppConstants.smallPadding),
          // CodeChef Rating with slider (1-7 stars)
          _buildStarRatingInput(
            label: 'CodeChef Stars (1-7)',
            value: _codeChef ?? 0,
            onChanged: (value) => setState(() => _codeChef = value),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          _buildGfgDropdown('GeeksforGeeks Status', _geeksForGeeks, (value) => setState(() => _geeksForGeeks = value)),
        ],
      ),
    );
  }

  Widget _buildNumericInput({
    required String label,
    required String value,
    required String hintText,
    required Function(String) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppTheme.darkNavyBlue,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppConstants.defaultBorderRadius)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: value),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStarRatingInput({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryColor,
                    inactiveTrackColor: AppTheme.darkNavyBlueLighter,
                    thumbColor: AppTheme.primaryColor,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    tickMarkShape: const RoundSliderTickMarkShape(),
                    activeTickMarkColor: AppTheme.primaryColor,
                    inactiveTickMarkColor: AppTheme.darkNavyBlueLighter,
                  ),
                  child: Slider(
                    value: value.toDouble(),
                    min: 0,
                    max: 7,
                    divisions: 7,
                    label: value == 0 ? 'Not Rated' : '$value Stars',
                    onChanged: (double newValue) {
                      int intValue = newValue.toInt();
                      onChanged(intValue);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Display current rating
              Container(
                width: 100,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.darkNavyBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value == 0 ? 'Not Rated' : '$value Stars',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGfgDropdown(String label, String? value, Function(String?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          CustomDropdown<String?>(
            value: value,
            hintText: 'Select status',
            items: _gfgOptions.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GradientButton(
            isEnabled: !_isLoading,
            onPressed: _isLoading ? () {} : _saveMockInterview,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.darkNavyBlue),
                    ),
                  )
                : const Text(
                    'Save Interview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.buttonTextColor,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveMockInterview() async {
    print('=== STARTING MOCK INTERVIEW SAVE PROCESS IN UI ===');
    
    if (_studentName.isEmpty) {
      print('❌ ERROR: Student name is empty');
      setState(() => _errorMessage = 'Please enter a student name');
      return;
    }
    
    // Validate that at least one rating is selected
    bool hasAnyRating = 
        _problemSolving != null || 
        _technicalKnowledge != null || 
        _codingEfficiency != null || 
        _systemDesign != null || 
        _logicalReasoning != null ||
        _communication != null ||
        _confidence != null ||
        _bodyLanguage != null ||
        _attitude != null ||
        _listening != null ||
        _decisionMaking != null ||
        _leadership != null ||
        _teamwork != null ||
        _stressHandling != null ||
        _realScenarioProblemSolving != null;
        
    if (!hasAnyRating) {
      print('❌ ERROR: No ratings provided');
      setState(() => _errorMessage = 'Please provide at least one evaluation rating');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      print('Creating MockInterview object...');
      final mockInterview = MockInterview(
        id: '${widget.selectedClass.id}_${widget.rollNumber}_${DateTime.now().millisecondsSinceEpoch}',
        studentPinNumber: widget.rollNumber,
        studentName: _studentName,
        interviewDate: _interviewDate,
        tr: MockInterviewRound(
          problemSolving: _problemSolving?.toString(),
          technicalKnowledge: _technicalKnowledge?.toString(),
          codingEfficiency: _codingEfficiency?.toString(),
          systemDesign: _systemDesign?.toString(),
          logicalReasoning: _logicalReasoning?.toString(),
        ),
        hr: MockInterviewRound(
          communication: _communication?.toString(),
          confidence: _confidence?.toString(),
          bodyLanguage: _bodyLanguage?.toString(),
          attitude: _attitude?.toString(),
          listening: _listening?.toString(),
        ),
        mr: MockInterviewRound(
          decisionMaking: _decisionMaking?.toString(),
          leadership: _leadership?.toString(),
          teamwork: _teamwork?.toString(),
          stressHandling: _stressHandling?.toString(),
          realScenarioProblemSolving: _realScenarioProblemSolving?.toString(),
        ),
        profile: MockInterviewProfile(
          gitHub: _gitHub,
          linkedIn: _linkedIn,
          resumeScore: _resumeScore,
        ),
        coding: MockInterviewCoding(
          leetCode: _leetCode,
          codeChef: _codeChef,
          geeksForGeeks: _geeksForGeeks,
        ),
      );
      
      print('Mock Interview Created:');
      print('  ID: ${mockInterview.id}');
      print('  Student Pin Number: ${mockInterview.studentPinNumber}');
      print('  Student Name: ${mockInterview.studentName}');
      print('  Interview Date: ${mockInterview.interviewDate}');
      print('  Selected Class: ${widget.selectedClass.className}');
      print('  Class Sheet Name: ${widget.selectedClass.sheetName}');
      print('  Class Google Sheet URL: ${widget.selectedClass.googleSheetUrl}');
      
      print('Calling MockInterviewService.saveMockInterview...');
      final success = await MockInterviewService.saveMockInterview(
        classModel: widget.selectedClass,
        mockInterview: mockInterview,
      );
      
      print('MockInterviewService returned: $success');
      
      if (success) {
        print('✅ SUCCESS: Mock interview saved successfully');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mock interview saved successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          
          // Go back to history screen
          Navigator.of(context).pop(true); // Return true to indicate successful save
        }
      } else {
        print('❌ ERROR: Failed to save mock interview');
        String errorMessage = 'Failed to save mock interview. ';
        errorMessage += 'Please check that:\n';
        errorMessage += '1. The selected class "${widget.selectedClass.className}" exists in your control sheet\n';
        errorMessage += '2. The class has a mock interview sheet URL configured\n';
        errorMessage += '3. The student PIN number is correct and exists in the master sheet\n';
        errorMessage += '4. Check the debug logs for more details';
        setState(() => _errorMessage = errorMessage);
      }
    } catch (e, stackTrace) {
      print('💥 ERROR saving mock interview: $e');
      print('📜 Stack trace: $stackTrace');
      setState(() => _errorMessage = 'Error saving mock interview: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}