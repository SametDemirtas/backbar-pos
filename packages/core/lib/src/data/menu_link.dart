import 'dart:async';

import 'package:flutter/foundation.dart';

import 'menu_repository.dart';

enum MenuLink {
  connecting,

  live,

  offline;

  String get label => switch (this) {
    MenuLink.connecting => 'CONNECTING',
    MenuLink.live => 'LIVE',
    MenuLink.offline => 'OFFLINE',
  };
}

class MenuLinkTracker extends ChangeNotifier {
  MenuLinkTracker(MenuRepository repository) {
    _subscription = repository.watchMenuIsLive().listen(
      (live) {
        _live = live;
        _hasBeenLive = _hasBeenLive || live;
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('Menu liveness failed: $error');
        _live = false;
        notifyListeners();
      },
    );
  }

  late final StreamSubscription<bool> _subscription;
  bool _live = false;
  bool _hasBeenLive = false;

  bool get hasBeenLive => _hasBeenLive;

  MenuLink link({bool menuError = false, bool menuLoading = false}) {
    if (menuError) return MenuLink.offline;
    if (menuLoading) return MenuLink.connecting;
    if (_live) return MenuLink.live;
    return _hasBeenLive ? MenuLink.offline : MenuLink.connecting;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
