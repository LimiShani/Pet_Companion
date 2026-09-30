import '../l10n/l10n.dart';

/// Form validators shared by the auth screens, answering in the language of
/// the strings they are given: `Validators(context.l10n).email`. Each
/// returns `null` when the value is valid.
class Validators {
  const Validators(this._l10n);

  final AppL10n _l10n;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static const minPasswordLength = 8;
  static const minNameLength = 2;

  /// Whether [value] looks like an email address.
  static bool isEmail(String value) => _email.hasMatch(value.trim());

  String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return _l10n.validEmailEmpty;
    if (!isEmail(v)) return _l10n.validEmailInvalid;
    return null;
  }

  String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return _l10n.validPasswordEmpty;
    if (v.length < minPasswordLength) return _l10n.validMinLength(minPasswordLength);
    return null;
  }

  String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return _l10n.validConfirmEmpty;
    if (value != original) return _l10n.validConfirmMismatch;
    return null;
  }

  String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return _l10n.validNameEmpty;
    if (v.length < minNameLength) return _l10n.validMinLength(minNameLength);
    return null;
  }
}
