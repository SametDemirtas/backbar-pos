import 'package:flutter/foundation.dart';

import '../models/menu_item.dart';
import '../models/order.dart';
import '../money/money.dart';

class OrderController extends ChangeNotifier {
  Order _order = Order.empty;
  Order get order => _order;

  bool get isEmpty => _order.isEmpty;
  Money get total => _order.total;
  int get itemCount => _order.itemCount;

  int quantityOf(String itemId) => _order.lines
      .where((line) => line.itemId == itemId)
      .fold(0, (sum, line) => sum + line.quantity);

  bool add(MenuItem item) {
    if (!item.isAvailable) return false;

    final line = OrderLine(
      itemId: item.id,
      name: item.name,
      unitPrice: Money.fromCents(item.priceCents),
      quantity: 1,
    );
    final index = _order.lines.indexWhere(
      (existing) => existing.key == line.key,
    );

    final lines = [..._order.lines];
    if (index == -1) {
      lines.add(line);
    } else {
      lines[index] = line.copyWith(quantity: lines[index].quantity + 1);
    }
    _setOrder(Order(lines: lines));
    return true;
  }

  void removeOne(String lineKey) {
    final index = _order.lines.indexWhere((line) => line.key == lineKey);
    if (index == -1) return;

    final lines = [..._order.lines];
    final line = lines[index];
    if (line.quantity <= 1) {
      lines.removeAt(index);
    } else {
      lines[index] = line.copyWith(quantity: line.quantity - 1);
    }
    _setOrder(Order(lines: lines));
  }

  void removeLine(String lineKey) {
    final lines = [
      for (final line in _order.lines)
        if (line.key != lineKey) line,
    ];
    if (lines.length == _order.lines.length) return;
    _setOrder(Order(lines: lines));
  }

  void clear() {
    if (_order.isEmpty) return;
    _setOrder(Order.empty);
  }

  void removeSubmitted(Order submitted) {
    final remaining = <OrderLine>[];
    final sentByKey = {
      for (final line in submitted.lines) line.key: line.quantity,
    };

    for (final line in _order.lines) {
      final sent = sentByKey[line.key] ?? 0;
      final left = line.quantity - sent;
      if (left > 0) remaining.add(line.copyWith(quantity: left));
    }

    if (remaining.length == _order.lines.length &&
        remaining.every((line) => _order.lines.contains(line))) {
      return;
    }
    _setOrder(Order(lines: remaining));
  }

  Set<String> unsellableItemIds(List<MenuItem> menu) =>
      _order.unsellableItemIds(menu);

  void _setOrder(Order order) {
    _order = order;
    notifyListeners();
  }
}
