import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-width pill button. [loading] disables it and shows a spinner.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.coralDark,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.coralDark.withValues(alpha: 0.6),
        disabledForegroundColor: AppColors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.white),
            )
          : Text(label),
    );
  }
}
