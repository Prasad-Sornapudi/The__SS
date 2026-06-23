import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class ComboTestWidget extends StatefulWidget {
  final String batchId;
  
  const ComboTestWidget({Key? key, required this.batchId}) : super(key: key);

  @override
  _ComboTestWidgetState createState() => _ComboTestWidgetState();
}

class _ComboTestWidgetState extends State<ComboTestWidget> {
  bool _isLoading = false;
  String _status = '';
  Map<String, int> _comboCounts = {};

  Future<void> _testComboFetch() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing combo fetch...';
      _comboCounts = {};
    });

    try {
      // Initialize Firebase service if not already initialized
      final firebaseService = FirebaseService();
      if (!firebaseService.isInitialized) {
        await firebaseService.init();
      }

      // Try to fetch combos for the specified batch
      final combosMap = await firebaseService.fetchCombosForBatch(widget.batchId);

      setState(() {
        _status = 'Found ${combosMap.length} combos';
        _isLoading = false;
        
        // Count students in each combo
        _comboCounts = {};
        combosMap.forEach((comboName, students) {
          _comboCounts[comboName] = students.length;
        });
      });

      print('✅ Combo test completed for batch "${widget.batchId}". Found ${combosMap.length} combos');
      if (_comboCounts.isNotEmpty) {
        print('📋 Combos: $_comboCounts');
      }
    } catch (e, stackTrace) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      print('❌ Error during combo test: $e');
      print('📜 Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Combo Test for Batch: ${widget.batchId}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testComboFetch,
              child: Text(_isLoading ? 'Testing...' : 'Test Combo Fetch'),
            ),
            const SizedBox(height: 8),
            Text(_status),
            const SizedBox(height: 8),
            if (_comboCounts.isNotEmpty) ...[
              Text('Results:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              ..._comboCounts.entries.map((entry) => 
                Text('${entry.key}: ${entry.value} students')
              ).toList(),
            ],
          ],
        ),
      ),
    );
  }
}