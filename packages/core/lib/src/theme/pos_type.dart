import 'package:flutter/widgets.dart';

abstract final class PosType {
  static const String family = 'Archivo';
  static const String package = 'backbar_pos_core';

  static const String resolvedFamily = 'packages/$package/$family';

  static const List<String> fallback = ['Helvetica Neue', 'Arial'];

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style({
    required double size,
    required double weight,
    double width = 100,
    double? height,
    double letterSpacing = 0,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: resolvedFamily,
      fontFamilyFallback: fallback,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      fontVariations: [
        FontVariation('wght', weight),
        FontVariation('wdth', width),
      ],
      fontWeight: _nearestWeight(weight),
      fontFeatures: tabular ? _tabular : null,
    );
  }

  static FontWeight _nearestWeight(double weight) {
    final index = ((weight / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }

  static final TextStyle marquee = _style(
    size: 13,
    weight: 700,
    width: 125,
    letterSpacing: 2.34,
    height: 1,
  );

  static final TextStyle tileTitle = _style(
    size: 17,
    weight: 600,
    height: 1.25,
  );

  static final TextStyle tilePrice = _style(
    size: 20,
    weight: 700,
    tabular: true,
  );

  static final TextStyle badge = _style(size: 14, weight: 700, tabular: true);

  static final TextStyle total = _style(
    size: 40,
    weight: 800,
    width: 87,
    letterSpacing: -0.4,
    height: 1,
    tabular: true,
  );

  static final TextStyle rowTitle = _style(size: 16, weight: 600, height: 1.25);

  static final TextStyle body = _style(size: 15, weight: 450, height: 1.45);

  static final TextStyle bodyStrong = _style(
    size: 15,
    weight: 550,
    height: 1.3,
  );

  static final TextStyle money = _style(size: 16, weight: 650, tabular: true);

  static final TextStyle moneySmall = _style(
    size: 13,
    weight: 550,
    tabular: true,
  );

  static final TextStyle meta = _style(
    size: 12,
    weight: 500,
    letterSpacing: 0.24,
  );

  static final TextStyle status = _style(
    size: 12,
    weight: 500,
    letterSpacing: 1.4,
  );

  static final TextStyle tag = _style(
    size: 10,
    weight: 800,
    width: 112,
    letterSpacing: 1.4,
  );

  static final TextStyle button = _style(
    size: 15,
    weight: 650,
    letterSpacing: 0.6,
  );

  static final TextStyle headline = _style(
    size: 26,
    weight: 800,
    width: 104,
    letterSpacing: -0.26,
    height: 1.1,
  );

  static final TextStyle sheetTitle = _style(
    size: 22,
    weight: 700,
    width: 108,
    height: 1.15,
  );

  static final TextStyle tillVenue = _style(
    size: 19,
    weight: 700,
    width: 108,
    height: 1.15,
  );

  static final TextStyle venueMark = _style(
    size: 17,
    weight: 800,
    width: 104,
    letterSpacing: -0.26,
    height: 1.1,
  );

  static final TextStyle stat = _style(
    size: 28,
    weight: 800,
    width: 92,
    height: 1,
    tabular: true,
  );

  static final TextStyle field = _style(size: 17, weight: 550);

  static final TextStyle fieldLabel = _style(
    size: 11,
    weight: 700,
    width: 118,
    letterSpacing: 1.54,
  );
}
