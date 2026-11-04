import 'package:flutter/material.dart';

import '../money/money.dart';
import '../theme/pos_palette.dart';
import '../theme/pos_type.dart';

class PriceText extends StatelessWidget {
  const PriceText(
    this.amount, {
    super.key,
    this.style,
    this.color,
    this.struck = false,
    this.symbol = '£',
    this.semanticsPrefix,
  });

  final Money amount;

  final TextStyle? style;

  final Color? color;

  final bool struck;

  final String symbol;

  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final text = amount.format(symbol: symbol);
    final effective = (style ?? PosType.money).copyWith(
      color: color ?? (struck ? palette.disabled : palette.textPrimary),
      decoration: struck ? TextDecoration.lineThrough : null,
      decorationColor: color ?? palette.disabled,
      decorationThickness: 2,
    );

    return Semantics(
      label: [
        if (semanticsPrefix != null) semanticsPrefix,
        text,
        if (struck) 'sold out',
      ].join(', '),
      excludeSemantics: true,
      child: Text(text, style: effective, maxLines: 1, softWrap: false),
    );
  }
}
