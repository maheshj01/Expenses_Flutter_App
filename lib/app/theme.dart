import 'package:flutter/material.dart';

/// Color tokens from the design prototype.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.card,
    required this.sunk,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.line,
    required this.lived,
    required this.livedSoft,
    required this.invested,
    required this.investedSoft,
    required this.earned,
    required this.earnedSoft,
    required this.warn,
    required this.warnSoft,
  });

  final Color background, card, sunk, ink, ink2, muted, line;
  final Color lived, livedSoft, invested, investedSoft, earned, earnedSoft, warn, warnSoft;

  static const light = AppColors(
    background: Color(0xFFFAF9F6),
    card: Color(0xFFFFFFFF),
    sunk: Color(0xFFF2F0EB),
    ink: Color(0xFF15171A),
    ink2: Color(0xFF3A3E43),
    muted: Color(0xFF73777C),
    line: Color(0xFFE6E2DA),
    lived: Color(0xFF1D7A52),
    livedSoft: Color(0xFFE2F1E8),
    invested: Color(0xFF4057D6),
    investedSoft: Color(0xFFE7EBFF),
    earned: Color(0xFFB7791F),
    earnedSoft: Color(0xFFFBF0DC),
    warn: Color(0xFFC2410C),
    warnSoft: Color(0xFFFDEBDF),
  );

  static const dark = AppColors(
    background: Color(0xFF131517),
    card: Color(0xFF1B1E21),
    sunk: Color(0xFF16191B),
    ink: Color(0xFFECEDEA),
    ink2: Color(0xFFC9CCCF),
    muted: Color(0xFF9097A0),
    line: Color(0xFF2A2E32),
    lived: Color(0xFF45C487),
    livedSoft: Color(0xFF16301F),
    invested: Color(0xFF8FA3FF),
    investedSoft: Color(0xFF1D2340),
    earned: Color(0xFFE3B158),
    earnedSoft: Color(0xFF2E2412),
    warn: Color(0xFFF08A55),
    warnSoft: Color(0xFF33200F),
  );

  /// Pastel category tile color, softened on dark backgrounds.
  Color categoryTile(int argb) {
    final c = Color(argb);
    return identical(this, dark) ? Color.alphaBlend(c.withValues(alpha: 0.16), card) : c;
  }

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 || other == null ? this : other;
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

const tabularFigures = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.lived,
    brightness: brightness,
  ).copyWith(primary: c.ink, onPrimary: c.background, surface: c.background, onSurface: c.ink);

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final text = base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink);

  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    extensions: [c],
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.ink,
      elevation: 0,
      centerTitle: false,
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.card,
      selectedColor: c.ink,
      side: BorderSide(color: c.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(color: c.ink2, fontWeight: FontWeight.w500),
      secondaryLabelStyle: TextStyle(color: c.background, fontWeight: FontWeight.w600),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.ink2),
      ),
      hintStyle: TextStyle(color: c.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.ink,
        foregroundColor: c.background,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(color: c.background, fontWeight: FontWeight.w600),
      actionTextColor: c.livedSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.line,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.ink,
      foregroundColor: c.background,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
