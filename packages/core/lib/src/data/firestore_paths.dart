import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/menu_item.dart';

MenuItem menuItemFromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
  final data = snapshot.data() ?? const <String, dynamic>{};
  return MenuItem.fromMap(snapshot.id, {
    for (final entry in data.entries)
      entry.key: switch (entry.value) {
        final Timestamp timestamp => timestamp.toDate(),
        final other => other,
      },
  });
}

class FirestorePaths {
  const FirestorePaths(this._firestore, this.venueId);

  final FirebaseFirestore _firestore;
  final String venueId;

  static const String venuesCollection = 'venues';
  static const String menuItemsCollection = 'menuItems';
  static const String ordersCollection = 'orders';

  DocumentReference<Map<String, dynamic>> get venue =>
      _firestore.collection(venuesCollection).doc(venueId);

  CollectionReference<MenuItem> get menuItems =>
      rawMenuItems.withConverter<MenuItem>(
        fromFirestore: (snapshot, _) => menuItemFromSnapshot(snapshot),
        toFirestore: (item, _) => item.toMap(),
      );

  CollectionReference<Map<String, dynamic>> get rawMenuItems =>
      venue.collection(menuItemsCollection);

  CollectionReference<Map<String, dynamic>> get orders =>
      venue.collection(ordersCollection);
}
