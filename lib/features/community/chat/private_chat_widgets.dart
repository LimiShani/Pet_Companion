import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../community_words.dart';
import '../feed/post_actions.dart' show showCommunitySnack;
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/icon_disc.dart';
import 'private_chat_providers.dart';

/// What leads a private chat: the other person's avatar in a chat of two,
/// a group disc otherwise.
class PrivateChatAvatar extends StatelessWidget {
  const PrivateChatAvatar({super.key, required this.chat, this.size = 48});

  final PrivateChat chat;
  final double size;

  @override
  Widget build(BuildContext context) => chat.direct
      ? AuthorAvatar(
          name: chat.directName,
          authorId: chat.directWith!,
          size: size,
        )
      : IconDisc(icon: Icons.groups_rounded, size: size);
}

/// An invitation waiting for the member: who invites them and to what,
/// with Join and No thanks. Joining opens the chat.
class ChatInvitationCard extends ConsumerStatefulWidget {
  const ChatInvitationCard({super.key, required this.invitation});

  final ChatInvitation invitation;

  @override
  ConsumerState<ChatInvitationCard> createState() => _ChatInvitationCardState();
}

class _ChatInvitationCardState extends ConsumerState<ChatInvitationCard> {
  var _busy = false;

  Future<void> _answer(bool accept) async {
    if (_busy) return;
    final invitation = widget.invitation;
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    final declined = context.communityL10n.invitationDeclined;
    setState(() => _busy = true);
    try {
      await ref
          .read(privateChatControllerProvider.notifier)
          .answer(invitation.channelId, accept: accept);
      if (!mounted) return;
      if (accept) {
        openChat(context, invitation.channelId);
      } else {
        showCommunitySnack(messenger, declined);
      }
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final invitation = widget.invitation;
    final inviter = l10n.inLine(l10n.memberName(invitation.inviterName));
    final title = invitation.direct || invitation.name.trim().isEmpty
        ? l10n.invitationDirect(inviter)
        : invitation.name;
    return Card(
      key: ValueKey('invitation-${invitation.channelId}'),
      color: AppColors.yellow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthorAvatar(
                  name: invitation.inviterName,
                  authorId: invitation.inviterId,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AutoDirectionText(
                        title,
                        style: AppText.cardTitle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dotted([
                          if (!invitation.direct) l10n.invitationFrom(inviter),
                          l10n.participantCount(invitation.participantCount),
                        ]),
                        style: AppText.label.copyWith(color: AppColors.brown),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _answer(false),
                  child: Text(l10n.declineInvitation),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _answer(true),
                  child: Text(l10n.joinChat),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A line of a private chat that says what happened, centred in the
/// conversation.
class ChatSystemLineTile extends StatelessWidget {
  const ChatSystemLineTile({
    super.key,
    required this.message,
    required this.viewerId,
  });

  final ChatMessage message;
  final String? viewerId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final text = l10n.systemLine(
      message.system!,
      actorId: message.authorId,
      actorName: message.authorName,
      viewerId: viewerId,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: ShapeDecoration(
            color: AppColors.white.withValues(alpha: 0.7),
            shape: const StadiumBorder(),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(
              color: AppColors.brown,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
