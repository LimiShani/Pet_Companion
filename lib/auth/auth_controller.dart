import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../platform/session.dart';
import 'app_user.dart';
import 'auth_repository.dart';
import 'fake_auth_repository.dart';

/// The auth backend. `main.dart` overrides this with Supabase when the app
/// is built with Supabase configuration; otherwise the in-memory fake runs.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FakeAuthRepository(),
);

/// Work that must happen while the session still exists, just before
/// signing out (for example: telling the server to stop sending this
/// phone push notifications). Each runs at most a few seconds; a failure
/// never stops the sign-out.
final beforeSignOutProvider = Provider<List<Future<void> Function()>>(
  (ref) => const [],
);

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
      _run(
        () => ref
            .read(authRepositoryProvider)
            .signIn(email: email, password: password),
      );

  Future<bool> signUp({
    required String displayName,
    required String email,
    required String password,
  }) => _run(
    () => ref
        .read(authRepositoryProvider)
        .signUp(displayName: displayName, email: email, password: password),
  );

  Future<bool> signOut() => _run(() async {
    for (final task in ref.read(beforeSignOutProvider)) {
      try {
        await task().timeout(const Duration(seconds: 4));
      } catch (_) {
        // Offline or refused: signing out matters more.
      }
    }
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

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

/// User-facing text for an auth failure, in the language of [l10n].
String authErrorText(AppL10n l10n, Object error) {
  if (error is! AuthException) return l10n.errorGeneric;
  return switch (error.failure) {
    AuthFailure.noAccount => l10n.authErrNoAccount,
    AuthFailure.wrongPassword => l10n.authErrWrongPassword,
    AuthFailure.emailTaken => l10n.authErrEmailTaken,
    AuthFailure.invalidCredentials => l10n.authErrInvalidCredentials,
    AuthFailure.emailNotConfirmed => l10n.authErrEmailNotConfirmed,
    AuthFailure.rateLimited => l10n.authErrRateLimited,
    AuthFailure.weakPassword => l10n.authErrWeakPassword,
    AuthFailure.network => l10n.authErrNetwork,
    AuthFailure.signInIncomplete => l10n.authErrSignInIncomplete,
    AuthFailure.signUpIncomplete => l10n.authErrSignUpIncomplete,
    AuthFailure.confirmEmailSent => l10n.authErrConfirmEmailSent,
    // The backend's own explanation is in English: shown as it is on an
    // English screen, replaced by a plain line on any other.
    AuthFailure.unknown =>
      l10n.localeName == 'en' ? error.message : l10n.errorGeneric,
  };
}

class PasswordRecoveryController extends Notifier<bool> {
  @override
  bool build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.recoveryChanges.listen(
      (recovering) => state = recovering,
    );
    ref.onDispose(subscription.cancel);
    return repository.isRecovering;
  }

  Future<void> finish(String password) async {
    final ticket = SessionTicket(ref);
    await ref.read(authRepositoryProvider).updatePassword(password);
    ticket.check();
    if (ref.mounted) state = false;
  }
}

final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryController, bool>(
      PasswordRecoveryController.new,
    );
