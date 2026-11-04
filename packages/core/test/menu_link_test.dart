import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:backbar_pos_core/backbar_pos_core.dart';

class _LiveOnly implements MenuRepository {
  final live = StreamController<bool>();

  @override
  Stream<bool> watchMenuIsLive() => live.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _LiveOnly repository;
  late MenuLinkTracker tracker;

  setUp(() {
    repository = _LiveOnly();
    tracker = MenuLinkTracker(repository);
  });

  tearDown(() => tracker.dispose());

  test('is connecting until the server confirms the menu', () {
    expect(tracker.link(), MenuLink.connecting);
    expect(tracker.hasBeenLive, isFalse);
  });

  test('is live once confirmed, offline once that is lost', () async {
    repository.live.add(true);
    await pumpEventQueue();
    expect(tracker.link(), MenuLink.live);

    repository.live.add(false);
    await pumpEventQueue();
    expect(tracker.link(), MenuLink.offline);
    expect(tracker.hasBeenLive, isTrue);
  });

  test('cache-only before any confirmation is still connecting', () async {
    repository.live.add(false);
    await pumpEventQueue();
    expect(tracker.link(), MenuLink.connecting);
  });

  test('the menu stream\'s own state comes first', () async {
    repository.live.add(true);
    await pumpEventQueue();
    expect(tracker.link(menuLoading: true), MenuLink.connecting);
    expect(tracker.link(menuError: true), MenuLink.offline);
  });

  test('tells its listeners when the link changes', () async {
    var notified = 0;
    tracker.addListener(() => notified++);
    repository.live.add(true);
    await pumpEventQueue();
    expect(notified, 1);
  });

  test(
    'a broken liveness stream after confirmation reads as offline',
    () async {
      repository.live.add(true);
      await pumpEventQueue();
      repository.live.addError(StateError('listener failed'));
      await pumpEventQueue();
      expect(tracker.link(), MenuLink.offline);
    },
  );

  test('a broken liveness stream is not an uncaught error', () async {
    repository.live.addError(StateError('listener failed'));
    await pumpEventQueue();
    expect(tracker.link(), MenuLink.connecting);
  });
}
