import 'package:flutter/material.dart';
import 'screens/new_dashboard_screen.dart';
import 'constants/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Attendance Scanner Preview',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppTheme.darkNavyBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primaryColor,
          brightness: Brightness.dark,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}