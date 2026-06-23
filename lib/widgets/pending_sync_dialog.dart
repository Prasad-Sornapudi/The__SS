import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/attendance_record.dart';
import '../services/session_sync_service.dart';

class PendingSyncDialog extends StatefulWidget {
  final PendingSyncInfo pendingSyncInfo;
  final VoidCallback onRetrySync;
  final VoidCallback onViewPending;

  const PendingSyncDialog({
    Key? key,
    required this.pendingSyncInfo,
    required this.onRetrySync,
    required this.onViewPending,
  }) : super(key: key);

  @override
  State<PendingSyncDialog> createState() => _PendingSyncDialogState();
}

class _PendingSyncDialogState extends State<PendingSyncDialog> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dialog from being dismissed
      child: AlertDialog(
        title: const Text('Pending Sync Required'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Previous session data for ${widget.pendingSyncInfo.classModel.className} '
              '(${widget.pendingSyncInfo.sessionName}) has not been synced. '
              'Please connect to the internet to sync now. '
              'New scanning is disabled until this is done.',
            ),
            const SizedBox(height: 16),
            Text(
              'Pending records: ${widget.pendingSyncInfo.recordCount}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (_isSyncing)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Syncing...'),
                ],
              ),
          ],
        ),
      ),
        actions: [
          ElevatedButton(
            onPressed: _isSyncing ? null : widget.onRetrySync,
            child: const Text('Retry Sync Now'),
          ),
          OutlinedButton(
            onPressed: _isSyncing ? null : widget.onViewPending,
            child: const Text('View Pending'),
          ),
        ],
      ),
    );
  }
}