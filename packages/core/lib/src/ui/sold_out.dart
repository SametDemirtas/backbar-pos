import 'package:flutter/material.dart';

import '../theme/pos_palette.dart';
import '../theme/pos_metrics.dart';
import '../theme/pos_type.dart';

class SoldOutHatch extends StatelessWidget {
  const SoldOutHatch({super.key, this.spacing = 13, this.thickness = 6})
    : assert(spacing > 0, 'Stripe spacing must be positive'),
      assert(thickness > 0, 'Stripe thickness must be positive');

  final double spacing;

  final double thickness;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _HatchPainter(
          color: PosPalette.of(context).emberWash,
          spacing: spacing,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter({
    required this.color,
    required this.spacing,
    required this.thickness,
  });

  final Color color;
  final double spacing;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    canvas.clipRect(Offset.zero & size);

    for (var x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.thickness != thickness;
}

class SoldOutTag extends StatelessWidget {
  const SoldOutTag({super.key, this.label = 'SOLD OUT'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: palette.emberWash,
        borderRadius: PosRadius.badge,
      ),
      child: Text(label, style: PosType.tag.copyWith(color: palette.emberInk)),
    );
  }
}
