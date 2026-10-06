import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_controller.dart';
import '../../l10n/l10n.dart';
import '../../platform/session.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final ticket = SessionTicket.widget(ref);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(passwordRecoveryProvider.notifier).finish(_password.text);
    } catch (error) {
      if (mounted && ticket.current) {
        setState(() => _error = authErrorText(context.l10n, error));
      }
    } finally {
      if (mounted && ticket.current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final he = Localizations.localeOf(context).languageCode == 'he';
    return Scaffold(
      appBar: AppBar(title: Text(he ? 'סיסמה חדשה' : 'New password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Form(
              key: _form,
              child: Column(
                children: [
                  Text(
                    he
                        ? 'בחרו סיסמה חדשה לחשבון שלכם.'
                        : 'Choose a new password for your account.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: he ? 'סיסמה חדשה' : 'New password',
                    ),
                    validator: (value) => (value?.length ?? 0) >= 8
                        ? null
                        : (he ? 'לפחות 8 תווים' : 'Use at least 8 characters'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: he ? 'אימות סיסמה' : 'Confirm password',
                    ),
                    validator: (value) => value == _password.text
                        ? null
                        : (he
                              ? 'הסיסמאות אינן זהות'
                              : 'Passwords do not match'),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const CircularProgressIndicator()
                        : Text(he ? 'שמירת הסיסמה' : 'Save password'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .signOut(),
                    child: Text(he ? 'ביטול' : 'Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
