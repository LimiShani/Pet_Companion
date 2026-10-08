import 'app_user.dart';

/// Why an account action failed. Repositories report the reason; the screen
/// puts it into words in the app's language (see `authErrorText`).
enum AuthFailure {
  noAccount,
  wrongPassword,
  emailTaken,
  invalidCredentials,
  emailNotConfirmed,
  rateLimited,
  weakPassword,
  network,
  signInIncomplete,
  signUpIncomplete,

  /// Not really a failure: the account was created and waits for the link
  /// in the confirmation email.
  confirmEmailSent,

  /// Anything the app has no words of its own for.
  unknown,
}

/// Thrown by an [AuthRepository]. [failure] says what went wrong;
/// [message] is the same in plain English, for logs and for an
/// [AuthFailure.unknown] failure, where it is the backend's own explanation.
class AuthException implements Exception {
  const AuthException(this.message, [this.failure = AuthFailure.unknown]);

  final String message;
  final AuthFailure failure;

  @override
  String toString() => message;
}

/// Account operations. The app talks only to this interface, so the
/// in-memory implementation can be swapped for Supabase (or Firebase)
/// without touching the screens.
abstract class AuthRepository {
  Stream<bool> get recoveryChanges;
  bool get isRecovering;
  Future<void> updatePassword(String password);

  /// Emits the current user whenever it changes (sign in, sign out, token
  /// refresh, a link opened from an email). `null` means signed out.
  Stream<AppUser?> get userChanges;

  /// The user from a previous session, or `null`.
  Future<AppUser?> restoreSession();

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> signUp({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Deletes the signed-in account and everything it owns, for good, and
  /// ends the session. Throws an [AuthException] when the backend refused;
  /// the account then still exists and stays signed in.
  Future<void> deleteAccount();

  /// Sends a reset link. Must not reveal whether the email is registered.
  Future<void> sendPasswordReset({required String email});
}
