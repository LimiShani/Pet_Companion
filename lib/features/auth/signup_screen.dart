import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../auth/validators.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(authControllerProvider.notifier).signUp(
          displayName: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
    if (!ok && mounted) {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(authErrorText(context.l10n, error ?? Object()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    final l10n = context.l10n;
    final validators = Validators(l10n);

    return AuthScaffold(
      title: l10n.authCreateTitle,
      subtitle: l10n.authCreateSubtitle,
      showBack: true,
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                label: l10n.authYourName,
                hint: l10n.authYourNameHint,
                controller: _name,
                validator: validators.displayName,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                enabled: !loading,
              ),
              const SizedBox(height: 14),
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
                hint: l10n.authPasswordMinHint(Validators.minPasswordLength),
                controller: _password,
                validator: validators.password,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                enabled: !loading,
                leftToRight: true,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: l10n.authRepeatPassword,
                hint: l10n.authRepeatPasswordHint,
                controller: _confirm,
                validator: (v) => validators.confirmPassword(v, _password.text),
                obscure: true,
                textInputAction: TextInputAction.done,
                enabled: !loading,
                onSubmitted: (_) => _submit(),
                leftToRight: true,
              ),
              const SizedBox(height: 22),
              PrimaryButton(label: l10n.authCreateAccount, onPressed: _submit, loading: loading),
              const SizedBox(height: 14),
              Text(
                l10n.authTerms,
                textAlign: TextAlign.center,
                style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
