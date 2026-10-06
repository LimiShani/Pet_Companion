import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// Distinguishes even two sessions belonging to the same account.
class SessionEpoch extends Notifier<int> {
  int _epoch = 0;

  @override
  int build() {
    ref.watch(authControllerProvider.select((value) => value.value?.id));
    return ++_epoch;
  }
}

final sessionEpochProvider = NotifierProvider<SessionEpoch, int>(
  SessionEpoch.new,
);

class StaleSessionException implements Exception {
  const StaleSessionException();
  @override
  String toString() => 'This operation belongs to a session that has ended.';
}

class SessionTicket {
  SessionTicket(Ref ref)
    : _mounted = (() => ref.mounted),
      _readEpoch = (() => ref.read(sessionEpochProvider)),
      _readUser = (() => ref.read(authControllerProvider).value?.id),
      _epoch = ref.read(sessionEpochProvider),
      _user = ref.read(authControllerProvider).value?.id;

  SessionTicket.widget(WidgetRef ref)
    : _mounted = (() => ref.context.mounted),
      _readEpoch = (() => ref.read(sessionEpochProvider)),
      _readUser = (() => ref.read(authControllerProvider).value?.id),
      _epoch = ref.read(sessionEpochProvider),
      _user = ref.read(authControllerProvider).value?.id;

  final bool Function() _mounted;
  final int Function() _readEpoch;
  final String? Function() _readUser;
  final int _epoch;
  final String? _user;

  bool get current =>
      _mounted() && _readEpoch() == _epoch && _readUser() == _user;

  void check() {
    if (!current) throw const StaleSessionException();
  }
}

final _operationKey = Object();

/// The ticket follows nested calls and queued writes across awaits.
Future<T> sessionOperation<T>(Ref ref, Future<T> Function() operation) {
  final ticket =
      Zone.current[_operationKey] as SessionTicket? ?? SessionTicket(ref);
  ticket.check();
  return runZoned(() async {
    ticket.check();
    final result = await operation();
    ticket.check();
    return result;
  }, zoneValues: {_operationKey: ticket});
}

void checkSession() => (Zone.current[_operationKey] as SessionTicket?)?.check();

/// Protects mutation completions; Riverpod's mounted check alone does not
/// distinguish a rebuilt notifier for a different account.
abstract class SessionSafeAsyncNotifier<T> extends AsyncNotifier<T> {
  @override
  AsyncValue<T> get state {
    checkSession();
    return super.state;
  }

  @override
  set state(AsyncValue<T> value) {
    checkSession();
    super.state = value;
  }
}
