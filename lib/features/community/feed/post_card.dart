import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../community_words.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/post_photo_view.dart';
import '../widgets/small_tag.dart';
import '../widgets/speech_icon.dart';
import 'post_composer_screen.dart';
import '../safety/safety_flows.dart';
import 'post_actions.dart';

enum _PostAction { edit, delete, share, report, block }

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
    final viewerId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    final isMine = post.authorId == viewerId;
    // Only offer what the account may do: the database refuses the rest.
    final canEdit =
        isMine && ref.watch(capabilityProvider('community.feed.edit'));
    final canReport =
        !isMine && ref.watch(capabilityProvider('community.feed.post'));
    final canLike = ref.watch(capabilityProvider('community.feed.post'));
    final meta = dotted([
      // A name in the other script is kept as one unit, so it cannot
      // reorder the line.
      if (post.petName != null) l10n.postWithPet(l10n.inLine(post.petName!)),
      l10n.relativeTime(app, format, post.createdAt, now),
      if (post.editedAt != null) l10n.postEdited,
    ]);
    final answered =
        post.kind == PostKind.question && post.helpfulCommentId != null;

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
                  Semantics(
                    button: true,
                    label: l10n.openProfile(
                      l10n.inLine(l10n.memberName(post.authorName)),
                    ),
                    child: GestureDetector(
                      onTap: () => openMember(context, post.authorId),
                      child: AuthorAvatar(
                        name: post.authorName,
                        authorId: post.authorId,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The author's name as they wrote it, next to the
                        // avatar whatever language it is in.
                        AutoDirectionText(
                          l10n.memberName(post.authorName),
                          style: AppText.cardTitle.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
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
                    icon: const AppIcon(
                      Icons.more_horiz_rounded,
                      color: AppColors.brown,
                    ),
                    color: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (action) => _onAction(context, ref, action),
                    itemBuilder: (context) => [
                      if (canEdit) ...[
                        PopupMenuItem(
                          value: _PostAction.edit,
                          child: _MenuRow(
                            icon: Icons.edit_outlined,
                            label: l10n.editPost,
                          ),
                        ),
                        PopupMenuItem(
                          value: _PostAction.delete,
                          child: _MenuRow(
                            icon: Icons.delete_outline_rounded,
                            label: app.commonDelete,
                          ),
                        ),
                      ],
                      PopupMenuItem(
                        value: _PostAction.share,
                        child: _MenuRow(
                          icon: Icons.share_outlined,
                          label: l10n.sharePost,
                        ),
                      ),
                      if (!isMine) ...[
                        if (canReport)
                          PopupMenuItem(
                            value: _PostAction.report,
                            child: _MenuRow(
                              icon: Icons.flag_outlined,
                              label: l10n.report,
                            ),
                          ),
                        PopupMenuItem(
                          value: _PostAction.block,
                          child: _MenuRow(
                            icon: Icons.block_rounded,
                            label: l10n.blockMember(
                              l10n.inLine(l10n.memberName(post.authorName)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (post.kind != PostKind.moment || answered)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (post.kind != PostKind.moment)
                        SmallTag(
                          l10n.postKind(post.kind),
                          color: post.kind == PostKind.lostFound
                              ? AppColors.peach
                              : AppColors.yellow,
                          icon: _kindIcon(post.kind),
                        ),
                      if (answered)
                        SmallTag(
                          l10n.answeredTag,
                          color: AppColors.sage,
                          icon: Icons.check_rounded,
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: AutoDirectionText(
                  post.text,
                  style: AppText.body.copyWith(fontSize: 15, height: 1.45),
                ),
              ),
              if (post.photo != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                  // Double tap on the photo likes, as in photo apps; it
                  // never unlikes. Only the photo: elsewhere a double tap
                  // would delay every single tap on the card.
                  child: GestureDetector(
                    onDoubleTap: canLike && !post.likedByMe
                        ? () => togglePostLike(context, ref, post)
                        : null,
                    child: PostPhotoView(photo: post.photo!),
                  ),
                ),
              const SizedBox(height: 4),
              // The buttons carry their own 8 px inset, so their icons line up
              // with the text above.
              Row(
                children: [
                  _CountButton(
                    tooltip: post.likedByMe ? l10n.unlike : l10n.like,
                    icon: post.likedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: post.likedByMe
                        ? AppColors.coralDark
                        : AppColors.brown,
                    count: format.integer(post.likeCount),
                    countInWords: l10n.likeCount(post.likeCount),
                    onTap: canLike
                        ? () => togglePostLike(context, ref, post)
                        : null,
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

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _PostAction action,
  ) async {
    if (action == _PostAction.edit) {
      await openPostComposer(context, editing: post);
      return;
    }
    if (action == _PostAction.share) {
      await sharePost(context, ref, post);
      return;
    }
    final flow = switch (action) {
      _PostAction.edit || _PostAction.share => Future.value(false),
      _PostAction.report => reportPostFlow(context, ref, post),
      _PostAction.block => blockMemberFlow(
        context,
        ref,
        memberId: post.authorId,
        memberName: post.authorName,
      ),
      _PostAction.delete => deletePostFlow(context, ref, post),
    };
    if (await flow) onRemoved?.call();
  }
}

IconData _kindIcon(PostKind kind) => switch (kind) {
  PostKind.moment => Icons.photo_camera_outlined,
  PostKind.question => Icons.help_outline_rounded,
  PostKind.tip => Icons.lightbulb_outline_rounded,
  PostKind.recommendation => Icons.thumb_up_alt_outlined,
  PostKind.lostFound => Icons.location_searching_rounded,
};

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 20, color: AppColors.ink),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(fontSize: 15),
          ),
        ),
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
                  style: AppText.secondary.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.brown,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
