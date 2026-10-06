import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../community_words.dart';
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/post_photo_view.dart';
import 'chat_providers.dart';

/// Where a message sits in a run of messages by the same person.
///
/// Messages one person sends within a few minutes form a run: the name and
/// the avatar show at its start, the time at its end, and the bubbles sit
/// close together.
class ChatRunPosition {
  const ChatRunPosition({required this.first, required this.last});

  final bool first;
  final bool last;

  /// How far apart messages may be and still form one run.
  static const gap = Duration(minutes: 5);

  static ChatRunPosition of(List<ChatEntry> entries, int i) {
    bool together(ChatMessage a, ChatMessage b) =>
        a.authorId == b.authorId &&
        isSameDay(a.sentAt, b.sentAt) &&
        b.sentAt.difference(a.sentAt).abs() <= gap;
    final message = entries[i].message;
    return ChatRunPosition(
      first: i == 0 || !together(entries[i - 1].message, message),
      last:
          i == entries.length - 1 || !together(message, entries[i + 1].message),
    );
  }
}

/// One message: avatar and name at the start of a run, the bubble (the
/// message it answers, a photo, the text), its reactions, and the time or
/// the sending state.
class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({
    super.key,
    required this.entry,
    required this.mine,
    required this.position,
    required this.onLongPress,
    required this.onReaction,
    this.onFailedTap,
  });

  final ChatEntry entry;
  final bool mine;
  final ChatRunPosition position;
  final VoidCallback onLongPress;

  /// Tapping a reaction under the message adds or removes the reader's;
  /// `null` when they may not react.
  final ValueChanged<String>? onReaction;

  /// Tapping a message that failed to send.
  final VoidCallback? onFailedTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final message = entry.message;
    const big = Radius.circular(20);
    const small = Radius.circular(6);
    // A bubble's corner near the avatar is sharp at the start of a run (on
    // others' messages) and at its end (on mine).
    final radius = BorderRadiusDirectional.only(
      topStart: !mine && !position.first ? small : big,
      topEnd: mine && !position.first ? small : big,
      bottomStart: !mine ? small : big,
      bottomEnd: mine ? small : big,
    );

    final bubble = Opacity(
      opacity: entry.sending ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.yellow : AppColors.white,
          borderRadius: radius,
          border: entry.failed
              ? Border.all(color: AppColors.coralDark, width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyToId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _ReplyQuote(reply: message.replyTo, mine: mine),
              ),
            if (message.photo != null)
              Padding(
                padding: EdgeInsets.only(bottom: message.text.isEmpty ? 0 : 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Semantics(
                    button: true,
                    label: l10n.openPhoto,
                    child: GestureDetector(
                      onTap: () => openPhotoViewer(context, message.photo!),
                      child: PostPhotoView(photo: message.photo!),
                    ),
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: AutoDirectionText(
                  message.text,
                  style: AppText.body.copyWith(fontSize: 15, height: 1.4),
                ),
              ),
          ],
        ),
      ),
    );

    final column = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (!mine && position.first)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, bottom: 3),
            child: AutoDirectionText(
              l10n.memberName(message.authorName),
              style: AppText.label.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.brown,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        GestureDetector(
          onLongPress: entry.sending ? null : onLongPress,
          onTap: entry.failed ? onFailedTap : null,
          child: bubble,
        ),
        if (message.reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final reaction in message.reactions)
                  _ReactionChip(
                    reaction: reaction,
                    onTap: onReaction == null
                        ? null
                        : () => onReaction!(reaction.emoji),
                  ),
              ],
            ),
          ),
        if (entry.pending != null || position.last)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 8, 0),
            child: _Meta(entry: entry, onFailedTap: onFailedTap),
          ),
      ],
    );

    return Semantics(
      container: true,
      label: mine ? l10n.ownMessage : null,
      child: Padding(
        padding: EdgeInsets.only(bottom: position.last ? 12 : 3),
        // Own messages at the end of the line, other people's at the
        // start: right and left in English, mirrored in a right-to-left
        // layout. The side says whose message it is, so it follows the
        // screen and not the language the message happens to be written in.
        child: Align(
          alignment: mine
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: 0.84,
            alignment: mine
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: mine
                ? column
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 30,
                        child: position.first
                            ? Padding(
                                padding: const EdgeInsets.only(top: 18),
                                child: AuthorAvatar(
                                  name: message.authorName,
                                  authorId: message.authorId,
                                  size: 30,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: column),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The time under the last message of a run; "Sending…" or "Not sent" for
/// a message on its way.
class _Meta extends StatelessWidget {
  const _Meta({required this.entry, this.onFailedTap});

  final ChatEntry entry;
  final VoidCallback? onFailedTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final style = AppText.navLabel.copyWith(color: AppColors.brown);
    if (entry.failed) {
      return InkWell(
        onTap: onFailedTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(
                Icons.error_outline_rounded,
                size: 14,
                color: AppColors.coralDark,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.messageNotSent,
                  style: style.copyWith(
                    color: AppColors.coralDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (entry.sending) return Text(l10n.messageSending, style: style);
    return Text(AppFormat.of(context).time(entry.message.sentAt), style: style);
  }
}

/// The message a reply answers, quoted at the top of the bubble.
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.reply, required this.mine});

  /// `null` when the message is gone or hidden from the reader.
  final ChatReplyPreview? reply;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final reply = this.reply;
    final text = reply == null
        ? l10n.replyUnavailable
        : reply.text.isNotEmpty
        ? reply.text
        : l10n.photoLabel;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: (mine ? AppColors.white : AppColors.cream).withValues(
          alpha: 0.7,
        ),
        borderRadius: BorderRadius.circular(12),
        border: const BorderDirectional(
          start: BorderSide(color: AppColors.coralDark, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reply != null)
            AutoDirectionText(
              l10n.memberName(reply.authorName),
              style: AppText.label.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.coralDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reply?.hasPhoto ?? false) ...[
                const AppIcon(
                  Icons.photo_rounded,
                  size: 14,
                  color: AppColors.brown,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: AutoDirectionText(
                  text,
                  style: AppText.secondary.copyWith(
                    color: AppColors.brown,
                    fontStyle: reply == null ? FontStyle.italic : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.reaction, this.onTap});

  final ChatReaction reaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final shape = StadiumBorder(
      side: BorderSide(
        color: reaction.mine ? AppColors.coralDark : AppColors.white,
        width: 1.5,
      ),
    );
    return Tooltip(
      message: l10n.reactWith(reaction.emoji),
      child: Material(
        color: reaction.mine ? AppColors.peach : AppColors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                '${reaction.emoji} ${AppFormat.of(context).integer(reaction.count)}',
                semanticsLabel: l10n.reactionsSummary(
                  reaction.emoji,
                  reaction.count,
                ),
                textAlign: TextAlign.center,
                style: AppText.secondary.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
