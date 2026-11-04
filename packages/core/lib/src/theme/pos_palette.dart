import 'package:flutter/material.dart';

@immutable
class PosPalette extends ThemeExtension<PosPalette> {
  const PosPalette({
    required this.background,
    required this.well,
    required this.surface,
    required this.raised,
    required this.line,
    required this.disabled,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.marquee,
    required this.onMarquee,
    required this.marqueeInk,
    required this.ember,
    required this.emberInk,
    required this.emberWash,
    required this.isDark,
  });

  final Color background;

  final Color well;

  final Color surface;

  final Color raised;

  final Color line;

  final Color disabled;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color marquee;

  final Color onMarquee;

  final Color marqueeInk;

  final Color ember;

  final Color emberInk;

  final Color emberWash;

  final bool isDark;

  static const PosPalette backbar = PosPalette(
    background: Color(0xFF0B0A09),
    well: Color(0xFF131110),
    surface: Color(0xFF1A1715),
    raised: Color(0xFF23201D),
    line: Color(0xFF322D29),
    disabled: Color(0xFF4A433D),
    textPrimary: Color(0xFFF5F0E8),
    textSecondary: Color(0xFFB8AFA3),
    textMuted: Color(0xFF958C81),
    marquee: Color(0xFFF2B03D),
    onMarquee: Color(0xFF2A1B03),
    marqueeInk: Color(0xFFF2B03D),
    ember: Color(0xFFE5533D),
    emberInk: Color(0xFFF06E5A),
    emberWash: Color(0x1AE5533D),
    isDark: true,
  );

  static const PosPalette daylight = PosPalette(
    background: Color(0xFFFAF7F2),
    well: Color(0xFFF2EDE4),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFF2EDE4),
    line: Color(0xFFE4DCCF),
    disabled: Color(0xFFB6AC9C),
    textPrimary: Color(0xFF1A1613),
    textSecondary: Color(0xFF6B6156),
    textMuted: Color(0xFF70675C),
    marquee: Color(0xFFF2B03D),
    onMarquee: Color(0xFF2A1B03),
    marqueeInk: Color(0xFF8A5A0F),
    ember: Color(0xFFB93A25),
    emberInk: Color(0xFFA8321F),
    emberWash: Color(0x14B93A25),
    isDark: false,
  );

  static PosPalette of(BuildContext context) {
    final palette = Theme.of(context).extension<PosPalette>();
    if (palette == null) {
      throw FlutterError(
        'No PosPalette found in the enclosing Theme.\n'
        'Wrap the application in PosTheme.backbar (the till) or '
        'PosTheme.daylight (the manager app). A widget from this package '
        'cannot choose a colour without one.',
      );
    }
    return palette;
  }

  @override
  PosPalette copyWith({
    Color? background,
    Color? well,
    Color? surface,
    Color? raised,
    Color? line,
    Color? disabled,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? marquee,
    Color? onMarquee,
    Color? marqueeInk,
    Color? ember,
    Color? emberInk,
    Color? emberWash,
    bool? isDark,
  }) {
    return PosPalette(
      background: background ?? this.background,
      well: well ?? this.well,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      line: line ?? this.line,
      disabled: disabled ?? this.disabled,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      marquee: marquee ?? this.marquee,
      onMarquee: onMarquee ?? this.onMarquee,
      marqueeInk: marqueeInk ?? this.marqueeInk,
      ember: ember ?? this.ember,
      emberInk: emberInk ?? this.emberInk,
      emberWash: emberWash ?? this.emberWash,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  PosPalette lerp(ThemeExtension<PosPalette>? other, double t) {
    if (other is! PosPalette) return this;
    return PosPalette(
      background: Color.lerp(background, other.background, t)!,
      well: Color.lerp(well, other.well, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      line: Color.lerp(line, other.line, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      marquee: Color.lerp(marquee, other.marquee, t)!,
      onMarquee: Color.lerp(onMarquee, other.onMarquee, t)!,
      marqueeInk: Color.lerp(marqueeInk, other.marqueeInk, t)!,
      ember: Color.lerp(ember, other.ember, t)!,
      emberInk: Color.lerp(emberInk, other.emberInk, t)!,
      emberWash: Color.lerp(emberWash, other.emberWash, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosPalette &&
          other.background == background &&
          other.well == well &&
          other.surface == surface &&
          other.raised == raised &&
          other.line == line &&
          other.disabled == disabled &&
          other.textPrimary == textPrimary &&
          other.textSecondary == textSecondary &&
          other.textMuted == textMuted &&
          other.marquee == marquee &&
          other.onMarquee == onMarquee &&
          other.marqueeInk == marqueeInk &&
          other.ember == ember &&
          other.emberInk == emberInk &&
          other.emberWash == emberWash &&
          other.isDark == isDark;

  @override
  int get hashCode => Object.hashAll([
    background,
    well,
    surface,
    raised,
    line,
    disabled,
    textPrimary,
    textSecondary,
    textMuted,
    marquee,
    onMarquee,
    marqueeInk,
    ember,
    emberInk,
    emberWash,
    isDark,
  ]);
}
