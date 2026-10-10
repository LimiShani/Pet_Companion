import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../feed/post_actions.dart' show showCommunitySnack;
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import 'private_chat_providers.dart';

/// Opens the page that starts a private chat, over the whole app.
Future<void> openNewChat(BuildContext context) {
  final router = GoRouter.of(context);
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => NewChatScreen(router: router)),
  );
}

/// Opens the same page to invite more people to [chat] (its admins only).
Future<void> openAddParticipants(BuildContext context, PrivateChat chat) =>
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => NewChatScreen(addTo: chat)));

/// Choosing people to chat with: search by name, the people the member
/// talked with recently first, the chosen ones as chips. With one person
/// Next opens the chat of the two; with more, a step names the group.
/// With [addTo] the chosen people are invited to that chat instead.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key, this.addTo, this.router});

  final PrivateChat? addTo;

  /// Opens the new chat once it exists.
  final GoRouter? router;

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _chosen = <String, ChatPerson>{};
  var _query = '';
  var _naming = false;
  var _busy = false;
  List<ChatPerson>? _lastPeople;

  /// Places left in the chat for the chosen people.
  int get _room =>
      PrivateChatLimits.participants -
      (widget.addTo?.participantCount ?? 1) -
      _chosen.length;

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  void _toggle(ChatPerson person) => setState(() {
    if (_chosen.remove(person.id) == null && _room > 0) {
      _chosen[person.id] = person;
    }
  });

  Future<void> _next() async {
    if (_chosen.isEmpty || _busy) return;
    if (widget.addTo == null && _chosen.length > 1 && !_naming) {
      setState(() => _naming = true);
      return;
    }
    final l10n = context.communityL10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    final router = widget.router;
    final controller = ref.read(privateChatControllerProvider.notifier);
    final ids = _chosen.keys.toList();
    setState(() => _busy = true);
    try {
      if (widget.addTo case final chat?) {
        await controller.invite(chat.id, ids);
        navigator.pop();
        showCommunitySnack(messenger, l10n.invitationsSent(ids.length));
        return;
      }
      final id = await controller.start(
        ids,
        name: ids.length > 1 ? _name.text.trim() : '',
      );
      navigator.pop();
      router?.push(CommunityRoutes.chat(id));
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final title = widget.addTo != null ? l10n.addParticipants : l10n.newChat;
    return PopScope(
      canPop: !_naming,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _naming) setState(() => _naming = false);
      },
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoralHeader(title: title, showBack: true),
            Expanded(child: _naming ? _nameStep(context) : _pickStep(context)),
          ],
        ),
      ),
    );
  }

  Widget _button(BuildContext context, String label, bool enabled) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        8,
        AppSpacing.screen,
        12,
      ),
      child: PrimaryButton(
        label: label,
        loading: _busy,
        onPressed: enabled ? _next : null,
      ),
    ),
  );

  Widget _pickStep(BuildContext context) {
    final l10n = context.communityL10n;
    final people = ref.watch(chatPeopleProvider(_query));
    final list = people.value ?? _lastPeople;
    if (people.value != null) _lastPeople = people.value;
    final present = {...?widget.addTo?.members.map((m) => m.userId)};
    final shown = [
      for (final p in list ?? const <ChatPerson>[])
        if (!present.contains(p.id)) p,
    ];
    final recent = [
      for (final p in shown)
        if (p.recent) p,
    ];
    final others = [
      for (final p in shown)
        if (!p.recent) p,
    ];

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppText.label.copyWith(
            color: AppColors.brown,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    final Widget body;
    if (list == null) {
      body = people.hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  communityErrorText(context, people.error),
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.brown),
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          16,
        ),
        children: [
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l10n.noPeopleFound,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.brown),
              ),
            ),
          if (recent.isNotEmpty) heading(l10n.recentPeople),
          for (final p in recent) _personTile(p),
          if (others.isNotEmpty) heading(l10n.communityMembersTitle),
          for (final p in others) _personTile(p),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            14,
            AppSpacing.screen,
            4,
          ),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.searchPeople,
              prefixIcon: const AppIcon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        if (_chosen.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              6,
              AppSpacing.screen,
              0,
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in _chosen.values)
                  InputChip(
                    key: ValueKey('chosen-${p.id}'),
                    avatar: AuthorAvatar(
                      name: p.name,
                      authorId: p.id,
                      size: 24,
                    ),
                    label: Text(
                      l10n.memberName(p.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: () => _toggle(p),
                    deleteButtonTooltipMessage: l10n.removePerson(
                      l10n.inLine(l10n.memberName(p.name)),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen + 4,
            8,
            AppSpacing.screen + 4,
            0,
          ),
          child: Text(
            dotted([
              if (_chosen.isNotEmpty) l10n.selectedCount(_chosen.length),
              l10n.participantsLimit(PrivateChatLimits.participants),
            ]),
            style: AppText.label.copyWith(color: AppColors.brown),
          ),
        ),
        Expanded(child: body),
        _button(
          context,
          widget.addTo != null ? l10n.addToChat : l10n.nextStep,
          _chosen.isNotEmpty,
        ),
      ],
    );
  }

  Widget _personTile(ChatPerson person) {
    final l10n = context.communityL10n;
    final chosen = _chosen.containsKey(person.id);
    final enabled = chosen || _room > 0;
    return CheckboxListTile(
      key: ValueKey('person-${person.id}'),
      contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 0),
      value: chosen,
      onChanged: enabled ? (_) => _toggle(person) : null,
      secondary: AuthorAvatar(name: person.name, authorId: person.id),
      title: AutoDirectionText(
        l10n.memberName(person.name),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.body.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: person.city.isEmpty
          ? null
          : AutoDirectionText(
              person.city,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(color: AppColors.brown),
            ),
    );
  }

  Widget _nameStep(BuildContext context) {
    final l10n = context.communityL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            children: [
              Text(
                l10n.groupNameTitle,
                style: AppText.cardTitle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.groupNameNote,
                style: AppText.body.copyWith(color: AppColors.brown),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('chat-name'),
                controller: _name,
                autofocus: true,
                maxLength: PrivateChatLimits.nameLength,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    PrivateChatLimits.nameLength,
                  ),
                ],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.chatNameLabel,
                  hintText: l10n.chatNameHint,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                dotted([
                  l10n.participantCount(_chosen.length + 1),
                  l10n.nameList(_chosen.values.map((p) => p.name)),
                ]),
                style: AppText.label.copyWith(color: AppColors.brown),
              ),
            ],
          ),
        ),
        _button(context, l10n.createChat, _name.text.trim().isNotEmpty),
      ],
    );
  }
}
