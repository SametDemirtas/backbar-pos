import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';
import 'package:pos/src/pos_home_page.dart';
import 'package:pos/src/widgets/menu_tile.dart';
import 'package:pos/src/widgets/order_panel.dart';

const venue = VenueConfig(
  venueId: 'copper-kettle',
  displayName: 'The Copper Kettle',
  currencySymbol: '£',
  tillLabel: 'TILL 2',
);

const menu = [
  MenuItem(
    id: 'guinness',
    name: 'Guinness, pint',
    priceCents: 720,
    category: MenuCategory.drinks,
    isAvailable: true,
  ),
];

class StubMenuRepository implements MenuRepository {
  StubMenuRepository({this.items = menu, this.error});

  final List<MenuItem> items;
  final Object? error;

  @override
  Stream<List<MenuItem>> watchMenu() =>
      error != null ? Stream.error(error!) : Stream.value(items);

  @override
  Stream<bool> watchMenuIsLive() => Stream.value(true);

  @override
  Future<String> create(MenuItemDraft draft) async => 'unused';

  @override
  Future<void> update(String itemId, MenuItemPatch patch) async {}

  @override
  Future<void> setAvailability(
    String itemId, {
    required bool isAvailable,
  }) async {}

  @override
  Future<void> delete(String itemId) async {}
}

class ControlledMenuRepository extends StubMenuRepository {
  ControlledMenuRepository({bool startLive = true}) {
    live.add(startLive);
  }

  final controller = StreamController<List<MenuItem>>();

  final live = StreamController<bool>();

  @override
  Stream<List<MenuItem>> watchMenu() => controller.stream;

  @override
  Stream<bool> watchMenuIsLive() => live.stream;
}

class RejectingOrderRepository implements OrderRepository {
  RejectingOrderRepository([this.error = 'permission-denied']);

  final Object error;
  int attempts = 0;

  @override
  String newOrderId() => 'order-${attempts + 1}';

  @override
  Future<String> submit(
    Order order, {
    required String orderId,
    required String tillLabel,
    required String staffUid,
  }) async {
    attempts++;
    throw Exception(error);
  }
}

class HangingOrderRepository implements OrderRepository {
  final completer = Completer<String>();
  int attempts = 0;

  @override
  String newOrderId() => 'order-1';

  @override
  Future<String> submit(
    Order order, {
    required String orderId,
    required String tillLabel,
    required String staffUid,
  }) {
    attempts++;
    return completer.future;
  }
}

Future<void> pumpTill(
  WidgetTester tester, {
  MenuRepository? menuRepository,
  OrderRepository? orderRepository,
}) async {
  tester.view.physicalSize = const Size(1194, 834);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: PosTheme.backbar,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: PosHomePage(
          menuRepository: menuRepository ?? StubMenuRepository(),
          orderRepository: orderRepository ?? RejectingOrderRepository(),
          venue: venue,
          staffUid: 'uid-under-test',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder tile(String name) =>
    find.descendant(of: find.byType(MenuTile), matching: find.text(name));

void main() {
  group('when the menu cannot be read', () {
    testWidgets('says so rather than showing an empty till', (tester) async {
      await pumpTill(
        tester,
        menuRepository: StubMenuRepository(
          error: StateError('permission-denied'),
        ),
      );

      expect(find.text('Cannot reach the menu'), findsOneWidget);
      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(find.byType(MenuTile), findsNothing);
      expect(find.textContaining('0 ITEMS'), findsNothing);
    });

    testWidgets('says so when the venue simply has no menu', (tester) async {
      await pumpTill(
        tester,
        menuRepository: StubMenuRepository(items: const []),
      );

      expect(find.text('This venue has no menu yet'), findsOneWidget);
      expect(find.textContaining('0 ITEMS'), findsNothing);
    });
  });

  testWidgets('a check too big for one order says to split it, not retry', (
    tester,
  ) async {
    const ceiling = MenuItem(
      id: 'ceiling',
      name: 'Ceiling',
      priceCents: Money.maxCents,
      category: MenuCategory.drinks,
      isAvailable: true,
    );
    final orders = RejectingOrderRepository();
    await pumpTill(
      tester,
      menuRepository: StubMenuRepository(items: const [ceiling]),
      orderRepository: orders,
    );
    await tester.tap(tile('Ceiling'));
    await tester.pump();
    await tester.tap(tile('Ceiling'));
    await tester.pump();
    await tester.tap(find.text('SEND ORDER'));
    await tester.pumpAndSettle();

    expect(orders.attempts, 0);
    expect(find.textContaining('as a separate order'), findsOneWidget);
    expect(
      find.text('Not sent — too big for one order, see above'),
      findsOneWidget,
    );
    expect(find.textContaining('Press send again'), findsNothing);
  });

  testWidgets('a small phone at normal text size keeps SEND on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final items = [
      for (var i = 0; i < 4; i++)
        MenuItem(
          id: 'item-$i',
          name: 'Item $i',
          priceCents: 100 + i,
          category: MenuCategory.drinks,
          isAvailable: true,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: PosTheme.backbar,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 667),
            disableAnimations: true,
          ),
          child: PosHomePage(
            menuRepository: StubMenuRepository(items: items),
            orderRepository: RejectingOrderRepository(),
            venue: venue,
            staffUid: 'uid-under-test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final grid = find
        .descendant(
          of: find.byKey(const ValueKey('menu-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 3; i++) {
      await tester.scrollUntilVisible(tile('Item $i'), 60, scrollable: grid);
      await tester.tap(tile('Item $i'));
      await tester.pump();
    }

    expect(find.textContaining('3 ITEMS'), findsOneWidget);
    expect(find.text('SEND ORDER').hitTestable(), findsOneWidget);
  });

  for (final (size, scale) in const [
    (Size(375, 667), 1.3),
    (Size(320, 568), 1.3),
    (Size(500, 400), 1.0),
    (Size(500, 400), 2.0),
    (Size(390, 844), 2.0),
    (Size(320, 480), 1.0),
    (Size(568, 320), 2.0),
    (Size(411, 400), 1.0),
    (Size(360, 330), 1.0),
    (Size(360, 330), 2.0),
    (Size(844, 390), 1.0),
    (Size(360, 500), 1.0),
    (Size(360, 518), 1.0),
  ]) {
    testWidgets('$size at ${scale}x: no overflow, and SEND stays whole', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: PosTheme.backbar,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: PosHomePage(
              menuRepository: StubMenuRepository(),
              orderRepository: RejectingOrderRepository(),
              venue: venue,
              staffUid: 'uid-under-test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final stacked =
          size.width < 640 && (size.height >= 480 || size.width < 520);
      final panelHeight = stacked
          ? math.min(size.height / 2, math.max(size.height * 0.4, 300.0))
          : size.height;
      final footerPadding = panelHeight < 260 ? PosSpace.x3 : PosSpace.x5;
      void expectFlush() {
        final send = tester.getRect(find.byType(PosButton).last);
        expect(size.height - send.bottom, closeTo(footerPadding, 1.5));
      }

      expectFlush();

      unawaited(
        Scrollable.ensureVisible(
          tester.element(tile('Guinness, pint')),
          alignment: 0.5,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(find.text('SEND ORDER'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Not sent'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final send = tester.getRect(find.byType(PosButton).last);
      expect(send.top, greaterThanOrEqualTo(0));
      expect(send.bottom, lessThanOrEqualTo(size.height));
      expect(find.text('SEND ORDER').hitTestable(), findsOneWidget);
      final status = tester.getRect(find.textContaining('Not sent'));
      expect(status.top, greaterThanOrEqualTo(0));
      expect(status.top, lessThan(send.top));
      expect(find.textContaining('Not sent').hitTestable(), findsOneWidget);
      expectFlush();
    });
  }

  testWidgets('a short window (a phone on its side) survives a failed send', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: PosTheme.backbar,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(568, 320),
            disableAnimations: true,
          ),
          child: PosHomePage(
            menuRepository: StubMenuRepository(),
            orderRepository: RejectingOrderRepository(),
            venue: venue,
            staffUid: 'uid-under-test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(tile('Guinness, pint'));
    await tester.pump();
    await tester.tap(find.text('SEND ORDER'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a small phone at twice the text size survives a failed send', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: PosTheme.backbar,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(375, 667),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: PosHomePage(
            menuRepository: StubMenuRepository(),
            orderRepository: RejectingOrderRepository(),
            venue: venue,
            staffUid: 'uid-under-test',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(tile('Guinness, pint'));
    await tester.pump();
    await tester.tap(find.text('SEND ORDER'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('on a tablet a long check never pushes SEND off screen', (
    tester,
  ) async {
    final items = [
      for (var i = 0; i < 30; i++)
        MenuItem(
          id: 'item-$i',
          name: 'Item $i',
          priceCents: 100 + i,
          category: MenuCategory.drinks,
          isAvailable: true,
        ),
    ];
    await pumpTill(tester, menuRepository: StubMenuRepository(items: items));
    for (var i = 0; i < 12; i++) {
      await tester.tap(tile('Item $i'));
      await tester.pump();
    }

    expect(find.text('SEND ORDER').hitTestable(), findsOneWidget);
  });

  group('when sending fails', () {
    testWidgets('keeps the check standing', (tester) async {
      final orders = RejectingOrderRepository();
      await pumpTill(tester, orderRepository: orders);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      expect(find.text('£14.40'), findsNWidgets(2));

      await tester.tap(find.text('SEND ORDER'));
      await tester.pumpAndSettle();

      expect(orders.attempts, 1);
      expect(find.byType(OrderLineRow), findsOneWidget);
      expect(find.text('£14.40'), findsNWidgets(2));
    });

    testWidgets('tells the bartender, in words', (tester) async {
      await pumpTill(tester, orderRepository: RejectingOrderRepository());

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(find.text('SEND ORDER'));
      await tester.pumpAndSettle();

      expect(find.text('Could not send the order'), findsOneWidget);
      expect(
        find.text('The round is still here. Press send again.'),
        findsOneWidget,
      );
      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);
    });

    testWidgets('can be retried without rebuilding the round', (tester) async {
      final orders = RejectingOrderRepository();
      await pumpTill(tester, orderRepository: orders);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();

      await tester.tap(find.text('SEND ORDER'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SEND ORDER'));
      await tester.pumpAndSettle();

      expect(orders.attempts, 2);
      expect(find.byType(OrderLineRow), findsOneWidget);
    });
  });

  group('while a send is in flight', () {
    testWidgets('the button is busy and cannot be pressed twice', (
      tester,
    ) async {
      final orders = HangingOrderRepository();
      await pumpTill(tester, orderRepository: orders);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(find.text('SEND ORDER'));
      await tester.pump();

      expect(find.text('SEND ORDER'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(orders.attempts, 1);

      orders.completer.complete('order-1');
      await tester.pumpAndSettle();
    });

    testWidgets('the check clears once the write lands', (tester) async {
      final orders = HangingOrderRepository();
      await pumpTill(tester, orderRepository: orders);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(find.text('SEND ORDER'));
      await tester.pump();

      orders.completer.complete('order-1');
      await tester.pumpAndSettle();

      expect(find.byType(OrderLineRow), findsNothing);
      expect(find.textContaining('Sent 1 item'), findsOneWidget);
    });
  });

  group('when a category leaves the menu', () {
    MenuItem food(int n) => MenuItem(
      id: 'food-$n',
      name: 'Dish $n',
      priceCents: 900,
      category: MenuCategory.food,
      isAvailable: true,
    );

    testWidgets('its return does not take the till back to it', (tester) async {
      final menuRepository = ControlledMenuRepository();
      menuRepository.controller.add([...menu, food(1)]);
      await pumpTill(tester, menuRepository: menuRepository);

      await tester.tap(find.text('FOOD'));
      await tester.pumpAndSettle();
      expect(tile('Dish 1'), findsOneWidget);

      menuRepository.controller.add(menu);
      await tester.pumpAndSettle();
      expect(tile('Guinness, pint'), findsOneWidget);

      menuRepository.controller.add([...menu, food(1)]);
      await tester.pumpAndSettle();
      expect(tile('Guinness, pint'), findsOneWidget);
      expect(tile('Dish 1'), findsNothing);
    });

    testWidgets('the grid it falls back to starts at the top', (tester) async {
      final menuRepository = ControlledMenuRepository();
      final drinks = [
        for (var n = 1; n <= 30; n++)
          MenuItem(
            id: 'drink-$n',
            name: 'Drink $n',
            priceCents: 500,
            category: MenuCategory.drinks,
            isAvailable: true,
          ),
      ];
      menuRepository.controller.add([
        ...drinks,
        for (var n = 1; n <= 30; n++) food(n),
      ]);
      await pumpTill(tester, menuRepository: menuRepository);

      await tester.tap(find.text('FOOD'));
      await tester.pumpAndSettle();
      final scroll = find.byKey(const ValueKey('menu-scroll'));
      await tester.drag(scroll, const Offset(0, -600));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.pixels, greaterThan(0));

      menuRepository.controller.add(drinks);
      await tester.pumpAndSettle();

      expect(position.pixels, 0);
      expect(tile('Drink 1'), findsOneWidget);
    });
  });

  group('a send in flight', () {
    testWidgets('locks the lines as well as Clear', (tester) async {
      final orders = HangingOrderRepository();
      await pumpTill(tester, orderRepository: orders);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(find.text('SEND ORDER'));
      await tester.pump();

      await tester.tap(find.byType(OrderLineRow));
      await tester.pump();
      await tester.tap(find.text('CLEAR'), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(OrderLineRow), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OrderLineRow),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      orders.completer.complete('order-1');
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a check line says what a tap and a long press do', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpTill(tester);
    await tester.tap(tile('Guinness, pint'));
    await tester.pump();

    expect(
      tester.getSemantics(find.byType(OrderLineRow)),
      // ignore: deprecated_member_use
      containsSemantics(
        onTapHint: 'remove one',
        onLongPressHint: 'remove the whole line',
      ),
    );
    handle.dispose();
  });

  group('when the till can only see its cache', () {
    testWidgets('says OFFLINE and keeps selling from the cached menu', (
      tester,
    ) async {
      final menuRepository = ControlledMenuRepository()..controller.add(menu);
      await pumpTill(tester, menuRepository: menuRepository);
      expect(find.text('LIVE'), findsOneWidget);

      menuRepository.live.add(false);
      await tester.pumpAndSettle();

      expect(find.text('LIVE'), findsNothing);
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(tile('Guinness, pint'), findsOneWidget);

      menuRepository.live.add(true);
      await tester.pumpAndSettle();
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('the connection state is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTill(tester);

      expect(
        tester.getSemantics(find.text('LIVE')),
        // ignore: deprecated_member_use
        containsSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('an empty cache on a first start offline is not "no menu"', (
      tester,
    ) async {
      final menuRepository = ControlledMenuRepository(startLive: false)
        ..controller.add(const []);
      await pumpTill(tester, menuRepository: menuRepository);

      expect(find.text('Waiting for the menu'), findsOneWidget);
      expect(find.text('This venue has no menu yet'), findsNothing);
    });

    testWidgets('a cold start from the cache is CONNECTING, not LIVE', (
      tester,
    ) async {
      final menuRepository = ControlledMenuRepository(startLive: false)
        ..controller.add(menu);
      await pumpTill(tester, menuRepository: menuRepository);

      expect(find.text('LIVE'), findsNothing);
      expect(find.text('CONNECTING'), findsOneWidget);
    });
  });

  for (final (label, scaler) in const [
    ('linear', TextScaler.linear(2)),
    ('non-linear, as Android 14 scales', _AndroidLikeScaler()),
  ]) {
    testWidgets('at twice the text size ($label) nothing overflows or clips', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const big = MenuItem(
        id: 'tasting',
        name: 'Loaded fries with smoked chilli mayo and pickles',
        priceCents: 12500,
        category: MenuCategory.drinks,
        isAvailable: true,
      );
      const pulled = MenuItem(
        id: 'pulled',
        name: 'Veggie burger with halloumi',
        priceCents: 1100,
        category: MenuCategory.drinks,
        isAvailable: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: PosTheme.backbar,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(1194, 834),
              textScaler: scaler,
              disableAnimations: true,
            ),
            child: PosHomePage(
              menuRepository: StubMenuRepository(items: const [big, pulled]),
              orderRepository: RejectingOrderRepository(),
              venue: venue,
              staffUid: 'uid-under-test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byType(MenuTile).first);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(OrderLineRow),
          matching: find.text('10'),
        ),
        findsOneWidget,
      );
    });
  }

  group('when the menu stream breaks mid-round', () {
    testWidgets('does not flag a check it can no longer read against', (
      tester,
    ) async {
      final menuRepository = ControlledMenuRepository()..controller.add(menu);
      await pumpTill(tester, menuRepository: menuRepository);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();

      menuRepository.controller.addError(StateError('unavailable'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot reach the menu'), findsOneWidget);
      expect(find.byType(OrderLineRow), findsOneWidget);
      expect(find.textContaining('No longer on sale'), findsNothing);
    });

    testWidgets('stops claiming to be live', (tester) async {
      final menuRepository = ControlledMenuRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: PosTheme.backbar,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: PosHomePage(
              menuRepository: menuRepository,
              orderRepository: RejectingOrderRepository(),
              venue: venue,
              staffUid: 'uid-under-test',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('CONNECTING'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);

      menuRepository.controller.add(menu);
      await tester.pumpAndSettle();
      expect(find.text('LIVE'), findsOneWidget);

      menuRepository.controller.addError(StateError('unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('LIVE'), findsNothing);
      expect(find.text('OFFLINE'), findsOneWidget);
    });
  });

  testWidgets('a remote rename that re-sorts the grid still flashes the tile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const lager = MenuItem(
      id: 'lager',
      name: 'Lager, pint',
      priceCents: 680,
      category: MenuCategory.drinks,
      isAvailable: true,
    );
    final menuRepository = ControlledMenuRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: PosTheme.backbar,
        home: PosHomePage(
          menuRepository: menuRepository,
          orderRepository: RejectingOrderRepository(),
          venue: venue,
          staffUid: 'uid-under-test',
        ),
      ),
    );
    menuRepository.controller.add([menu.first, lager]);
    await tester.pump();

    menuRepository.controller.add([
      lager.copyWith(name: 'Ale, pint'),
      menu.first,
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final flash = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('Ale, pint'),
              matching: find.byType(ChangeFlash),
            ),
            matching: find.byType(FadeTransition),
          )
          .last,
    );
    expect(flash.opacity.value, greaterThan(0));

    final untouched = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('Guinness, pint'),
              matching: find.byType(ChangeFlash),
            ),
            matching: find.byType(FadeTransition),
          )
          .last,
    );
    expect(untouched.opacity.value, 0);
  });

  for (final size in const [Size(390, 844), Size(375, 667)]) {
    testWidgets(
      'the check on a $size phone never overflows, empty or with a notice',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: PosTheme.backbar,
            home: MediaQuery(
              data: MediaQueryData(size: size, disableAnimations: true),
              child: PosHomePage(
                menuRepository: StubMenuRepository(),
                orderRepository: RejectingOrderRepository(),
                venue: venue,
                staffUid: 'uid-under-test',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(tile('Guinness, pint'));
        await tester.pump();
        await tester.tap(find.text('SEND ORDER'));
        await tester.pumpAndSettle();

        expect(find.text('Could not send the order'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a failed send is announced in the footer, wherever the list is',
    (tester) async {
      await pumpTill(tester, orderRepository: RejectingOrderRepository());

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(find.text('SEND ORDER'));
      await tester.pumpAndSettle();

      expect(
        find.text('Not sent — see above, then send again'),
        findsOneWidget,
      );

      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();
      expect(find.text('Not sent — see above, then send again'), findsNothing);
    },
  );
}

class _AndroidLikeScaler extends TextScaler {
  const _AndroidLikeScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 20 ? fontSize * 2 : 40 + (fontSize - 20) * 0.2;

  @override
  double get textScaleFactor => 2;
}
