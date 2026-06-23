import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class ComboTestScreen extends StatefulWidget {
  @override
  _ComboTestScreenState createState() => _ComboTestScreenState();
}

class _ComboTestScreenState extends State<ComboTestScreen> {
  bool _isLoading = false;
  String _status = '';
  Map<String, List<String>> _combosWithStudents = {};

  Future<void> _testComboFetch() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing combo fetch...';
      _combosWithStudents = {};
    });

    try {
      // Initialize Firebase service if not already initialized
      final firebaseService = FirebaseService();
      if (!firebaseService.isInitialized) {
        await firebaseService.init();
      }

      // Try to fetch combos for the Skill_Sync01 batch
      final combosMap = await firebaseService.fetchCombosForBatch('Skill_Sync01');

      setState(() {
        _status = 'Found ${combosMap.length} combos';
        _isLoading = false;
        
        // Convert to combo names with student counts for display
        _combosWithStudents = {};
        combosMap.forEach((comboName, students) {
          _combosWithStudents[comboName] = students.map((s) => s.name).toList();
        });
      });

      print('✅ Test completed. Found ${combosMap.length} combos');
      if (_combosWithStudents.isNotEmpty) {
        print('📋 Sample combos: ${_combosWithStudents.keys.take(5).join(', ')}');
        combosMap.forEach((comboName, students) {
          print('   - $comboName: ${students.length} students');
        });
      }
    } catch (e, stackTrace) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      print('❌ Error during test: $e');
      print('📜 Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Combo Test Screen')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testComboFetch,
              child: Text(_isLoading ? 'Testing...' : 'Test Combo Fetch'),
            ),
            SizedBox(height: 16),
            Text(_status, style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            if (_combosWithStudents.isNotEmpty) ...[
              Text('Found ${_combosWithStudents.length} combos:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _combosWithStudents.length,
                  itemBuilder: (context, index) {
                    final comboName = _combosWithStudents.keys.elementAt(index);
                    final students = _combosWithStudents[comboName]!;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(comboName, style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${students.length} students'),
                            SizedBox(height: 4),
                            Text(students.take(3).join(', ') + (students.length > 3 ? '...' : '')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}