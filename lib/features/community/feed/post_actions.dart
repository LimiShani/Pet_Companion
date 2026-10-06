import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/l10n.dart';
import '../community_words.dart';
import '../../../services/community/data/community_models.dart';
import '../safety/safety_flows.dart';
import '../community_routes.dart';
import 'feed_controller.dart';

/// Hands text to the phone's share sheet. Tests replace it.
final communityShareProvider = Provider<Future<void> Function(String text)>(
  (ref) => (text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  },
);

/// Shares a post's words, with who wrote them, outside the app.
Future<void> sharePost(BuildContext context, WidgetRef ref, Post post) async {
  final l10n = context.communityL10n;
  await ref.read(communityShareProvider)(
    l10n.shareText(l10n.memberName(post.authorName), post.text),
  );
}

/// Opens a member's page above the current one, so Back returns to it.
void openMember(BuildContext context, String memberId) =>
    GoRouter.of(context).push(CommunityRoutes.member(memberId));

void showCommunitySnack(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Likes or unlikes [post], reporting a failure in a snack bar.
Future<void> togglePostLike(
  BuildContext context,
  WidgetRef ref,
  Post post,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final errorWords = communityErrorWords(context);
  try {
    await ref
        .read(feedControllerProvider.notifier)
        .setLiked(post.id, liked: !post.likedByMe, known: post);
  } catch (e) {
    showCommunitySnack(messenger, errorWords(e));
  }
}

/// Asks for a reason, records the report and hides the post. Returns
/// whether the post was reported.
Future<bool> reportPostFlow(
  BuildContext context,
  WidgetRef ref,
  Post post,
) async {
  // Looked up before the first await: the card may be gone afterwards.
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(feedControllerProvider.notifier);
  final l10n = context.communityL10n;
  final errorWords = communityErrorWords(context);

  final reason = await askReportReason(
    context,
    title: l10n.reportTitle,
    body: l10n.reportBody,
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
Future<bool> deletePostFlow(
  BuildContext context,
  WidgetRef ref,
  Post post,
) async {
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(app.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(app.commonDelete),
        ),
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
