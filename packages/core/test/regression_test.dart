import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';
import 'package:backbar_pos_core/src/data/firestore_paths.dart';

Future<MenuItem> readBack(Map<String, Object?> data) async {
  final firestore = FakeFirebaseFirestore();
  final ref = firestore.collection('menuItems').doc('item-1');
  await ref.set(data);
  final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();
  return menuItemFromSnapshot(snapshot);
}

MenuItem item(
  String id, {
  String? name,
  int priceCents = 720,
  bool isAvailable = true,
}) => MenuItem(
  id: id,
  name: name ?? id,
  priceCents: priceCents,
  category: MenuCategory.drinks,
  isAvailable: isAvailable,
);

void main() {
  group('a free drink is not a drink', () {
    test('a zero-priced document is not sellable', () async {
      final zero = await readBack({
        'name': 'Guinness',
        'priceCents': 0,
        'category': 'drinks',
        'isAvailable': true,
      });

      expect(zero.isAvailable, isFalse);
      expect(zero.priceCents, 0);
    });

    test(
      'a fractional price that would round to zero is not sellable',
      () async {
        final rounding = await readBack({
          'name': 'Guinness',
          'priceCents': 0.4,
          'category': 'drinks',
          'isAvailable': true,
        });

        expect(rounding.isAvailable, isFalse);
      },
    );

    test('the till refuses to ring one in', () {
      final controller = OrderController();
      addTearDown(controller.dispose);

      expect(
        controller.add(item('free', priceCents: 0, isAvailable: false)),
        isFalse,
      );
      expect(controller.isEmpty, isTrue);
    });

    test('a draft cannot be built at zero either', () {
      expect(
        () => MenuItemDraft(
          name: 'Free pint',
          priceCents: 0,
          category: MenuCategory.drinks,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('a send does not swallow the next round', () {
    test('removeSubmitted takes off exactly what was sent', () {
      final controller = OrderController();
      addTearDown(controller.dispose);

      controller
        ..add(item('guinness', priceCents: 720))
        ..add(item('guinness', priceCents: 720));
      final submitted = controller.order;

      controller.add(item('coke', priceCents: 300));
      expect(controller.total, const Money.fromCents(1740));

      controller.removeSubmitted(submitted);

      expect(controller.order.lines, hasLength(1));
      expect(controller.order.lines.single.itemId, 'coke');
      expect(controller.total, const Money.fromCents(300));
    });

    test('subtracts quantities, so a line that grew keeps the difference', () {
      final controller = OrderController();
      addTearDown(controller.dispose);

      controller.add(item('guinness', priceCents: 720));
      final submitted = controller.order;

      controller
        ..add(item('guinness', priceCents: 720))
        ..add(item('guinness', priceCents: 720));

      controller.removeSubmitted(submitted);

      expect(controller.order.lines.single.quantity, 2);
      expect(controller.total, const Money.fromCents(1440));
    });

    test('empties the check when nothing else was rung in', () {
      final controller = OrderController();
      addTearDown(controller.dispose);

      controller.add(item('guinness', priceCents: 720));
      controller.removeSubmitted(controller.order);

      expect(controller.isEmpty, isTrue);
    });

    test('ignores a submission holding lines the check no longer has', () {
      final controller = OrderController();
      addTearDown(controller.dispose);
      controller.add(item('coke', priceCents: 300));
      var notified = 0;
      controller.addListener(() => notified++);

      controller.removeSubmitted(
        Order(
          lines: [
            OrderLine(
              itemId: 'ghost',
              name: 'Ghost',
              unitPrice: const Money.fromCents(999),
              quantity: 1,
            ),
          ],
        ),
      );

      expect(controller.order.lines.single.itemId, 'coke');
      expect(notified, 0);
    });
  });

  group('voiding one line does not void another', () {
    test('removeLine drops this item at this price only', () {
      final controller = OrderController();
      addTearDown(controller.dispose);

      controller
        ..add(item('guinness', priceCents: 720))
        ..add(item('guinness', priceCents: 720))
        ..add(item('guinness', priceCents: 750));
      expect(controller.total, const Money.fromCents(2190));

      controller.removeLine('guinness@750');

      expect(controller.order.lines, hasLength(1));
      expect(controller.total, const Money.fromCents(1440));
    });
  });

  group('a patch writes only what changed', () {
    test('an untouched field is absent from the payload', () {
      const patch = MenuItemPatch(name: 'Guinness');

      expect(patch.toMap(), {'name': 'Guinness'});
      expect(patch.toMap().containsKey('isAvailable'), isFalse);
      expect(patch.toMap().containsKey('priceCents'), isFalse);
      expect(patch.toMap().containsKey('category'), isFalse);
    });

    test('an empty patch is recognisable, so no write is made', () {
      expect(const MenuItemPatch().isEmpty, isTrue);
      expect(const MenuItemPatch(name: 'x').isEmpty, isFalse);
    });

    test('a patched price still has to be a price', () {
      expect(
        () => MenuItemPatch(priceCents: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => MenuItemPatch(priceCents: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('leaves a concurrent availability change alone', () async {
      final db = FakeFirebaseFirestore();
      final repository = FirestoreMenuRepository(
        firestore: db,
        venueId: 'copper-kettle',
      );
      final doc = db
          .collection('venues')
          .doc('copper-kettle')
          .collection('menuItems')
          .doc('guinness');

      await doc.set({
        'name': 'Guiness, pint',
        'priceCents': 720,
        'category': 'drinks',
        'isAvailable': true,
      });

      await repository.setAvailability('guinness', isAvailable: false);
      await repository.update(
        'guinness',
        const MenuItemPatch(name: 'Guinness, pint'),
      );

      final stored = (await doc.get()).data()!;
      expect(stored['name'], 'Guinness, pint');
      expect(
        stored['isAvailable'],
        isFalse,
        reason: 'the item must not come back on sale on every till',
      );
    });

    test('leaves an unrecognised category alone', () async {
      final db = FakeFirebaseFirestore();
      final repository = FirestoreMenuRepository(
        firestore: db,
        venueId: 'copper-kettle',
      );
      final doc = db
          .collection('venues')
          .doc('copper-kettle')
          .collection('menuItems')
          .doc('tote');

      await doc.set({
        'name': 'Tote bag',
        'priceCents': 1500,
        'category': 'apparel',
        'isAvailable': true,
      });

      await repository.update('tote', const MenuItemPatch(priceCents: 1600));

      expect((await doc.get()).data()!['category'], 'apparel');
    });
  });
}
