import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

Widget host(
  Widget child, {
  required ThemeData theme,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  final climates = {'backbar': PosTheme.backbar, 'daylight': PosTheme.daylight};

  group('PriceText', () {
    for (final entry in climates.entries) {
      testWidgets('renders an amount in ${entry.key}', (tester) async {
        await tester.pumpWidget(
          host(const PriceText(Money.fromCents(1250)), theme: entry.value),
        );

        expect(find.text('£12.50'), findsOneWidget);
      });
    }

    testWidgets('strikes through and dims a sold-out price', (tester) async {
      await tester.pumpWidget(
        host(
          const PriceText(Money.fromCents(1250), struck: true),
          theme: PosTheme.backbar,
        ),
      );

      final style = tester.widget<Text>(find.text('£12.50')).style!;
      expect(style.decoration, TextDecoration.lineThrough);
      expect(style.color, PosPalette.backbar.disabled);
    });

    testWidgets('renders every number with tabular figures', (tester) async {
      await tester.pumpWidget(
        host(const PriceText(Money.fromCents(1250)), theme: PosTheme.backbar),
      );

      final style = tester.widget<Text>(find.text('£12.50')).style!;
      expect(
        style.fontFeatures,
        contains(const FontFeature.tabularFigures()),
        reason: 'a total whose digits change width reads as broken hardware',
      );
    });

    testWidgets('honours the venue currency', (tester) async {
      await tester.pumpWidget(
        host(
          const PriceText(Money.fromCents(1250), symbol: '€'),
          theme: PosTheme.backbar,
        ),
      );

      expect(find.text('€12.50'), findsOneWidget);
    });

    testWidgets('announces itself with its label and its state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const PriceText(
            Money.fromCents(1250),
            struck: true,
            semanticsPrefix: 'Total',
          ),
          theme: PosTheme.backbar,
        ),
      );

      expect(find.bySemanticsLabel('Total, £12.50, sold out'), findsOneWidget);
      handle.dispose();
    });
  });

  group('MarqueeLabel', () {
    testWidgets('shouts on screen but not to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const MarqueeLabel('Drinks'), theme: PosTheme.backbar),
      );

      expect(find.text('DRINKS'), findsOneWidget);
      expect(find.bySemanticsLabel('Drinks'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('runs vertically for the till rail', (tester) async {
      await tester.pumpWidget(
        host(
          const MarqueeLabel('Drinks', axis: Axis.vertical),
          theme: PosTheme.backbar,
        ),
      );

      expect(find.byType(RotatedBox), findsOneWidget);
    });
  });

  group('SoldOutTag', () {
    testWidgets('says the words, in both climates', (tester) async {
      for (final theme in climates.values) {
        await tester.pumpWidget(host(const SoldOutTag(), theme: theme));
        expect(find.text('SOLD OUT'), findsOneWidget);
      }
    });
  });

  group('SoldOutHatch', () {
    testWidgets('paints without swallowing taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 200,
            height: 100,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => tapped = true,
                    child: const ColoredBox(color: Color(0xFF000000)),
                  ),
                ),
                const Positioned.fill(child: SoldOutHatch()),
              ],
            ),
          ),
          theme: PosTheme.backbar,
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue, reason: 'the hatch is decoration, not a barrier');
    });
  });

  group('PosButton', () {
    testWidgets('keyboard focus draws a ring, not a fill under the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          PosButton(label: 'SEND ORDER', onPressed: () {}),
          theme: PosTheme.backbar,
        ),
      );
      final ring = find.descendant(
        of: find.byType(FocusRing),
        matching: find.byType(Positioned),
      );
      expect(ring, findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring, findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(ring, findsNothing);

      expect(PosTheme.backbar.focusColor, Colors.transparent);
      expect(PosTheme.daylight.focusColor, Colors.transparent);
    });

    testWidgets('an inset ring keeps the focus that drew it', (tester) async {
      await tester.pumpWidget(
        host(
          FocusRing(
            child: InkWell(
              onTap: () {},
              child: const SizedBox(width: 200, height: 56),
            ),
          ),
          theme: PosTheme.backbar,
        ),
      );
      final before = tester.element(find.byType(InkWell));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump();

      expect(tester.element(find.byType(InkWell)), same(before));
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
      expect(
        tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(FocusRing),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration,
        isA<BoxDecoration>().having((d) => d.border, 'border', isNotNull),
      );
    });

    testWidgets('calls back when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          PosButton(label: 'SEND ORDER', onPressed: () => taps++),
          theme: PosTheme.backbar,
        ),
      );

      await tester.tap(find.text('SEND ORDER'));
      expect(taps, 1);
    });

    testWidgets('a null callback disables it', (tester) async {
      await tester.pumpWidget(
        host(
          const PosButton(label: 'SEND ORDER', onPressed: null),
          theme: PosTheme.backbar,
        ),
      );

      await tester.tap(find.text('SEND ORDER'), warnIfMissed: false);
      await tester.pump();

      final ink = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(PosButton),
          matching: find.byType(InkWell),
        ),
      );
      expect(ink.onTap, isNull);

      final style = tester.widget<Text>(find.text('SEND ORDER')).style!;
      expect(style.color, PosPalette.backbar.disabled);
    });

    testWidgets('swallows taps and shows a spinner while busy', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          PosButton(label: 'SAVE', onPressed: () => taps++, busy: true),
          theme: PosTheme.daylight,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('SAVE'), findsNothing);

      await tester.tap(find.byType(PosButton));
      expect(taps, 0, reason: 'a double tap must not submit twice');
    });

    testWidgets('can actually be pressed by a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        host(
          PosButton(label: 'SEND ORDER', onPressed: () => taps++),
          theme: PosTheme.backbar,
        ),
      );

      final node = tester.getSemantics(find.bySemanticsLabel('SEND ORDER'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.tap,
          viewId: tester.view.viewId,
          nodeId: node.id,
        ),
      );
      await tester.pump();

      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('offers no tap action to a screen reader when disabled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const PosButton(label: 'SEND ORDER', onPressed: null),
          theme: PosTheme.backbar,
        ),
      );

      final node = tester.getSemantics(find.bySemanticsLabel('SEND ORDER'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('is at least a full touch target tall', (tester) async {
      await tester.pumpWidget(
        host(
          PosButton(
            label: 'CLEAR',
            onPressed: () {},
            kind: PosButtonKind.ghost,
          ),
          theme: PosTheme.backbar,
        ),
      );

      expect(
        tester.getSize(find.byType(PosButton)).height,
        greaterThanOrEqualTo(PosTouch.control),
      );
    });
  });

  group('StreamStateView', () {
    Widget view(Stream<List<int>> stream) => host(
      StreamStateView<List<int>>(
        stream: stream,
        emptyTitle: 'No items yet',
        emptyDetail: 'Add one from the manager app.',
        errorTitle: 'Cannot reach the menu',
        builder: (context, data) => Text('items: ${data.length}'),
      ),
      theme: PosTheme.backbar,
    );

    testWidgets('shows a spinner while a live stream has yet to speak', (
      tester,
    ) async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);

      await tester.pumpWidget(view(controller.stream));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does not spin forever on a stream that closes silently', (
      tester,
    ) async {
      await tester.pumpWidget(view(const Stream<List<int>>.empty()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No items yet'), findsOneWidget);
    });

    testWidgets('builds the data when there is some', (tester) async {
      await tester.pumpWidget(view(Stream.value(const [1, 2, 3])));
      await tester.pump();

      expect(find.text('items: 3'), findsOneWidget);
    });

    testWidgets('surfaces the error instead of rendering a blank screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        view(
          Stream.error(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Cannot reach the menu'), findsOneWidget);
      expect(find.textContaining('not allowed'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);
    });
  });

  group('ChangeFlash', () {
    Widget flashing(Object signature, {bool reduceMotion = false}) => host(
      ChangeFlash(
        signature: signature,
        child: const SizedBox(width: 100, height: 50),
      ),
      theme: PosTheme.backbar,
      reduceMotion: reduceMotion,
    );

    double edgeOpacity(WidgetTester tester) {
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(ChangeFlash),
          matching: find.byType(FadeTransition),
        ),
      );
      return fade.opacity.value;
    }

    testWidgets('does not flash on first build', (tester) async {
      await tester.pumpWidget(flashing('v1'));
      await tester.pump(const Duration(milliseconds: 240));

      expect(edgeOpacity(tester), 0);
    });

    testWidgets('lights the edge when the remote signature changes', (
      tester,
    ) async {
      await tester.pumpWidget(flashing('v1'));
      await tester.pumpWidget(flashing('v2'));
      await tester.pump(PosDuration.flashIn);

      expect(edgeOpacity(tester), greaterThan(0.9));
    });

    testWidgets('fades back out on its own', (tester) async {
      await tester.pumpWidget(flashing('v1'));
      await tester.pumpWidget(flashing('v2'));
      await tester.pump(PosDuration.flashTotal + const Duration(seconds: 1));

      expect(edgeOpacity(tester), 0);
    });

    testWidgets('stays still when the device asks for no animation', (
      tester,
    ) async {
      await tester.pumpWidget(flashing('v1', reduceMotion: true));
      await tester.pumpWidget(flashing('v2', reduceMotion: true));
      await tester.pump(PosDuration.flashIn);

      expect(edgeOpacity(tester), 0);
    });

    testWidgets('does not flash when the signature is unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(flashing('v1'));
      await tester.pumpWidget(flashing('v1'));
      await tester.pump(PosDuration.flashIn);

      expect(edgeOpacity(tester), 0);
    });
  });

  group('LiveDot', () {
    testWidgets('pulses while the screen is listening', (tester) async {
      await tester.pumpWidget(host(const LiveDot(), theme: PosTheme.backbar));
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('holds still under reduce motion, halo hidden', (tester) async {
      await tester.pumpWidget(
        host(const LiveDot(), theme: PosTheme.backbar, reduceMotion: true),
      );

      expect(tester.hasRunningAnimations, isFalse);
      final halo = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(LiveDot),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(halo.scale.value, 1);
    });

    testWidgets('is not read out', (tester) async {
      await tester.pumpWidget(host(const LiveDot(), theme: PosTheme.backbar));

      final excluded = tester.widget<ExcludeSemantics>(
        find.descendant(
          of: find.byType(LiveDot),
          matching: find.byType(ExcludeSemantics),
        ),
      );
      expect(excluded.excluding, isTrue);
    });
  });

  group('PosType', () {
    test('resolves the font through this package, not the app bundle', () {
      expect(PosType.tileTitle.fontFamily, 'packages/backbar_pos_core/Archivo');
      expect(PosType.marquee.fontFamily, 'packages/backbar_pos_core/Archivo');
    });

    test('drives the variable axes, not just fontWeight', () {
      final axes = {
        for (final v in PosType.marquee.fontVariations!) v.axis: v.value,
      };

      expect(axes['wght'], 700);
      expect(axes['wdth'], 125, reason: 'the marquee is the wide one');
    });

    test('the total is condensed so a four-figure tab cannot re-wrap', () {
      final axes = {
        for (final v in PosType.total.fontVariations!) v.axis: v.value,
      };

      expect(axes['wdth'], lessThan(100));
    });

    test('every money style is tabular', () {
      for (final style in [
        PosType.total,
        PosType.tilePrice,
        PosType.money,
        PosType.moneySmall,
        PosType.stat,
      ]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    test(
      'carries a nearest static weight for platforms without variations',
      () {
        expect(PosType.marquee.fontWeight, FontWeight.w700);
        expect(PosType.total.fontWeight, FontWeight.w800);
        expect(PosType.body.fontWeight, FontWeight.w500);
      },
    );
  });

  group('PosPalette', () {
    testWidgets('is reachable from anywhere under either theme', (
      tester,
    ) async {
      late PosPalette seen;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) {
              seen = PosPalette.of(context);
              return const SizedBox();
            },
          ),
          theme: PosTheme.daylight,
        ),
      );

      expect(seen, same(PosPalette.daylight));
      expect(seen.isDark, isFalse);
    });

    test('the two climates are genuinely different, not one tinted', () {
      expect(
        PosPalette.backbar.background,
        isNot(PosPalette.daylight.background),
      );
      expect(
        PosPalette.backbar.textPrimary,
        isNot(PosPalette.daylight.textPrimary),
      );
      expect(PosPalette.backbar.marquee, PosPalette.daylight.marquee);
    });

    test('lerp moves every channel', () {
      final mid = PosPalette.backbar.lerp(PosPalette.daylight, 0.5);

      expect(mid.background, isNot(PosPalette.backbar.background));
      expect(mid.background, isNot(PosPalette.daylight.background));
    });
  });
}
