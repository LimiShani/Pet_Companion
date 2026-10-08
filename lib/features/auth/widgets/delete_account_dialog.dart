import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Asks whether to delete the account for good. The red button only works
/// once the confirmation word is typed, so a slip of the thumb cannot
/// wipe years of records. Resolves to `true` when confirmed.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const DeleteAccountDialog(),
  );
  return confirmed ?? false;
}

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  static const fieldKey = Key('delete-account-word');
  static const confirmKey = Key('delete-account-confirm');
  static const cancelKey = Key('delete-account-cancel');

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _word = TextEditingController();

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final expected = l10n.accountDeleteWord;
    final typed = _word.text.trim().toLowerCase() == expected.toLowerCase();

    return AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      ),
      title: Text(l10n.accountDeleteTitle, style: AppText.cardTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.accountDeleteBody, style: AppText.body),
          const SizedBox(height: 16),
          TextField(
            key: DeleteAccountDialog.fieldKey,
            controller: _word,
            onChanged: (_) => setState(() {}),
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: l10n.accountDeleteHint(expected),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          key: DeleteAccountDialog.cancelKey,
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.brown),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: DeleteAccountDialog.confirmKey,
          onPressed: typed ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.coralDark,
            foregroundColor: AppColors.white,
            shape: const StadiumBorder(),
          ),
          child: Text(l10n.accountDeleteConfirm),
        ),
      ],
    );
  }
}
