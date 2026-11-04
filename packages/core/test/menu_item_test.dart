import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';
import 'package:backbar_pos_core/src/data/firestore_paths.dart';

Future<MenuItem> readBack(Map<String, Object?> data) async {
  final firestore = FakeFirebaseFirestore();
  final ref = firestore.collection('menuItems').doc('item-1');
  await ref.set(data);
  return menuItemFromSnapshot(await ref.get());
}

void main() {
  group('reading a menu document', () {
    test('reads a well-formed document', () async {
      final item = await readBack({
        'name': 'Guinness, pint',
        'priceCents': 720,
        'category': 'drinks',
        'isAvailable': true,
      });

      expect(item.id, 'item-1');
      expect(item.name, 'Guinness, pint');
      expect(item.priceCents, 720);
      expect(item.category, MenuCategory.drinks);
      expect(item.isAvailable, isTrue);
    });

    test('trims a name that was saved with stray whitespace', () async {
      final item = await readBack({
        'name': '  Negroni \n',
        'priceCents': 1100,
        'category': 'drinks',
        'isAvailable': true,
      });

      expect(item.name, 'Negroni');
    });

    test(
      'defaults a missing availability flag to sold out, not on sale',
      () async {
        final item = await readBack({
          'name': 'Halloumi wrap',
          'priceCents': 950,
          'category': 'food',
        });

        expect(item.isAvailable, isFalse);
      },
    );

    test('survives a price written as a double by an older build', () async {
      final item = await readBack({
        'name': 'Coke, bottle',
        'priceCents': 300.0,
        'category': 'drinks',
        'isAvailable': true,
      });

      expect(item.priceCents, 300);
    });

    test('buckets an unknown category instead of dropping the item', () async {
      final item = await readBack({
        'name': 'Tote bag',
        'priceCents': 1500,
        'category': 'apparel',
        'isAvailable': true,
      });

      expect(item.category, MenuCategory.food);
      expect(item.name, 'Tote bag');
    });

    test('a nameless item is not sellable', () async {
      for (final name in [null, '', '   ']) {
        final item = await readBack({
          'name': ?name,
          'priceCents': 450,
          'category': 'snacks',
          'isAvailable': true,
        });

        expect(item.isAvailable, isFalse, reason: 'name: "$name"');
      }
    });

    test(
      'says when the stored item cannot be sold whatever its flag',
      () async {
        final fine = await readBack({
          'name': 'Olives',
          'priceCents': 450,
          'category': 'snacks',
          'isAvailable': false,
        });
        final unpriced = await readBack({
          'name': 'Olives',
          'priceCents': 4.5,
          'category': 'snacks',
          'isAvailable': true,
        });
        final nameless = await readBack({
          'name': '',
          'priceCents': 450,
          'category': 'snacks',
          'isAvailable': true,
        });

        expect(nameless.displayName, 'Unnamed item');
        final padded = await readBack({
          'name': 'Olives   ',
          'priceCents': 450,
          'category': 'snacks',
          'isAvailable': true,
        });
        expect(padded.name, 'Olives');
        expect(padded.nameNeedsRepair, isTrue);
        expect(fine.nameNeedsRepair, isFalse);
        expect(fine.displayName, 'Olives');
        expect(fine.blockedFromSale, isFalse);
        expect(unpriced.blockedFromSale, isTrue);
        expect(nameless.blockedFromSale, isTrue);
      },
    );

    test('survives a document with nothing usable in it', () async {
      final item = await readBack(const <String, Object?>{});

      expect(item.name, '');
      expect(item.priceCents, 0);
      expect(item.isAvailable, isFalse);
      expect(item.updatedAt, isNull);
    });

    group('a malformed document must not take the whole menu down', () {
      test('a non-boolean availability flag reads as sold out', () async {
        final item = await readBack({
          'name': 'Guinness',
          'priceCents': 720,
          'category': 'drinks',
          'isAvailable': 'true',
        });

        expect(item.isAvailable, isFalse);
        expect(item.name, 'Guinness');
      });

      test('a non-string name reads as empty', () async {
        final item = await readBack({
          'name': 123,
          'priceCents': 720,
          'category': 'drinks',
          'isAvailable': true,
        });

        expect(item.name, '');
      });

      test('a negative price makes the item unsellable', () async {
        final item = await readBack({
          'name': 'Guinness',
          'priceCents': -500,
          'category': 'drinks',
          'isAvailable': true,
        });

        expect(item.priceCents, 0);
        expect(
          item.isAvailable,
          isFalse,
          reason: 'a negative price would pay the customer to drink',
        );
      });

      test('a price beyond the ceiling makes the item unsellable', () async {
        final item = await readBack({
          'name': 'Tab',
          'priceCents': Money.maxCents + 1,
          'category': 'drinks',
          'isAvailable': true,
        });

        expect(item.isAvailable, isFalse);
      });

      test('a non-finite price makes the item unsellable', () async {
        for (final price in [double.nan, double.infinity]) {
          final item = await readBack({
            'name': 'Guinness',
            'priceCents': price,
            'category': 'drinks',
            'isAvailable': true,
          });

          expect(item.priceCents, 0, reason: '$price must not reach round()');
          expect(item.isAvailable, isFalse);
        }
      });

      test(
        'a fractional price makes the item unsellable instead of rounding',
        () async {
          for (final price in [7.2, 720.5]) {
            final item = await readBack({
              'name': 'Guinness',
              'priceCents': price,
              'category': 'drinks',
              'isAvailable': true,
            });

            expect(item.priceCents, 0, reason: '$price must not be rounded');
            expect(item.isAvailable, isFalse);
          }
        },
      );

      test(
        'a price of the wrong type entirely makes the item unsellable',
        () async {
          final item = await readBack({
            'name': 'Guinness',
            'priceCents': '7.20',
            'category': 'drinks',
            'isAvailable': true,
          });

          expect(item.priceCents, 0);
          expect(item.isAvailable, isFalse);
        },
      );
    });

    group('an unrecognised category survives a round trip', () {
      test('is shown under the fallback but kept on the model', () async {
        final item = await readBack({
          'name': 'Tote bag',
          'priceCents': 1500,
          'category': 'apparel',
          'isAvailable': true,
        });

        expect(item.category, MenuCategory.fallback);
        expect(item.unrecognisedCategory, 'apparel');
        expect(item.categoryWireValue, 'apparel');
        expect(item.isAvailable, isTrue, reason: 'it is still sellable');
      });

      test('is written back untouched', () async {
        final item = await readBack({
          'name': 'Tote bag',
          'priceCents': 1500,
          'category': 'apparel',
          'isAvailable': true,
        });

        expect(item.toMap()['category'], 'apparel');

        expect(
          item.copyWith(isAvailable: false).toMap()['category'],
          'apparel',
        );
      });

      test('is dropped once somebody picks a real category', () async {
        final item = await readBack({
          'name': 'Tote bag',
          'priceCents': 1500,
          'category': 'apparel',
          'isAvailable': true,
        });

        final recategorised = item.copyWith(category: MenuCategory.merch);

        expect(recategorised.unrecognisedCategory, isNull);
        expect(recategorised.toMap()['category'], 'merch');
      });

      test('a non-string category is not preserved', () async {
        final item = await readBack({
          'name': 'Odd',
          'priceCents': 100,
          'category': 42,
          'isAvailable': true,
        });

        expect(item.unrecognisedCategory, isNull);
        expect(item.toMap()['category'], MenuCategory.fallback.wireValue);
      });
    });

    test('reads the server timestamp when one is present', () async {
      final when = DateTime.utc(2026, 8, 10, 22, 4);
      final item = await readBack({
        'name': 'Neck Oil IPA',
        'priceCents': 650,
        'category': 'drinks',
        'isAvailable': true,
        'updatedAt': Timestamp.fromDate(when),
      });

      expect(item.updatedAt, when);
      expect(
        item.updatedAt!.isUtc,
        isTrue,
        reason: 'a device-local timestamp cannot be compared across tills',
      );
    });
  });

  group('MenuItem.toMap', () {
    test('writes the wire value for the category, not the enum name', () {
      const item = MenuItem(
        id: 'x',
        name: 'Loaded fries',
        priceCents: 800,
        category: MenuCategory.food,
        isAvailable: true,
      );

      expect(item.toMap(), {
        'name': 'Loaded fries',
        'priceCents': 800,
        'category': 'food',
        'isAvailable': true,
      });
    });

    test('never writes its own updatedAt', () {
      const item = MenuItem(
        id: 'x',
        name: 'Guinness',
        priceCents: 720,
        category: MenuCategory.drinks,
        isAvailable: true,
      );

      expect(item.toMap().containsKey('updatedAt'), isFalse);
    });

    test('round-trips through Firestore', () async {
      const original = MenuItem(
        id: 'item-1',
        name: 'Espresso Martini',
        priceCents: 1250,
        category: MenuCategory.drinks,
        isAvailable: false,
      );

      final item = await readBack(original.toMap());

      expect(item, original);
    });
  });

  group('MenuItem value semantics', () {
    const base = MenuItem(
      id: 'a',
      name: 'Guinness',
      priceCents: 720,
      category: MenuCategory.drinks,
      isAvailable: true,
    );

    test('two items with the same fields are equal', () {
      expect(base, base.copyWith());
      expect(base.hashCode, base.copyWith().hashCode);
    });

    test('copyWith changes only what it is given', () {
      final soldOut = base.copyWith(isAvailable: false);

      expect(soldOut.isAvailable, isFalse);
      expect(soldOut.name, base.name);
      expect(soldOut.priceCents, base.priceCents);
      expect(soldOut.id, base.id);
      expect(soldOut == base, isFalse);
    });
  });

  group('MenuCategory', () {
    test('every category has a stable wire value distinct from the others', () {
      final wireValues = MenuCategory.values.map((c) => c.wireValue).toSet();

      expect(wireValues, hasLength(MenuCategory.values.length));
      for (final category in MenuCategory.values) {
        expect(MenuCategory.fromWire(category.wireValue), category);
      }
    });

    test('falls back rather than throwing on anything unexpected', () {
      expect(MenuCategory.fromWire(null), MenuCategory.food);
      expect(MenuCategory.fromWire(42), MenuCategory.food);
      expect(MenuCategory.fromWire('DRINKS'), MenuCategory.food);
    });
  });

  group('MenuItemPatch.between', () {
    const existing = MenuItem(
      id: 'x',
      name: 'Negroni',
      priceCents: 1100,
      category: MenuCategory.drinks,
      isAvailable: true,
    );

    MenuItem stored({
      int priceCents = 1100,
      bool isAvailable = true,
      String? unrecognisedCategory,
      bool needsRepair = false,
    }) => MenuItem(
      id: 'x',
      name: 'Negroni',
      priceCents: priceCents,
      category: MenuCategory.drinks,
      isAvailable: isAvailable,
      unrecognisedCategory: unrecognisedCategory,
      nameNeedsRepair: needsRepair,
      categoryNeedsRepair: needsRepair,
      availabilityNeedsRepair: needsRepair,
    );

    MenuItemPatch between(
      MenuItem item, {
      String name = 'Negroni',
      int priceCents = 1100,
      MenuCategory category = MenuCategory.drinks,
      bool categoryTouched = false,
      bool isAvailable = true,
    }) => MenuItemPatch.between(
      item,
      name: name,
      priceCents: priceCents,
      category: category,
      categoryTouched: categoryTouched,
      isAvailable: isAvailable,
    );

    test('nothing changed writes nothing', () {
      expect(between(existing).isEmpty, isTrue);
    });

    test('writes only the field that changed', () {
      expect(between(existing, priceCents: 1200).toMap(), {'priceCents': 1200});
      expect(between(existing, isAvailable: false).toMap(), {
        'isAvailable': false,
      });
    });

    test('a category touched and put back is not written', () {
      expect(between(existing, categoryTouched: true).isEmpty, isTrue);
    });

    test('an untouched category is not written even if it differs', () {
      final patch = between(existing, category: MenuCategory.food);
      expect(patch.category, isNull);
    });

    test('a touched category keeps an unrecognised one from staying', () {
      final patch = between(
        stored(unrecognisedCategory: 'cocktails'),
        categoryTouched: true,
      );
      expect(patch.toMap(), {'category': 'drinks'});
    });

    test('repairs a stored document the rules would refuse', () {
      final patch = between(stored(needsRepair: true));
      expect(patch.toMap(), {
        'name': 'Negroni',
        'category': 'drinks',
        'isAvailable': true,
      });
    });

    test('fixing the price of a blocked item writes its availability', () {
      final patch = between(
        stored(priceCents: 0, isAvailable: false),
        isAvailable: false,
      );
      expect(patch.toMap(), {'priceCents': 1100, 'isAvailable': false});
    });
  });
}
