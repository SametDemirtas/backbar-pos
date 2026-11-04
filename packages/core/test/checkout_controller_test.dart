import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

const guinness = MenuItem(
  id: 'guinness',
  name: 'Guinness, pint',
  priceCents: 720,
  category: MenuCategory.drinks,
  isAvailable: true,
);

const lager = MenuItem(
  id: 'lager',
  name: 'Lager, pint',
  priceCents: 680,
  category: MenuCategory.drinks,
  isAvailable: true,
);

class ControlledOrderRepository implements OrderRepository {
  ControlledOrderRepository({this.prefix = 'order'});

  final String prefix;
  final submitted = <Order>[];
  final ids = <String>[];
  final sentAs = <(String, String)>[];
  Completer<String> pending = Completer<String>();
  var _next = 0;

  @override
  String newOrderId() => '$prefix-${++_next}';

  @override
  Future<String> submit(
    Order order, {
    required String orderId,
    required String tillLabel,
    required String staffUid,
  }) {
    submitted.add(order);
    ids.add(orderId);
    sentAs.add((tillLabel, staffUid));
    pending = Completer<String>();
    return pending.future;
  }
}

void main() {
  late OrderController order;
  late ControlledOrderRepository repository;
  late CheckoutController checkout;

  setUp(() {
    order = OrderController();
    repository = ControlledOrderRepository();
    checkout = CheckoutController(
      order: order,
      repository: repository,
      tillLabel: 'TILL 1',
      staffUid: 'uid',
      slowAfter: const Duration(milliseconds: 20),
    );
  });

  tearDown(() {
    checkout.dispose();
    order.dispose();
  });

  test('takes only what was sent off the check', () async {
    order.add(guinness);
    order.add(guinness);
    final send = checkout.send();

    order.add(guinness);
    order.add(lager);
    repository.pending.complete('order-1');
    final sent = await send;

    expect(sent!.itemCount, 2);
    expect(order.quantityOf('guinness'), 1);
    expect(order.quantityOf('lager'), 1);
  });

  test('a failed send leaves the check standing and says why', () async {
    order.add(guinness);
    final send = checkout.send();
    repository.pending.completeError(StateError('permission-denied'));

    expect(await send, isNull);
    expect(order.quantityOf('guinness'), 1);
    expect(checkout.error, isA<StateError>());
    expect(checkout.sending, isFalse);
  });

  test('the next send clears the last failure', () async {
    order.add(guinness);
    final first = checkout.send();
    repository.pending.completeError(StateError('offline'));
    await first;

    final second = checkout.send();
    expect(checkout.error, isNull);
    repository.pending.complete('order-1');
    await second;
  });

  test('an emptied check drops the failure that belonged to it', () async {
    order.add(guinness);
    final send = checkout.send();
    repository.pending.completeError(StateError('offline'));
    await send;
    expect(checkout.error, isNotNull);

    order.clear();
    expect(checkout.error, isNull);
  });

  test('the next send uses whatever it was last configured with', () async {
    final other = ControlledOrderRepository();
    checkout.configure(repository: other, tillLabel: 'TILL 9', staffUid: 'b');

    order.add(guinness);
    final send = checkout.send();
    other.pending.complete('order-1');
    await send;

    expect(repository.submitted, isEmpty);
    expect(other.submitted, hasLength(1));
    expect(other.sentAs, [('TILL 9', 'b')]);
  });

  test('a new repository starts a new attempt', () async {
    order.add(guinness);
    final first = checkout.send();
    repository.pending.completeError(StateError('unavailable'));
    await first;

    final other = ControlledOrderRepository(prefix: 'other');
    checkout.configure(repository: other, tillLabel: 'TILL 1', staffUid: 'uid');
    final retry = checkout.send();
    other.pending.complete('other-1');
    await retry;

    expect(other.ids, ['other-1']);
  });

  test('a new till label alone keeps the attempt', () async {
    order.add(guinness);
    final first = checkout.send();
    repository.pending.completeError(StateError('unavailable'));
    await first;

    checkout.configure(
      repository: repository,
      tillLabel: 'TILL 2',
      staffUid: 'uid',
    );
    final retry = checkout.send();
    repository.pending.complete('order-1');
    await retry;

    expect(repository.ids, ['order-1', 'order-1']);
    expect(repository.sentAs.last, ('TILL 2', 'uid'));
  });

  test('retrying the same check reuses its id', () async {
    order.add(guinness);
    final first = checkout.send();
    repository.pending.completeError(StateError('unavailable'));
    await first;

    final retry = checkout.send();
    repository.pending.complete('order-1');
    await retry;

    expect(repository.ids, ['order-1', 'order-1']);
  });

  test('a check that changed after a failure is a new order', () async {
    order.add(guinness);
    final first = checkout.send();
    repository.pending.completeError(StateError('unavailable'));
    await first;

    order.add(lager);
    final retry = checkout.send();
    repository.pending.complete('order-2');
    await retry;

    expect(repository.ids, ['order-1', 'order-2']);
  });

  test('the next round after a success gets a fresh id', () async {
    order.add(guinness);
    final first = checkout.send();
    repository.pending.complete('order-1');
    await first;

    order.add(guinness);
    final second = checkout.send();
    repository.pending.complete('order-2');
    await second;

    expect(repository.ids, ['order-1', 'order-2']);
  });

  test('a new identity starts a new attempt', () async {
    order.add(guinness);
    final first = checkout.send();
    repository.pending.completeError(StateError('unavailable'));
    await first;

    checkout.configure(
      repository: repository,
      tillLabel: 'TILL 1',
      staffUid: 'someone-else',
    );
    final retry = checkout.send();
    repository.pending.complete('order-2');
    await retry;

    expect(repository.ids, ['order-1', 'order-2']);
  });

  test('refuses a check too big for one order, and says so', () async {
    const ceiling = MenuItem(
      id: 'ceiling',
      name: 'Ceiling',
      priceCents: Money.maxCents,
      category: MenuCategory.merch,
      isAvailable: true,
    );
    order.add(ceiling);
    order.add(ceiling);

    expect(await checkout.send(), isNull);
    expect(repository.submitted, isEmpty);
    expect(checkout.error, isA<CheckTooLarge>());
    expect(describeFailure(checkout.error!), contains('too big'));
    expect(order.quantityOf('ceiling'), 2);
  });

  test('splitting an oversized check clears the warning', () async {
    const ceiling = MenuItem(
      id: 'ceiling',
      name: 'Ceiling',
      priceCents: Money.maxCents,
      category: MenuCategory.merch,
      isAvailable: true,
    );
    order.add(ceiling);
    order.add(ceiling);
    await checkout.send();
    expect(checkout.error, isA<CheckTooLarge>());

    order.removeOne(order.order.lines.single.key);
    expect(checkout.error, isNull);
  });

  test('a second press while one is in flight sends nothing', () async {
    order.add(guinness);
    final first = checkout.send();

    expect(await checkout.send(), isNull);
    expect(repository.submitted, hasLength(1));

    repository.pending.complete('order-1');
    await first;
  });

  test('an empty check is never sent', () async {
    expect(await checkout.send(), isNull);
    expect(repository.submitted, isEmpty);
    expect(checkout.sending, isFalse);
  });

  testWidgets('says when a send has been in flight too long, then stops', (
    tester,
  ) async {
    order.add(guinness);
    final send = checkout.send();
    expect(checkout.slow, isFalse);

    await tester.pump(const Duration(milliseconds: 19));
    expect(checkout.slow, isFalse);
    await tester.pump(const Duration(milliseconds: 2));
    expect(checkout.slow, isTrue);

    repository.pending.complete('order-1');
    await send;
    expect(checkout.slow, isFalse);
  });

  test('a send that lands after the till is gone does not throw', () async {
    order.add(guinness);
    final send = checkout.send();

    checkout.dispose();
    order.dispose();

    repository.pending.complete('order-1');
    await expectLater(send, completes);

    order = OrderController();
    checkout = CheckoutController(
      order: order,
      repository: repository,
      tillLabel: 'TILL 1',
      staffUid: 'uid',
    );
  });
}
