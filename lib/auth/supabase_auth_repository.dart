import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'app_user.dart';
import 'auth_repository.dart';

/// [AuthRepository] backed by Supabase Auth (email + password).
///
/// Sessions are persisted by supabase_flutter, so [restoreSession] is
/// answered from local storage after `Supabase.initialize`.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final sb.SupabaseClient _client;

  sb.GoTrueClient get _auth => _client.auth;

  @override
  Stream<AppUser?> get userChanges => _auth.onAuthStateChange.map((state) => _toUser(state.session?.user));

  @override
  Future<AppUser?> restoreSession() async => _toUser(_auth.currentSession?.user);

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    try {
      final res = await _auth.signInWithPassword(email: email.trim(), password: password);
      final user = _toUser(res.user);
      if (user == null) throw const AuthException('Sign in did not return a user. Please try again.');
      return user;
    } on sb.AuthException catch (e) {
      throw AuthException(_friendly(e));
    }
  }

  @override
  Future<AppUser> signUp({required String displayName, required String email, required String password}) async {
    try {
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      // With "Confirm email" on (the Supabase default) there is no session
      // until the link in the email is opened.
      if (res.session == null) {
        throw const AuthException('Almost there: open the confirmation email we just sent, then sign in.');
      }
      final user = _toUser(res.user);
      if (user == null) throw const AuthException('Sign up did not return a user. Please try again.');
      return user;
    } on sb.AuthException catch (e) {
      throw AuthException(_friendly(e));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on sb.AuthException catch (e) {
      throw AuthException(_friendly(e));
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
    } on sb.AuthException catch (e) {
      throw AuthException(_friendly(e));
    }
  }

  static AppUser? _toUser(sb.User? user) {
    if (user == null) return null;
    final name = user.userMetadata?['display_name'];
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: name is String ? name : '',
    );
  }

  /// Maps Supabase's error strings to copy that fits the app's tone.
  static String _friendly(sb.AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) return 'Incorrect email or password. Please try again.';
    if (m.contains('email not confirmed')) return 'Please confirm your email address first. Check your inbox for the link.';
    if (m.contains('already registered') || m.contains('already exists')) return 'An account with that email already exists.';
    if (m.contains('rate limit') || m.contains('too many')) return 'Too many attempts. Please wait a moment and try again.';
    if (m.contains('password') && m.contains('least')) return 'Please choose a longer password.';
    if (m.contains('network') || m.contains('socket') || m.contains('failed host lookup')) {
      return 'Cannot reach the server. Check your connection and try again.';
    }
    return e.message;
  }
}
