import 'package:cloud_firestore/cloud_firestore.dart'
    show FieldValue, FirebaseFirestore;

import '../models/menu_item.dart';
import 'firestore_paths.dart';

abstract interface class MenuRepository {
  Stream<List<MenuItem>> watchMenu();

  Stream<bool> watchMenuIsLive();

  Future<String> create(MenuItemDraft draft);

  Future<void> update(String itemId, MenuItemPatch patch);

  Future<void> setAvailability(String itemId, {required bool isAvailable});

  Future<void> delete(String itemId);

  static List<MenuItem> sortForDisplay(List<MenuItem> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      final byCategory = a.category.index.compareTo(b.category.index);
      if (byCategory != 0) return byCategory;
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }
}

class FirestoreMenuRepository implements MenuRepository {
  FirestoreMenuRepository({
    FirebaseFirestore? firestore,
    required String venueId,
  }) : _paths = FirestorePaths(
         firestore ?? FirebaseFirestore.instance,
         venueId,
       );

  final FirestorePaths _paths;

  @override
  Stream<List<MenuItem>> watchMenu() {
    return _paths.menuItems.snapshots().map((snapshot) {
      final items = [for (final doc in snapshot.docs) doc.data()];
      return MenuRepository.sortForDisplay(items);
    });
  }

  @override
  Stream<bool> watchMenuIsLive() {
    return _paths.rawMenuItems
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => !snapshot.metadata.isFromCache)
        .distinct();
  }

  @override
  Future<String> create(MenuItemDraft draft) async {
    final reference = await _paths.rawMenuItems.add({
      ...draft.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return reference.id;
  }

  @override
  Future<void> update(String itemId, MenuItemPatch patch) {
    if (patch.isEmpty) return Future.value();
    return _paths.rawMenuItems.doc(itemId).update({
      ...patch.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setAvailability(String itemId, {required bool isAvailable}) {
    return _paths.rawMenuItems.doc(itemId).update({
      'isAvailable': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> delete(String itemId) =>
      _paths.rawMenuItems.doc(itemId).delete();
}
