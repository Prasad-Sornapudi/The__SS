import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../models/class_model.dart';
import '../models/mock_interview.dart';
import '../services/mock_interview_service.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/scanner_widgets.dart';

class MockInterviewScreen extends StatefulWidget {
  final ClassModel? initialClass;
  final String? initialRollNumber;
  final bool startInHistoryMode;
  
  const MockInterviewScreen({super.key, this.initialClass, this.initialRollNumber, this.startInHistoryMode = false});

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  ClassModel? _selectedClass;
  String _rollNumber = '';
  String _studentName = '';
  DateTime _interviewDate = DateTime.now();
  
  // Text editing controllers
  final TextEditingController _rollNumberController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  
  // Technical Round metrics
  String? _problemSolving;
  String? _technicalKnowledge;
  String? _codingEfficiency;
  String? _systemDesign;
  String? _logicalReasoning;
  
  // HR Round metrics
  String? _communication;
  String? _confidence;
  String? _bodyLanguage;
  String? _attitude;
  String? _listening;
  
  // Managerial Round metrics
  String? _decisionMaking;
  String? _leadership;
  String? _teamwork;
  String? _stressHandling;
  String? _realScenarioProblemSolving;
  
  // Profile metrics
  String? _gitHub;
  String? _linkedIn;
  int? _resumeScore;
  
  // Coding metrics
  int? _leetCode;
  int? _codeChef;
  String? _geeksForGeeks;
  
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _historicalData = [];
  bool _showHistory = false;

  final List<String> _statusOptions = ['Inactive', 'Active', 'Strong'];
  final List<String> _gfgOptions = ['Beginner', 'Intermediate', 'Contributor', 'Expert'];

  @override
  void initState() {
    super.initState();
    // Set initial class if provided
    if (widget.initialClass != null) {
      _selectedClass = widget.initialClass;
    }
    
    // Set initial roll number if provided
    if (widget.initialRollNumber != null) {
      _rollNumber = widget.initialRollNumber!;
      _rollNumberController.text = _rollNumber;
    }
    
    // If starting in history mode, fetch historical data
    if (widget.startInHistoryMode && widget.initialClass != null && widget.initialRollNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchHistoricalData();
      });
    }
  }

  @override
  void dispose() {
    _rollNumberController.dispose();
    _studentNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavyBlue,
      appBar: AppBar(
        title: const Text('Mock Interview'),
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
            const SizedBox(height: AppConstants.defaultPadding),
            const Text(
              'Evaluate student performance across Technical, HR, and Managerial rounds',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: AppConstants.largePadding),
            
            // Class Selection
            _buildClassSelection(),
            const SizedBox(height: AppConstants.defaultPadding),
            
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
                _buildRatingDropdown('Problem-Solving Ability', _problemSolving, (value) => setState(() => _problemSolving = value)),
                _buildRatingDropdown('Technical Knowledge', _technicalKnowledge, (value) => setState(() => _technicalKnowledge = value)),
                _buildRatingDropdown('Coding Efficiency', _codingEfficiency, (value) => setState(() => _codingEfficiency = value)),
                _buildRatingDropdown('System Design Understanding', _systemDesign, (value) => setState(() => _systemDesign = value)),
                _buildRatingDropdown('Logical Reasoning', _logicalReasoning, (value) => setState(() => _logicalReasoning = value)),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // HR Round Section
            _buildRoundSection(
              title: 'HR Round (HR)',
              icon: Icons.people,
              color: AppTheme.successColor,
              children: [
                _buildRatingDropdown('Communication Skills', _communication, (value) => setState(() => _communication = value)),
                _buildRatingDropdown('Confidence', _confidence, (value) => setState(() => _confidence = value)),
                _buildRatingDropdown('Body Language', _bodyLanguage, (value) => setState(() => _bodyLanguage = value)),
                _buildRatingDropdown('Attitude', _attitude, (value) => setState(() => _attitude = value)),
                _buildRatingDropdown('Listening Skills', _listening, (value) => setState(() => _listening = value)),
              ],
            ),
            const SizedBox(height: AppConstants.defaultPadding),
            
            // Managerial Round Section
            _buildRoundSection(
              title: 'Managerial Round (MR)',
              icon: Icons.leaderboard,
              color: AppTheme.warningColor,
              children: [
                _buildRatingDropdown('Decision-Making Ability', _decisionMaking, (value) => setState(() => _decisionMaking = value)),
                _buildRatingDropdown('Leadership Quality', _leadership, (value) => setState(() => _leadership = value)),
                _buildRatingDropdown('Teamwork/Collaboration', _teamwork, (value) => setState(() => _teamwork = value)),
                _buildRatingDropdown('Stress Handling', _stressHandling, (value) => setState(() => _stressHandling = value)),
                _buildRatingDropdown('Real-Scenario Problem-Solving', _realScenarioProblemSolving, (value) => setState(() => _realScenarioProblemSolving = value)),
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
            
            // Historical Data Section
            _buildHistoricalDataSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSelection() {
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
            'Select Class',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          Consumer<ClassProvider>(
            builder: (context, classProvider, child) {
              print('📋 Available classes in dropdown: ${classProvider.classes.length}');
              for (final classModel in classProvider.classes) {
                print('  - ${classModel.className} (ID: ${classModel.id})');
              }
              
              if (classProvider.classes.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  decoration: BoxDecoration(
                    color: AppTheme.darkNavyBlue,
                    borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
                  ),
                  child: const Text(
                    'No classes available. Please refresh class data.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              
              return CustomDropdown<ClassModel?>(
                    hintText: 'Select a class',
                    value: _selectedClass,
                    items: classProvider.classes.map((classModel) {
                      return DropdownMenuItem<ClassModel>(
                        value: classModel,
                        child: Text(
                            classModel.className,
                            overflow: TextOverflow.ellipsis,
                          ),
                      );
                    }).toList(),
                    onChanged: (ClassModel? selectedClass) {
                      print('📋 User selected class: ${selectedClass?.className ?? "None"}');
                      setState(() {
                        _selectedClass = selectedClass;
                      });
                    },
                  );
            },
          ),
        ],
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
            controller: _rollNumberController,
            decoration: const InputDecoration(
              labelText: 'Roll Number',
              labelStyle: TextStyle(color: Colors.white70),
              filled: true,
              fillColor: AppTheme.darkNavyBlue,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppConstants.defaultBorderRadius)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() => _rollNumber = value);
            },
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

  Widget _buildRatingDropdown(String label, String? value, Function(String?) onChanged) {
    // Convert string value to int for slider
    int currentValue = 0;
    if (value != null && value.isNotEmpty) {
      currentValue = int.tryParse(value) ?? 0;
    }

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
                      String stringValue = intValue.toString();
                      if (intValue == 0) {
                        onChanged(null); // Not rated
                      } else {
                        onChanged(stringValue);
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
              return DropdownMenuItem<String>(
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
              return DropdownMenuItem<String>(
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          flex: 1,
          child: GradientButton(
            isEnabled: !_isLoading,
            onPressed: _isLoading ? () {} : _fetchHistoricalData,
            child: const Text(
              'View History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.buttonTextColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppConstants.defaultPadding),
        Expanded(
          flex: 1,
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
                    'Start New Mock',
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

  Widget _buildHistoricalDataSection() {
    if (!_showHistory || _historicalData.isEmpty) {
      return const SizedBox.shrink();
    }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historical Mock Interviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: GradientButton(
                  onPressed: () {
                    setState(() {
                      _showHistory = false;
                      // Clear historical data when switching to new interview mode
                      _historicalData = [];
                    });
                  },
                  child: const Text(
                    'Take New Interview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.buttonTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          for (int i = 0; i < _historicalData.length; i++) ...[
            _buildHistoricalInterviewCard(_historicalData[i]),
            if (i < _historicalData.length - 1) const SizedBox(height: AppConstants.defaultPadding),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoricalInterviewCard(Map<String, dynamic> data) {
    final date = data['date'] as String? ?? 'Unknown Date';
    
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkNavyBlue,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          _buildHistoricalMetrics('Technical Round', data['TR'] as Map<String, dynamic>?),
          const SizedBox(height: AppConstants.smallPadding),
          _buildHistoricalMetrics('HR Round', data['HR'] as Map<String, dynamic>?),
          const SizedBox(height: AppConstants.smallPadding),
          _buildHistoricalMetrics('Managerial Round', data['MR'] as Map<String, dynamic>?),
          const SizedBox(height: AppConstants.smallPadding),
          _buildHistoricalProfile(data['Profile'] as Map<String, dynamic>?),
          const SizedBox(height: AppConstants.smallPadding),
          _buildHistoricalCoding(data['Coding'] as Map<String, dynamic>?),
        ],
      ),
    );
  }

  Widget _buildHistoricalMetrics(String title, Map<String, dynamic>? metrics) {
    if (metrics == null || metrics.isEmpty) return const SizedBox.shrink();
    
    // Filter out null or empty values
    final nonNullMetrics = <String, dynamic>{};
    metrics.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        nonNullMetrics[key] = value;
      }
    });
    
    if (nonNullMetrics.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        for (final entry in nonNullMetrics.entries) ...[
          Row(
            children: [
              SizedBox(
                width: 180,
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
              Text(
                entry.value.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHistoricalProfile(Map<String, dynamic>? profile) {
    if (profile == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        if (profile['GitHub'] != null)
          Text('GitHub: ${profile['GitHub']}', style: const TextStyle(fontSize: 12, color: Colors.white)),
        if (profile['LinkedIn'] != null)
          Text('LinkedIn: ${profile['LinkedIn']}', style: const TextStyle(fontSize: 12, color: Colors.white)),
        if (profile['Resume'] != null)
          Text('Resume Score: ${profile['Resume']}', style: const TextStyle(fontSize: 12, color: Colors.white)),
      ],
    );
  }

  Widget _buildHistoricalCoding(Map<String, dynamic>? coding) {
    if (coding == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Coding',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        if (coding['LeetCode'] != null)
          Text('LeetCode: ${coding['LeetCode']}', style: const TextStyle(fontSize: 12, color: Colors.white)),
        if (coding['CodeChef'] != null)
          Text('CodeChef: ${coding['CodeChef']}', style: const TextStyle(fontSize: 12, color: Colors.white)),
        if (coding['GeeksforGeeks'] != null)
          Text('GeeksforGeeks: ${coding['GeeksforGeeks']}', style: const TextStyle(fontSize: 12, color: Colors.white)),
      ],
    );
  }

  Future<void> _saveMockInterview() async {
    print('=== STARTING MOCK INTERVIEW SAVE PROCESS IN UI ===');
    
    if (_selectedClass == null) {
      print('❌ ERROR: No class selected');
      setState(() => _errorMessage = 'Please select a class');
      return;
    }
    
    print('📋 Selected class details:');
    print('  Class Name: ${_selectedClass!.className}');
    print('  Class ID: ${_selectedClass!.id}');
    print('  Sheet Name: ${_selectedClass!.sheetName}');
    print('  Google Sheet URL: ${_selectedClass!.googleSheetUrl}');
    
    if (_rollNumber.isEmpty) {
      print('❌ ERROR: Roll number is empty');
      setState(() => _errorMessage = 'Please enter a roll number');
      return;
    }
    
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
        id: '${_selectedClass!.id}_${_rollNumber}_${DateTime.now().millisecondsSinceEpoch}',
        studentPinNumber: _rollNumber,
        studentName: _studentName,
        interviewDate: _interviewDate,
        tr: MockInterviewRound(
          problemSolving: _problemSolving,
          technicalKnowledge: _technicalKnowledge,
          codingEfficiency: _codingEfficiency,
          systemDesign: _systemDesign,
          logicalReasoning: _logicalReasoning,
        ),
        hr: MockInterviewRound(
          communication: _communication,
          confidence: _confidence,
          bodyLanguage: _bodyLanguage,
          attitude: _attitude,
          listening: _listening,
        ),
        mr: MockInterviewRound(
          decisionMaking: _decisionMaking,
          leadership: _leadership,
          teamwork: _teamwork,
          stressHandling: _stressHandling,
          realScenarioProblemSolving: _realScenarioProblemSolving,
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
      print('  Selected Class: ${_selectedClass!.className}');
      print('  Class Sheet Name: ${_selectedClass!.sheetName}');
      print('  Class Google Sheet URL: ${_selectedClass!.googleSheetUrl}');
      
      print('Calling MockInterviewService.saveMockInterview...');
      final success = await MockInterviewService.saveMockInterview(
        classModel: _selectedClass!,
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
          
          // Clear form
          setState(() {
            _rollNumber = '';
            _studentName = '';
            _problemSolving = null;
            _technicalKnowledge = null;
            _codingEfficiency = null;
            _systemDesign = null;
            _logicalReasoning = null;
            _communication = null;
            _confidence = null;
            _bodyLanguage = null;
            _attitude = null;
            _listening = null;
            _decisionMaking = null;
            _leadership = null;
            _teamwork = null;
            _stressHandling = null;
            _realScenarioProblemSolving = null;
            _gitHub = null;
            _linkedIn = null;
            _resumeScore = null;
            _leetCode = null;
            _codeChef = null;
            _geeksForGeeks = null;
          });
        }
      } else {
        print('❌ ERROR: Failed to save mock interview');
        String errorMessage = 'Failed to save mock interview. ';
        errorMessage += 'Please check that:\n';
        errorMessage += '1. The selected class "${_selectedClass!.className}" exists in your control sheet\n';
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

  Future<void> _fetchHistoricalData() async {
    if (_selectedClass == null) {
      setState(() => _errorMessage = 'Please select a class');
      return;
    }
    
    if (_rollNumber.isEmpty) {
      setState(() => _errorMessage = 'Please enter a roll number');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final data = await MockInterviewService.fetchMockInterviewDataByRollNumber(
        classModel: _selectedClass!,
        rollNumber: _rollNumber,
      );
      
      setState(() {
        _historicalData = data;
        _showHistory = true;
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
}