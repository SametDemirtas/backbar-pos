import 'package:cloud_firestore/cloud_firestore.dart'
    show CollectionReference, FirebaseException;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

const venueId = 'copper-kettle';

CollectionReference<Map<String, dynamic>> ordersOf(FakeFirebaseFirestore db) =>
    db.collection('venues').doc(venueId).collection('orders');

void main() {
  late FakeFirebaseFirestore db;
  late OrderRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = FirestoreOrderRepository(firestore: db, venueId: venueId);
  });

  test('writes the lines, the count, the total and who rang it in', () async {
    final order = Order(
      lines: [
        OrderLine(
          itemId: 'guinness',
          name: 'Guinness, pint',
          unitPrice: const Money.fromCents(720),
          quantity: 3,
        ),
        OrderLine(
          itemId: 'house-red',
          name: 'House Red, 175ml',
          unitPrice: const Money.fromCents(750),
          quantity: 1,
        ),
      ],
    );

    final id = await repository.submit(
      order,
      orderId: repository.newOrderId(),
      tillLabel: 'TILL 2',
      staffUid: 'uid-123',
    );

    final stored = (await ordersOf(db).doc(id).get()).data()!;

    expect(stored['itemCount'], 4);
    expect(stored['totalCents'], 2910);
    expect(stored['tillLabel'], 'TILL 2');
    expect(stored['staffUid'], 'uid-123');
    expect(stored['createdAt'], isNotNull);

    final lines = stored['lines']! as List<dynamic>;
    expect(lines, hasLength(2));
    expect(lines.first, {
      'itemId': 'guinness',
      'name': 'Guinness, pint',
      'unitPriceCents': 720,
      'quantity': 3,
      'amountCents': 2160,
    });
  });

  test(
    'refuses an empty order rather than writing a zero-value check',
    () async {
      await expectLater(
        repository.submit(
          Order.empty,
          orderId: repository.newOrderId(),
          tillLabel: 'TILL 1',
          staffUid: 'uid',
        ),
        throwsArgumentError,
      );

      expect((await ordersOf(db).get()).docs, isEmpty);
    },
  );

  test('each submission is its own document', () async {
    final order = Order(
      lines: [
        OrderLine(
          itemId: 'guinness',
          name: 'Guinness',
          unitPrice: const Money.fromCents(720),
          quantity: 1,
        ),
      ],
    );

    final first = await repository.submit(
      order,
      orderId: repository.newOrderId(),
      tillLabel: 'TILL 1',
      staffUid: 'uid',
    );
    final second = await repository.submit(
      order,
      orderId: repository.newOrderId(),
      tillLabel: 'TILL 1',
      staffUid: 'uid',
    );

    expect(first, isNot(second));
    expect((await ordersOf(db).get()).docs, hasLength(2));
  });

  test('the same id twice is one order, not two', () async {
    final order = Order(
      lines: [
        OrderLine(
          itemId: 'guinness',
          name: 'Guinness',
          unitPrice: const Money.fromCents(720),
          quantity: 1,
        ),
      ],
    );
    final id = repository.newOrderId();

    await repository.submit(
      order,
      orderId: id,
      tillLabel: 'TILL 1',
      staffUid: 'uid',
    );
    await repository.submit(
      order,
      orderId: id,
      tillLabel: 'TILL 1',
      staffUid: 'uid',
    );

    expect((await ordersOf(db).get()).docs.map((doc) => doc.id), [id]);
  });

  test('orders are scoped to their venue', () async {
    final order = Order(
      lines: [
        OrderLine(
          itemId: 'guinness',
          name: 'Guinness',
          unitPrice: const Money.fromCents(720),
          quantity: 1,
        ),
      ],
    );

    await repository.submit(
      order,
      orderId: repository.newOrderId(),
      tillLabel: 'TILL 1',
      staffUid: 'uid',
    );

    final otherVenue = await db
        .collection('venues')
        .doc('some-other-venue')
        .collection('orders')
        .get();

    expect(otherVenue.docs, isEmpty);
    expect((await ordersOf(db).get()).docs, hasLength(1));
  });

  group('a resend the server refuses', () {
    final order = Order(
      lines: [
        OrderLine(
          itemId: 'guinness',
          name: 'Guinness',
          unitPrice: const Money.fromCents(720),
          quantity: 1,
        ),
      ],
    );
    late String id;

    setUp(() => id = repository.newOrderId());

    void refuseWrites() {
      whenCalling(Invocation.method(#set, null))
          .on(ordersOf(db).doc(id))
          .thenThrow(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          );
    }

    Future<void> storedBy(String staffUid) => db
        .collection('venues')
        .doc(venueId)
        .collection('orders')
        .doc(id)
        .set({'staffUid': staffUid});

    test('is the earlier send landing, so it counts as sent', () async {
      await storedBy('uid');
      refuseWrites();

      expect(
        await repository.submit(
          order,
          orderId: id,
          tillLabel: 'TILL 1',
          staffUid: 'uid',
        ),
        id,
      );
    });

    test('is a real refusal when another device holds the id', () async {
      await storedBy('someone-else');
      refuseWrites();

      await expectLater(
        repository.submit(
          order,
          orderId: id,
          tillLabel: 'TILL 1',
          staffUid: 'uid',
        ),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('is a real refusal when nothing was stored', () async {
      refuseWrites();
      await expectLater(
        repository.submit(
          order,
          orderId: id,
          tillLabel: 'TILL 1',
          staffUid: 'uid',
        ),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('is a real refusal when the read-back fails too', () async {
      await storedBy('uid');
      refuseWrites();
      whenCalling(Invocation.method(#get, null))
          .on(ordersOf(db).doc(id))
          .thenThrow(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          );

      await expectLater(
        repository.submit(
          order,
          orderId: id,
          tillLabel: 'TILL 1',
          staffUid: 'uid',
        ),
        throwsA(
          isA<FirebaseException>().having(
            (error) => error.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });
  });
}
