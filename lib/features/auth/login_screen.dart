import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_controller.dart';
import '../../auth/validators.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

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
      _showMessage(authErrorMessage(error ?? Object()));
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (Validators.email(email) != null) {
      _showMessage('Enter your email address above first, then tap Forgot password.');
      return;
    }
    final sent = await ref.read(authControllerProvider.notifier).sendPasswordReset(email: email);
    if (mounted) {
      _showMessage(sent ? 'If an account uses $email, a reset link is on its way.' : 'Could not send a reset link. Please try again.');
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

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to see how your pets are doing today.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                hint: 'Your password',
                controller: _password,
                validator: Validators.password,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !loading,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loading ? null : _forgotPassword,
                  style: TextButton.styleFrom(foregroundColor: AppColors.coralDark),
                  child: const Text('Forgot password?', style: AppText.secondary),
                ),
              ),
              const SizedBox(height: 6),
              PrimaryButton(label: 'Sign in', onPressed: _submit, loading: loading),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('New here?', style: AppText.body.copyWith(color: AppColors.brown)),
                  TextButton(
                    onPressed: loading ? null : () => context.push(AppRoutes.signUp),
                    style: TextButton.styleFrom(foregroundColor: AppColors.coralDark),
                    child: const Text('Create an account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
