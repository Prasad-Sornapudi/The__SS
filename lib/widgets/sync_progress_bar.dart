import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_progress_provider.dart';
import '../constants/theme.dart';

class SyncProgressBar extends StatelessWidget {
  const SyncProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProgressProvider>(
      builder: (context, syncProgressProvider, child) {
        // Only show the progress bar when syncing
        if (!syncProgressProvider.isSyncing && syncProgressProvider.progress == 0.0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 8.0,
            bottom: 16.0,
          ),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: AppTheme.darkNavyBlueLighter,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: syncProgressProvider.progress,
                backgroundColor: AppTheme.glassBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                minHeight: 4.0,
              ),
              const SizedBox(height: 4.0),
              // Status message
              if (syncProgressProvider.message.isNotEmpty) ...[
                Text(
                  syncProgressProvider.message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}