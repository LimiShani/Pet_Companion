/// The signed-in account. Pets belong to a user.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String email;
  final String displayName;

  /// One letter for the account avatar.
  String get initial {
    final source = displayName.trim().isNotEmpty ? displayName.trim() : email;
    return source.isEmpty ? '?' : source[0].toUpperCase();
  }
}
