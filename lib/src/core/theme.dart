import 'package:flutter/material.dart';

// ─── Brand palette ─────────────────────────────────────────────────────────
// AquaGas green — matches the consumer app and the live-tracking screen
// (0xFF10B981 / 0xFF064E3B), replacing the old orange/navy scheme so the
// vendor app is visually consistent with the rest of AquaGas.
const _primaryGreen = Color(0xFF10B981);
const _primaryGreenDark = Color(0xFF064E3B);
const _primaryNavy = Color(0xFF0F1729);
const _surfaceLight = Color(0xFFF8F9FC);
const _cardLight = Color(0xFFFFFFFF);
const _surfaceDark = Color(0xFF1A2235);
const _cardDark = Color(0xFF243047);
const _accentGreen = Color(0xFF22C55E);
const _accentAmber = Color(0xFFF59E0B);
const _textPrimLight = Color(0xFF0F1729);
const _textSecLight = Color(0xFF64748B);
const _textPrimDark = Color(0xFFF1F5F9);
const _textSecDark = Color(0xFF94A3B8);

/// FIX: was instance methods — now all static so main.dart can access without
/// constructing an AppTheme instance.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryGreen,
          brightness: Brightness.light,
          primary: _primaryGreen,
          secondary: _primaryGreenDark,
          surface: _surfaceLight,
          error: const Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: _surfaceLight,
        cardTheme: CardThemeData(
          color: _cardLight,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _cardLight,
          foregroundColor: _textPrimLight,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _textPrimLight,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _cardLight,
          indicatorColor: _primaryGreen.withOpacity(0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: _primaryGreen, size: 22);
            }
            return const IconThemeData(color: _textSecLight, size: 22);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                  color: _primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w600);
            }
            return const TextStyle(
                color: _textSecLight,
                fontSize: 11,
                fontWeight: FontWeight.w500);
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primaryGreen,
            side: const BorderSide(color: _primaryGreen, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryGreen, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(color: _textSecLight),
          hintStyle: const TextStyle(color: _textSecLight),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _surfaceLight,
          selectedColor: _primaryGreen.withOpacity(0.15),
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE2E8F0),
          thickness: 1,
          space: 1,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              color: _textPrimLight,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5),
          headlineLarge: TextStyle(
              color: _textPrimLight,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5),
          headlineMedium: TextStyle(
              color: _textPrimLight,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3),
          titleLarge:
              TextStyle(color: _textPrimLight, fontWeight: FontWeight.w700),
          titleMedium:
              TextStyle(color: _textPrimLight, fontWeight: FontWeight.w600),
          titleSmall:
              TextStyle(color: _textPrimLight, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: _textPrimLight),
          bodyMedium: TextStyle(color: _textPrimLight),
          bodySmall: TextStyle(color: _textSecLight),
          labelLarge:
              TextStyle(color: _textSecLight, fontWeight: FontWeight.w600),
          labelMedium:
              TextStyle(color: _textSecLight, fontWeight: FontWeight.w500),
          labelSmall: TextStyle(
              color: _textSecLight,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryGreen,
          brightness: Brightness.dark,
          primary: _primaryGreen,
          secondary: const Color(0xFF60A5FA),
          surface: _surfaceDark,
          error: const Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: _primaryNavy,
        cardTheme: CardThemeData(
          color: _cardDark,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _primaryNavy,
          foregroundColor: _textPrimDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _textPrimDark,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _cardDark,
          indicatorColor: _primaryGreen.withOpacity(0.2),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: _primaryGreen, size: 22);
            }
            return IconThemeData(color: _textSecDark, size: 22);
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _cardDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryGreen, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(color: _textSecDark),
          hintStyle: TextStyle(color: _textSecDark),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF334155),
          thickness: 1,
          space: 1,
        ),
        textTheme: TextTheme(
          displayLarge: const TextStyle(
              color: _textPrimDark, fontWeight: FontWeight.w800),
          headlineLarge: const TextStyle(
              color: _textPrimDark, fontWeight: FontWeight.w700),
          headlineMedium: const TextStyle(
              color: _textPrimDark, fontWeight: FontWeight.w700),
          titleLarge: const TextStyle(
              color: _textPrimDark, fontWeight: FontWeight.w700),
          titleMedium: const TextStyle(
              color: _textPrimDark, fontWeight: FontWeight.w600),
          titleSmall: const TextStyle(
              color: _textPrimDark, fontWeight: FontWeight.w600),
          bodyLarge: const TextStyle(color: _textPrimDark),
          bodyMedium: const TextStyle(color: _textPrimDark),
          bodySmall: TextStyle(color: _textSecDark),
          labelLarge:
              TextStyle(color: _textSecDark, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(color: _textSecDark),
          labelSmall: TextStyle(color: _textSecDark),
        ),
      );

  // ── Semantic helpers used across the app ─────────────────────────────────
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return _accentAmber;
      case 'confirmed':
        return const Color(0xFF60A5FA);
      case 'preparing':
        return const Color(0xFFA78BFA);
      case 'ready':
        return _accentGreen;
      case 'dispatched':
        return _primaryGreen;
      case 'delivered':
        return _accentGreen;
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFEF4444);
      default:
        return _textSecLight;
    }
  }

  static Color get orange => _primaryGreen; // kept for source compat; now green
  static Color get navy => _primaryNavy;
  static Color get primary => _primaryGreen;
  static Color get primaryDark => _primaryGreenDark;
  static Color get success => _accentGreen;
  static Color get warning => _accentAmber;
  static Color get danger => const Color(0xFFEF4444);
}
