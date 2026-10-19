import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
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
      primary: AppColors.gold,
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
      primary: AppColors.goldText,
      background: AppColors.ink050,
      surface: AppColors.paper,
      foreground: AppColors.ink900,
      secondaryText: AppColors.ink600,
      border: AppColors.ink200,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color background,
    required Color surface,
    required Color foreground,
    required Color secondaryText,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? AppColors.ink900 : AppColors.paper,
      secondary: isDark ? AppColors.ink300 : AppColors.ink600,
      onSecondary: isDark ? AppColors.ink900 : AppColors.paper,
      error: isDark ? AppColors.alertDark : AppColors.alertLight,
      onError: isDark ? AppColors.ink950 : AppColors.paper,
      surface: surface,
      onSurface: foreground,
      outline: border,
      shadow: Colors.transparent,
      surfaceTint: Colors.transparent,
    );

    final baseTextTheme = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final archivoTextTheme = TextTheme(
      displayLarge: GoogleFonts.archivo(textStyle: baseTextTheme.displayLarge),
      displayMedium: GoogleFonts.archivo(
        textStyle: baseTextTheme.displayMedium,
      ),
      displaySmall: GoogleFonts.archivo(textStyle: baseTextTheme.displaySmall),
      headlineLarge: GoogleFonts.archivo(
        textStyle: baseTextTheme.headlineLarge,
      ),
      headlineMedium: GoogleFonts.archivo(
        textStyle: baseTextTheme.headlineMedium,
      ),
      headlineSmall: GoogleFonts.archivo(
        textStyle: baseTextTheme.headlineSmall,
      ),
      titleLarge: GoogleFonts.archivo(textStyle: baseTextTheme.titleLarge),
      titleMedium: GoogleFonts.archivo(textStyle: baseTextTheme.titleMedium),
      titleSmall: GoogleFonts.archivo(textStyle: baseTextTheme.titleSmall),
      bodyLarge: GoogleFonts.archivo(textStyle: baseTextTheme.bodyLarge),
      bodyMedium: GoogleFonts.archivo(textStyle: baseTextTheme.bodyMedium),
      bodySmall: GoogleFonts.archivo(textStyle: baseTextTheme.bodySmall),
      labelLarge: GoogleFonts.archivo(textStyle: baseTextTheme.labelLarge),
      labelMedium: GoogleFonts.archivo(textStyle: baseTextTheme.labelMedium),
      labelSmall: GoogleFonts.archivo(textStyle: baseTextTheme.labelSmall),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      shadowColor: Colors.transparent,
      textTheme: archivoTextTheme.copyWith(
        displayLarge: AppTypography.display.copyWith(color: foreground),
        headlineLarge: AppTypography.h1.copyWith(color: foreground),
        headlineMedium: AppTypography.h2.copyWith(color: foreground),
        headlineSmall: AppTypography.h3.copyWith(color: foreground),
        bodyLarge: AppTypography.body.copyWith(color: foreground),
        bodyMedium: AppTypography.body.copyWith(color: foreground),
        bodySmall: AppTypography.small.copyWith(color: secondaryText),
        labelSmall: AppTypography.micro.copyWith(color: secondaryText),
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
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.ink900,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          ),
          textStyle: AppTypography.body,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: AppSpacing.borderWidth,
        space: AppSpacing.borderWidth,
      ),
      dialogTheme: const DialogThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
