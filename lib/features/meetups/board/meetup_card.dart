import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/feature_ui.dart';
import '../../../presentation/health_widgets.dart'
    show TypedText, kHealthTapTarget;
import '../../../presentation/pet_avatar.dart';
import '../../../services/meetups/data/meetup_models.dart';
import '../../../services/meetups/state/meetups_providers.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../community/chat/private_chat_providers.dart'
    show privateChatCapability;
import '../../community/community_words.dart';
import '../../outdoors/outdoors.dart' show parkDetailIcon;
import '../../outdoors/outdoors_words.dart';
import '../meetup_actions.dart';
import '../meetups_words.dart';
import '../../../widgets/app_tag.dart';

/// One ad: the pet, the kind, the place (a park opens its page), when, how
/// far, the note, the author, and "I want to join" (or, on one's own ad,
/// the author's tools when [ownerTools]).
class MeetupCard extends ConsumerWidget {
  const MeetupCard({
    super.key,
    required this.meetup,
    this.distanceM,
    this.ownerTools = false,
  });

  static Key keyOf(String id) => Key('meetup-card-$id');
  static Key joinKey(String id) => Key('meetup-join-$id');
  static Key chatKey(String id) => Key('meetup-chat-$id');
  static Key menuKey(String id) => Key('meetup-menu-$id');
  static Key parkKey(String id) => Key('meetup-park-$id');
  static Key manageKey(String id) => Key('meetup-manage-$id');
  static Key editKey(String id) => Key('meetup-edit-$id');
  static Key closeKey(String id) => Key('meetup-close-$id');
  static Key renewKey(String id) => Key('meetup-renew-$id');
  static Key againKey(String id) => Key('meetup-again-$id');
  static Key groupKey(String id) => Key('meetup-group-$id');
  static const reportItemKey = Key('meetup-menu-report');
  static const blockItemKey = Key('meetup-menu-block');

  final Meetup meetup;
  final double? distanceM;

  /// Edit, close, renew, post again, the responders' group.
  final bool ownerTools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.meetupsL10n;
    final community = context.communityL10n;
    final text = MeetupText(context, ref.watch(weekSettingsProvider));
    final now = ref.watch(meetupsClockProvider)();
    final viewer = ref.watch(authControllerProvider).value?.id;
    final ad = meetup;
    final own = ad.authorId == viewer;
    final pet = ad.pet;
    final myPet = own && pet?.petId != null
        ? ref
              .watch(petsProvider)
              .where((p) => p.id == pet!.petId)
              .firstOrNull
        : null;
    final canChat = ref.watch(capabilityProvider(privateChatCapability));
    final ended = ad.hasEndedAt(now);
    final closed = ad.status == MeetupStatus.closed;
    final park = ad.park;

    final tags = [
      if (own) _Tag(l10n.yourAd, tone: AppTagTone.peach),
      if (own && ad.hidden) _Tag(l10n.hiddenTag, tone: AppTagTone.yellow),
      if (closed)
        _Tag(l10n.closedTag, tone: AppTagTone.ink)
      else if (ended)
        _Tag(l10n.endedTag, tone: AppTagTone.ink),
      if (!own && ad.answered) _Tag(l10n.answeredTag, tone: AppTagTone.sage),
    ];

    return Material(
      key: keyOf(ad.id),
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (myPet != null)
                  PetAvatar(pet: myPet, size: 48)
                else if (pet != null)
                  PetAvatar(pet: pet.asPet, size: 48)
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.peach.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const AppIcon(
                      Icons.person_rounded,
                      color: AppColors.ink,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TypedText(
                        pet?.name ?? l10n.noPet,
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pet != null)
                        Text(
                          text.petLine(pet, now),
                          style: AppText.secondary.copyWith(
                            color: AppColors.brown,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          AppTag(
                            l10n.kind(ad.kind),
                            tone: AppTagTone.yellow,
                            icon: ad.kind == MeetupKind.walk
                                ? Icons.directions_walk_rounded
                                : Icons.sports_baseball_rounded,
                          ),
                          ...tags,
                        ],
                      ),
                    ],
                  ),
                ),
                if (!own)
                  PopupMenuButton<String>(
                    key: menuKey(ad.id),
                    tooltip: l10n.more,
                    icon: const AppIcon(
                      Icons.more_vert_rounded,
                      color: AppColors.brown,
                    ),
                    onSelected: (choice) => choice == 'report'
                        ? reportMeetupFlow(context, ref, ad)
                        : blockMeetupAuthorFlow(context, ref, ad),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        key: reportItemKey,
                        value: 'report',
                        child: Text(l10n.menuReport),
                      ),
                      PopupMenuItem(
                        key: blockItemKey,
                        value: 'block',
                        child: Text(
                          l10n.menuBlock(
                            community.inLine(text.author(ad.authorName)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Line(
                    icon: park != null
                        ? Icons.park_rounded
                        : Icons.place_rounded,
                    child: park != null && canOpenFeature(context, 'park')
                        ? InkWell(
                            key: parkKey(ad.id),
                            onTap: () => openFeature<Object>(
                              context,
                              'park',
                              '',
                              {'parkId': park.id},
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 32,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  text.place(ad),
                                  style: AppText.body.copyWith(
                                    color: AppColors.coralDark,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.coralDark,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : TypedText(text.place(ad), style: AppText.body),
                  ),
                  if (park != null && park.has.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 28,
                        bottom: 6,
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final detail in park.has)
                            AppTag(
                              context.outdoorsL10n.detail(detail),
                              icon: parkDetailIcon(detail),
                            ),
                        ],
                      ),
                    ),
                  _Line(
                    icon: Icons.schedule_rounded,
                    child: Text(text.when(ad.time, now), style: AppText.body),
                  ),
                  if (distanceM != null || l10n.suits(ad.suits) != null)
                    _Line(
                      icon: Icons.straighten_rounded,
                      child: Text(
                        dotted([
                          if (distanceM case final metres?)
                            text.distance(metres),
                          ?l10n.suits(ad.suits),
                        ]),
                        style: AppText.body.copyWith(color: AppColors.brown),
                      ),
                    ),
                  if (ad.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    TypedText(
                      ad.note,
                      style: AppText.body.copyWith(color: AppColors.ink),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    dotted([
                      if (!own) community.inLine(text.author(ad.authorName)),
                      community.relativeTime(
                        context.l10n,
                        text.format,
                        ad.createdAt,
                        now,
                      ),
                      l10n.answers(ad.answerCount),
                    ]),
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
                  if (own && ad.isRecurring && !ended && !closed)
                    Text(
                      l10n.showsUntil(text.format.date(ad.expiresAt)),
                      style: AppText.secondary.copyWith(
                        color: AppColors.brown,
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (own && ownerTools)
                    _OwnerTools(meetup: ad, now: now)
                  else if (own)
                    OutlinedButton.icon(
                      key: manageKey(ad.id),
                      onPressed: () =>
                          openMeetupPage(context, ad.id, initial: ad),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(kHealthTapTarget),
                      ),
                      icon: const AppIcon(Icons.tune_rounded),
                      label: Text(l10n.manage),
                    )
                  else if (canChat && ad.answered)
                    OutlinedButton.icon(
                      key: chatKey(ad.id),
                      onPressed: () => reopenMeetupChat(context, ref, ad),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(kHealthTapTarget),
                      ),
                      icon: const AppIcon(Icons.chat_bubble_outline_rounded),
                      label: Text(l10n.openChat),
                    )
                  else if (canChat && ad.isLiveAt(now))
                    // Outlined: "New ad" is the board's one filled button.
                    OutlinedButton.icon(
                      key: joinKey(ad.id),
                      onPressed: () => joinMeetupFlow(context, ref, ad),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(kHealthTapTarget),
                      ),
                      icon: const AppIcon(Icons.waving_hand_rounded),
                      label: Text(l10n.join),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {required this.tone});

  final String label;
  final AppTagTone tone;

  @override
  Widget build(BuildContext context) => AppTag(label, tone: tone);
}

/// A line with an icon at the start.
class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.child});

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 2, end: 8),
          child: AppIcon(icon, size: 20, color: AppColors.brown),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

/// The author's buttons on their own ad.
class _OwnerTools extends ConsumerWidget {
  const _OwnerTools({required this.meetup, required this.now});

  final Meetup meetup;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.meetupsL10n;
    final ad = meetup;
    final live = ad.status == MeetupStatus.open && ad.expiresAt.isAfter(now);
    final canPost = ref.watch(capabilityProvider(MeetupCapabilities.post));
    final canChat = ref.watch(capabilityProvider(privateChatCapability));
    final soon = ad.expiresAt.difference(now) < const Duration(days: 7);
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, kHealthTapTarget),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (live && canPost && !ad.hidden)
          OutlinedButton.icon(
            key: MeetupCard.editKey(ad.id),
            onPressed: () => openMeetupForm(context, edit: ad),
            style: style,
            icon: const AppIcon(Icons.edit_rounded),
            label: Text(l10n.edit),
          ),
        if (live)
          OutlinedButton.icon(
            key: MeetupCard.closeKey(ad.id),
            onPressed: () => closeMeetupFlow(context, ref, ad),
            style: style,
            icon: const AppIcon(Icons.check_circle_outline_rounded),
            label: Text(l10n.closeAd),
          ),
        if (ad.isRecurring && canPost && !ad.hidden && (!live || soon))
          FilledButton.icon(
            key: MeetupCard.renewKey(ad.id),
            onPressed: () => renewMeetupFlow(context, ref, ad),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.autorenew_rounded),
            label: Text(l10n.renew),
          ),
        if (!ad.isRecurring && !live && canPost)
          OutlinedButton.icon(
            key: MeetupCard.againKey(ad.id),
            onPressed: () => openMeetupForm(context, copyOf: ad),
            style: style,
            icon: const AppIcon(Icons.replay_rounded),
            label: Text(l10n.postAgain),
          ),
        if (canChat && ad.answerCount >= 2)
          FilledButton.icon(
            key: MeetupCard.groupKey(ad.id),
            onPressed: () => responderGroupFlow(context, ref, ad),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.groups_rounded),
            label: Text(l10n.groupButton(ad.answerCount)),
          ),
      ],
    );
  }
}
