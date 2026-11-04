import 'package:flutter/material.dart';

import '../theme/pos_palette.dart';
import '../theme/pos_type.dart';

class MarqueeLabel extends StatelessWidget {
  const MarqueeLabel(
    this.text, {
    super.key,
    this.color,
    this.axis = Axis.horizontal,
    this.style,
    this.header = false,
  });

  final String text;
  final Color? color;

  final Axis axis;

  final TextStyle? style;

  final bool header;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final label = Text(
      text.toUpperCase(),
      style: (style ?? PosType.marquee).copyWith(
        color: color ?? palette.textSecondary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Semantics(
      label: text,
      header: header,
      excludeSemantics: true,
      child: axis == Axis.horizontal
          ? label
          : RotatedBox(quarterTurns: 1, child: label),
    );
  }
}
