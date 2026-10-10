import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../presentation/health_widgets.dart'
    show HealthSheetBody, SheetTitle, kHealthTapTarget;
import '../../services/community/data/audience.dart';
import '../../services/meetups/data/meetup_models.dart';
import '../../services/meetups/state/meetups_providers.dart';
import '../../services/outdoors/data/park_models.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../community/chat/private_chat_providers.dart'
    show openDirectChat, openGroupChat;
import '../community/feed/post_actions.dart' show showCommunitySnack;
import '../community/safety/safety_flows.dart'
    show askReportReason, blockMemberFlow, ensureCommunityRules;
import 'form/meetup_form_screen.dart';
import 'meetups_words.dart';
import 'mine/meetup_screen.dart';
import 'mine/my_meetups_screen.dart';

/// Opens the form for a new ad ([park] chosen already, or a copy of
/// [copyOf]), or for changing [edit]. Full screen, over the bottom bar.
Future<void> openMeetupForm(
  BuildContext context, {
  Meetup? edit,
  Meetup? copyOf,
  DogPark? park,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => MeetupFormScreen(edit: edit, copyOf: copyOf, park: park),
  ),
);

/// An ad's own page (from a push, a member page, a park page).
Future<void> openMeetupPage(
  BuildContext context,
  String id, {
  Meetup? initial,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => MeetupScreen(meetupId: id, initial: initial),
  ),
);

/// "My ads".
Future<void> openMyMeetups(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => const MyMeetupsScreen()));

/// "I want to join": the rules once, the message sheet, then the chat of
/// two with the author, the message ready in the field. The answer is
/// recorded once the chat is open (the count, the author's group).
Future<void> joinMeetupFlow(
  BuildContext context,
  WidgetRef ref,
  Meetup ad,
) async {
  if (!await ensureCommunityRules(context, ref)) return;
  if (!context.mounted) return;
  final draft = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => HealthSheetBody(child: JoinMeetupSheet(meetup: ad)),
  );
  if (draft == null || !context.mounted) return;
  final chat = await openDirectChat(
    context,
    ref,
    userId: ad.authorId,
    draft: draft,
  );
  if (chat == null) return;
  try {
    await ref.read(meetupsControllerProvider.notifier).answer(ad.id);
  } catch (_) {
    // The chat is open; the count catches up on the next answer.
  }
}

/// Back to the chat with the author after answering (no new draft).
Future<void> reopenMeetupChat(
  BuildContext context,
  WidgetRef ref,
  Meetup ad,
) => openDirectChat(context, ref, userId: ad.authorId);

/// The author's "Group for everyone who answered": one group chat named
/// after the ad, with everyone who answered and is still reachable.
Future<void> responderGroupFlow(
  BuildContext context,
  WidgetRef ref,
  Meetup ad,
) async {
  final l10n = context.meetupsL10n;
  final messenger = ScaffoldMessenger.of(context);
  final name = MeetupText(context).groupName(ad);
  final List<MeetupResponder> people;
  try {
    people = await ref.read(meetupRespondersProvider(ad.id).future);
  } catch (e) {
    showCommunitySnack(messenger, l10n.failure(e));
    return;
  }
  if (!context.mounted) return;
  if (people.isEmpty) {
    showCommunitySnack(messenger, l10n.groupNone);
    return;
  }
  await openGroupChat(
    context,
    ref,
    userIds: [for (final p in people) p.id],
    name: name,
  );
}

Future<void> closeMeetupFlow(
  BuildContext context,
  WidgetRef ref,
  Meetup ad,
) async {
  final l10n = context.meetupsL10n;
  final messenger = ScaffoldMessenger.of(context);
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.closeConfirmTitle),
      content: Text(l10n.closeConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.closeConfirm),
        ),
      ],
    ),
  );
  if (sure != true) return;
  try {
    await ref.read(meetupsControllerProvider.notifier).close(ad.id);
    showCommunitySnack(messenger, l10n.closedDone);
  } catch (e) {
    showCommunitySnack(messenger, l10n.failure(e));
  }
}

Future<void> renewMeetupFlow(
  BuildContext context,
  WidgetRef ref,
  Meetup ad,
) async {
  final l10n = context.meetupsL10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(meetupsControllerProvider.notifier).renew(ad.id);
    showCommunitySnack(messenger, l10n.renewed);
  } catch (e) {
    showCommunitySnack(messenger, l10n.failure(e));
  }
}

Future<void> reportMeetupFlow(
  BuildContext context,
  WidgetRef ref,
  Meetup ad,
) async {
  final l10n = context.meetupsL10n;
  final messenger = ScaffoldMessenger.of(context);
  final reason = await askReportReason(
    context,
    title: l10n.reportTitle,
    body: l10n.reportBody,
  );
  if (reason == null) return;
  try {
    await ref.read(meetupsControllerProvider.notifier).report(ad.id, reason);
    showCommunitySnack(messenger, l10n.reportThanks);
  } catch (e) {
    showCommunitySnack(messenger, l10n.failure(e));
  }
}

Future<void> blockMeetupAuthorFlow(
  BuildContext context,
  WidgetRef ref,
  Meetup ad,
) => blockMemberFlow(
  context,
  ref,
  memberId: ad.authorId,
  memberName: ad.authorName,
);

/// "Message to Ron": who is coming (one of my pets, or just me) and the
/// first message, ready to edit. Pops with the message.
class JoinMeetupSheet extends ConsumerStatefulWidget {
  const JoinMeetupSheet({super.key, required this.meetup});

  static const messageKey = Key('meetup-join-message');
  static const sendKey = Key('meetup-join-send');
  static const justMeKey = Key('meetup-join-just-me');
  static Key petKey(String petId) => Key('meetup-join-pet-$petId');

  final Meetup meetup;

  @override
  ConsumerState<JoinMeetupSheet> createState() => _JoinMeetupSheetState();
}

class _JoinMeetupSheetState extends ConsumerState<JoinMeetupSheet> {
  final _message = TextEditingController();
  String? _petId;
  var _edited = false;
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    // The pet of the ad's kind of animal, the selected one first.
    final pets = ref.read(petsProvider);
    final selected = ref.read(selectedPetProvider);
    final audience = widget.meetup.audience;
    bool fits(Pet pet) =>
        audience == Audience.everyone ||
        audienceOfSpecies(pet.species) == audience;
    final ordered = [
      ...pets.where((p) => p.id == selected.id),
      ...pets.where((p) => p.id != selected.id),
    ];
    _petId = ordered.where(fits).firstOrNull?.id;
    _message.text = _draft();
  }

  String _draft() {
    final pets = ref.read(petsProvider);
    final pet = pets.where((p) => p.id == _petId).firstOrNull;
    return MeetupText(context).draft(widget.meetup, petName: pet?.name);
  }

  void _choose(String? petId) => setState(() {
    _petId = petId;
    if (!_edited) _message.text = _draft();
  });

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.meetupsL10n;
    final text = MeetupText(context);
    final pets = ref.watch(petsProvider);
    final name = text.author(widget.meetup.authorName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        SheetTitle(l10n.joinTitle(name), subtitle: l10n.joinBody(name)),
        const SizedBox(height: 14),
        Text(l10n.whoComing, style: AppText.label.copyWith(color: AppColors.brown)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final pet in pets)
              ChoiceChip(
                key: JoinMeetupSheet.petKey(pet.id),
                label: Text(pet.name),
                selected: _petId == pet.id,
                showCheckmark: false,
                onSelected: (_) => _choose(pet.id),
              ),
            ChoiceChip(
              key: JoinMeetupSheet.justMeKey,
              label: Text(l10n.justMe),
              selected: _petId == null,
              showCheckmark: false,
              onSelected: (_) => _choose(null),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: JoinMeetupSheet.messageKey,
          controller: _message,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          onChanged: (_) => _edited = true,
          decoration: InputDecoration(labelText: l10n.joinMessageLabel),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(top: 2, end: 8),
              child: AppIcon(
                Icons.shield_outlined,
                size: 18,
                color: AppColors.brown,
              ),
            ),
            Expanded(
              child: Text(
                l10n.joinTip,
                style: AppText.secondary.copyWith(color: AppColors.brown),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder(
          valueListenable: _message,
          builder: (context, value, _) => FilledButton.icon(
            key: JoinMeetupSheet.sendKey,
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(value.text.trim()),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.chat_bubble_outline_rounded),
            label: Text(l10n.joinSend, textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}
