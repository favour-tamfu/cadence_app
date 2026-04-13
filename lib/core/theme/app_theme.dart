import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.midnight,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.amber,
        secondary: AppColors.amberLight,
        surface:   AppColors.midnight2,
        error:     AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.cream,
      ),

      // ── Typography
      textTheme: TextTheme(
        // Display — Playfair Display
        displayLarge: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 52, fontWeight: FontWeight.w400,
          color: AppColors.cream, letterSpacing: -0.5,
        ),
        displayMedium: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 40, fontWeight: FontWeight.w400,
          color: AppColors.cream,
        ),
        displaySmall: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 32, fontWeight: FontWeight.w400,
          color: AppColors.cream,
        ),
        // Headings
        headlineLarge: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 28, fontWeight: FontWeight.w400,
          color: AppColors.cream,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 24, fontWeight: FontWeight.w400,
          color: AppColors.cream,
        ),
        // Body — DM Sans via Google Fonts
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w400,
          color: AppColors.creamDim, height: 1.7,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: AppColors.creamDim, height: 1.65,
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12, fontWeight: FontWeight.w300,
          color: AppColors.muted, height: 1.6,
        ),
        // Labels
        labelLarge: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w500,
          color: AppColors.cream, letterSpacing: 0.2,
        ),
        labelSmall: GoogleFonts.dmSans(
          fontSize: 10, fontWeight: FontWeight.w500,
          color: AppColors.muted,
          letterSpacing: 1.4,
        ),
      ),

      // ── AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.midnight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: 18, color: AppColors.cream,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.cream),
      ),

      // ── Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w500,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cream,
          side: BorderSide(color: AppColors.cream.withValues(alpha: 0.2)),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // ── Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cream.withValues(alpha: 0.06),
        hintStyle: GoogleFonts.dmSans(
          color: AppColors.muted, fontSize: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.cream.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.cream.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.amber, width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18, vertical: 14,
        ),
      ),

      // ── Cards
      cardTheme: CardThemeData(
        color: AppColors.midnight2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.cream.withValues(alpha: 0.08),
          ),
        ),
      ),

      // ── Bottom Nav
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.midnight,
        indicatorColor: AppColors.amberDim,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.amberLight, size: 22);
          }
          return const IconThemeData(color: AppColors.muted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.dmSans(
              fontSize: 10, fontWeight: FontWeight.w500,
              color: AppColors.amberLight,
            );
          }
          return GoogleFonts.dmSans(
            fontSize: 10, color: AppColors.muted,
          );
        }),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.cream.withValues(alpha: 0.07),
        thickness: 0.5,
      ),
    );
  }
}
