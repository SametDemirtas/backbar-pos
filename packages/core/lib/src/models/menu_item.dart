import 'package:flutter/foundation.dart';

import '../money/money.dart';
import 'menu_category.dart';

@immutable
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.category,
    required this.isAvailable,
    this.updatedAt,
    this.unrecognisedCategory,
    this.categoryNeedsRepair = false,
    this.availabilityNeedsRepair = false,
    this.nameNeedsRepair = false,
  });

  final String id;
  final String name;
  final int priceCents;
  final MenuCategory category;

  final bool isAvailable;

  final DateTime? updatedAt;

  final String? unrecognisedCategory;

  final bool categoryNeedsRepair;

  final bool nameNeedsRepair;

  final bool availabilityNeedsRepair;

  String get categoryWireValue => unrecognisedCategory ?? category.wireValue;

  Money get price => Money.fromCents(priceCents);

  String get displayName => name.isEmpty ? 'Unnamed item' : name;

  bool get blockedFromSale => priceCents == 0 || name.isEmpty;

  factory MenuItem.fromMap(String id, Map<String, Object?> data) {
    final rawCategory = data['category'];
    final category = MenuCategory.tryFromWire(rawCategory);

    final priceCents = _readPriceCents(data['priceCents']);
    final name = _readName(data['name']);

    return MenuItem(
      id: id,
      name: name,
      priceCents: priceCents ?? 0,
      category: category ?? MenuCategory.fallback,
      isAvailable:
          data['isAvailable'] == true && priceCents != null && name.isNotEmpty,
      updatedAt: _readTimestamp(data['updatedAt']),
      unrecognisedCategory: category == null && rawCategory is String
          ? rawCategory
          : null,
      categoryNeedsRepair: rawCategory is! String,
      nameNeedsRepair: data['name'] is! String || data['name'] != name,
      availabilityNeedsRepair: data['isAvailable'] is! bool,
    );
  }

  static String _readName(Object? value) => value is String ? value.trim() : '';

  static int? _readPriceCents(Object? value) {
    if (value is! num) return null;
    if (value is double && !value.isFinite) return null;
    if (value is double && value != value.truncateToDouble()) return null;
    final cents = value.round();
    if (cents <= 0 || cents > Money.maxCents) return null;
    return cents;
  }

  static DateTime? _readTimestamp(Object? value) =>
      value is DateTime ? value.toUtc() : null;

  Map<String, Object?> toMap() => {
    'name': name,
    'priceCents': priceCents,
    'category': categoryWireValue,
    'isAvailable': isAvailable,
  };

  MenuItem copyWith({
    String? name,
    int? priceCents,
    MenuCategory? category,
    bool? isAvailable,
  }) {
    return MenuItem(
      id: id,
      name: name ?? this.name,
      priceCents: priceCents ?? this.priceCents,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      updatedAt: updatedAt,
      unrecognisedCategory: category == null ? unrecognisedCategory : null,
      categoryNeedsRepair: category == null && categoryNeedsRepair,
      availabilityNeedsRepair: isAvailable == null && availabilityNeedsRepair,
      nameNeedsRepair: name == null && nameNeedsRepair,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuItem &&
          other.id == id &&
          other.name == name &&
          other.priceCents == priceCents &&
          other.category == category &&
          other.isAvailable == isAvailable &&
          other.unrecognisedCategory == unrecognisedCategory;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    priceCents,
    category,
    isAvailable,
    unrecognisedCategory,
  );

  @override
  String toString() =>
      'MenuItem($id, $name, $priceCents, $categoryWireValue, '
      'available: $isAvailable)';
}

@immutable
class MenuItemPatch {
  const MenuItemPatch({
    this.name,
    this.priceCents,
    this.category,
    this.isAvailable,
  }) : assert(
         priceCents == null || (priceCents > 0 && priceCents <= Money.maxCents),
         'A patched price still has to be a price',
       );

  final String? name;
  final int? priceCents;
  final MenuCategory? category;
  final bool? isAvailable;

  factory MenuItemPatch.between(
    MenuItem existing, {
    required String name,
    required int priceCents,
    required MenuCategory category,
    required bool categoryTouched,
    required bool isAvailable,
  }) {
    return MenuItemPatch(
      name: name == existing.name && !existing.nameNeedsRepair ? null : name,
      priceCents: priceCents == existing.priceCents ? null : priceCents,
      category:
          existing.categoryNeedsRepair ||
              (categoryTouched &&
                  (category != existing.category ||
                      existing.unrecognisedCategory != null))
          ? category
          : null,
      isAvailable:
          isAvailable != existing.isAvailable ||
              existing.blockedFromSale ||
              existing.availabilityNeedsRepair
          ? isAvailable
          : null,
    );
  }

  bool get isEmpty =>
      name == null &&
      priceCents == null &&
      category == null &&
      isAvailable == null;

  Map<String, Object?> toMap() => {
    if (name != null) 'name': name,
    if (priceCents != null) 'priceCents': priceCents,
    if (category != null) 'category': category!.wireValue,
    if (isAvailable != null) 'isAvailable': isAvailable,
  };
}

@immutable
class MenuItemDraft {
  const MenuItemDraft({
    required this.name,
    required this.priceCents,
    required this.category,
    this.isAvailable = true,
  }) : assert(priceCents > 0, 'A free or negative price is not a price'),
       assert(priceCents <= Money.maxCents, 'Price above the agreed ceiling');

  final String name;
  final int priceCents;
  final MenuCategory category;
  final bool isAvailable;

  Map<String, Object?> toMap() => {
    'name': name,
    'priceCents': priceCents,
    'category': category.wireValue,
    'isAvailable': isAvailable,
  };

  static const int maxNameLength = 60;

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Give the item a name — this is what the bartender reads.';
    }
    if (name.length > maxNameLength) {
      return 'Too long to fit on the till. Keep it to $maxNameLength '
          'characters or fewer.';
    }
    return null;
  }

  static String? validatePrice(String? value) {
    final money = Money.tryParse(value ?? '');
    if (money == null) {
      return 'That is not a price. Try something like 7.20.';
    }
    if (money.isNegative) {
      return 'A negative price pays the customer to drink.';
    }
    if (money.isZero) {
      return 'A price of zero will pour free drinks all night.';
    }
    return null;
  }
}
