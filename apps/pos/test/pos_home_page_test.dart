import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';
import 'package:pos/src/pos_home_page.dart';
import 'package:pos/src/widgets/marquee_rail.dart';
import 'package:pos/src/widgets/menu_tile.dart';
import 'package:pos/src/widgets/order_panel.dart';

const venue = VenueConfig(
  venueId: 'copper-kettle',
  displayName: 'The Copper Kettle',
  currencySymbol: '£',
  tillLabel: 'TILL 2',
);

Future<void> seed(
  FakeFirebaseFirestore db,
  String id, {
  required String name,
  required int priceCents,
  MenuCategory category = MenuCategory.drinks,
  bool isAvailable = true,
}) {
  return db
      .collection('venues')
      .doc(venue.venueId)
      .collection('menuItems')
      .doc(id)
      .set({
        'name': name,
        'priceCents': priceCents,
        'category': category.wireValue,
        'isAvailable': isAvailable,
      });
}

Future<void> pumpTill(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  Size size = const Size(1194, 834),
  String staffUid = 'uid-under-test',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: PosTheme.backbar,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: PosHomePage(
          menuRepository: FirestoreMenuRepository(
            firestore: db,
            venueId: venue.venueId,
          ),
          orderRepository: FirestoreOrderRepository(
            firestore: db,
            venueId: venue.venueId,
          ),
          venue: venue,
          staffUid: staffUid,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder tile(String name) =>
    find.descendant(of: find.byType(MenuTile), matching: find.text(name));

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await seed(db, 'guinness', name: 'Guinness, pint', priceCents: 720);
    await seed(db, 'hells', name: 'Camden Hells Lager', priceCents: 680);
    await seed(
      db,
      'martini',
      name: 'Espresso Martini',
      priceCents: 1250,
      isAvailable: false,
    );
    await seed(
      db,
      'fries',
      name: 'Loaded fries',
      priceCents: 800,
      category: MenuCategory.food,
    );
  });

  group('the menu', () {
    testWidgets('shows the venue name and the till it is', (tester) async {
      await pumpTill(tester, db);

      expect(find.text('The Copper Kettle'), findsOneWidget);
      expect(find.textContaining('TILL 2'), findsWidgets);
    });

    testWidgets('shows name, price and availability for the open category', (
      tester,
    ) async {
      await pumpTill(tester, db);

      expect(find.text('Guinness, pint'), findsOneWidget);
      expect(find.text('£7.20'), findsOneWidget);
      expect(find.text('Camden Hells Lager'), findsOneWidget);
      expect(find.text('£6.80'), findsOneWidget);
    });

    testWidgets('keeps a sold-out item on the grid, marked', (tester) async {
      await pumpTill(tester, db);

      expect(find.text('Espresso Martini'), findsOneWidget);
      expect(find.text('SOLD OUT'), findsOneWidget);
      expect(find.byType(SoldOutHatch), findsOneWidget);
    });

    testWidgets('separates categories behind the rail', (tester) async {
      await pumpTill(tester, db);

      expect(find.text('Loaded fries'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Food'));
      await tester.pumpAndSettle();

      expect(find.text('Loaded fries'), findsOneWidget);
      expect(find.text('Guinness, pint'), findsNothing);
    });

    testWidgets('offers only categories that have something in them', (
      tester,
    ) async {
      await pumpTill(tester, db);

      expect(find.bySemanticsLabel('Drinks'), findsOneWidget);
      expect(find.bySemanticsLabel('Food'), findsOneWidget);
      expect(find.bySemanticsLabel('Merch'), findsNothing);
      expect(find.bySemanticsLabel('Snacks'), findsNothing);
    });
  });

  group('building an order', () {
    testWidgets('a tap adds the item and moves the running total', (
      tester,
    ) async {
      await pumpTill(tester, db);

      expect(find.text('£0.00'), findsOneWidget);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();

      expect(find.text('£7.20'), findsNWidgets(3));
      expect(find.textContaining('1 ITEM'), findsOneWidget);
    });

    testWidgets('tapping twice increments one line rather than adding two', (
      tester,
    ) async {
      await pumpTill(tester, db);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(tile('Guinness, pint'));
      await tester.pump();

      expect(find.byType(OrderLineRow), findsOneWidget);
      expect(find.text('£14.40'), findsNWidgets(2));
      expect(find.textContaining('2 ITEMS'), findsOneWidget);
    });

    testWidgets('adds up across different items', (tester) async {
      await pumpTill(tester, db);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(tile('Camden Hells Lager'));
      await tester.pump();

      expect(find.byType(OrderLineRow), findsNWidgets(2));
      expect(find.text('£14.00'), findsOneWidget);
    });

    testWidgets('a sold-out item cannot be added at all', (tester) async {
      await pumpTill(tester, db);

      await tester.tap(tile('Espresso Martini'), warnIfMissed: false);
      await tester.pump();

      expect(find.byType(OrderLineRow), findsNothing);
      expect(find.text('£0.00'), findsOneWidget);
    });

    testWidgets('a tap on a line takes one back off', (tester) async {
      await pumpTill(tester, db);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      expect(find.text('£14.40'), findsNWidgets(2));

      await tester.tap(find.byType(OrderLineRow));
      await tester.pump();

      expect(find.text('£7.20'), findsNWidgets(3));
      expect(find.byType(OrderLineRow), findsOneWidget);
    });

    testWidgets('clear empties the check', (tester) async {
      await pumpTill(tester, db);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();

      await tester.tap(find.text('CLEAR'));
      await tester.pump();

      expect(find.byType(OrderLineRow), findsNothing);
      expect(find.text('£0.00'), findsOneWidget);
      expect(find.text('Tap the menu to start a round.'), findsOneWidget);
    });

    testWidgets('nothing can be sent while the check is empty', (tester) async {
      await pumpTill(tester, db);

      final ink = tester.widget<InkWell>(
        find.descendant(
          of: find.ancestor(
            of: find.text('SEND ORDER'),
            matching: find.byType(PosButton),
          ),
          matching: find.byType(InkWell),
        ),
      );

      expect(ink.onTap, isNull);
    });
  });

  group('remote menu changes', () {
    testWidgets('a price change from the manager app lands with no restart', (
      tester,
    ) async {
      await pumpTill(tester, db);
      expect(find.text('£7.20'), findsOneWidget);

      final repository = FirestoreMenuRepository(
        firestore: db,
        venueId: venue.venueId,
      );
      await repository.update(
        'guinness',
        const MenuItemPatch(
          name: 'Guinness, pint',
          priceCents: 750,
          category: MenuCategory.drinks,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('£7.50'), findsOneWidget);
      expect(find.text('£7.20'), findsNothing);
    });

    testWidgets('a new item appears without a restart', (tester) async {
      await pumpTill(tester, db);
      expect(find.text('Neck Oil IPA'), findsNothing);

      await FirestoreMenuRepository(
        firestore: db,
        venueId: venue.venueId,
      ).create(
        const MenuItemDraft(
          name: 'Neck Oil IPA',
          priceCents: 650,
          category: MenuCategory.drinks,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Neck Oil IPA'), findsOneWidget);
    });

    testWidgets('a deleted item disappears without a restart', (tester) async {
      await pumpTill(tester, db);
      expect(find.text('Camden Hells Lager'), findsOneWidget);

      await FirestoreMenuRepository(
        firestore: db,
        venueId: venue.venueId,
      ).delete('hells');
      await tester.pumpAndSettle();

      expect(find.text('Camden Hells Lager'), findsNothing);
    });

    testWidgets('an item marked sold out becomes unsellable in place', (
      tester,
    ) async {
      await pumpTill(tester, db);
      expect(find.text('SOLD OUT'), findsOneWidget);

      await FirestoreMenuRepository(
        firestore: db,
        venueId: venue.venueId,
      ).setAvailability('guinness', isAvailable: false);
      await tester.pumpAndSettle();

      expect(find.text('SOLD OUT'), findsNWidgets(2));

      await tester.tap(tile('Guinness, pint'), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(OrderLineRow), findsNothing);
    });

    testWidgets(
      'an item that goes sold out mid-round is flagged, not deleted',
      (tester) async {
        await pumpTill(tester, db);

        await tester.tap(tile('Guinness, pint'));
        await tester.pump();
        expect(find.text('£7.20'), findsNWidgets(3));

        await FirestoreMenuRepository(
          firestore: db,
          venueId: venue.venueId,
        ).setAvailability('guinness', isAvailable: false);
        await tester.pumpAndSettle();

        expect(find.byType(OrderLineRow), findsOneWidget);
        expect(find.textContaining('No longer on sale'), findsOneWidget);
      },
    );

    testWidgets('the till survives the menu emptying underneath it', (
      tester,
    ) async {
      await pumpTill(tester, db);

      final menu = db
          .collection('venues')
          .doc(venue.venueId)
          .collection('menuItems');
      for (final doc in (await menu.get()).docs) {
        await doc.reference.delete();
      }
      await tester.pumpAndSettle();

      expect(find.text('This venue has no menu yet'), findsOneWidget);
    });
  });

  group('sending', () {
    testWidgets('writes the check, clears it and says so', (tester) async {
      await pumpTill(tester, db);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();
      await tester.tap(tile('Camden Hells Lager'));
      await tester.pump();

      await tester.tap(find.text('SEND ORDER'));
      await tester.pumpAndSettle();

      final orders = await db
          .collection('venues')
          .doc(venue.venueId)
          .collection('orders')
          .get();

      expect(orders.docs, hasLength(1));
      final stored = orders.docs.single.data();
      expect(stored['totalCents'], 1400);
      expect(stored['itemCount'], 2);
      expect(stored['tillLabel'], 'TILL 2');
      expect(stored['staffUid'], 'uid-under-test');

      expect(find.byType(OrderLineRow), findsNothing);
      expect(find.textContaining('Sent 2 items'), findsOneWidget);
    });

    testWidgets('the submitted record holds the price at the time of the tap', (
      tester,
    ) async {
      await pumpTill(tester, db);

      await tester.tap(tile('Guinness, pint'));
      await tester.pump();

      await FirestoreMenuRepository(
        firestore: db,
        venueId: venue.venueId,
      ).update(
        'guinness',
        const MenuItemPatch(
          name: 'Guinness, pint',
          priceCents: 900,
          category: MenuCategory.drinks,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('SEND ORDER'));
      await tester.pumpAndSettle();

      final orders = await db
          .collection('venues')
          .doc(venue.venueId)
          .collection('orders')
          .get();

      expect(
        orders.docs.single.data()['totalCents'],
        720,
        reason: 'the customer was quoted £7.20 and that is what they pay',
      );
    });
  });

  group('layout', () {
    testWidgets('drops the vertical rail when the window is narrow', (
      tester,
    ) async {
      await pumpTill(tester, db, size: const Size(700, 900));

      expect(
        tester.widget<MarqueeRail>(find.byType(MarqueeRail)).axis,
        Axis.horizontal,
      );
      expect(find.byType(MenuTile), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
