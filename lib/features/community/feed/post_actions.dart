import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
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
  try {
    await ref.read(feedControllerProvider.notifier).setLiked(post.id, liked: !post.likedByMe);
  } catch (e) {
    showCommunitySnack(messenger, communityErrorMessage(e));
  }
}

/// Asks for a reason, records the report and hides the post. Returns
/// whether the post was reported.
Future<bool> reportPostFlow(BuildContext context, WidgetRef ref, Post post) async {
  // Looked up before the first await: the card may be gone afterwards.
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(feedControllerProvider.notifier);

  final reason = await showModalBottomSheet<ReportReason>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => const _ReportSheet(),
  );
  if (reason == null) return false;

  try {
    await controller.report(post.id, reason);
    showCommunitySnack(messenger, 'Thanks. We have hidden this post and will review it.');
    return true;
  } catch (e) {
    showCommunitySnack(messenger, communityErrorMessage(e));
    return false;
  }
}

/// Confirms, then deletes the user's own post. Returns whether it was
/// deleted.
Future<bool> deletePostFlow(BuildContext context, WidgetRef ref, Post post) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(feedControllerProvider.notifier);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this post?'),
      content: const Text('Its comments and likes go with it. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirmed != true) return false;

  try {
    await controller.delete(post.id);
    showCommunitySnack(messenger, 'Your post was deleted.');
    return true;
  } catch (e) {
    showCommunitySnack(messenger, communityErrorMessage(e));
    return false;
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.fieldRadius);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report this post', style: AppText.cardTitle.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Tell us what is wrong. We hide the post for you right away and review it.',
              style: AppText.body.copyWith(color: AppColors.brown),
            ),
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
                          Expanded(child: Text(reason.label, style: AppText.body.copyWith(fontSize: 15))),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
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
