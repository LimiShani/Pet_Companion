import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../auth/widgets/delete_account_dialog.dart';

export '../../auth/widgets/delete_account_dialog.dart';

/// "Delete account" on the You page: asks for the confirmation word
/// ([DeleteAccountDialog]), deletes, and says on the sign-in screen that it
/// is done (or why it is not). Nothing happens when the dialog is
/// cancelled.
Future<void> confirmAndDeleteAccount(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;
  // Taken before the wait: the app has left this page by the time the
  // message is shown.
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDeleteAccountDialog(context);
  if (!confirmed || !context.mounted) return;
  final failure = await ref
      .read(authControllerProvider.notifier)
      .deleteAccount();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          failure == null ? l10n.accountDeleted : authErrorText(l10n, failure),
        ),
      ),
    );
}
