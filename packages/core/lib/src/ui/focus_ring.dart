import 'package:flutter/material.dart';

import '../theme/pos_metrics.dart';
import '../theme/pos_palette.dart';

class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.outset = false,
    this.borderRadius = PosRadius.control,
  });

  final Widget child;

  final bool outset;

  final BorderRadius borderRadius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

const double _ringWidth = 2.5;

const double _outset = 4;

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onModeChanged);
    super.dispose();
  }

  void _onModeChanged(FocusHighlightMode _) {
    if (_focused && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    final show =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final ring = BoxDecoration(
      borderRadius: widget.outset
          ? widget.borderRadius +
                const BorderRadius.all(Radius.circular(_outset - 1))
          : widget.borderRadius,
      border: Border.all(
        color: palette.isDark ? palette.marquee : palette.marqueeInk,
        width: _ringWidth,
      ),
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: widget.outset
          ? Stack(
              fit: StackFit.passthrough,
              clipBehavior: Clip.none,
              children: [
                widget.child,
                if (show)
                  Positioned(
                    left: -_outset,
                    top: -_outset,
                    right: -_outset,
                    bottom: -_outset,
                    child: IgnorePointer(child: DecoratedBox(decoration: ring)),
                  ),
              ],
            )
          : DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: show ? ring : const BoxDecoration(),
              child: widget.child,
            ),
    );
  }
}
