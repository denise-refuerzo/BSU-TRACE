import 'package:flutter/material.dart';

class AppTheme {
  // Define your primary colors here so they can be changed in one place
  static const Color primaryRed = Color(0xFFB01A22);
  static const Color scaffoldBg = Color(0xFFFCF6F6);
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Colors.red;

  // Global App Theme Configuration
  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryRed,
    scaffoldBackgroundColor: scaffoldBg,
    
    // Using Material 3 ColorScheme for consistent UI elements
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryRed,
      primary: primaryRed,
      surface: surfaceColor,
    ),
    
    // Global AppBar Styling
    appBarTheme: const AppBarTheme(
      backgroundColor: scaffoldBg,
      elevation: 0,
      iconTheme: IconThemeData(color: primaryRed),
      titleTextStyle: TextStyle(
        color: primaryRed,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Global Input/Field Styling
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFF9F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryRed),
      ),
    ),
    
    useMaterial3: true,
  );
}