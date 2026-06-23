import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // New color palette
  static const Color brightOrange = Color(0xFFFF8400); // Bright orange
  static const Color amber = Color(0xFF40C0FF); // Amber (Material Design accent)
  static const Color vividBlue = Color(0xFF1C57E7); // Vivid royal blue
  static const Color midnightIndigo = Color(0xFF0A2346); // Midnight indigo
  static const Color veryDarkNavy = Color(0xFF071733); // Very dark navy
  static const Color deepSlateBlue = Color(0xFF334354); // Deep slate blue
  static const Color appBackgroundColor = Color(0xFF040C1B); // App background color
  static const Color cardColor = Color(0xFF001D3A); // Card color
  static const Color techwingyellow = Color(0xFFFAD02C); // Techwing yellow
  
  // Map new colors to existing theme structure
  static const Color darkNavyBlue = appBackgroundColor; // Background color
  static const Color darkNavyBlueLighter = midnightIndigo; // Overlays
  static const Color primaryColor = amber; // Yellow/Amber
  static const Color secondaryColor = techwingyellow; // Orange
  static const Color tertiaryColor = techwingyellow; // Orange (same as secondary)
  
  // Complementary Colors (using only the specified colors)
  static const Color successColor = brightOrange; // Orange for success
  static const Color warningColor = brightOrange; // Orange for warning
  static const Color errorColor = brightOrange; // Orange for error
  static const Color infoColor = amber; // Amber for info
  
  // Text Colors on Dark Navy
  static const Color onDarkNavy = Color(0xFFFFFFFF); // Pure white text
  static const Color onDarkNavySecondary = Color(0xFFE5E5E7); // Light gray text
  static const Color onDarkNavyTertiary = Color(0xFF98989D); // Medium gray text
  
  // Glass Morphism Colors (adjusted to use only specified colors)
  static const Color glassBackground = Color(0xB30A2346); // Semi-transparent overlay
  static const Color glassBorder = Color(0x330A2346); // Border using overlay color
  static const Color borderColor = glassBorder;
  static const Color glassHighlight = Color(0x4D0A2346); // Highlight using overlay color
  
  // Legacy color mappings for compatibility
  static const Color darkBackground = darkNavyBlue;
  static const Color darkSurface = darkNavyBlueLighter;
  static const Color darkSurfaceVariant = darkNavyBlueLighter;
  static const Color darkOnSurface = onDarkNavy;
  static const Color darkOnSurfaceVariant = onDarkNavySecondary;

  static ThemeData get darkTheme {
    return ThemeData(
      scaffoldBackgroundColor: Colors.transparent,
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        error: errorColor,
        surface: darkNavyBlueLighter,
        surfaceContainerHighest: darkNavyBlueLighter,
        onSurface: onDarkNavy,
        onSurfaceVariant: onDarkNavySecondary,
        background: darkNavyBlue,
        onBackground: onDarkNavy,
      ),
      
      // Typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.agdasima(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
          color: onDarkNavy,
        ),
        displayMedium: GoogleFonts.agdasima(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: onDarkNavy,
        ),
        displaySmall: GoogleFonts.agdasima(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: onDarkNavy,
        ),
        headlineLarge: GoogleFonts.agdasima(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: onDarkNavy,
        ),
        headlineMedium: GoogleFonts.agdasima(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: onDarkNavy,
        ),
        headlineSmall: GoogleFonts.agdasima(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: onDarkNavy,
        ),
        titleLarge: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          color: onDarkNavy,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          color: onDarkNavy,
        ),
        titleSmall: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: onDarkNavy,
        ),
        labelLarge: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: onDarkNavy,
        ),
        labelMedium: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: onDarkNavySecondary,
        ),
        labelSmall: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: onDarkNavySecondary,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          color: onDarkNavy,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: onDarkNavy,
        ),
        bodySmall: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: onDarkNavySecondary,
        ),
      ),

      // App Bar Theme with Glass Morphism
      appBarTheme: AppBarTheme(
        backgroundColor: darkNavyBlueLighter.withOpacity(0.8),
        foregroundColor: onDarkNavy,
        titleTextStyle: GoogleFonts.agdasima(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onDarkNavy,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),

      // Card Theme with Gradient and Midnight Indigo Stroke
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: midnightIndigo, // Midnight indigo stroke
            width: 2, // 2 pixels width
          ),
        ),
        // Using a custom decoration instead of color to apply gradient
      ),

      // Elevated Button Theme with Glass Morphism (kept for backward compatibility)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryColor, // Orange fill
          foregroundColor: Colors.white, // White text
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Outlined Button Theme with Glass Morphism
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent, // No fill for outlined buttons
          foregroundColor: Colors.white, // White text
          side: BorderSide(color: AppTheme.techwingyellow, width: 2), // Orange stroke
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Text Button Theme (kept for backward compatibility)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: primaryColor, // Amber fill
          foregroundColor: const Color.fromARGB(255, 255, 255, 255), // Dark blue text
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Input Decoration Theme with Glass Morphism
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: GoogleFonts.manrope(
          color: onDarkNavySecondary,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.manrope(
          color: onDarkNavyTertiary,
          fontSize: 14,
        ),
      ),

      // Bottom Navigation Bar Theme with Glass Morphism
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: primaryColor,
        unselectedItemColor: onDarkNavySecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Floating Action Button Theme with Glass Morphism
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: glassBorder,
            width: 1,
          ),
        ),
      ),

      // Dialog Theme with Glass Morphism
      dialogTheme: DialogThemeData(
        backgroundColor: darkNavyBlueLighter.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: glassBorder,
            width: 1,
          ),
        ),
        titleTextStyle: GoogleFonts.agdasima(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onDarkNavy,
        ),
        contentTextStyle: GoogleFonts.manrope(
          fontSize: 14,
          color: onDarkNavy,
        ),
      ),

      // Snack Bar Theme with Glass Morphism
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkNavyBlueLighter.withOpacity(0.9),
        contentTextStyle: GoogleFonts.manrope(
          color: onDarkNavy,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: glassBorder,
            width: 1,
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return onDarkNavySecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return onDarkNavyTertiary.withOpacity(0.3);
        }),
      ),

      // Checkbox Theme with Glass Morphism
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.black),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
            color: glassBorder,
            width: 1,
          ),
        ),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: darkNavyBlueLighter,
        circularTrackColor: darkNavyBlueLighter,
      ),
    );
  }

  // Custom colors for QR scanning feedback with glass morphism
  static const Color scanSuccessColor = Color(0xCCFF8400); // Semi-transparent bright orange
  static const Color scanWarningColor = Color(0xCCFF8400); // Semi-transparent bright orange
  static const Color scanErrorColor = Color(0xCCFF8400); // Semi-transparent bright orange

  // Glass Morphism Utility Methods
  static BoxDecoration glassContainer({double borderRadius = 16.0}) {
    return BoxDecoration(
      gradient: appBackgroundGradient, // Use the new gradient
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: glassBorder,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration glassCard({double borderRadius = 12.0}) {
    return BoxDecoration(
      gradient: appBackgroundGradient, // Use the new gradient
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: midnightIndigo, // Midnight indigo stroke
        width: 2, // 2 pixels width
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 15,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // Gradient definitions (using only specified colors)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [primaryColor, primaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [secondaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // New gradient for buttons
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [
      Color(0xFFFDD64E), // Light gold
      Color(0xFFEC990E), // Dark gold
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text color for buttons with gradient background
  static const Color buttonTextColor = Color(0xFF0A2346); // Midnight indigo for good contrast

  // Gradient for app Cards
  static const LinearGradient appBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      cardColor, // Card color
      Color(0xFF122545), // Card color
    ],
  );

  // Gradient for glass elements
  static LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      glassBackground, // Semi-transparent overlay
      glassBackground.withOpacity(0.5), // Lighter overlay
    ],
  );

  // Animation durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration slowAnimation = Duration(milliseconds: 500);

  // Border radius values
  static const double smallRadius = 8.0;
  static const double mediumRadius = 12.0;
  static const double largeRadius = 16.0;
  static const double extraLargeRadius = 24.0;

  // Spacing values
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double extraLargeSpacing = 32.0;
}