import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../auth/validators.dart';
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
        ..showSnackBar(SnackBar(content: Text(authErrorMessage(error ?? Object()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'One account for all of your pets.',
      showBack: true,
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                label: 'Your name',
                hint: 'What should we call you?',
                controller: _name,
                validator: Validators.displayName,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                enabled: !loading,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: 'Email',
                hint: 'you@example.com',
                controller: _email,
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !loading,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: 'Password',
                hint: 'At least ${Validators.minPasswordLength} characters',
                controller: _password,
                validator: Validators.password,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                enabled: !loading,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: 'Repeat password',
                hint: 'Same as above',
                controller: _confirm,
                validator: (v) => Validators.confirmPassword(v, _password.text),
                obscure: true,
                textInputAction: TextInputAction.done,
                enabled: !loading,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 22),
              PrimaryButton(label: 'Create account', onPressed: _submit, loading: loading),
              const SizedBox(height: 14),
              Text(
                'By creating an account you agree to the Terms of Use and Privacy Policy.',
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
