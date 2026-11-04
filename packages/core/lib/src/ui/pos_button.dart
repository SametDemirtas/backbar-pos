import 'package:flutter/material.dart';

import '../theme/pos_metrics.dart';
import '../theme/pos_palette.dart';
import '../theme/pos_type.dart';
import 'focus_ring.dart';

enum PosButtonKind { primary, ghost, danger }

class PosButton extends StatelessWidget {
  const PosButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = PosButtonKind.primary,
    this.height,
    this.busy = false,
  });

  final String label;

  final VoidCallback? onPressed;

  final PosButtonKind kind;
  final double? height;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final enabled = onPressed != null && !busy;

    final (background, foreground, border) = switch (kind) {
      PosButtonKind.primary => (
        enabled ? palette.marquee : palette.raised,
        enabled ? palette.onMarquee : palette.disabled,
        null,
      ),
      PosButtonKind.ghost => (
        Colors.transparent,
        enabled ? palette.textSecondary : palette.disabled,
        palette.line,
      ),
      PosButtonKind.danger => (
        Colors.transparent,
        enabled ? palette.emberInk : palette.disabled,
        palette.emberInk.withValues(alpha: 0.3),
      ),
    };

    return FocusRing(
      outset: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        onTap: enabled ? onPressed : null,
        child: ExcludeSemantics(
          child: SizedBox(
            height: height ?? PosTouch.control,
            child: Material(
              color: background,
              borderRadius: PosRadius.control,
              child: InkWell(
                onTap: enabled ? onPressed : null,
                borderRadius: PosRadius.control,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: PosRadius.control,
                    border: border == null ? null : Border.all(color: border),
                  ),
                  child: Center(
                    child: busy
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: foreground,
                            ),
                          )
                        : Text(
                            label,
                            style: PosType.button.copyWith(color: foreground),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
