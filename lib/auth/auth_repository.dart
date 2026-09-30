import 'app_user.dart';

/// Thrown by an [AuthRepository] with a message safe to show to the user.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Account operations. The app talks only to this interface, so the
/// in-memory implementation can be swapped for Supabase (or Firebase)
/// without touching the screens.
abstract class AuthRepository {
  /// Emits the current user whenever it changes (sign in, sign out, token
  /// refresh, a link opened from an email). `null` means signed out.
  Stream<AppUser?> get userChanges;

  /// The user from a previous session, or `null`.
  Future<AppUser?> restoreSession();

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> signUp({required String displayName, required String email, required String password});

  Future<void> signOut();

  /// Sends a reset link. Must not reveal whether the email is registered.
  Future<void> sendPasswordReset({required String email});
}
