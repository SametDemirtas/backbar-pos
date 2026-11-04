import 'package:flutter/widgets.dart';

abstract final class PosSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 24;
  static const double x6 = 32;
  static const double x7 = 48;
  static const double x8 = 64;
}

abstract final class PosRadius {
  static const BorderRadius badge = BorderRadius.all(Radius.circular(2));
  static const BorderRadius control = BorderRadius.all(Radius.circular(6));
  static const BorderRadius surface = BorderRadius.all(Radius.circular(8));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(16),
  );
}

abstract final class PosTouch {
  static const double tile = 124;

  static const double action = 60;

  static const double control = 56;

  static const double gap = 8;
}

abstract final class PosDuration {
  static const Duration flashIn = Duration(milliseconds: 240);
  static const Duration flashHold = Duration(milliseconds: 600);
  static const Duration flashOut = Duration(milliseconds: 400);

  static Duration get flashTotal => flashIn + flashHold + flashOut;
}

abstract final class PosCurve {
  static const Curve flashIn = Curves.easeOut;
  static const Curve flashOut = Curves.easeIn;
}

abstract final class PosMotion {
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
