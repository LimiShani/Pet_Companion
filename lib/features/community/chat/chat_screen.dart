import '../../../access/feature_gate.dart';
import '../../../access/access_provider.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../community_words.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../data/photo_picker.dart';
import '../feed/post_actions.dart' show showCommunitySnack;
import '../safety/safety_flows.dart';
import '../widgets/advice_notice.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/community_keeper.dart';
import '../widgets/message_bar.dart';
import '../widgets/section_state.dart';
import 'chat_message_tile.dart';
import 'chat_providers.dart';

/// A chat room: the live conversation and a message field.
///
/// Long-press a message to react, answer, copy, delete your own, report or
/// block someone else's. A message shows at once and says when it failed
/// to go. Scrolling up loads older messages; while reading them, a button
/// leads back to the latest and counts what arrived meanwhile.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  PickedPhoto? _photo;
  ChatReplyPreview? _reply;

  /// Scrolled up, reading older messages.
  var _away = false;

  /// Messages from others that arrived while [_away].
  var _arrived = 0;
  String? _latestId;
  bool? _noticeHidden;

  String get _noticeKey => 'community.notice.${widget.channelId}';

  /// The health room keeps its note: answers there are most easily taken
  /// for advice.
  bool get _noticeDismissible => widget.channelId != 'health';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _message.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // The list is reversed: offset 0 is the latest message.
    final away = position.pixels > 240;
    if (away != _away) {
      setState(() {
        _away = away;
        if (!away) _arrived = 0;
      });
    }
    if (position.maxScrollExtent - position.pixels < 400) {
      final conversation = ref
          .read(chatConversationProvider(widget.channelId))
          .value;
      if (conversation != null &&
          conversation.canLoadOlder &&
          !conversation.loadingOlder) {
        _loadOlder();
      }
    }
  }

  Future<void> _loadOlder() async {
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    try {
      await ref.read(chatRoomProvider(widget.channelId).notifier).loadOlder();
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    }
  }

  void _toLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Follows the conversation: marks the room read and counts what arrives
  /// while the reader is scrolled up.
  void _onConversation(ChatConversation conversation) {
    ChatEntry? latest;
    for (final entry in conversation.entries.reversed) {
      if (entry.pending == null) {
        latest = entry;
        break;
      }
    }
    if (latest == null || latest.message.id == _latestId) return;
    final previous = _latestId;
    _latestId = latest.message.id;
    if (previous != null && _away) {
      // Everyone else's messages after the one that was latest before.
      final viewerId = ref.read(authControllerProvider).value?.id;
      final entries = conversation.entries;
      final from = entries.indexWhere((e) => e.message.id == previous);
      final added = from < 0
          ? 0
          : entries
                .skip(from + 1)
                .where(
                  (e) => e.pending == null && e.message.authorId != viewerId,
                )
                .length;
      if (added > 0) setState(() => _arrived += added);
    }
    unawaited(
      ref
          .read(chatRoomProvider(widget.channelId).notifier)
          .markRead(latest.message.id),
    );
  }

  Future<void> _send() async {
    if (!ref.read(capabilityProvider('community.chat.send'))) return;
    final text = _message.text.trim();
    final photo = _photo;
    if (text.isEmpty && photo == null) return;
    if (!await ensureCommunityRules(context, ref)) return;
    if (!mounted) return;
    final reply = _reply;
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    _message.clear();
    setState(() {
      _photo = null;
      _reply = null;
    });
    _toLatest();
    // Shown at once; a failure is marked on the message itself, and said
    // in a snack bar.
    final failure = await ref
        .read(chatRoomProvider(widget.channelId).notifier)
        .send(text: text, photo: photo, reply: reply);
    if (failure != null) showCommunitySnack(messenger, errorWords(failure));
  }

  Future<void> _pickPhoto() async {
    final l10n = context.communityL10n;
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const AppIcon(Icons.photo_library_rounded),
              title: Text(l10n.gallery),
              onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            ),
            ListTile(
              leading: const AppIcon(Icons.photo_camera_rounded),
              title: Text(l10n.camera),
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    try {
      final photo = await ref.read(photoPickerProvider).pick(source);
      if (photo != null && mounted) setState(() => _photo = photo);
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    }
  }

  Future<void> _hideNotice() async {
    setState(() => _noticeHidden = true);
    await ref.read(settingsStoreProvider).write(_noticeKey, '1');
  }

  Future<void> _showRoomInfo(ChatChannel? channel, String name) async {
    final l10n = context.communityL10n;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AutoDirectionText(
                name,
                style: AppText.cardTitle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (channel != null) ...[
                const SizedBox(height: 4),
                AutoDirectionText(
                  l10n.roomAbout(channel),
                  style: AppText.body.copyWith(color: AppColors.brown),
                ),
              ],
              const SizedBox(height: 14),
              const AdviceNotice(),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => showCommunityRules(context),
                  icon: const AppIcon(Icons.rule_rounded),
                  label: Text(l10n.rulesTitle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The long-press menu of a message.
  Future<void> _messageActions(ChatEntry entry) async {
    final message = entry.message;
    final l10n = context.communityL10n;
    final app = context.l10n;
    final viewerId = ref.read(authControllerProvider).value?.id;
    final mine = message.authorId == viewerId;
    final canSend = ref.read(capabilityProvider('community.chat.send'));
    final room = ref.read(chatRoomProvider(widget.channelId).notifier);
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    final name = l10n.inLine(l10n.memberName(message.authorName));

    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canSend)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screen - 8,
                    vertical: 4,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      for (final emoji in chatReactions)
                        _EmojiButton(
                          emoji: emoji,
                          chosen: message.reactions.any(
                            (r) => r.emoji == emoji && r.mine,
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(_MessageAction(emoji)),
                        ),
                    ],
                  ),
                ),
              if (canSend)
                ListTile(
                  leading: const AppIcon(Icons.reply_rounded),
                  title: Text(l10n.chatReply),
                  onTap: () =>
                      Navigator.of(context).pop(const _MessageAction.reply()),
                ),
              if (message.text.isNotEmpty)
                ListTile(
                  leading: const AppIcon(Icons.copy_rounded),
                  title: Text(l10n.chatCopy),
                  onTap: () =>
                      Navigator.of(context).pop(const _MessageAction.copy()),
                ),
              if (mine && canSend)
                ListTile(
                  leading: const AppIcon(Icons.delete_outline_rounded),
                  title: Text(app.commonDelete),
                  onTap: () =>
                      Navigator.of(context).pop(const _MessageAction.delete()),
                ),
              if (!mine) ...[
                // Reports are kept only from members who may write here.
                if (canSend)
                  ListTile(
                    leading: const AppIcon(Icons.flag_outlined),
                    title: Text(l10n.report),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(const _MessageAction.report()),
                  ),
                ListTile(
                  leading: const AppIcon(Icons.block_rounded),
                  title: Text(l10n.blockMember(name)),
                  onTap: () =>
                      Navigator.of(context).pop(const _MessageAction.block()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;

    try {
      switch (action.kind) {
        case _ActionKind.react:
          await room.toggleReaction(message, action.emoji!);
        case _ActionKind.reply:
          setState(() => _reply = message.asReplyPreview());
        case _ActionKind.copy:
          await Clipboard.setData(ClipboardData(text: message.text));
          showCommunitySnack(messenger, l10n.chatCopied);
        case _ActionKind.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.chatDeleteTitle),
              content: Text(l10n.chatDeleteBody),
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
          if (confirmed != true) return;
          await room.delete(message);
          showCommunitySnack(messenger, l10n.chatDeleted);
        case _ActionKind.report:
          if (!mounted) return;
          final reason = await askReportReason(
            context,
            title: l10n.chatReportTitle,
            body: l10n.chatReportBody,
          );
          if (reason == null) return;
          await room.report(message, reason);
          showCommunitySnack(messenger, l10n.chatReportThanks);
        case _ActionKind.block:
          if (!mounted) return;
          await blockMemberFlow(
            context,
            ref,
            memberId: message.authorId,
            memberName: message.authorName,
          );
      }
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    }
  }

  /// A message that failed to go: try again, or let it go.
  Future<void> _failedActions(ChatEntry entry) async {
    final pending = entry.pending;
    if (pending == null) return;
    final l10n = context.communityL10n;
    final app = context.l10n;
    final reason = communityErrorText(context, pending.error);
    final room = ref.read(chatRoomProvider(widget.channelId).notifier);
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    final retry = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(
                l10n.messageNotSentTitle,
                style: AppText.cardTitle.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(reason),
            ),
            ListTile(
              leading: const AppIcon(Icons.refresh_rounded),
              title: Text(app.commonTryAgain),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: const AppIcon(Icons.delete_outline_rounded),
              title: Text(app.commonDelete),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (retry == null) return;
    if (retry) {
      final failure = await room.retry(pending.localId);
      if (failure != null) showCommunitySnack(messenger, errorWords(failure));
    } else {
      room.discard(pending.localId);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.chat.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final channels =
        ref.watch(chatChannelsProvider).value ?? const <ChatChannel>[];
    ChatChannel? channel;
    for (final c in channels) {
      if (c.id == widget.channelId) channel = c;
    }
    final name = channel == null ? l10n.sectionChat : l10n.roomName(channel);
    final canSend = ref.watch(capabilityProvider('community.chat.send'));
    _noticeHidden ??= ref.read(settingsStoreProvider).read(_noticeKey) == '1';
    final showNotice = !_noticeDismissible || _noticeHidden != true;

    ref.listen(chatConversationProvider(widget.channelId), (_, next) {
      if (next.value case final conversation?) _onConversation(conversation);
    });

    return CommunityKeeper(
      channelId: widget.channelId,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoralHeader(
              title: name,
              showBack: true,
              actions: [
                CoralHeaderAction(
                  icon: Icons.info_outline_rounded,
                  tooltip: l10n.roomInfo,
                  onPressed: () => _showRoomInfo(channel, name),
                ),
              ],
            ),
            if (showNotice)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  10,
                  AppSpacing.screen,
                  0,
                ),
                child: AdviceNotice(
                  onDismiss: _noticeDismissible ? _hideNotice : null,
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _Messages(
                      channelId: widget.channelId,
                      scroll: _scroll,
                      canReact: canSend,
                      onLongPress: _messageActions,
                      onFailedTap: _failedActions,
                    ),
                  ),
                  if (_away)
                    PositionedDirectional(
                      end: 16,
                      bottom: 12,
                      child: _JumpButton(arrived: _arrived, onTap: _toLatest),
                    ),
                ],
              ),
            ),
            if (canSend)
              MessageBar(
                controller: _message,
                hint: l10n.messageHint(l10n.inLine(name)),
                sendTooltip: l10n.sendMessage,
                onSend: _send,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    CommunityLimits.messageLength,
                  ),
                ],
                leading: IconButton(
                  onPressed: _pickPhoto,
                  tooltip: l10n.addPhoto,
                  icon: const AppIcon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.brown,
                  ),
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 48,
                  ),
                  padding: EdgeInsets.zero,
                ),
                above: _reply == null && _photo == null
                    ? null
                    : _ComposerExtras(
                        reply: _reply,
                        photo: _photo,
                        onCancelReply: () => setState(() => _reply = null),
                        onRemovePhoto: () => setState(() => _photo = null),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _ActionKind { react, reply, copy, delete, report, block }

class _MessageAction {
  const _MessageAction(this.emoji) : kind = _ActionKind.react;
  const _MessageAction.reply() : kind = _ActionKind.reply, emoji = null;
  const _MessageAction.copy() : kind = _ActionKind.copy, emoji = null;
  const _MessageAction.delete() : kind = _ActionKind.delete, emoji = null;
  const _MessageAction.report() : kind = _ActionKind.report, emoji = null;
  const _MessageAction.block() : kind = _ActionKind.block, emoji = null;

  final _ActionKind kind;
  final String? emoji;
}

class _Messages extends ConsumerWidget {
  const _Messages({
    required this.channelId,
    required this.scroll,
    required this.canReact,
    required this.onLongPress,
    required this.onFailedTap,
  });

  final String channelId;
  final ScrollController scroll;
  final bool canReact;
  final ValueChanged<ChatEntry> onLongPress;
  final ValueChanged<ChatEntry> onFailedTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final format = AppFormat.of(context);
    final conversation = ref.watch(chatConversationProvider(channelId));
    final viewerId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    final now = ref.watch(communityClockProvider)();
    final value = conversation.value;

    if (value == null) {
      if (conversation.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return SectionState(
        icon: Icons.cloud_off_rounded,
        title: l10n.chatLoadFailed,
        message: communityErrorText(context, conversation.error),
        actionLabel: app.commonTryAgain,
        onAction: () => ref.invalidate(chatMessagesProvider(channelId)),
      );
    }

    final entries = value.entries;
    if (entries.isEmpty) {
      return SectionState(
        icon: Icons.chat_bubble_rounded,
        title: l10n.noMessagesTitle,
        message: l10n.noMessagesMessage,
      );
    }

    final room = ref.read(chatRoomProvider(channelId).notifier);
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);

    // Reversed, so the list starts at the newest message and stays there
    // as new ones arrive. The extra item at the top is the history's state.
    return ListView.builder(
      controller: scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen - 6,
        16,
        AppSpacing.screen - 6,
        8,
      ),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == entries.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: value.loadingOlder || value.canLoadOlder
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : Text(
                    l10n.conversationStart,
                    textAlign: TextAlign.center,
                    style: AppText.label.copyWith(color: AppColors.brown),
                  ),
          );
        }
        final i = entries.length - 1 - index;
        final entry = entries[i];
        final message = entry.message;
        final startsDay =
            i == 0 || !isSameDay(entries[i - 1].message.sentAt, message.sentAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (startsDay)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  dayLabel(app, format, message.sentAt, now),
                  textAlign: TextAlign.center,
                  style: AppText.label.copyWith(color: AppColors.brown),
                ),
              ),
            ChatMessageTile(
              key: ValueKey(message.id),
              entry: entry,
              mine: message.authorId == viewerId,
              position: ChatRunPosition.of(entries, i),
              onLongPress: () => onLongPress(entry),
              onFailedTap: () => onFailedTap(entry),
              onReaction: canReact && entry.pending == null
                  ? (emoji) async {
                      try {
                        await room.toggleReaction(message, emoji);
                      } catch (e) {
                        showCommunitySnack(messenger, errorWords(e));
                      }
                    }
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    required this.emoji,
    required this.chosen,
    required this.onTap,
  });

  final String emoji;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.communityL10n.reactWith(emoji),
      child: Material(
        color: chosen ? AppColors.peach : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Leads back to the latest message; says how many arrived meanwhile.
class _JumpButton extends StatelessWidget {
  const _JumpButton({required this.arrived, required this.onTap});

  final int arrived;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    return Tooltip(
      message: l10n.jumpToLatest,
      child: Material(
        color: AppColors.coralDark,
        shape: const StadiumBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (arrived > 0) ...[
                    Text(
                      l10n.newMessages(arrived),
                      style: AppText.secondary.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const AppIcon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Above the message field: the message being answered, and the photo to
/// send, each with a way to drop it.
class _ComposerExtras extends StatelessWidget {
  const _ComposerExtras({
    required this.reply,
    required this.photo,
    required this.onCancelReply,
    required this.onRemovePhoto,
  });

  final ChatReplyPreview? reply;
  final PickedPhoto? photo;
  final VoidCallback onCancelReply;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final reply = this.reply;
    final photo = this.photo;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        8,
        AppSpacing.screen,
        0,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reply != null)
            Row(
              children: [
                const AppIcon(
                  Icons.reply_rounded,
                  size: 18,
                  color: AppColors.coralDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.replyingTo(
                          l10n.inLine(l10n.memberName(reply.authorName)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.coralDark,
                        ),
                      ),
                      AutoDirectionText(
                        reply.text.isNotEmpty ? reply.text : l10n.photoLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.secondary.copyWith(
                          color: AppColors.brown,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onCancelReply,
                  tooltip: l10n.cancelReply,
                  icon: const AppIcon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.brown,
                  ),
                ),
              ],
            ),
          if (photo != null)
            Row(
              children: [
                Semantics(
                  image: true,
                  label: l10n.chatPhotoPreview,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      photo.bytes,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox(width: 56, height: 56),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRemovePhoto,
                  tooltip: l10n.removePhoto,
                  icon: const AppIcon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.brown,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
