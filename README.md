# Skill Sync - QR Attendance Application

Skill Sync is a Flutter-based mobile application designed for QR code-based attendance tracking with Google Sheets integration. The app provides robust synchronization capabilities to ensure data consistency across multiple devices and offline scenarios.

## Features

- QR-based attendance scanning
- Google Sheets integration for data storage
- Offline attendance tracking with local storage
- Multi-device synchronization
- Mock interview scheduling and tracking
- Class management
- Automated attendance uploading
- Session-based sync with morning and afternoon sessions (now selectable at any time)
- Pending sync enforcement with non-cancelable dialogs
- Background sync with two-cycle rule
- Comprehensive sync logging and monitoring

## Session Sync System

The app implements a comprehensive Session Sync, Preserve & Clear System that manages attendance data based on user-selected sessions (no longer time-based).

### Session Rules

- **Morning Session**: Available for selection at any time
- **Afternoon Session**: Available for selection at any time

### Key Features

1. **Local Data Storage**
   - All scanned attendance data stored locally immediately
   - Data preserved until verified sync completion
   - No data deletion until sync is confirmed successful

2. **Multi-Device Sync**
   - Union-based merging of attendance data from all devices
   - Duplicate prevention with present integrity rule
   - Conflict resolution prioritizing present status

3. **Background Sync (Two-Cycle Rule)**
   - Auto-sync continues in background for exactly two cycles
   - Stops if no new data changes detected
   - Resets when app returns to foreground

4. **Sync Priority and Cutoff Times**
   - Syncing always takes priority over clearing
   - Data cleared only after verified successful sync
   - Pending data blocks new scanning until synced

5. **Pending Sync Enforcement**
   - Non-cancelable dialog for unsynced data
   - Retry and view options for pending records
   - New scanning disabled until sync completion

6. **Web App Support**
   - Direct sheet updates when online
   - Local storage when offline
   - Automatic retry on reconnection

7. **Verification and Clearance**
   - Read-back verification after sync
   - Session data cleared only after successful verification
   - Automatic detection of already-synced data from other devices

8. **Logging and Monitoring**
   - Comprehensive sync operation logging
   - Error tracking with timestamps and device IDs
   - Sync success rate monitoring
   - Debug screen for log viewing

## Robust Synchronization System

The app implements a robust attendance synchronization system that ensures perfect consistency between all class attendance sheets, even under multi-device, offline, or column-missing conditions.

### Key Features

1. **Date Column Validation & Self-Healing**
   - Automatic creation of missing date columns
   - Self-healing of deleted or missing columns
   - Validation on every sync operation

2. **Union-Based Attendance Merging**
   - Intelligent merging of local and remote attendance data
   - Preservation of "Present" entries
   - Proper handling of absent students

3. **Multi-Device Safe Sync**
   - Concurrent access handling
   - Data integrity across multiple devices
   - Accurate student mapping

4. **Critical Present Integrity Rule**
   - Once a student is marked "Present", the entry is never changed
   - Protection against accidental overwrites
   - Conflict resolution for concurrent updates

5. **Complete Union Display**
   - Displays the complete union of locally scanned and remotely synced attendance data
   - Real-time interface updates showing all present students
   - Multi-device attendance visibility

For detailed information about the robust synchronization system, see:
- [Robust Sync System Documentation](docs/robust_sync_system.md)
- [Usage Examples](docs/robust_sync_example.md)
- [Complete Union Display](docs/complete_union_display.md)

## Architecture

The application follows a clean architecture pattern with the following main components:

- **Models**: Data classes for students, classes, and attendance records
- **Services**: Business logic for Google Sheets integration, local storage, and synchronization
- **Providers**: State management using the Provider pattern
- **Screens**: UI components for different app features
- **Widgets**: Reusable UI components

## Setup

1. Clone the repository
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Set up Google Sheets integration:
   - Create a Google Cloud project
   - Enable Google Sheets API
   - Create a service account
   - Share your Google Sheets with the service account email
4. Configure the app with your Google Sheets URLs and credentials

## Testing

Run the test suite:
```bash
flutter test
```

## Building

Build the application:
```bash
flutter build apk
```

## Documentation

- [Control Sheet Secrets Obfuscation](scripts/README_CONTROL_SHEET.md)
- [Robust Synchronization System](docs/robust_sync_system.md)
- [Robust Sync Usage Examples](docs/robust_sync_example.md)

## Contributing

Contributions are welcome! Please follow the standard GitHub workflow for submitting pull requests.

## License

This project is proprietary and confidential. All rights reserved.