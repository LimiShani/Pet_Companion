import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/validators.dart';
import '../../l10n/l10n.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/primary_button.dart';
import '../findvet/findvet.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// Opens Find a vet's emergency path: no account is needed for it.
  static const findVetKey = Key('login-find-vet');

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text.trim(), password: _password.text);
    if (!ok && mounted) {
      final error = ref.read(authControllerProvider).error;
      _showMessage(authErrorText(context.l10n, error ?? Object()));
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!Validators.isEmail(email)) {
      _showMessage(context.l10n.authForgotNeedsEmail);
      return;
    }
    final sent = await ref.read(authControllerProvider.notifier).sendPasswordReset(email: email);
    if (mounted) {
      final l10n = context.l10n;
      _showMessage(sent ? l10n.authResetSent(email) : l10n.authResetFailed);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    final l10n = context.l10n;
    final validators = Validators(l10n);

    return AuthScaffold(
      title: l10n.authWelcomeBack,
      subtitle: l10n.authSignInSubtitle,
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                label: l10n.authEmail,
                hint: 'you@example.com',
                controller: _email,
                validator: validators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !loading,
                leftToRight: true,
                leftToRightHint: true,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: l10n.authPassword,
                hint: l10n.authPasswordHint,
                controller: _password,
                validator: validators.password,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !loading,
                onSubmitted: (_) => _submit(),
                leftToRight: true,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: loading ? null : _forgotPassword,
                  style: TextButton.styleFrom(foregroundColor: AppColors.coralDark),
                  child: Text(l10n.authForgotPassword, style: AppText.secondary),
                ),
              ),
              const SizedBox(height: 6),
              PrimaryButton(label: l10n.authSignIn, onPressed: _submit, loading: loading),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.authNewHere, style: AppText.body.copyWith(color: AppColors.brown)),
                  TextButton(
                    onPressed: loading ? null : () => context.push(AppRoutes.signUp),
                    style: TextButton.styleFrom(foregroundColor: AppColors.coralDark),
                    child: Text(
                      l10n.authCreateAnAccount,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton.icon(
                  key: LoginScreen.findVetKey,
                  onPressed: () => openFindVet(context, mode: VetSearchMode.emergency),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coralDark,
                    side: const BorderSide(color: AppColors.coralDark, width: 2),
                    minimumSize: const Size(0, 48),
                    shape: const StadiumBorder(),
                  ),
                  icon: const AppIcon(Icons.local_hospital_rounded, size: 20),
                  label: Text(context.findVetL10n.loginEmergencyLink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
