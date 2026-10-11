import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_controller.dart';
import '../../l10n/l10n.dart';
import '../../platform/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/primary_button.dart';
import 'widgets/auth_text_field.dart';

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
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          // No back arrow: the screen is opened by a recovery link, and
          // Cancel below signs out instead.
          CoralHeader(title: l10n.resetPasswordTitle),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                28,
                AppSpacing.screen,
                24,
              ),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.resetPasswordIntro,
                        style: AppText.body.copyWith(color: AppColors.brown),
                      ),
                      const SizedBox(height: 22),
                      AuthTextField(
                        label: l10n.resetPasswordLabel,
                        controller: _password,
                        obscure: true,
                        enabled: !_busy,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) => (value?.length ?? 0) >= 8
                            ? null
                            : l10n.resetPasswordTooShort,
                        leftToRight: true,
                      ),
                      const SizedBox(height: 14),
                      AuthTextField(
                        label: l10n.resetPasswordConfirm,
                        controller: _confirm,
                        obscure: true,
                        enabled: !_busy,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) => value == _password.text
                            ? null
                            : l10n.resetPasswordMismatch,
                        onSubmitted: (_) => _save(),
                        leftToRight: true,
                      ),
                      const SizedBox(height: 22),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: AppText.body.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      PrimaryButton(
                        label: l10n.resetPasswordSave,
                        onPressed: _save,
                        loading: _busy,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => ref
                                    .read(authControllerProvider.notifier)
                                    .signOut(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.coralDark,
                          ),
                          child: Text(
                            l10n.commonCancel,
                            style: AppText.body.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
