import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Spacing and radius system shared by every screen.
abstract final class AppSpacing {
  /// Horizontal screen margin.
  static const screen = 20.0;

  /// Internal padding of dashboard cards.
  static const card = EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  /// Gap between dashboard cards.
  static const cardGap = 12.0;

  /// Corner radius of dashboard cards.
  static const cardRadius = 28.0;

  /// Corner radius of the bottom navigation bar and the header's bottom edge.
  static const shellRadius = 28.0;
  static const headerRadius = 44.0;
}

/// Type scale from the redesign brief.
abstract final class AppText {
  static const appTitle = TextStyle(fontSize: 23, fontWeight: FontWeight.w800);
  static const petName = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 28 / 24);
  static const metric = TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 32 / 30);
  static const metricSmall = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 32 / 28);
  static const pillValue = TextStyle(fontSize: 18, fontWeight: FontWeight.w800);
  static const cardTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static const secondary = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
  static const navLabel = TextStyle(fontSize: 11, fontWeight: FontWeight.w700);
}

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.coral,
      onPrimary: AppColors.white,
      secondary: AppColors.yellow,
      onSecondary: AppColors.ink,
      tertiary: AppColors.sage,
      onTertiary: AppColors.ink,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.brown,
      error: Color(0xFFB3261E),
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.ink),
      dividerColor: AppColors.white.withValues(alpha: 0.55),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.coral,
        linearTrackColor: Color(0x8CFFFFFF),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.coral,
        foregroundColor: AppColors.white,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.merge(AppText.appTitle).copyWith(color: AppColors.white),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
