import 'package:flutter/material.dart';
import '../models/attendance_record.dart';
import '../models/class_model.dart';

class PendingRecordsView extends StatelessWidget {
  final List<AttendanceRecord> records;
  final ClassModel classModel;

  const PendingRecordsView({
    Key? key,
    required this.records,
    required this.classModel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pending Records - ${classModel.className}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Attendance Records',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Total records: ${records.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return Card(
                    child: ListTile(
                      title: Text(record.studentName),
                      subtitle: Text(
                        '${record.studentPinNumber} - ${record.status.name} - ${record.displayTime}',
                      ),
                      trailing: Icon(
                        record.status == AttendanceStatus.present
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: record.status == AttendanceStatus.present
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}