import 'package:flutter/material.dart';

import '../theme/pos_palette.dart';

class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 8, this.color});

  final double size;
  final Color? color;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  late final Animation<double> _spread = _controller.drive(
    CurveTween(curve: Curves.easeOut),
  );
  late final Animation<double> _haloScale = _spread.drive(
    Tween(begin: 1, end: 3.2),
  );
  late final Animation<double> _haloOpacity = _spread.drive(
    Tween(begin: 0.5, end: 0),
  );

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? PosPalette.of(context).marquee;
    final dot = DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              FadeTransition(
                opacity: _haloOpacity,
                child: ScaleTransition(scale: _haloScale, child: dot),
              ),
              dot,
            ],
          ),
        ),
      ),
    );
  }
}
