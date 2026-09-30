import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Labelled, rounded text field used by the auth forms.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscure = false,
    this.enabled = true,
    this.onSubmitted,
    this.leftToRight = false,
    this.leftToRightHint = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  /// Password-style field with a show/hide toggle.
  final bool obscure;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  /// What is typed here always runs left to right, whatever the screen's
  /// direction: an e-mail address, a password.
  final bool leftToRight;

  /// The hint is itself left-to-right text (`you@example.com`), so it sits
  /// where the typing will start. A hint in words follows the screen.
  final bool leftToRightHint;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 6, bottom: 6),
          child: Text(widget.label, style: AppText.label.copyWith(color: AppColors.brown)),
        ),
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          obscureText: _hidden,
          enabled: widget.enabled,
          onFieldSubmitted: widget.onSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          textDirection: widget.leftToRight ? TextDirection.ltr : null,
          style: AppText.body.copyWith(fontSize: 16, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintTextDirection: widget.leftToRightHint ? TextDirection.ltr : Directionality.of(context),
            hintStyle: AppText.body.copyWith(fontSize: 16, color: AppColors.brown.withValues(alpha: 0.55)),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: _border(Colors.transparent),
            enabledBorder: _border(Colors.transparent),
            focusedBorder: _border(AppColors.coral, 2),
            errorBorder: _border(Theme.of(context).colorScheme.error),
            focusedErrorBorder: _border(Theme.of(context).colorScheme.error, 2),
            errorStyle: AppText.label.copyWith(fontWeight: FontWeight.w600),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    tooltip: _hidden ? l10n.authShowPassword : l10n.authHidePassword,
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    color: AppColors.brown,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
}
