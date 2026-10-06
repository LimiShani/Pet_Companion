import '../../../access/feature_gate.dart';
import '../../../access/access_provider.dart';
import '../../../platform/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../community_words.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../feed/post_actions.dart' show showCommunitySnack;
import '../widgets/advice_notice.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/message_bar.dart';
import '../widgets/section_state.dart';
import 'chat_providers.dart';

/// A chat room: the live conversation and a message field.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _message = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!ref.read(capabilityProvider('community.chat.send'))) return;
    final ticket = SessionTicket.widget(ref);
    final text = _message.text.trim();
    final author = ref.read(authControllerProvider).value;
    if (text.isEmpty || _sending || author == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(author: author, channelId: widget.channelId, text: text);
      if (!ticket.current) return;
      _message.clear();
    } catch (e) {
      if (!ticket.current) return;
      showCommunitySnack(messenger, errorWords(e));
    } finally {
      if (mounted) setState(() => _sending = false);
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

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: name, showBack: true),
          // Pinned: it stays in view while the conversation scrolls.
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screen,
              10,
              AppSpacing.screen,
              0,
            ),
            child: AdviceNotice(),
          ),
          Expanded(child: _Messages(channelId: widget.channelId)),
          if (ref.watch(capabilityProvider('community.chat.send')))
            MessageBar(
              controller: _message,
              hint: l10n.messageHint(l10n.inLine(name)),
              sendTooltip: l10n.sendMessage,
              sending: _sending,
              onSend: _send,
              inputFormatters: [
                LengthLimitingTextInputFormatter(CommunityLimits.messageLength),
              ],
            ),
        ],
      ),
    );
  }
}

class _Messages extends ConsumerWidget {
  const _Messages({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'community.chat.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final format = AppFormat.of(context);
    final messages = ref.watch(chatMessagesProvider(channelId));
    final viewerId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    final now = ref.watch(communityClockProvider)();
    final list = messages.value;

    if (list == null) {
      if (messages.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return SectionState(
        icon: Icons.cloud_off_rounded,
        title: l10n.chatLoadFailed,
        message: communityErrorText(context, messages.error),
        actionLabel: app.commonTryAgain,
        onAction: () => ref.invalidate(chatMessagesProvider(channelId)),
      );
    }

    if (list.isEmpty) {
      return SectionState(
        icon: Icons.chat_bubble_rounded,
        title: l10n.noMessagesTitle,
        message: l10n.noMessagesMessage,
      );
    }

    // Reversed, so the list starts at the newest message and stays there
    // as new ones arrive.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        16,
        AppSpacing.screen,
        8,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final i = list.length - 1 - index;
        final message = list[i];
        final startsDay =
            i == 0 || !isSameDay(list[i - 1].sentAt, message.sentAt);
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
            _Bubble(
              key: ValueKey(message.id),
              message: message,
              mine: message.authorId == viewerId,
            ),
          ],
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.chat.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    const big = Radius.circular(20);
    const small = Radius.circular(6);

    return Semantics(
      container: true,
      label: mine ? l10n.ownMessage : null,
      child: Align(
        // Own messages at the end of the line, other people's at the start:
        // right and left in English, mirrored in a right-to-left layout.
        // The side says whose message it is, so it follows the screen and
        // not the language the message happens to be written in.
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: 0.82,
          alignment: mine
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!mine)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 8,
                      bottom: 3,
                    ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? AppColors.yellow : AppColors.white,
                    borderRadius: BorderRadiusDirectional.only(
                      topStart: big,
                      topEnd: big,
                      bottomStart: mine ? big : small,
                      bottomEnd: mine ? small : big,
                    ),
                  ),
                  child: AutoDirectionText(
                    message.text,
                    style: AppText.body.copyWith(fontSize: 15, height: 1.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 3, 8, 0),
                  child: Text(
                    AppFormat.of(context).time(message.sentAt),
                    style: AppText.navLabel.copyWith(color: AppColors.brown),
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
