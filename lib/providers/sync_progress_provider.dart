import 'package:flutter/foundation.dart';

class SyncProgressProvider extends ChangeNotifier {
  static final SyncProgressProvider _instance = SyncProgressProvider._internal();
  factory SyncProgressProvider() => _instance;
  SyncProgressProvider._internal();

  bool _isSyncing = false;
  double _progress = 0.0;
  String _message = '';

  // Getters
  bool get isSyncing => _isSyncing;
  double get progress => _progress;
  String get message => _message;

  // Setters
  void startSync([String message = 'Syncing...']) {
    _isSyncing = true;
    _progress = 0.0;
    _message = message;
    notifyListeners();
  }

  void updateProgress(double progress, [String message = '']) {
    _progress = progress;
    if (message.isNotEmpty) {
      _message = message;
    }
    notifyListeners();
  }

  void completeSync([String message = 'Sync completed']) {
    _isSyncing = false;
    _progress = 1.0;
    _message = message;
    notifyListeners();
    
    // Reset after a short delay to hide the progress bar
    Future.delayed(const Duration(seconds: 2), () {
      if (_isSyncing == false && _progress == 1.0) {
        _progress = 0.0;
        notifyListeners();
      }
    });
  }

  void errorSync(String errorMessage) {
    _isSyncing = false;
    _message = errorMessage;
    notifyListeners();
    
    // Reset after a short delay to hide the error message
    Future.delayed(const Duration(seconds: 3), () {
      if (_isSyncing == false) {
        _message = '';
        notifyListeners();
      }
    });
  }

  void reset() {
    _isSyncing = false;
    _progress = 0.0;
    _message = '';
    notifyListeners();
  }
}