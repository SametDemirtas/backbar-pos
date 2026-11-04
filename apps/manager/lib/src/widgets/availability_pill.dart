import 'package:flutter/material.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

class AvailabilityPill extends StatelessWidget {
  const AvailabilityPill({
    super.key,
    required this.isAvailable,
    required this.onChanged,
    this.subject,
    this.pending = false,
  });

  final bool isAvailable;
  final VoidCallback onChanged;

  final String? subject;

  final bool pending;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);

    final (background, border, foreground, label) = pending
        ? (palette.well, palette.line, palette.textMuted, 'Updating')
        : isAvailable
        ? (palette.marquee, palette.marquee, palette.onMarquee, 'On sale')
        : (
            palette.emberWash,
            palette.emberInk.withValues(alpha: 0.28),
            palette.emberInk,
            'Sold out',
          );

    return FocusRing(
      outset: true,
      child: Semantics(
        button: true,
        enabled: !pending,
        label: [label, ?subject].join(', '),
        onTapHint: pending
            ? null
            : isAvailable
            ? 'mark sold out'
            : 'put back on sale',
        onTap: pending ? null : onChanged,
        child: ExcludeSemantics(
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: pending ? null : onChanged,
              borderRadius: PosRadius.control,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: PosTouch.control,
                  minWidth: 92 + PosTouch.gap,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PosTouch.gap / 2,
                    vertical: (PosTouch.control - 44) / 2,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: PosRadius.control,
                      border: Border.all(color: border),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 92,
                        minHeight: 44,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PosSpace.x2,
                        ),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: Text(
                            label.toUpperCase(),
                            maxLines: 1,
                            softWrap: false,
                            style: PosType.tag.copyWith(color: foreground),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
