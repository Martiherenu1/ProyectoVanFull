
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Temas visuales compartidos de VanFull.
/// Fuente: 08-Brief-de-Diseno-UI.md.
abstract final class AppTheme {
  static ThemeData get passenger => _darkTheme();

  static ThemeData get driver => _darkTheme();

  static ThemeData get admin => _lightTheme();

  static ThemeData _darkTheme() {
    return _buildTheme(
      brightness: Brightness.dark,
      background: AppColors.ink950,
      surface: AppColors.ink800,
      foreground: AppColors.ink100,
      secondaryText: AppColors.ink400,
      border: AppColors.ink700,
    );
  }

  static ThemeData _lightTheme() {
    return _buildTheme(
      brightness: Brightness.light,
      background: AppColors.ink050,
      surface: AppColors.paper,
      foreground: AppColors.ink900,
      secondaryText: AppColors.ink600,
      border: AppColors.ink200,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color foreground,
    required Color secondaryText,
    required Color border,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: brightness,
      surface: surface,
    ).copyWith(
      primary: AppColors.gold,
      onPrimary: AppColors.ink900,
      surface: surface,
      onSurface: foreground,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: TextTheme(
        displayLarge: AppTypography.display.copyWith(color: foreground),
        headlineLarge: AppTypography.h1.copyWith(color: foreground),
        headlineMedium: AppTypography.h2.copyWith(color: foreground),
        headlineSmall: AppTypography.h3.copyWith(color: foreground),
        bodyLarge: AppTypography.body.copyWith(color: foreground),
        bodyMedium: AppTypography.body.copyWith(color: foreground),
        bodySmall: AppTypography.small.copyWith(color: secondaryText),
        labelSmall: AppTypography.micro.copyWith(color: secondaryText),
        titleMedium: AppTypography.data.copyWith(color: foreground),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.h3.copyWith(color: foreground),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.ink900,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          textStyle: AppTypography.body,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
