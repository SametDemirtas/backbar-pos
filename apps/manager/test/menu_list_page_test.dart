import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show CollectionReference;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager/src/menu_editor_sheet.dart';
import 'package:manager/src/menu_list_page.dart';
import 'package:manager/src/widgets/availability_pill.dart';
import 'package:manager/src/widgets/menu_row.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

const venue = VenueConfig(
  venueId: 'copper-kettle',
  displayName: 'The Copper Kettle',
  currencySymbol: '£',
  tillLabel: 'TILL 1',
);

CollectionReference<Map<String, dynamic>> menuOf(FakeFirebaseFirestore db) =>
    db.collection('venues').doc(venue.venueId).collection('menuItems');

Future<void> seed(
  FakeFirebaseFirestore db,
  String id, {
  required String name,
  required int priceCents,
  MenuCategory category = MenuCategory.drinks,
  bool isAvailable = true,
}) {
  return menuOf(db).doc(id).set({
    'name': name,
    'priceCents': priceCents,
    'category': category.wireValue,
    'isAvailable': isAvailable,
  });
}

Future<void> pumpManager(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  Size size = const Size(390, 844),
  MenuRepository Function(MenuRepository)? wrap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: PosTheme.daylight,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MenuListPage(
          repository: (wrap ?? (repository) => repository)(
            FirestoreMenuRepository(firestore: db, venueId: venue.venueId),
          ),
          venue: venue,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder rowFor(String name) =>
    find.bySemanticsLabel(RegExp('^${RegExp.escape(name)},.*edit\$'));

Future<Map<String, dynamic>?> read(FakeFirebaseFirestore db, String id) async {
  return (await menuOf(db).doc(id).get()).data();
}

class UnacknowledgedRepository implements MenuRepository {
  UnacknowledgedRepository(this.inner);

  final MenuRepository inner;

  @override
  Stream<List<MenuItem>> watchMenu() => inner.watchMenu();

  @override
  Stream<bool> watchMenuIsLive() => inner.watchMenuIsLive();

  @override
  Future<String> create(MenuItemDraft draft) => inner.create(draft);

  @override
  Future<void> update(String itemId, MenuItemPatch patch) =>
      inner.update(itemId, patch);

  @override
  Future<void> setAvailability(String itemId, {required bool isAvailable}) {
    unawaited(inner.setAvailability(itemId, isAvailable: isAvailable));
    return Completer<void>().future;
  }

  @override
  Future<void> delete(String itemId) => inner.delete(itemId);
}

class OfflineRepository extends UnacknowledgedRepository {
  OfflineRepository(super.inner);

  @override
  Future<void> update(String itemId, MenuItemPatch patch) {
    unawaited(inner.update(itemId, patch));
    return Completer<void>().future;
  }
}

class StallingRepository extends UnacknowledgedRepository {
  StallingRepository(super.inner);

  @override
  Future<void> setAvailability(String itemId, {required bool isAvailable}) =>
      Completer<void>().future;

  @override
  Future<void> update(String itemId, MenuItemPatch patch) {
    unawaited(inner.update(itemId, patch));
    return Future<void>.delayed(
      MenuEditorSheet.acknowledgementGrace * 2,
      () => throw StateError('refused'),
    );
  }
}

class OfflineDeleteRepository extends UnacknowledgedRepository {
  OfflineDeleteRepository(super.inner);

  @override
  Future<void> delete(String itemId) {
    unawaited(inner.delete(itemId));
    return Completer<void>().future;
  }
}

class LivenessRepository extends UnacknowledgedRepository {
  LivenessRepository(super.inner, {bool startLive = true}) {
    live.add(startLive);
  }

  final live = StreamController<bool>();

  @override
  Stream<bool> watchMenuIsLive() => live.stream;

  @override
  Future<void> setAvailability(String itemId, {required bool isAvailable}) =>
      inner.setAvailability(itemId, isAvailable: isAvailable);
}

class CountingRepository extends UnacknowledgedRepository {
  CountingRepository(super.inner);

  int creates = 0;

  @override
  Future<String> create(MenuItemDraft draft) {
    creates++;
    return inner.create(draft);
  }
}

class RefusingRepository extends UnacknowledgedRepository {
  RefusingRepository(super.inner);

  @override
  Future<void> update(String itemId, MenuItemPatch patch) =>
      Future.error(StateError('refused'));

  @override
  Future<void> delete(String itemId) => Future.error(StateError('refused'));
}

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await seed(db, 'guinness', name: 'Guinness, pint', priceCents: 720);
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

  group('the list', () {
    testWidgets('leads with what is off, because that is the question', (
      tester,
    ) async {
      await pumpManager(tester, db);

      expect(find.bySemanticsLabel('2 On sale'), findsOneWidget);
      expect(find.bySemanticsLabel('1 Sold out'), findsOneWidget);
      expect(find.bySemanticsLabel('2 Categories'), findsOneWidget);
    });

    testWidgets('shows every item with its price, grouped by category', (
      tester,
    ) async {
      await pumpManager(tester, db);

      expect(find.text('Guinness, pint'), findsOneWidget);
      expect(find.text('£7.20'), findsOneWidget);
      expect(find.text('Loaded fries'), findsOneWidget);
      expect(find.text('£8.00'), findsOneWidget);
      expect(find.bySemanticsLabel('Drinks'), findsOneWidget);
      expect(find.bySemanticsLabel('Food'), findsOneWidget);
    });

    testWidgets('does not hide sold-out items behind a filter', (tester) async {
      await pumpManager(tester, db);

      expect(find.text('Espresso Martini'), findsOneWidget);
      expect(find.byType(SoldOutHatch), findsOneWidget);
      expect(
        find.bySemanticsLabel('Sold out, Espresso Martini'),
        findsOneWidget,
      );
    });

    testWidgets('says so when the venue has no menu at all', (tester) async {
      final empty = FakeFirebaseFirestore();
      await pumpManager(tester, empty);

      expect(find.text('No menu yet'), findsOneWidget);
    });
  });

  group('the sold-out switch', () {
    testWidgets('marks an item sold out with one tap', (tester) async {
      await pumpManager(tester, db);

      await tester.tap(find.bySemanticsLabel('On sale, Guinness, pint'));
      await tester.pumpAndSettle();

      expect((await read(db, 'guinness'))!['isAvailable'], isFalse);
      expect(find.bySemanticsLabel('2 Sold out'), findsOneWidget);
    });

    testWidgets('puts one back on sale', (tester) async {
      await pumpManager(tester, db);

      await tester.tap(find.bySemanticsLabel('Sold out, Espresso Martini'));
      await tester.pumpAndSettle();

      expect((await read(db, 'martini'))!['isAvailable'], isTrue);
      expect(find.bySemanticsLabel('0 Sold out'), findsOneWidget);
    });

    testWidgets('sends an item with an unusable price to the editor', (
      tester,
    ) async {
      await menuOf(db).doc('coke').set({
        'name': 'Coke, bottle',
        'priceCents': 3.5,
        'category': 'drinks',
        'isAvailable': true,
      });
      await pumpManager(tester, db);

      await tester.tap(find.bySemanticsLabel('Sold out, Coke, bottle'));
      await tester.pumpAndSettle();

      expect(find.text('Edit item'), findsOneWidget);
      expect(find.textContaining('has no usable price'), findsOneWidget);
      final stored = (await read(db, 'coke'))!;
      expect(stored['priceCents'], 3.5);
      expect(stored['isAvailable'], isTrue, reason: 'nothing was written');
    });

    testWidgets('sends a nameless item to the editor rather than writing', (
      tester,
    ) async {
      await menuOf(db).doc('blank').set({
        'name': '  ',
        'priceCents': 500,
        'category': 'drinks',
        'isAvailable': true,
      });
      await pumpManager(tester, db);

      await tester.tap(find.bySemanticsLabel('Sold out, Unnamed item'));
      await tester.pumpAndSettle();

      expect(find.text('Edit item'), findsOneWidget);
      expect(find.textContaining('has no name'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Olives');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      final stored = (await read(db, 'blank'))!;
      expect(stored['name'], 'Olives');
      expect(stored['isAvailable'], isFalse);
    });

    testWidgets('an edit writes back a name stored with stray spaces', (
      tester,
    ) async {
      await menuOf(db).doc('olives').set({
        'name': 'Olives${' ' * 58}',
        'priceCents': 450,
        'category': 'snacks',
        'isAvailable': true,
      });
      await pumpManager(tester, db);
      await tester.tap(rowFor('Olives'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, '4.75');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      final stored = (await read(db, 'olives'))!;
      expect(stored['name'], 'Olives');
      expect(stored['priceCents'], 475);
    });

    testWidgets('an edit repairs a missing category and a string flag', (
      tester,
    ) async {
      await menuOf(db).doc('stout').set({
        'name': 'Stout',
        'priceCents': 500,
        'isAvailable': 'true',
      });
      await pumpManager(tester, db);
      await tester.tap(rowFor('Stout'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, '5.50');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      final stored = (await read(db, 'stout'))!;
      expect(stored['priceCents'], 550);
      expect(stored['category'], MenuCategory.fallback.wireValue);
      expect(stored['isAvailable'], isFalse);
    });

    testWidgets('fixing an unusable price saves the availability shown', (
      tester,
    ) async {
      await menuOf(db).doc('coke').set({
        'name': 'Coke, bottle',
        'priceCents': 3.5,
        'category': 'drinks',
        'isAvailable': true,
      });
      await pumpManager(tester, db);
      await tester.tap(find.bySemanticsLabel('Sold out, Coke, bottle'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).last, '3.50');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      final stored = (await read(db, 'coke'))!;
      expect(stored['priceCents'], 350);
      expect(stored['isAvailable'], isFalse);
    });

    testWidgets('shows … while a write is in flight', (tester) async {
      await pumpManager(tester, db, wrap: StallingRepository.new);

      await tester.tap(find.bySemanticsLabel('On sale, Guinness, pint'));
      await tester.pump();

      expect(find.text('UPDATING'), findsOneWidget);
    });

    testWidgets('does not hang on "…" when the write is never acknowledged', (
      tester,
    ) async {
      await pumpManager(tester, db, wrap: UnacknowledgedRepository.new);

      await tester.tap(find.bySemanticsLabel('On sale, Guinness, pint'));
      await tester.pumpAndSettle();

      expect(find.text('UPDATING'), findsNothing);
      expect(find.bySemanticsLabel('Sold out, Guinness, pint'), findsOneWidget);

      await menuOf(db).doc('guinness').update({'isAvailable': true});
      await tester.pumpAndSettle();
      expect(find.text('UPDATING'), findsNothing);
      expect(find.bySemanticsLabel('On sale, Guinness, pint'), findsOneWidget);
    });

    testWidgets('the pill is named by what it shows, the action is the hint', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpManager(tester, db);

      expect(
        tester.getSemantics(find.bySemanticsLabel('On sale, Guinness, pint')),
        // ignore: deprecated_member_use
        containsSemantics(onTapHint: 'mark sold out'),
      );
      expect(find.text('ON SALE'), findsWidgets);
      handle.dispose();
    });

    testWidgets('leaves the price and name alone', (tester) async {
      await pumpManager(tester, db);

      await tester.tap(find.bySemanticsLabel('On sale, Guinness, pint'));
      await tester.pumpAndSettle();

      final stored = (await read(db, 'guinness'))!;
      expect(stored['name'], 'Guinness, pint');
      expect(stored['priceCents'], 720);
    });
  });

  group('creating an item', () {
    testWidgets('writes it and it appears in the list', (tester) async {
      await pumpManager(tester, db);

      await tester.tap(find.text('NEW ITEM'));
      await tester.pumpAndSettle();

      expect(find.text('New item'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Neck Oil IPA');
      await tester.enterText(find.byType(TextFormField).last, '6.50');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(find.text('Neck Oil IPA'), findsOneWidget);
      expect(find.text('£6.50'), findsOneWidget);

      final docs = (await menuOf(db).get()).docs;
      expect(docs, hasLength(4));
    });

    testWidgets('two taps on Save in one frame make one item', (tester) async {
      late CountingRepository repository;
      await pumpManager(
        tester,
        db,
        wrap: (inner) => repository = CountingRepository(inner),
      );

      await tester.tap(find.text('NEW ITEM'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Neck Oil IPA');
      await tester.enterText(find.byType(TextFormField).last, '6.50');
      final save = tester.getCenter(find.text('SAVE'));
      await tester.tapAt(save);
      await tester.tapAt(save);
      await tester.pumpAndSettle();

      expect(repository.creates, 1);
      expect((await menuOf(db).get()).docs, hasLength(4));
    });

    testWidgets('a new item lands on sale', (tester) async {
      await pumpManager(tester, db);

      await tester.tap(find.text('NEW ITEM'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Neck Oil IPA');
      await tester.enterText(find.byType(TextFormField).last, '6.50');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('3 On sale'), findsOneWidget);
    });

    testWidgets('files it under the chosen category', (tester) async {
      await pumpManager(tester, db);

      await tester.tap(find.text('NEW ITEM'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Tote bag');
      await tester.enterText(find.byType(TextFormField).last, '15');
      await tester.tap(find.bySemanticsLabel('Merch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      final docs = (await menuOf(db).get()).docs;
      final created = docs.firstWhere(
        (doc) => doc.data()['name'] == 'Tote bag',
      );
      expect(created.data()['category'], 'merch');
    });
  });

  group('validation', () {
    Future<void> openNew(WidgetTester tester) async {
      await pumpManager(tester, db);
      await tester.tap(find.text('NEW ITEM'));
      await tester.pumpAndSettle();
    }

    testWidgets('refuses a nameless item and says why it matters', (
      tester,
    ) async {
      await openNew(tester);

      await tester.enterText(find.byType(TextFormField).last, '6.50');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('this is what the bartender reads'),
        findsOneWidget,
      );
      expect((await menuOf(db).get()).docs, hasLength(3));
    });

    testWidgets('a refused save is announced even when focus cannot move', (
      tester,
    ) async {
      final announced = <Object?>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            announced.add(message);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );

      await pumpManager(tester, db);
      await tester.tap(find.text('NEW ITEM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(announced.toString(), contains('Give the item a name'));
    });

    testWidgets('a refused save takes focus to the field that needs fixing', (
      tester,
    ) async {
      await pumpManager(tester, db);
      await tester.tap(find.text('NEW ITEM'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '4.50');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).first,
          matching: find.byType(TextField),
        ),
      );
      expect(nameField.focusNode!.hasFocus, isTrue);
    });

    testWidgets('refuses a free drink', (tester) async {
      await openNew(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Free pint');
      await tester.enterText(find.byType(TextFormField).last, '0.00');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(find.textContaining('pour free drinks all night'), findsOneWidget);
      expect((await menuOf(db).get()).docs, hasLength(3));
    });

    testWidgets('refuses a price that is not a price', (tester) async {
      await openNew(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Mystery');
      await tester.enterText(find.byType(TextFormField).last, '12.999');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(find.textContaining('That is not a price'), findsOneWidget);
      expect((await menuOf(db).get()).docs, hasLength(3));
    });

    testWidgets('will not accept letters in the price field at all', (
      tester,
    ) async {
      await openNew(tester);

      await tester.enterText(find.byType(TextFormField).last, 'abc7.20xyz');
      await tester.pump();

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, '7.20');
    });
  });

  group('editing an item', () {
    Future<void> openEdit(WidgetTester tester, String name) async {
      await pumpManager(tester, db);
      await tester.tap(rowFor(name));
      await tester.pumpAndSettle();
    }

    testWidgets('large text puts the categories in two rows of two', (
      tester,
    ) async {
      Future<Map<String, Offset>> layout(TextScaler scaler) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: PosTheme.daylight,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: scaler, disableAnimations: true),
              child: child!,
            ),
            home: MenuListPage(
              repository: FirestoreMenuRepository(
                firestore: db,
                venueId: venue.venueId,
              ),
              venue: venue,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('NEW ITEM'));
        await tester.pumpAndSettle();
        final centres = {
          for (final label in ['DRINKS', 'FOOD', 'SNACKS', 'MERCH'])
            label: tester.getCenter(find.text(label).last),
        };
        Navigator.of(tester.element(find.text('New item'))).pop();
        await tester.pumpAndSettle();
        return centres;
      }

      final normal = await layout(TextScaler.noScaling);
      expect(normal.values.map((c) => c.dy).toSet(), hasLength(1));

      final large = await layout(const TextScaler.linear(2));
      expect(large['FOOD']!.dy, large['DRINKS']!.dy);
      expect(large['MERCH']!.dy, large['SNACKS']!.dy);
      expect(large['SNACKS']!.dy, greaterThan(large['DRINKS']!.dy));
      expect(large['SNACKS']!.dx, large['DRINKS']!.dx);
      expect(large['MERCH']!.dx, large['FOOD']!.dx);
      expect(large['FOOD']!.dx, greaterThan(large['DRINKS']!.dx));
    });

    testWidgets('names its fields and its single choice for a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openEdit(tester, 'Guinness, pint');

      expect(find.bySemanticsLabel(RegExp(r'^Name')), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Name'))),
        // ignore: deprecated_member_use
        containsSemantics(isTextField: true),
        reason: 'the label must merge into the field, not sit beside it',
      );
      expect(find.bySemanticsLabel(RegExp(r'^Price')), findsOneWidget);
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byType(MenuEditorSheet),
            matching: find.bySemanticsLabel('Drinks'),
          ),
        ),
        // ignore: deprecated_member_use
        containsSemantics(isInMutuallyExclusiveGroup: true, isChecked: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Edit item')),
        // ignore: deprecated_member_use
        containsSemantics(isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('at twice the text size the sheet does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: PosTheme.daylight,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: MenuListPage(
            repository: FirestoreMenuRepository(
              firestore: db,
              venueId: venue.venueId,
            ),
            venue: venue,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(rowFor('Guinness, pint'));
      await tester.pumpAndSettle();

      expect(find.text('Edit item'), findsOneWidget);
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('Edit item'))),
        const TextScaler.linear(2),
        reason: 'the sheet itself must be rendered at 2x',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens populated with what is stored', (tester) async {
      await openEdit(tester, 'Guinness, pint');

      expect(find.text('Edit item'), findsOneWidget);

      final fields = tester
          .widgetList<TextField>(
            find.descendant(
              of: find.byType(TextFormField),
              matching: find.byType(TextField),
            ),
          )
          .toList();
      expect(fields.first.controller!.text, 'Guinness, pint');
      expect(fields.last.controller!.text, '7.20');
    });

    testWidgets('saves a new name and price', (tester) async {
      await openEdit(tester, 'Guinness, pint');

      await tester.enterText(find.byType(TextFormField).first, 'Guinness');
      await tester.enterText(find.byType(TextFormField).last, '7.50');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      final stored = (await read(db, 'guinness'))!;
      expect(stored['name'], 'Guinness');
      expect(stored['priceCents'], 750);
      expect(find.text('£7.50'), findsOneWidget);
    });

    testWidgets('can pull an item from inside the editor', (tester) async {
      await openEdit(tester, 'Guinness, pint');

      await tester.tap(find.bySemanticsLabel('On sale, availability'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect((await read(db, 'guinness'))!['isAvailable'], isFalse);
    });

    testWidgets('flipping availability and back writes nothing', (
      tester,
    ) async {
      await openEdit(tester, 'Guinness, pint');

      await menuOf(db).doc('guinness').update({'isAvailable': false});
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('On sale, availability'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Sold out, availability'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Guinness');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      final stored = (await read(db, 'guinness'))!;
      expect(stored['name'], 'Guinness');
      expect(stored['isAvailable'], isFalse, reason: "the colleague's change");
    });

    testWidgets('an edit made offline closes the sheet and says so', (
      tester,
    ) async {
      await pumpManager(tester, db, wrap: OfflineRepository.new);
      await tester.tap(rowFor('Guinness, pint'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Guinness');
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      expect(find.text('Edit item'), findsOneWidget);

      await tester.pump(MenuEditorSheet.acknowledgementGrace);
      await tester.pumpAndSettle();

      expect(find.text('Edit item'), findsNothing);
      expect(find.textContaining('Saved on this phone'), findsOneWidget);
      expect((await read(db, 'guinness'))!['name'], 'Guinness');
    });

    testWidgets('a save refused after the sheet closed is still reported', (
      tester,
    ) async {
      await pumpManager(tester, db, wrap: StallingRepository.new);
      await tester.tap(rowFor('Guinness, pint'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Guinness');
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      await tester.pump(MenuEditorSheet.acknowledgementGrace);
      await tester.pumpAndSettle();
      expect(find.text('Edit item'), findsNothing);

      await tester.pump(MenuEditorSheet.acknowledgementGrace);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not save'), findsOneWidget);
    });

    testWidgets('a refused save is explained inside the sheet', (tester) async {
      await pumpManager(tester, db, wrap: RefusingRepository.new);
      await tester.tap(rowFor('Guinness, pint'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Guinness');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(find.text('Edit item'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MenuEditorSheet),
          matching: find.textContaining('Could not save'),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('a delete made offline closes the sheet and says so', (
    tester,
  ) async {
    await pumpManager(tester, db, wrap: OfflineDeleteRepository.new);
    await tester.tap(rowFor('Guinness, pint'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DELETE ITEM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(MenuEditorSheet.acknowledgementGrace);
    await tester.pumpAndSettle();

    expect(find.text('Edit item'), findsNothing);
    expect(find.textContaining('Deleted on this phone'), findsOneWidget);
    expect(await read(db, 'guinness'), isNull);
  });

  testWidgets('an empty list before the server answers is not an empty menu', (
    tester,
  ) async {
    final empty = FakeFirebaseFirestore();
    late LivenessRepository repository;
    await pumpManager(
      tester,
      empty,
      wrap: (inner) => repository = LivenessRepository(inner, startLive: false),
    );
    expect(find.text('Waiting for the menu'), findsOneWidget);
    expect(find.text('The Copper Kettle'), findsOneWidget);
    expect(find.text('CONNECTING'), findsOneWidget);

    repository.live.add(true);
    await tester.pumpAndSettle();
    expect(find.text('No menu yet'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
  });

  testWidgets('says OFFLINE when the list is only the cached copy', (
    tester,
  ) async {
    late LivenessRepository repository;
    await pumpManager(
      tester,
      db,
      wrap: (inner) => repository = LivenessRepository(inner),
    );
    expect(find.text('LIVE'), findsOneWidget);

    repository.live.add(false);
    await tester.pumpAndSettle();
    expect(find.text('LIVE'), findsNothing);
    expect(find.text('OFFLINE'), findsOneWidget);
  });

  testWidgets('a refused delete is explained inside the sheet', (tester) async {
    await pumpManager(tester, db, wrap: RefusingRepository.new);
    await tester.tap(rowFor('Guinness, pint'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('DELETE ITEM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Edit item'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MenuEditorSheet),
        matching: find.textContaining('Could not delete'),
      ),
      findsOneWidget,
    );
    expect(await read(db, 'guinness'), isNotNull);
  });

  group('deleting an item', () {
    testWidgets('asks first, and explains the softer option', (tester) async {
      await pumpManager(tester, db);
      await tester.tap(rowFor('Guinness, pint'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DELETE ITEM'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this item?'), findsOneWidget);
      expect(
        find.textContaining('Marking it sold out keeps it on the menu'),
        findsOneWidget,
      );
      final deleteStyle = DefaultTextStyle.of(
        tester.element(find.text('Delete')),
      ).style;
      expect(
        deleteStyle.color,
        PosPalette.of(tester.element(find.text('Delete'))).emberInk,
      );

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(await read(db, 'guinness'), isNotNull);
    });

    testWidgets('removes it from every till once confirmed', (tester) async {
      await pumpManager(tester, db);
      await tester.tap(rowFor('Guinness, pint'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('DELETE ITEM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await read(db, 'guinness'), isNull);
      expect(find.text('Guinness, pint'), findsNothing);
    });
  });

  group('changes made elsewhere', () {
    testWidgets('another manager\'s edit lands without a restart', (
      tester,
    ) async {
      await pumpManager(tester, db);
      expect(find.text('£7.20'), findsOneWidget);

      await FirestoreMenuRepository(
        firestore: db,
        venueId: venue.venueId,
      ).update('guinness', const MenuItemPatch(priceCents: 850));
      await tester.pumpAndSettle();

      expect(find.text('£8.50'), findsOneWidget);
    });

    testWidgets('the sold-out count follows a change made elsewhere', (
      tester,
    ) async {
      await pumpManager(tester, db);
      expect(find.bySemanticsLabel('1 Sold out'), findsOneWidget);

      await FirestoreMenuRepository(
        firestore: db,
        venueId: venue.venueId,
      ).setAvailability('fries', isAvailable: false);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('2 Sold out'), findsOneWidget);
    });
  });

  testWidgets('the availability pill paints its ink where it can be seen', (
    tester,
  ) async {
    await pumpManager(tester, db);
    final ink = find.descendant(
      of: find.byType(AvailabilityPill).first,
      matching: find.byType(InkWell),
    );

    final material = tester.widget<Material>(
      find.ancestor(of: ink, matching: find.byType(Material)).first,
    );
    expect(material.type, MaterialType.transparency);
    expect(
      find.descendant(of: ink, matching: find.byType(Ink)),
      findsOneWidget,
    );
  });

  group('the row', () {
    testWidgets('is tall enough to hit without looking', (tester) async {
      await pumpManager(tester, db);

      for (final row in tester.widgetList<MenuRow>(find.byType(MenuRow))) {
        final size = tester.getSize(find.byWidget(row));
        expect(size.height, greaterThanOrEqualTo(PosTouch.control));
      }

      final switchSize = tester.getSize(find.byType(AvailabilityPill).first);
      expect(switchSize.height, greaterThanOrEqualTo(PosTouch.control));
    });
  });

  group('on a desktop window', () {
    testWidgets('holds the phone layout to a readable width', (tester) async {
      await pumpManager(tester, db, size: const Size(1440, 900));

      final row = tester.getSize(rowFor('Guinness, pint').first);
      expect(
        row.width,
        lessThanOrEqualTo(560),
        reason:
            'a row stretched across a desktop puts the name and its switch '
            'a screen apart',
      );
    });

    testWidgets('still gives the list its full height', (tester) async {
      await pumpManager(tester, db, size: const Size(1440, 900));

      final list = tester.getSize(find.byType(CustomScrollView).first);
      expect(list.height, greaterThan(200));
      expect(find.byType(MenuRow), findsNWidgets(3));
    });
  });
}
