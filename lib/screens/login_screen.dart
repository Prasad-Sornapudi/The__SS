import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add this import for kDebugMode
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Add this import for SVG support
import '../services/control_sheet_service.dart';
import '../services/firebase_config_service.dart';
import '../providers/class_provider.dart';
import '../providers/user_provider.dart';
import '../services/auto_class_service.dart';
import '../screens/home_screen.dart'; // Change this import back to scanner screen
import '../widgets/update_screen.dart';
import '../widgets/scanner_widgets.dart';
import '../constants/theme.dart';
import '../constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  List<LoginCredentials> _loginCredentials = [];
  late SvgPicture _logoImage; // Change type to SvgPicture
  bool _isLogoPreloaded = false;

  @override
  void initState() {
    super.initState();
    // Initialize with a default SVG image to avoid late initialization error
    _logoImage = SvgPicture.asset(
      'assets/images/Techwing.svg',
      height: 48,
      fit: BoxFit.contain,
      // Ensure colors are preserved
      colorFilter: null,
    );
    _loadLoginCredentials();
    _loadSavedCredentials(); // Add this line
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload logo once after dependencies are ready
    if (!_isLogoPreloaded) {
      _preloadLogo();
      _isLogoPreloaded = true;
    }
  }

  // Add this method to load saved credentials
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('saved_username');
      final savedPassword = prefs.getString('saved_password');
      
      if (savedUsername != null && savedPassword != null) {
        _usernameController.text = savedUsername;
        _passwordController.text = savedPassword;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading saved credentials: $e');
      }
    }
  }

  // Preload the logo image to avoid loading delays
  void _preloadLogo() {
    final logoImage = SvgPicture.asset(
      'assets/images/Techwing.svg',
      height: 48,
      fit: BoxFit.contain,
      // Use highest quality rendering
      color: null,
      colorFilter: null,
      allowDrawingOutsideViewBox: true,
      matchTextDirection: false,
      clipBehavior: Clip.none,
      // Add additional parameters for better rendering
      excludeFromSemantics: false,
    );
    
    // For SVG, we don't need precaching as it's handled differently
    setState(() {
      _logoImage = logoImage;
    });
  }

  // Save credentials to SharedPreferences
  Future<void> _saveCredentials(String username, String password, String displayName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_username', username);
      await prefs.setString('saved_password', password);
      await prefs.setString('saved_display_name', displayName);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving credentials: $e');
      }
    }
  }

  Future<void> _loadClassesAndNavigate() async {
    try {
      final classProvider = context.read<ClassProvider>();
      
      // Load classes from local storage
      await classProvider.loadClasses();
      
      // Check if we already have classes
      if (classProvider.hasClasses) {
        // Navigate directly to main screen
        _navigateToMainScreen();
        return;
      }
      
      // If no classes, show update screen to fetch from Google Sheets
      _navigateToUpdateScreen();
    } catch (e) {
      String errorMessage = 'Failed to initialize app: $e';
      
      // Handle specific network errors
      if (e.toString().contains('SocketException') || e.toString().contains('failed host lookup')) {
        errorMessage = 'Network connection failed. Please check your internet connection and try again.';
      } else if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        errorMessage = 'SSL certificate verification failed. Please check your network security settings.';
      } else if (e.toString().contains('Connection timed out')) {
        errorMessage = 'Connection timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('404') || e.toString().contains('not found')) {
        errorMessage = 'Google Sheet not found. Please check if the sheet URL is correct.';
      } else if (e.toString().contains('403') || e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check if the Google Sheet is shared with the service account.';
      }
      
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
    }
  }

  void _navigateToMainScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(), // Change back to ScannerScreen
      ),
    );
  }

  void _navigateToUpdateScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const UpdateScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Load login credentials from Firebase
  Future<void> _loadLoginCredentials() async {
    try {
      print('Loading login credentials from Firebase...');
      final credentials = await ControlSheetService.readLoginCredentials();
      setState(() {
        _loginCredentials = credentials;
      });
      print('Loaded ${credentials.length} login credentials');
    } catch (e) {
      if (kDebugMode) {
        print('Error loading login credentials: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load login credentials: $e';
      });
    }
  }

  // Attempt to login with provided credentials
  Future<void> _attemptLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // Reload credentials if we don't have them
      if (_loginCredentials.isEmpty) {
        await _loadLoginCredentials();
      }

      // Check if credentials exist
      if (_loginCredentials.isEmpty) {
        setState(() {
          _errorMessage = 'No login credentials found. Please sync credentials first.';
          _isLoading = false;
        });
        return;
      }

      // Validate credentials
      LoginCredentials? validCredential;
      
      for (final credential in _loginCredentials) {
        if (credential.username == username && credential.password == password) {
          validCredential = credential;
          break;
        }
      }

      if (validCredential != null) {
        // Save credentials
        await _saveCredentials(username, password, validCredential.name);
        
        // Set user in provider
        final userProvider = context.read<UserProvider>();
        try {
          userProvider.setUser(validCredential.name, username, validCredential.role);
        } catch (e) {
          print('Error setting user: $e');
          setState(() {
            _errorMessage = 'Failed to set user data: $e';
            _isLoading = false;
          });
          return;
        }
        
        // Load classes and navigate
        await _loadClassesAndNavigate();
      } else {
        setState(() {
          _errorMessage = 'Invalid username or password.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: $e';
        _isLoading = false;
      });
    }
  }

  // Sync credentials from Firebase
  Future<void> _syncCredentials() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      await _loadLoginCredentials();
      
      if (_loginCredentials.isEmpty) {
        setState(() {
          _errorMessage = 'No credentials found in Firebase. Make sure the Login_Credentials sheet is properly configured and synced.';
        });
      } else {
        setState(() {
          _errorMessage = 'Successfully synced ${_loginCredentials.length} credentials from Firebase.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sync credentials: $e';
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040C1B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.largeSpacing),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(AppTheme.largeSpacing),
            decoration: AppTheme.glassCard(
              borderRadius: AppTheme.largeRadius,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Logo/Title - Use preloaded image
                  _logoImage,
                  const SizedBox(height: AppTheme.largeSpacing),
                  Text(
                    'Login to ${AppConstants.appName}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppTheme.largeSpacing),
                  
                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    textCapitalization: TextCapitalization.none,
                    keyboardType: TextInputType.emailAddress, // Avoids auto-caps on iOS
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.mediumSpacing),
                  
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      filled: true,
                      fillColor: const Color(0xFF040C1B).withOpacity(0.5), // 50% opacity
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.mediumSpacing),
                  
                  // Error message
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppTheme.mediumSpacing),
                  ],
                  
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      onPressed: _isLoading ? () {} : _attemptLogin,
                      isEnabled: !_isLoading,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Login', style: TextStyle(color: AppTheme.buttonTextColor)),
                    ),
                  ),
                  const SizedBox(height: AppTheme.mediumSpacing),
                  
                  // Add Diagnostic Button (only in debug mode)
                  if (kDebugMode) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/diagnostic');
                        },
                        child: const Text('Run Sheet Diagnostic'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.smallSpacing),
                  ],
                  
                  // Sync Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isSyncing || _isLoading ? null : _syncCredentials,
                      child: _isSyncing
                          ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                          : const Text('Sync Credentials'),
                    ),
                  ),
                  const SizedBox(height: AppTheme.largeSpacing),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}