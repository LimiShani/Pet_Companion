import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

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

  /// Corner radius of list cards, sheets and dialogs.
  static const surfaceRadius = 24.0;

  /// Corner radius of text fields and small tiles.
  static const fieldRadius = 18.0;

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
      // coralDark, not coral: Material widgets put small text and icons in
      // `primary`, and coral is too light for that on cream.
      primary: AppColors.coralDark,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.yellow,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.yellow,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.yellow,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.sage,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.sage,
      onTertiaryContainer: AppColors.ink,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.brown,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: Color(0xFFFFFBF0),
      surfaceContainer: Color(0xFFFFF3D6),
      surfaceContainerHigh: Color(0xFFFDEFC9),
      surfaceContainerHighest: Color(0xFFFBE9BD),
      outline: Color(0xFF9A7B4F),
      outlineVariant: Color(0xFFE7D9B5),
      error: Color(0xFFB3261E),
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = AppFonts.textTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    const pillLabel = TextStyle(fontSize: 15, fontWeight: FontWeight.w800);

    OutlineInputBorder fieldBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.ink),
      dividerColor: scheme.outlineVariant,
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      splashFactory: InkSparkle.splashFactory,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.coralDark,
          foregroundColor: AppColors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          textStyle: pillLabel,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.coralDark,
          side: const BorderSide(color: AppColors.coralDark, width: 2),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          textStyle: pillLabel,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.coralDark,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.coralDark,
        foregroundColor: AppColors.white,
        elevation: 2,
        shape: StadiumBorder(),
        extendedTextStyle: pillLabel,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: AppText.body.copyWith(fontSize: 16, color: AppColors.brown.withValues(alpha: 0.55)),
        labelStyle: AppText.body.copyWith(color: AppColors.brown),
        border: fieldBorder(Colors.transparent),
        enabledBorder: fieldBorder(Colors.transparent),
        focusedBorder: fieldBorder(AppColors.coral, 2),
        errorBorder: fieldBorder(scheme.error),
        focusedErrorBorder: fieldBorder(scheme.error, 2),
        errorStyle: AppText.label.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.yellow,
        disabledColor: scheme.surfaceContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: AppText.secondary.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
        secondaryLabelStyle: AppText.secondary.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800),
        checkmarkColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.body.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.fieldRadius)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: Color(0xFFE7D9B5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.shellRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius)),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink),
        contentTextStyle: textTheme.bodyMedium?.merge(AppText.body).copyWith(color: AppColors.ink),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.brown,
        textColor: AppColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.brown,
        indicatorColor: AppColors.coralDark,
        dividerColor: scheme.outlineVariant,
        labelStyle: AppText.body.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: AppText.body,
      ),
    );
  }
}
