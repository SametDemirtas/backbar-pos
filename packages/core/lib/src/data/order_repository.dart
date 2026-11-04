import 'package:cloud_firestore/cloud_firestore.dart'
    show FieldValue, FirebaseException, FirebaseFirestore;

import '../models/order.dart';
import 'firestore_paths.dart';

abstract interface class OrderRepository {
  String newOrderId();

  Future<String> submit(
    Order order, {
    required String orderId,
    required String tillLabel,
    required String staffUid,
  });
}

class FirestoreOrderRepository implements OrderRepository {
  FirestoreOrderRepository({
    FirebaseFirestore? firestore,
    required String venueId,
  }) : _paths = FirestorePaths(
         firestore ?? FirebaseFirestore.instance,
         venueId,
       );

  final FirestorePaths _paths;

  @override
  String newOrderId() => _paths.orders.doc().id;

  @override
  Future<String> submit(
    Order order, {
    required String orderId,
    required String tillLabel,
    required String staffUid,
  }) async {
    if (order.isEmpty) {
      throw ArgumentError.value(order, 'order', 'Cannot submit an empty order');
    }

    final reference = _paths.orders.doc(orderId);
    try {
      await reference.set({
        ...order.toMap(),
        'tillLabel': tillLabel,
        'staffUid': staffUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied' ||
          !await _alreadySent(orderId, staffUid)) {
        rethrow;
      }
    }
    return orderId;
  }

  Future<bool> _alreadySent(String orderId, String staffUid) async {
    try {
      final existing = await _paths.orders.doc(orderId).get();
      return existing.exists && existing.data()?['staffUid'] == staffUid;
    } on FirebaseException {
      return false;
    }
  }
}
