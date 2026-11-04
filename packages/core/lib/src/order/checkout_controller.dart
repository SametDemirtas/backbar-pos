import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/order_repository.dart';
import '../models/order.dart';
import 'order_controller.dart';

class CheckoutController extends ChangeNotifier {
  CheckoutController({
    required this.order,
    required OrderRepository repository,
    required String tillLabel,
    required String staffUid,
    this.slowAfter = defaultSlowAfter,
  }) : _repository = repository,
       _tillLabel = tillLabel,
       _staffUid = staffUid {
    order.addListener(_onOrderChanged);
  }

  static const Duration defaultSlowAfter = Duration(seconds: 6);

  final OrderController order;
  final Duration slowAfter;

  OrderRepository _repository;
  String _tillLabel;
  String _staffUid;

  bool _sending = false;
  bool _slow = false;

  String? _attemptId;
  Order? _attemptOrder;
  Object? _error;
  Timer? _slowTimer;
  bool _disposed = false;

  bool get sending => _sending;

  bool get slow => _slow;

  Object? get error => _error;

  void configure({
    required OrderRepository repository,
    required String tillLabel,
    required String staffUid,
  }) {
    if (!identical(repository, _repository) || staffUid != _staffUid) {
      _attemptId = null;
      _attemptOrder = null;
    }
    _repository = repository;
    _tillLabel = tillLabel;
    _staffUid = staffUid;
  }

  void _onOrderChanged() {
    if (_sending || _error == null) return;
    if (order.isEmpty ||
        (_error is CheckTooLarge && order.order.fitsOneOrder)) {
      _error = null;
      notifyListeners();
    }
  }

  Future<Order?> send() async {
    if (_sending || order.isEmpty) return null;
    final submitted = order.order;

    if (!submitted.fitsOneOrder) {
      _error = const CheckTooLarge();
      notifyListeners();
      return null;
    }
    final orderId = _attemptOrder == submitted && _attemptId != null
        ? _attemptId!
        : _repository.newOrderId();
    _attemptId = orderId;
    _attemptOrder = submitted;

    _sending = true;
    _slow = false;
    _error = null;
    notifyListeners();
    _slowTimer = Timer(slowAfter, () {
      if (_disposed) return;
      _slow = true;
      notifyListeners();
    });

    try {
      await _repository.submit(
        submitted,
        orderId: orderId,
        tillLabel: _tillLabel,
        staffUid: _staffUid,
      );
      _attemptId = null;
      _attemptOrder = null;
      if (!_disposed) order.removeSubmitted(submitted);
      return submitted;
    } catch (error) {
      debugPrint('Send failed: $error');
      _error = error;
      return null;
    } finally {
      _slowTimer?.cancel();
      if (!_disposed) {
        _sending = false;
        _slow = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    order.removeListener(_onOrderChanged);
    _slowTimer?.cancel();
    super.dispose();
  }
}
