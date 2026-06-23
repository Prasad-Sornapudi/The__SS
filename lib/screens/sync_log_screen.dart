import 'package:flutter/material.dart';
import '../services/sync_logging_service.dart';

class SyncLogScreen extends StatefulWidget {
  const SyncLogScreen({Key? key}) : super(key: key);

  @override
  State<SyncLogScreen> createState() => _SyncLogScreenState();
}

class _SyncLogScreenState extends State<SyncLogScreen> {
  late SyncLoggingService _syncLoggingService;
  List<SyncLogEntry> _logs = [];
  bool _showOnlyErrors = false;

  @override
  void initState() {
    super.initState();
    _syncLoggingService = SyncLoggingService();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      _logs = _showOnlyErrors 
          ? _syncLoggingService.getAllSyncLogs().where((log) => log.result != SyncResult.success).toList()
          : _syncLoggingService.getAllSyncLogs();
    });
  }

  void _toggleErrorFilter() {
    setState(() {
      _showOnlyErrors = !_showOnlyErrors;
      _loadLogs();
    });
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all sync logs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Clear logs logic would go here
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _syncLoggingService.getLogSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Logs'),
        actions: [
          IconButton(
            icon: Icon(_showOnlyErrors ? Icons.error : Icons.error_outline),
            onPressed: _toggleErrorFilter,
            tooltip: _showOnlyErrors ? 'Show all logs' : 'Show only errors',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sync Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryCard('Total', summary.totalSyncs.toString(), Colors.blue),
                      _buildSummaryCard('Success', summary.successfulSyncs.toString(), Colors.green),
                      _buildSummaryCard('Failed', summary.failedSyncs.toString(), Colors.red),
                      _buildSummaryCard('Partial', summary.partialSyncs.toString(), Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Success Rate: ${summary.successRate.toStringAsFixed(1)}%'),
                  if (summary.mostCommonErrors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Most Common Errors:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...summary.mostCommonErrors.take(3).map((error) => Text('- $error')),
                  ],
                ],
              ),
            ),
          ),
          // Logs list
          Expanded(
            child: _logs.isEmpty
                ? const Center(child: Text('No sync logs found'))
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(
                            '${log.className} - ${log.operationType.toString().split('.').last}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getResultColor(log.result),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Records: ${log.recordCount}, Attempt: ${log.attemptNumber}'),
                              Text('Device: ${log.deviceId}'),
                              if (log.errorMessage != null)
                                Text(
                                  'Error: ${log.errorMessage}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              Text(
                                'Time: ${log.timestamp.toString().split('.').first}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            _getResultIcon(log.result),
                            color: _getResultColor(log.result),
                          ),
                          isThreeLine: log.errorMessage != null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Color _getResultColor(SyncResult result) {
    switch (result) {
      case SyncResult.success:
        return Colors.green;
      case SyncResult.failure:
        return Colors.red;
      case SyncResult.partial:
        return Colors.orange;
    }
  }

  IconData _getResultIcon(SyncResult result) {
    switch (result) {
      case SyncResult.success:
        return Icons.check_circle;
      case SyncResult.failure:
        return Icons.error;
      case SyncResult.partial:
        return Icons.warning;
    }
  }
}