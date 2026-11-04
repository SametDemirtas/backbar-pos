import 'package:flutter/foundation.dart';

import '../money/money.dart';
import 'menu_item.dart';

@immutable
class OrderLine {
  const OrderLine({
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  }) : assert(quantity > 0, 'A line with no quantity should not exist');

  final String itemId;
  final String name;
  final Money unitPrice;
  final int quantity;

  String get key => '$itemId@${unitPrice.cents}';

  Money get amount => unitPrice * quantity;

  OrderLine copyWith({int? quantity}) => OrderLine(
    itemId: itemId,
    name: name,
    unitPrice: unitPrice,
    quantity: quantity ?? this.quantity,
  );

  Map<String, Object?> toMap() => {
    'itemId': itemId,
    'name': name,
    'unitPriceCents': unitPrice.cents,
    'quantity': quantity,
    'amountCents': amount.cents,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderLine &&
          other.itemId == itemId &&
          other.name == name &&
          other.unitPrice == unitPrice &&
          other.quantity == quantity;

  @override
  int get hashCode => Object.hash(itemId, name, unitPrice, quantity);

  @override
  String toString() => 'OrderLine($quantity × $name @ ${unitPrice.format()})';
}

@immutable
class Order {
  Order({List<OrderLine> lines = const []})
    : lines = List<OrderLine>.unmodifiable(lines);

  final List<OrderLine> lines;

  static final Order empty = Order();

  static const int maxLines = 200;
  static const int maxItems = 10000;

  bool get fitsOneOrder =>
      lines.length <= maxLines &&
      itemCount <= maxItems &&
      total.cents <= Money.maxCents;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  Money get total => lines.fold(Money.zero, (sum, line) => sum + line.amount);

  Set<String> unsellableItemIds(List<MenuItem> menu) {
    final sellable = {
      for (final item in menu)
        if (item.isAvailable) item.id,
    };
    return {
      for (final line in lines)
        if (!sellable.contains(line.itemId)) line.itemId,
    };
  }

  Map<String, Object?> toMap() => {
    'lines': [for (final line in lines) line.toMap()],
    'itemCount': itemCount,
    'totalCents': total.cents,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order && listEquals(other.lines, lines);

  @override
  int get hashCode => Object.hashAll(lines);

  @override
  String toString() => 'Order(${lines.length} lines, ${total.format()})';
}

class CheckTooLarge implements Exception {
  const CheckTooLarge();

  @override
  String toString() => 'CheckTooLarge';
}
