import 'package:flutter/material.dart';

import '../theme/pos_metrics.dart';
import '../theme/pos_palette.dart';

class ChangeFlash extends StatefulWidget {
  const ChangeFlash({
    super.key,
    required this.signature,
    required this.child,
    this.width = 3,
  });

  final Object? signature;
  final Widget child;
  final double width;

  @override
  State<ChangeFlash> createState() => _ChangeFlashState();
}

class _ChangeFlashState extends State<ChangeFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PosDuration.flashTotal,
  );

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: PosCurve.flashIn)),
      weight: PosDuration.flashIn.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: ConstantTween(1.0),
      weight: PosDuration.flashHold.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: PosCurve.flashOut)),
      weight: PosDuration.flashOut.inMilliseconds.toDouble(),
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(ChangeFlash old) {
    super.didUpdateWidget(old);
    if (old.signature != widget.signature) {
      if (PosMotion.of(context, PosDuration.flashTotal) == Duration.zero) {
        _controller.value = 0;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = PosPalette.of(context);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: widget.width,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _opacity,
              child: ColoredBox(color: palette.marquee),
            ),
          ),
        ),
      ],
    );
  }
}
