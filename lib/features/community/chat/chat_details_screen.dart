import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../feed/post_actions.dart' show openMember, showCommunitySnack;
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/community_keeper.dart';
import '../widgets/section_state.dart';
import '../widgets/small_tag.dart';
import 'new_chat_screen.dart';
import 'private_chat_providers.dart';
import 'private_chat_widgets.dart';

/// A private chat's details: its name (admins rename a group), who is in
/// it and their roles, adding people (admins), muting and leaving. An
/// admin's menu on a member makes them admin or removes them.
class ChatDetailsScreen extends ConsumerWidget {
  const ChatDetailsScreen({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final chat = ref.watch(privateChatProvider(channelId));
    final chats = ref.watch(privateChatsProvider);
    final viewerId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );

    final Widget body;
    if (chat == null) {
      body = chats.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SectionState(
              icon: Icons.forum_outlined,
              title: l10n.chatGoneTitle,
              message: l10n.chatGoneMessage,
            );
    } else {
      body = _Details(chat: chat, viewerId: viewerId);
    }
    return CommunityKeeper(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoralHeader(title: l10n.chatDetails, showBack: true),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.chat, required this.viewerId});

  final PrivateChat chat;
  final String? viewerId;

  Future<void> _act(
    BuildContext context,
    Future<void> Function(PrivateChatController controller) action, {
    String? done,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    try {
      await action(
        ProviderScope.containerOf(
          context,
          listen: false,
        ).read(privateChatControllerProvider.notifier),
      );
      if (done != null) showCommunitySnack(messenger, done);
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    }
  }

  Future<void> _rename(BuildContext context) async {
    final l10n = context.communityL10n;
    final name = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => _RenameSheet(initial: chat.name),
    );
    if (name == null || !context.mounted) return;
    await _act(context, (c) => c.rename(chat.id, name), done: l10n.chatRenamed);
  }

  Future<void> _leave(BuildContext context) async {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveChatTitle),
        content: Text(l10n.leaveChatBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(app.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    final left = l10n.sysLeftMine;
    try {
      await ProviderScope.containerOf(
        context,
        listen: false,
      ).read(privateChatControllerProvider.notifier).leave(chat.id);
      router.go(CommunityRoutes.root);
      showCommunitySnack(messenger, left);
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    }
  }

  Future<void> _remove(BuildContext context, PrivateChatMember member) async {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final name = l10n.inLine(l10n.memberName(member.name));
    if (member.joined) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.removeMemberTitle(name)),
          content: Text(l10n.removeMemberBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(app.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.removeItem),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    await _act(
      context,
      (c) => c.remove(chat.id, member.userId),
      done: l10n.memberRemovedDone,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final admin = chat.isAdmin(viewerId);
    final group = !chat.direct;
    final muted = privateChatMuted(ref, chat);
    final name = l10n.privateChatName(chat, viewerId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        16,
        AppSpacing.screen,
        24,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                PrivateChatAvatar(chat: chat, size: 72),
                const SizedBox(height: 10),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  textDirection: contentDirection(context, name),
                  style: AppText.cardTitle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dotted([
                    l10n.privateChat,
                    l10n.participantCount(chat.participantCount),
                  ]),
                  textAlign: TextAlign.center,
                  style: AppText.label.copyWith(color: AppColors.brown),
                ),
                if (admin && group) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _rename(context),
                    icon: const AppIcon(Icons.edit_outlined, size: 18),
                    label: Text(l10n.renameChat),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (admin &&
                  group &&
                  chat.participantCount < PrivateChatLimits.participants)
                ListTile(
                  leading: const AppIcon(
                    Icons.person_add_alt_1_rounded,
                    color: AppColors.coralDark,
                  ),
                  title: Text(
                    l10n.addParticipants,
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.coralDark,
                    ),
                  ),
                  onTap: () => openAddParticipants(context, chat),
                ),
              for (final member in chat.members)
                _MemberTile(
                  member: member,
                  me: member.userId == viewerId,
                  menu: admin && group && member.userId != viewerId,
                  onOpen: () => openMember(context, member.userId),
                  onMakeAdmin: () =>
                      _act(context, (c) => c.makeAdmin(chat.id, member.userId)),
                  onRemove: () => _remove(context, member),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SwitchListTile(
                key: const ValueKey('mute-chat'),
                value: muted,
                title: Text(l10n.muteChat),
                subtitle: muted ? Text(l10n.chatMutedNote) : null,
                onChanged: (on) =>
                    _act(context, (c) => c.setMuted(chat.id, muted: on)),
              ),
              ListTile(
                key: const ValueKey('leave-chat'),
                leading: const AppIcon(
                  Icons.logout_rounded,
                  color: AppColors.coralDark,
                ),
                title: Text(
                  l10n.leaveChat,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.coralDark,
                  ),
                ),
                onTap: () => _leave(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _MemberAction { admin, remove }

/// A member in the details: name, Admin / Invited / You, and for an admin
/// a menu to make them admin or remove them.
class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.me,
    required this.menu,
    required this.onOpen,
    required this.onMakeAdmin,
    required this.onRemove,
  });

  final PrivateChatMember member;
  final bool me;
  final bool menu;
  final VoidCallback onOpen;
  final VoidCallback onMakeAdmin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final name = l10n.memberName(member.name);
    final tags = [
      if (me) SmallTag(l10n.youTag, color: AppColors.sage),
      if (member.isAdmin) SmallTag(l10n.adminTag, color: AppColors.peach),
      if (!member.joined) SmallTag(l10n.invitedTag, color: AppColors.yellow),
    ];
    return ListTile(
      key: ValueKey('member-${member.userId}'),
      onTap: onOpen,
      leading: AuthorAvatar(name: member.name, authorId: member.userId),
      title: AutoDirectionText(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.body.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: tags.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 6, runSpacing: 4, children: tags),
            ),
      trailing: !menu
          ? null
          : PopupMenuButton<_MemberAction>(
              tooltip: l10n.memberOptions(l10n.inLine(name)),
              icon: const AppIcon(
                Icons.more_vert_rounded,
                color: AppColors.brown,
              ),
              onSelected: (action) => switch (action) {
                _MemberAction.admin => onMakeAdmin(),
                _MemberAction.remove => onRemove(),
              },
              itemBuilder: (context) => [
                if (member.joined && !member.isAdmin)
                  PopupMenuItem(
                    value: _MemberAction.admin,
                    child: Text(l10n.makeAdmin),
                  ),
                PopupMenuItem(
                  value: _MemberAction.remove,
                  child: Text(
                    member.joined ? l10n.removeFromChat : l10n.cancelInvitation,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Renaming a group chat: returns the new name, `null` when cancelled.
class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.initial});

  final String initial;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final valid = _name.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
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
              Text(
                l10n.renameChat,
                style: AppText.cardTitle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('rename-field'),
                controller: _name,
                autofocus: true,
                maxLength: PrivateChatLimits.nameLength,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    PrivateChatLimits.nameLength,
                  ),
                ],
                decoration: InputDecoration(labelText: l10n.chatNameLabel),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: l10n.saveChanges,
                onPressed: valid
                    ? () => Navigator.of(context).pop(_name.text.trim())
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
