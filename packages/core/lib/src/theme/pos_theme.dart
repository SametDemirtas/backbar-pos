import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'pos_metrics.dart';
import 'pos_palette.dart';
import 'pos_type.dart';

abstract final class PosTheme {
  static ThemeData get backbar => _build(PosPalette.backbar);

  static ThemeData get daylight => _build(PosPalette.daylight);

  static ThemeData _build(PosPalette palette) {
    final scheme =
        ColorScheme(
          brightness: palette.isDark ? Brightness.dark : Brightness.light,
          primary: palette.marqueeInk,
          onPrimary: palette.onMarquee,
          secondary: palette.marqueeInk,
          onSecondary: palette.onMarquee,
          error: palette.ember,
          onError: palette.isDark
              ? const Color(0xFF2A0B06)
              : const Color(0xFFFFF3F0),
          surface: palette.surface,
          onSurface: palette.textPrimary,
        ).copyWith(
          outline: palette.line,
          surfaceContainerLowest: palette.background,
          surfaceContainerLow: palette.well,
          surfaceContainerHighest: palette.raised,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      dividerColor: palette.line,
      splashFactory: InkSparkle.splashFactory,
      focusColor: Colors.transparent,
      extensions: <ThemeExtension<dynamic>>[palette],
      fontFamily: PosType.resolvedFamily,
      fontFamilyFallback: PosType.fallback,
      textTheme: _textTheme(palette),
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: PosRadius.surface),
        titleTextStyle: PosType.sheetTitle.copyWith(color: palette.textPrimary),
        contentTextStyle: PosType.body.copyWith(color: palette.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: palette.isDark ? 0 : 8,
        shadowColor: palette.isDark
            ? Colors.transparent
            : const Color(0x141A1613),
        shape: const RoundedRectangleBorder(borderRadius: PosRadius.sheet),
        showDragHandle: true,
        dragHandleColor: palette.line,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.isDark ? palette.raised : palette.textPrimary,
        contentTextStyle: PosType.bodyStrong.copyWith(
          color: palette.isDark ? palette.textPrimary : palette.background,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: PosRadius.control),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.well,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PosSpace.x3,
          vertical: PosSpace.x4,
        ),
        border: _fieldBorder(palette.textMuted),
        enabledBorder: _fieldBorder(palette.textMuted),
        focusedBorder: _fieldBorder(
          palette.isDark ? palette.marquee : palette.marqueeInk,
          width: 2,
        ),
        errorBorder: _fieldBorder(palette.emberInk),
        focusedErrorBorder: _fieldBorder(palette.emberInk, width: 2),
        hintStyle: PosType.field.copyWith(color: palette.textMuted),
        errorStyle: PosType.moneySmall.copyWith(color: palette.emberInk),
        errorMaxLines: 3,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.marquee,
        linearMinHeight: 2,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: PosRadius.control,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(PosPalette palette) {
    return TextTheme(
      displayLarge: PosType.total.copyWith(color: palette.marquee),
      headlineLarge: PosType.headline.copyWith(color: palette.textPrimary),
      headlineSmall: PosType.sheetTitle.copyWith(color: palette.textPrimary),
      titleLarge: PosType.tileTitle.copyWith(color: palette.textPrimary),
      titleMedium: PosType.rowTitle.copyWith(color: palette.textPrimary),
      bodyLarge: PosType.body.copyWith(color: palette.textPrimary),
      bodyMedium: PosType.body.copyWith(color: palette.textSecondary),
      bodySmall: PosType.meta.copyWith(color: palette.textMuted),
      labelLarge: PosType.button.copyWith(color: palette.textPrimary),
      labelMedium: PosType.marquee.copyWith(color: palette.textSecondary),
      labelSmall: PosType.tag.copyWith(color: palette.textMuted),
    );
  }
}
