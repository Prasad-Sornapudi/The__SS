import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Connectivity Service
/// Monitors network connectivity and triggers sync when online
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = false;
  final List<Function()> _onlineCallbacks = [];

  /// Initialize connectivity monitoring
  Future<void> init() async {
    try {
      print('ConnectivityService: Initializing connectivity monitoring...');
      
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(result);
      
      print('ConnectivityService: Initial connectivity: ${_isOnline ? "Online" : "Offline"}');
      
      // Listen for connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          print('❌ ConnectivityService: Error in connectivity stream: $error');
        },
      );
      
      print('✅ ConnectivityService: Initialized successfully');
    } catch (e) {
      print('❌ ConnectivityService: Failed to initialize: $e');
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = _isConnected(results);
    
    print('ConnectivityService: Connectivity changed - ${_isOnline ? "Online" : "Offline"}');
    
    // If we just came online, trigger callbacks
    if (!wasOnline && _isOnline) {
      print('ConnectivityService: Device came online, triggering ${_onlineCallbacks.length} callbacks');
      for (final callback in _onlineCallbacks) {
        try {
          callback();
        } catch (e) {
          print('⚠️ ConnectivityService: Error in online callback: $e');
        }
      }
    }
  }

  /// Check if connected based on connectivity results
  bool _isConnected(List<ConnectivityResult> results) {
    // Check if any result indicates connectivity
    for (final result in results) {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet) {
        return true;
      }
    }
    return false;
  }

  /// Get current online status
  bool get isOnline => _isOnline;

  /// Register callback to be called when device comes online
  void registerOnlineCallback(Function() callback) {
    if (!_onlineCallbacks.contains(callback)) {
      _onlineCallbacks.add(callback);
      print('ConnectivityService: Registered online callback (total: ${_onlineCallbacks.length})');
    }
  }

  /// Unregister online callback
  void unregisterOnlineCallback(Function() callback) {
    _onlineCallbacks.remove(callback);
    print('ConnectivityService: Unregistered online callback (remaining: ${_onlineCallbacks.length})');
  }

  /// Check connectivity status (async version)
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = _isConnected(result);
      return _isOnline;
    } catch (e) {
      print('❌ ConnectivityService: Failed to check connectivity: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    print('ConnectivityService: Disposing resources');
    _subscription?.cancel();
    _subscription = null;
    _onlineCallbacks.clear();
  }
}
