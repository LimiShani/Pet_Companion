import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Asks before an edit page closes with changes that were not saved.
///
/// While [dirty], going back (the header arrow, which calls
/// `Navigator.maybePop`, or the phone's back button) shows "Discard
/// changes?" and closes the page only if the owner agrees. Saving pops
/// with `Navigator.pop`, which does not ask, so it keeps working.
///
/// [dirty] must compare the fields with the values the page opened with,
/// so undoing an edit stops the question, and must be `false` while the
/// page is saving.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({super.key, required this.dirty, required this.child});

  final bool dirty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardChanges(context) && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}

/// Asks "Discard changes?"; `true` when the owner chose to discard them.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final l10n = context.l10n;
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.discardChangesTitle),
      content: Text(l10n.discardChangesBody),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.discardChangesKeepEditing)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.discardChangesDiscard)),
      ],
    ),
  );
  return discard == true;
}
