import 'package:flutter/foundation.dart';
import '../services/hive_service.dart';

class UserProvider extends ChangeNotifier {
  String? _userName;
  String? _userDisplayName;
  String? _role;

  // Initialize method to load user data from Hive
  Future<void> initialize() async {
    try {
      _userDisplayName = HiveService.getUserDisplayName();
      _role = HiveService.getUserRole();
      _userName = HiveService.getUserName(); // Load userName from Hive
    } catch (e) {
      print('Error initializing user provider: $e');
      // Reset values if there's an error
      _userDisplayName = null;
      _role = null;
      _userName = null;
    }
    notifyListeners();
  }

  // Getters
  String? get userName => _userName;
  String? get userDisplayName => _userDisplayName;
  String? get role => _role;
  bool get isLoggedIn => _userName != null && _userName!.isNotEmpty;
  bool get isAdmin => _role == 'Admin';

  // Load user data from Hive
  Future<void> loadUser() async {
    try {
      _userDisplayName = HiveService.getUserDisplayName();
      _role = HiveService.getUserRole();
      _userName = HiveService.getUserName();
    } catch (e) {
      print('Error loading user data: $e');
      // Reset values if there's an error
      _userDisplayName = null;
      _role = null;
      _userName = null;
    }
    notifyListeners();
  }

  // Set user information after login
  void setUser(String name, String username, String role) {
    _userDisplayName = name.isNotEmpty ? name : username;
    _userName = username;
    _role = role;
    // Persist to Hive
    try {
      HiveService.saveUserRole(role);
    } catch (e) {
      print('Error saving user role to Hive: $e');
    }
    if (_userDisplayName != null) {
      try {
        HiveService.saveUserDisplayName(_userDisplayName!);
      } catch (e) {
        print('Error saving user display name to Hive: $e');
      }
    }
    try {
      HiveService.saveUserName(username); // Save userName to Hive
    } catch (e) {
      print('Error saving user name to Hive: $e');
    }
    notifyListeners();
  }

  // Update user display name
  void updateUserDisplayName(String newDisplayName) {
    _userDisplayName = newDisplayName;
    try {
      HiveService.saveUserDisplayName(newDisplayName);
    } catch (e) {
      print('Error saving user display name to Hive: $e');
    }
    notifyListeners();
  }

  // Update user name (can be email or phone)
  void updateUserName(String newUserName) {
    _userName = newUserName;
    try {
      HiveService.saveUserName(newUserName);
    } catch (e) {
      print('Error saving user name to Hive: $e');
    }
    notifyListeners();
  }

  // Update user role
  void updateUserRole(String newRole) {
    _role = newRole;
    try {
      HiveService.saveUserRole(newRole);
    } catch (e) {
      print('Error saving user role to Hive: $e');
    }
    notifyListeners();
  }

  // Clear user information on logout
  void clearUser() {
    _userDisplayName = null;
    _userName = null;
    _role = null;
    try {
      HiveService.saveUserRole(''); // Clear role from Hive
      HiveService.saveUserDisplayName(''); // Clear display name from Hive
      HiveService.saveUserName(''); // Clear userName from Hive
    } catch (e) {
      print('Error clearing user data from Hive: $e');
    }
    notifyListeners();
  }
}