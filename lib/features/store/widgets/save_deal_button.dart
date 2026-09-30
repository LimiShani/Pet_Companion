import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/coral_header.dart';
import '../state/store_providers.dart';
import 'store_messages.dart';

/// The heart that saves a deal for the signed-in user, or unsaves it.
class SaveDealButton extends ConsumerWidget {
  const SaveDealButton({super.key, required this.dealId, this.inHeader = false});

  final String dealId;

  /// A plain white icon for a [CoralHeader]; otherwise a white disc that
  /// sits on a deal's picture.
  final bool inHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.storeL10n;
    final saved = ref.watch(savedDealIdsProvider.select((ids) => ids.value?.contains(dealId) ?? false));
    final icon = saved ? Icons.favorite_rounded : Icons.favorite_border_rounded;
    final tooltip = saved ? l10n.removeFromSaved : l10n.saveDeal;

    Future<void> toggle() async {
      final stored = await ref.read(savedDealIdsProvider.notifier).toggle(dealId);
      if (!context.mounted) return;
      showStoreMessage(
        context,
        !stored
            ? l10n.couldNotUpdateSaved
            : saved
                ? l10n.removedFromSaved
                : l10n.savedConfirmation,
      );
    }

    if (inHeader) return CoralHeaderAction(icon: icon, tooltip: tooltip, onPressed: toggle);

    return IconButton(
      onPressed: toggle,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.white.withValues(alpha: 0.92),
        foregroundColor: saved ? AppColors.coralDark : AppColors.brown,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
