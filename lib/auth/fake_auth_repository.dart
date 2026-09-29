import 'app_user.dart';
import 'auth_repository.dart';

/// In-memory accounts for development. Nothing persists across restarts.
///
/// A demo account is seeded so the app can be signed into right away:
/// see [demoEmail] and [demoPassword].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.latency = const Duration(milliseconds: 400)}) {
    _accounts[demoEmail] = _Account(
      user: const AppUser(id: 'demo', email: demoEmail, displayName: 'Alex'),
      password: demoPassword,
    );
  }

  static const demoEmail = 'demo@petcompanion.app';
  static const demoPassword = 'kelly1234';

  /// Simulated network delay so loading states are visible.
  final Duration latency;

  final _accounts = <String, _Account>{};
  AppUser? _current;

  static String _key(String email) => email.trim().toLowerCase();

  Future<void> _wait() => Future<void>.delayed(latency);

  @override
  Future<AppUser?> restoreSession() async {
    await _wait();
    return _current;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    await _wait();
    final account = _accounts[_key(email)];
    if (account == null) throw const AuthException('No account uses that email address.');
    if (account.password != password) throw const AuthException('Incorrect password. Please try again.');
    return _current = account.user;
  }

  @override
  Future<AppUser> signUp({required String displayName, required String email, required String password}) async {
    await _wait();
    final key = _key(email);
    if (_accounts.containsKey(key)) throw const AuthException('An account with that email already exists.');
    final user = AppUser(id: 'u${_accounts.length + 1}', email: key, displayName: displayName.trim());
    _accounts[key] = _Account(user: user, password: password);
    return _current = user;
  }

  @override
  Future<void> signOut() async {
    await _wait();
    _current = null;
  }

  @override
  Future<void> sendPasswordReset({required String email}) => _wait();
}

class _Account {
  const _Account({required this.user, required this.password});

  final AppUser user;
  final String password;
}
