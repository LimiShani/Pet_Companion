import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../community_words.dart';
import '../data/community_models.dart';
import 'feed_controller.dart';

void showCommunitySnack(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Likes or unlikes [post], reporting a failure in a snack bar.
Future<void> togglePostLike(BuildContext context, WidgetRef ref, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  final errorWords = communityErrorWords(context);
  try {
    await ref.read(feedControllerProvider.notifier).setLiked(post.id, liked: !post.likedByMe);
  } catch (e) {
    showCommunitySnack(messenger, errorWords(e));
  }
}

/// Asks for a reason, records the report and hides the post. Returns
/// whether the post was reported.
Future<bool> reportPostFlow(BuildContext context, WidgetRef ref, Post post) async {
  // Looked up before the first await: the card may be gone afterwards.
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(feedControllerProvider.notifier);
  final l10n = context.communityL10n;
  final errorWords = communityErrorWords(context);

  final reason = await showModalBottomSheet<ReportReason>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => const _ReportSheet(),
  );
  if (reason == null) return false;

  try {
    await controller.report(post.id, reason);
    showCommunitySnack(messenger, l10n.reportThanks);
    return true;
  } catch (e) {
    showCommunitySnack(messenger, errorWords(e));
    return false;
  }
}

/// Confirms, then deletes the user's own post. Returns whether it was
/// deleted.
Future<bool> deletePostFlow(BuildContext context, WidgetRef ref, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(feedControllerProvider.notifier);
  final l10n = context.communityL10n;
  final app = context.l10n;
  final errorWords = communityErrorWords(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.deletePostTitle),
      content: Text(l10n.deletePostBody),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(app.commonCancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(app.commonDelete)),
      ],
    ),
  );
  if (confirmed != true) return false;

  try {
    await controller.delete(post.id);
    showCommunitySnack(messenger, l10n.postDeleted);
    return true;
  } catch (e) {
    showCommunitySnack(messenger, errorWords(e));
    return false;
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final radius = BorderRadius.circular(AppSpacing.fieldRadius);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.reportTitle, style: AppText.cardTitle.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(l10n.reportBody, style: AppText.body.copyWith(color: AppColors.brown)),
            const SizedBox(height: 12),
            for (final reason in ReportReason.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.white,
                  borderRadius: radius,
                  child: InkWell(
                    borderRadius: radius,
                    onTap: () => Navigator.of(context).pop(reason),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(child: Text(l10n.reportReason(reason), style: AppText.body.copyWith(fontSize: 15))),
                          // Mirrors itself in a right-to-left layout.
                          const AppIcon(Icons.chevron_right_rounded, color: AppColors.brown),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
