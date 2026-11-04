import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

const venueId = 'copper-kettle';

CollectionReference<Map<String, dynamic>> menuOf(FakeFirebaseFirestore db) =>
    db.collection('venues').doc(venueId).collection('menuItems');

Future<void> seed(
  FakeFirebaseFirestore db,
  String id, {
  required String name,
  int priceCents = 720,
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

void main() {
  late FakeFirebaseFirestore db;
  late MenuRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirestoreMenuRepository(firestore: db, venueId: venueId);
  });

  test('watchMenuIsLive reports a server-confirmed menu', () async {
    await seed(db, 'guinness', name: 'Guinness, pint');

    expect(await repository.watchMenuIsLive().first, isTrue);
  });

  group('watchMenu', () {
    test('emits the venue menu, typed', () async {
      await seed(db, 'guinness', name: 'Guinness, pint', priceCents: 720);

      final menu = await repository.watchMenu().first;

      expect(menu, hasLength(1));
      expect(menu.single, isA<MenuItem>());
      expect(menu.single.id, 'guinness');
      expect(menu.single.name, 'Guinness, pint');
      expect(menu.single.priceCents, 720);
    });

    test('keeps sold-out items in the stream', () async {
      await seed(db, 'negroni', name: 'Negroni', isAvailable: false);

      final menu = await repository.watchMenu().first;

      expect(menu, hasLength(1));
      expect(menu.single.isAvailable, isFalse);
    });

    test('is scoped to its venue and sees nothing from another', () async {
      await seed(db, 'guinness', name: 'Guinness');
      await db
          .collection('venues')
          .doc('some-other-venue')
          .collection('menuItems')
          .doc('x')
          .set({
            'name': 'Not ours',
            'priceCents': 100,
            'category': 'drinks',
            'isAvailable': true,
          });

      final menu = await repository.watchMenu().first;

      expect(menu.map((item) => item.name), ['Guinness']);
    });

    test('emits again when an item changes, with no re-subscribe', () async {
      await seed(db, 'guinness', name: 'Guinness', isAvailable: true);

      final emissions = <List<MenuItem>>[];
      final subscription = repository.watchMenu().listen(emissions.add);
      await pumpEventQueue();

      await repository.setAvailability('guinness', isAvailable: false);
      await pumpEventQueue();

      await subscription.cancel();

      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.first.single.isAvailable, isTrue);
      expect(emissions.last.single.isAvailable, isFalse);
    });

    test(
      'emits an empty menu rather than failing when there is none',
      () async {
        expect(await repository.watchMenu().first, isEmpty);
      },
    );
  });

  group('sortForDisplay', () {
    test('orders by category, then name, then id', () {
      const items = [
        MenuItem(
          id: 'z',
          name: 'Tote bag',
          priceCents: 1500,
          category: MenuCategory.merch,
          isAvailable: true,
        ),
        MenuItem(
          id: 'b',
          name: 'apple juice',
          priceCents: 300,
          category: MenuCategory.drinks,
          isAvailable: true,
        ),
        MenuItem(
          id: 'a',
          name: 'Apple juice',
          priceCents: 300,
          category: MenuCategory.drinks,
          isAvailable: true,
        ),
        MenuItem(
          id: 'c',
          name: 'Loaded fries',
          priceCents: 800,
          category: MenuCategory.food,
          isAvailable: true,
        ),
      ];

      final sorted = MenuRepository.sortForDisplay(items);

      expect(sorted.map((item) => item.id), ['a', 'b', 'c', 'z']);
    });

    test(
      'is case insensitive on name, so casing does not scatter a section',
      () {
        const items = [
          MenuItem(
            id: '1',
            name: 'zinfandel',
            priceCents: 700,
            category: MenuCategory.drinks,
            isAvailable: true,
          ),
          MenuItem(
            id: '2',
            name: 'Aperol Spritz',
            priceCents: 1000,
            category: MenuCategory.drinks,
            isAvailable: true,
          ),
        ];

        expect(MenuRepository.sortForDisplay(items).map((item) => item.name), [
          'Aperol Spritz',
          'zinfandel',
        ]);
      },
    );

    test('does not mutate the list it was given', () {
      const items = [
        MenuItem(
          id: 'b',
          name: 'B',
          priceCents: 1,
          category: MenuCategory.food,
          isAvailable: true,
        ),
        MenuItem(
          id: 'a',
          name: 'A',
          priceCents: 1,
          category: MenuCategory.drinks,
          isAvailable: true,
        ),
      ];

      MenuRepository.sortForDisplay(items);

      expect(items.map((item) => item.id), ['b', 'a']);
    });
  });

  group('create', () {
    test('writes the draft and stamps server timestamps', () async {
      final id = await repository.create(
        const MenuItemDraft(
          name: 'Espresso Martini',
          priceCents: 1250,
          category: MenuCategory.drinks,
        ),
      );

      final stored = (await menuOf(db).doc(id).get()).data()!;

      expect(stored['name'], 'Espresso Martini');
      expect(stored['priceCents'], 1250);
      expect(stored['category'], 'drinks');
      expect(stored['isAvailable'], isTrue);
      expect(stored['createdAt'], isNotNull);
      expect(stored['updatedAt'], isNotNull);
    });

    test('a new item defaults to on sale', () async {
      final id = await repository.create(
        const MenuItemDraft(
          name: 'Neck Oil IPA',
          priceCents: 650,
          category: MenuCategory.drinks,
        ),
      );

      final menu = await repository.watchMenu().first;

      expect(menu.firstWhere((item) => item.id == id).isAvailable, isTrue);
    });

    test('appears on a stream that was already listening', () async {
      final emissions = <int>[];
      final subscription = repository.watchMenu().listen(
        (menu) => emissions.add(menu.length),
      );
      await pumpEventQueue();

      await repository.create(
        const MenuItemDraft(
          name: 'Old Fashioned',
          priceCents: 1150,
          category: MenuCategory.drinks,
        ),
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions.first, 0);
      expect(emissions.last, 1);
    });
  });

  group('update', () {
    test('an empty patch writes nothing, not even updatedAt', () async {
      await seed(db, 'guinness', name: 'Guinness');

      await repository.update('guinness', const MenuItemPatch());

      final stored = (await menuOf(db).doc('guinness').get()).data()!;
      expect(stored.containsKey('updatedAt'), isFalse);
    });

    test('changes the editable fields and re-stamps updatedAt', () async {
      await seed(db, 'guinness', name: 'Guinness', priceCents: 720);

      await repository.update(
        'guinness',
        const MenuItemPatch(
          name: 'Guinness, pint',
          priceCents: 750,
          category: MenuCategory.drinks,
        ),
      );

      final stored = (await menuOf(db).doc('guinness').get()).data()!;

      expect(stored['name'], 'Guinness, pint');
      expect(stored['priceCents'], 750);
      expect(stored['updatedAt'], isNotNull);
    });

    test('leaves fields this build does not know about alone', () async {
      await menuOf(db).doc('guinness').set({
        'name': 'Guinness',
        'priceCents': 720,
        'category': 'drinks',
        'isAvailable': true,
        'allergens': ['barley'],
      });

      await repository.update(
        'guinness',
        const MenuItemPatch(
          name: 'Guinness, pint',
          priceCents: 720,
          category: MenuCategory.drinks,
        ),
      );

      final stored = (await menuOf(db).doc('guinness').get()).data()!;

      expect(stored['allergens'], ['barley']);
    });
  });

  group('setAvailability', () {
    test('flips the flag without needing the rest of the item', () async {
      await seed(db, 'guinness', name: 'Guinness', isAvailable: true);

      await repository.setAvailability('guinness', isAvailable: false);
      expect(
        (await menuOf(db).doc('guinness').get()).data()!['isAvailable'],
        isFalse,
      );

      await repository.setAvailability('guinness', isAvailable: true);
      expect(
        (await menuOf(db).doc('guinness').get()).data()!['isAvailable'],
        isTrue,
      );
    });

    test('does not disturb the price or the name', () async {
      await seed(db, 'guinness', name: 'Guinness, pint', priceCents: 720);

      await repository.setAvailability('guinness', isAvailable: false);

      final stored = (await menuOf(db).doc('guinness').get()).data()!;
      expect(stored['name'], 'Guinness, pint');
      expect(stored['priceCents'], 720);
    });

    test('re-stamps updatedAt, which the rules require', () async {
      await seed(db, 'guinness', name: 'Guinness');

      await repository.setAvailability('guinness', isAvailable: false);

      final stored = (await menuOf(db).doc('guinness').get()).data()!;
      expect(stored['updatedAt'], isNotNull);
    });
  });

  group('delete', () {
    test('removes the item from the menu stream', () async {
      await seed(db, 'guinness', name: 'Guinness');
      expect(await repository.watchMenu().first, hasLength(1));

      await repository.delete('guinness');

      expect(await repository.watchMenu().first, isEmpty);
    });
  });
}
