import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

OrderLine line(String itemId, {int cents = 720, int quantity = 1}) => OrderLine(
  itemId: itemId,
  name: itemId,
  unitPrice: Money.fromCents(cents),
  quantity: quantity,
);

void main() {
  group('OrderLine', () {
    test('amount is unit price times quantity', () {
      expect(
        line('guinness', cents: 720, quantity: 3).amount,
        const Money.fromCents(2160),
      );
      expect(line('guinness', cents: 720).amount, const Money.fromCents(720));
    });

    test(
      'key is item and price, so a re-price cannot merge into a stale line',
      () {
        expect(line('guinness', cents: 720).key, 'guinness@720');
        expect(line('guinness', cents: 750).key, 'guinness@750');
        expect(
          line('guinness', cents: 720).key == line('guinness', cents: 750).key,
          isFalse,
        );
      },
    );

    test('a line with no quantity is not a thing that can exist', () {
      expect(
        () => line('guinness', quantity: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => line('guinness', quantity: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('serialises the computed amount alongside the inputs', () {
      expect(line('guinness', cents: 720, quantity: 3).toMap(), {
        'itemId': 'guinness',
        'name': 'guinness',
        'unitPriceCents': 720,
        'quantity': 3,
        'amountCents': 2160,
      });
    });
  });

  group('Order', () {
    test('an empty order totals zero and counts nothing', () {
      expect(Order.empty.isEmpty, isTrue);
      expect(Order.empty.total, Money.zero);
      expect(Order.empty.itemCount, 0);
    });

    test('itemCount counts physical items, not lines', () {
      final order = Order(
        lines: [
          line('guinness', quantity: 3),
          line('hells', cents: 680, quantity: 2),
        ],
      );

      expect(order.lines, hasLength(2));
      expect(order.itemCount, 5);
    });

    test('total sums the lines exactly', () {
      final order = Order(
        lines: [
          line('guinness', cents: 720, quantity: 3),
          line('house-red', cents: 750),
          line('lime-soda', cents: 220, quantity: 2),
        ],
      );

      expect(order.total, const Money.fromCents(3350));
      expect(order.total.format(), '£33.50');
    });

    test('unsellableItemIds flags sold out and deleted items alike', () {
      final order = Order(
        lines: [
          line('guinness'),
          line('espresso-martini', cents: 1250),
          line('ghost'),
        ],
      );

      const menu = [
        MenuItem(
          id: 'guinness',
          name: 'Guinness',
          priceCents: 720,
          category: MenuCategory.drinks,
          isAvailable: true,
        ),
        MenuItem(
          id: 'espresso-martini',
          name: 'Espresso Martini',
          priceCents: 1250,
          category: MenuCategory.drinks,
          isAvailable: false,
        ),
      ];

      expect(order.unsellableItemIds(menu), {'espresso-martini', 'ghost'});
    });

    test('serialises with a denormalised count and total', () {
      final order = Order(lines: [line('guinness', quantity: 2)]);

      expect(order.toMap(), {
        'lines': [
          {
            'itemId': 'guinness',
            'name': 'guinness',
            'unitPriceCents': 720,
            'quantity': 2,
            'amountCents': 1440,
          },
        ],
        'itemCount': 2,
        'totalCents': 1440,
      });
    });

    test('the line list cannot be mutated behind the order', () {
      final order = Order(lines: [line('guinness', quantity: 2)]);

      expect(() => order.lines.clear(), throwsUnsupportedError);
      expect(() => order.lines.add(line('hells')), throwsUnsupportedError);
      expect(() => order.lines.sort((a, b) => 0), throwsUnsupportedError);
      expect(order.total, const Money.fromCents(1440));
    });

    test('copies the list it was given, so later edits do not reach it', () {
      final source = [line('guinness')];
      final order = Order(lines: source);

      source.add(line('hells'));

      expect(order.lines, hasLength(1));
    });

    test('two orders with the same lines are equal', () {
      final a = Order(lines: [line('guinness'), line('hells', cents: 680)]);
      final b = Order(lines: [line('guinness'), line('hells', cents: 680)]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == Order(lines: [line('guinness')]), isFalse);
    });
  });

  group('fitsOneOrder', () {
    OrderLine line(String id, {int cents = 720, int quantity = 1}) => OrderLine(
      itemId: id,
      name: id,
      unitPrice: Money.fromCents(cents),
      quantity: quantity,
    );

    test('an ordinary check fits', () {
      expect(Order(lines: [line('a', quantity: 3)]).fitsOneOrder, isTrue);
    });

    test('too many lines, items or pence do not', () {
      expect(
        Order(
          lines: [for (var i = 0; i <= Order.maxLines; i++) line('i$i')],
        ).fitsOneOrder,
        isFalse,
      );
      expect(
        Order(lines: [line('a', quantity: Order.maxItems + 1)]).fitsOneOrder,
        isFalse,
      );
      expect(
        Order(
          lines: [line('a', cents: Money.maxCents, quantity: 2)],
        ).fitsOneOrder,
        isFalse,
      );
    });
  });
}
