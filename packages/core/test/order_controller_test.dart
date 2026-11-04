import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

MenuItem item(
  String id, {
  String? name,
  int priceCents = 720,
  bool isAvailable = true,
  MenuCategory category = MenuCategory.drinks,
}) {
  return MenuItem(
    id: id,
    name: name ?? id,
    priceCents: priceCents,
    category: category,
    isAvailable: isAvailable,
  );
}

void main() {
  late OrderController controller;
  late int notifications;

  setUp(() {
    controller = OrderController();
    notifications = 0;
    controller.addListener(() => notifications++);
  });

  tearDown(() => controller.dispose());

  group('adding', () {
    test('starts empty', () {
      expect(controller.isEmpty, isTrue);
      expect(controller.total, Money.zero);
      expect(controller.itemCount, 0);
      expect(controller.order.lines, isEmpty);
    });

    test('adds a line and notifies', () {
      expect(controller.add(item('guinness', priceCents: 720)), isTrue);

      expect(controller.order.lines, hasLength(1));
      expect(controller.order.lines.single.quantity, 1);
      expect(controller.total, const Money.fromCents(720));
      expect(notifications, 1);
    });

    test(
      'a second tap on the same item increments rather than duplicating',
      () {
        final guinness = item('guinness', priceCents: 720);
        controller
          ..add(guinness)
          ..add(guinness)
          ..add(guinness);

        expect(controller.order.lines, hasLength(1));
        expect(controller.order.lines.single.quantity, 3);
        expect(controller.itemCount, 3);
        expect(controller.total, const Money.fromCents(2160));
      },
    );

    test('different items get their own lines', () {
      controller
        ..add(item('guinness', priceCents: 720))
        ..add(item('hells', priceCents: 680));

      expect(controller.order.lines, hasLength(2));
      expect(controller.total, const Money.fromCents(1400));
      expect(controller.itemCount, 2);
    });

    test('refuses a sold-out item, silently and without notifying', () {
      expect(controller.add(item('negroni', isAvailable: false)), isFalse);

      expect(controller.isEmpty, isTrue);
      expect(notifications, 0);
    });
  });

  group('price snapshotting', () {
    test('a re-priced item opens a second line instead of merging', () {
      controller
        ..add(item('guinness', priceCents: 720))
        ..add(item('guinness', priceCents: 720))
        ..add(item('guinness', priceCents: 750));

      expect(controller.order.lines, hasLength(2));
      expect(controller.order.lines[0].quantity, 2);
      expect(controller.order.lines[0].unitPrice, const Money.fromCents(720));
      expect(controller.order.lines[1].quantity, 1);
      expect(controller.order.lines[1].unitPrice, const Money.fromCents(750));

      expect(controller.total, const Money.fromCents(2190));
    });

    test('a rename with no price change updates the name on the open line', () {
      controller.add(item('guinness', name: 'Guinness', priceCents: 720));
      controller.add(item('guinness', name: 'Guinness, pint', priceCents: 720));

      expect(controller.order.lines, hasLength(1));
      expect(controller.order.lines.single.quantity, 2);
      expect(
        controller.order.lines.single.name,
        'Guinness, pint',
        reason: 'the stale name would follow the check into the record',
      );
    });

    test('quantityOf sums every line for the item, across prices', () {
      controller
        ..add(item('guinness', priceCents: 720))
        ..add(item('guinness', priceCents: 750))
        ..add(item('hells', priceCents: 680));

      expect(controller.quantityOf('guinness'), 2);
      expect(controller.quantityOf('hells'), 1);
      expect(controller.quantityOf('nothing'), 0);
    });
  });

  group('removing', () {
    test('removeOne decrements, then drops the line at zero', () {
      final guinness = item('guinness', priceCents: 720);
      controller
        ..add(guinness)
        ..add(guinness);
      final key = controller.order.lines.single.key;

      controller.removeOne(key);
      expect(controller.order.lines.single.quantity, 1);
      expect(controller.total, const Money.fromCents(720));

      controller.removeOne(key);
      expect(controller.isEmpty, isTrue);
      expect(controller.total, Money.zero);
    });

    test('removeLine drops the whole line whatever the quantity', () {
      final guinness = item('guinness', priceCents: 720);
      controller
        ..add(guinness)
        ..add(guinness)
        ..add(guinness)
        ..add(item('hells', priceCents: 680));

      controller.removeLine('guinness@720');

      expect(controller.order.lines, hasLength(1));
      expect(controller.order.lines.single.itemId, 'hells');
    });

    test('removing something that is not on the check does nothing at all', () {
      controller.add(item('guinness'));
      notifications = 0;

      controller
        ..removeOne('nope@1')
        ..removeLine('nope@1');

      expect(controller.order.lines, hasLength(1));
      expect(notifications, 0, reason: 'a no-op must not rebuild the till');
    });

    test('clear empties the check, and is a no-op when already empty', () {
      controller
        ..add(item('guinness'))
        ..add(item('hells'));
      controller.clear();

      expect(controller.isEmpty, isTrue);
      expect(controller.total, Money.zero);

      notifications = 0;
      controller.clear();
      expect(notifications, 0);
    });
  });

  group('sold out mid-order', () {
    test('flags a line whose item went sold out, without deleting it', () {
      controller
        ..add(item('espresso-martini', priceCents: 1250))
        ..add(item('guinness', priceCents: 720));

      final liveMenu = [
        item('espresso-martini', priceCents: 1250, isAvailable: false),
        item('guinness', priceCents: 720),
      ];

      expect(controller.unsellableItemIds(liveMenu), {'espresso-martini'});
      expect(controller.order.lines, hasLength(2));
      expect(controller.total, const Money.fromCents(1970));
    });

    test('flags a line whose item was deleted from the menu entirely', () {
      controller.add(item('guinness', priceCents: 720));

      expect(controller.unsellableItemIds(const []), {'guinness'});
    });

    test('flags nothing when everything is still on sale', () {
      controller.add(item('guinness', priceCents: 720));

      expect(controller.unsellableItemIds([item('guinness')]), isEmpty);
    });
  });
}
