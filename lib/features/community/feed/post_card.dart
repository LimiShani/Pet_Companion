import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../community_words.dart';
import '../data/community_models.dart';
import '../data/community_providers.dart';
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/post_photo_view.dart';
import '../widgets/speech_icon.dart';
import 'post_actions.dart';

enum _PostAction { report, delete }

/// A post as a white card: author, text, photo, like and comment counts.
///
/// [onOpen] makes the card (and its comment button) open the post; leave
/// it `null` where the post is already open. [onRemoved] runs after the
/// user deleted or reported the post from the card's menu.
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, this.onOpen, this.onRemoved});

  final Post post;
  final VoidCallback? onOpen;
  final VoidCallback? onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final format = AppFormat.of(context);
    final now = ref.watch(communityClockProvider)();
    final viewerId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    final isMine = post.authorId == viewerId;
    final meta = dotted([
      // A name in the other script is kept as one unit, so it cannot
      // reorder the line.
      if (post.petName != null) l10n.postWithPet(l10n.inLine(post.petName!)),
      l10n.relativeTime(app, format, post.createdAt, now),
    ]);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 8),
                  AuthorAvatar(name: post.authorName, authorId: post.authorId),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The author's name as they wrote it, next to the
                        // avatar whatever language it is in.
                        AutoDirectionText(
                          l10n.memberName(post.authorName),
                          style: AppText.cardTitle.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          meta,
                          style: AppText.label.copyWith(color: AppColors.brown),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_PostAction>(
                    tooltip: l10n.postOptions,
                    icon: const Icon(Icons.more_horiz_rounded, color: AppColors.brown),
                    color: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (action) => _onAction(context, ref, action),
                    itemBuilder: (context) => [
                      if (isMine)
                        PopupMenuItem(
                          value: _PostAction.delete,
                          child: _MenuRow(icon: Icons.delete_outline_rounded, label: app.commonDelete),
                        )
                      else
                        PopupMenuItem(
                          value: _PostAction.report,
                          child: _MenuRow(icon: Icons.flag_outlined, label: l10n.report),
                        ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: AutoDirectionText(post.text, style: AppText.body.copyWith(fontSize: 15, height: 1.45)),
              ),
              if (post.photo != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                  child: PostPhotoView(photo: post.photo!),
                ),
              const SizedBox(height: 4),
              // The buttons carry their own 8 px inset, so their icons line up
              // with the text above.
              Row(
                children: [
                  _CountButton(
                    tooltip: post.likedByMe ? l10n.unlike : l10n.like,
                    icon: post.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: post.likedByMe ? AppColors.coralDark : AppColors.brown,
                    count: format.integer(post.likeCount),
                    countInWords: l10n.likeCount(post.likeCount),
                    onTap: () => togglePostLike(context, ref, post),
                  ),
                  const SizedBox(width: 4),
                  _CountButton(
                    tooltip: l10n.comments,
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppColors.brown,
                    count: format.integer(post.commentCount),
                    countInWords: l10n.commentCount(post.commentCount),
                    onTap: onOpen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, _PostAction action) async {
    final flow = switch (action) {
      _PostAction.report => reportPostFlow(context, ref, post),
      _PostAction.delete => deletePostFlow(context, ref, post),
    };
    if (await flow) onRemoved?.call();
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.ink),
        const SizedBox(width: 10),
        Text(label, style: AppText.body.copyWith(fontSize: 15)),
      ],
    );
  }
}

/// Icon with a count next to it, with a 44 px tap target.
class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.count,
    required this.countInWords,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;

  /// The number as shown: "14".
  final String count;

  /// The number as a screen reader says it: "14 likes".
  final String countInWords;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DirectionalCommunityIcon(icon, size: 22, color: color),
                const SizedBox(width: 6),
                Text(
                  count,
                  semanticsLabel: countInWords,
                  style: AppText.secondary.copyWith(fontWeight: FontWeight.w800, color: AppColors.brown),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
