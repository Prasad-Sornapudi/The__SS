import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/class_provider.dart';
import '../models/class_model.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import '../screens/mock_interview_history_screen.dart';

class ClassDetailsCard extends StatefulWidget {
  final String classId; // Store class ID instead of the full ClassModel
  final Function(String) onStudentSelected;
  final Function(Student, bool) onEditStudent;
  final bool isAdmin;

  const ClassDetailsCard({
    super.key,
    required this.classId,
    required this.onStudentSelected,
    required this.onEditStudent,
    required this.isAdmin,
  });

  @override
  State<ClassDetailsCard> createState() => _ClassDetailsCardState();
}

class _ClassDetailsCardState extends State<ClassDetailsCard> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Student> _getFilteredStudents(ClassModel classModel) {
    if (_searchQuery.isEmpty) {
      return classModel.students;
    }

    final query = _searchQuery.toLowerCase();
    return classModel.students.where((student) {
      return student.name.toLowerCase().contains(query) ||
          student.pinNumber.toLowerCase().contains(query) ||
          student.branch.toLowerCase().contains(query) ||
          student.combo.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    return Consumer<ClassProvider>(
      builder: (context, classProvider, child) {
        // Get the latest class model from the provider
        final classModel = classProvider.getClassById(widget.classId);
        
        // If class model is not found, show a loading state instead of error
        if (classModel == null) {
          // Show loading indicator if class provider is currently refreshing
          if (classProvider.isRefreshing) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              decoration: AppTheme.glassCard(
                borderRadius: AppConstants.defaultBorderRadius,
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: AppConstants.smallPadding),
                    Text(
                      'Refreshing class data...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // If not refreshing, try to get the active class as fallback
          final activeClass = classProvider.activeClass;
          if (activeClass != null) {
            // Use the active class as fallback
            final filteredStudents = _getFilteredStudents(activeClass);
            return _buildClassDetailsContent(activeClass, filteredStudents, userProvider);
          }
          
          // If no active class and not refreshing, show error
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: AppTheme.glassCard(
              borderRadius: AppConstants.defaultBorderRadius,
            ),
            child: const Center(
              child: Text(
                'Class not found',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        
        final filteredStudents = _getFilteredStudents(classModel);
        return _buildClassDetailsContent(classModel, filteredStudents, userProvider);
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentItem(BuildContext context, Student student, bool isAdmin) {
    return GestureDetector(
      onTap: () {
        // Call the onStudentSelected callback with the student's pin number
        widget.onStudentSelected(student.pinNumber);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
        padding: const EdgeInsets.all(AppConstants.smallPadding),
        decoration: BoxDecoration(
          color: AppTheme.darkNavyBlue.withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppConstants.smallPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${student.pinNumber} • ${student.branch}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                onPressed: () => widget.onEditStudent(student, isAdmin),
              ),

          ],
        ),
      ),
    );
  }

  Widget _buildClassDetailsContent(ClassModel classModel, List<Student> filteredStudents, UserProvider userProvider) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.glassCard(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppConstants.defaultBorderRadius),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.school,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: AppConstants.smallPadding),
                const Text(
                  'Class Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    classModel.className,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkNavyBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          // Class Information
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Total Students', classModel.students.length.toString()),
                const SizedBox(height: AppConstants.smallPadding),
                _buildInfoRow('Sheet Name', classModel.sheetName ?? 'Not specified'),
                const SizedBox(height: AppConstants.smallPadding),
                // _buildInfoRow('Upload Type', classModel.uploadType.displayName), // Removed - using Firebase real-time sync
                // _buildInfoRow('Batch Size', classModel.uploadBatchSize.toString()), // Removed - field doesn't exist
              ],

            ),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          // Search Bar
          Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or roll number...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: Icon(
                          Icons.clear,
                          color: Colors.white.withOpacity(0.7),
                          size: 20,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.darkNavyBlue.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          // Student List
          Container(
            height: 300,
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
            child: filteredStudents.isEmpty
                ? const Center(
                    child: Text(
                      'No students found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];
                      return _buildStudentItem(context, student, userProvider.isAdmin);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}