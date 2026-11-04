import 'package:flutter/material.dart';

import '../theme/pos_metrics.dart';
import '../theme/pos_palette.dart';
import '../theme/pos_type.dart';

enum StateTone { neutral, error }

class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.title,
    this.detail,
    this.tone = StateTone.neutral,
  });

  final String title;
  final String? detail;
  final StateTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final error = tone == StateTone.error;
    final accent = error ? palette.emberInk : palette.textMuted;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(PosSpace.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(color: accent, width: 2),
                  borderRadius: PosRadius.control,
                ),
              ),
              const SizedBox(height: PosSpace.x4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: PosType.bodyStrong.copyWith(
                  color: error ? palette.emberInk : palette.textSecondary,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: PosSpace.x2),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: PosType.meta.copyWith(color: palette.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class Notice extends StatelessWidget {
  const Notice({super.key, required this.child, this.tone = StateTone.neutral});

  final Widget child;
  final StateTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final error = tone == StateTone.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PosSpace.x3),
      decoration: BoxDecoration(
        color: error ? palette.emberWash : palette.raised,
        borderRadius: PosRadius.control,
        border: Border.all(
          color: error
              ? palette.emberInk.withValues(alpha: 0.35)
              : palette.line,
        ),
      ),
      child: child,
    );
  }
}

class StateLoading extends StatelessWidget {
  const StateLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: PosPalette.of(context).marquee,
        ),
      ),
    );
  }
}
