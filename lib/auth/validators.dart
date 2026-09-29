/// Form validators shared by the auth screens. Return `null` when valid.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static const minPasswordLength = 8;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address.';
    if (!_email.hasMatch(v)) return 'That does not look like an email address.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter your password.';
    if (v.length < minPasswordLength) return 'Use at least $minPasswordLength characters.';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Repeat your password.';
    if (value != original) return 'The passwords do not match.';
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Tell us what to call you.';
    if (v.length < 2) return 'Use at least 2 characters.';
    return null;
  }
}
