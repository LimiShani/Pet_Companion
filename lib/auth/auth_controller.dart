import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_user.dart';
import 'auth_repository.dart';
import 'fake_auth_repository.dart';

/// The auth backend. `main.dart` overrides this with Supabase when the app
/// is built with Supabase configuration; otherwise the in-memory fake runs.
final authRepositoryProvider = Provider<AuthRepository>((ref) => FakeAuthRepository());

/// The signed-in user (`null` when signed out). Loading while a session is
/// being restored or an auth action is in flight; error after a failed one.
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() {
    final repo = ref.watch(authRepositoryProvider);
    // Keep in step with the backend: token refreshes, sign-outs from other
    // tabs, links opened from emails.
    final sub = repo.userChanges.listen((user) => state = AsyncData(user));
    ref.onDispose(sub.cancel);
    return repo.restoreSession();
  }

  Future<bool> signIn({required String email, required String password}) =>
      _run(() => ref.read(authRepositoryProvider).signIn(email: email, password: password));

  Future<bool> signUp({required String displayName, required String email, required String password}) =>
      _run(() => ref.read(authRepositoryProvider).signUp(displayName: displayName, email: email, password: password));

  Future<bool> signOut() => _run(() async {
        await ref.read(authRepositoryProvider).signOut();
        return null;
      });

  Future<bool> sendPasswordReset({required String email}) async {
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email: email);
      return true;
    } on AuthException {
      return false;
    }
  }

  /// Runs [action], exposing loading and error states through [state].
  /// Returns whether it succeeded.
  Future<bool> _run(Future<AppUser?> Function() action) async {
    // Riverpod keeps the previous value on a loading state, so the router
    // can tell "signing in" apart from "restoring the session".
    state = const AsyncLoading();
    final next = await AsyncValue.guard(action);
    state = next;
    return !next.hasError;
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

/// User-facing text for an auth failure.
String authErrorMessage(Object error) =>
    error is AuthException ? error.message : 'Something went wrong. Please try again.';
