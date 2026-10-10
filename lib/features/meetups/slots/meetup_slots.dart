import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../presentation/health_widgets.dart' show kHealthTapTarget;
import '../../../presentation/pet_avatar.dart';
import '../../../services/meetups/data/meetup_models.dart';
import '../../../services/meetups/state/meetups_providers.dart';
import '../../../services/outdoors/state/parks_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../community/community_words.dart';
import '../../community/safety/safety_providers.dart' show blockedIdsProvider;
import '../../outdoors/outdoors.dart' show ParkTag;
import '../meetup_actions.dart';
import '../meetups_state.dart';
import '../meetups_words.dart';

/// "Post a meetup here": beside Navigate on a park's page; the form opens
/// with the park chosen.
class PostMeetupHereButton extends ConsumerWidget {
  const PostMeetupHereButton({super.key, required this.parkId});

  static const buttonKey = Key('park-post-meetup');

  final String parkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(capabilityProvider(MeetupCapabilities.post))) {
      return const SizedBox.shrink();
    }
    final park = ref.watch(parkProvider(parkId)).value;
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: park == null || park.isClosed
          ? null
          : () => openMeetupForm(context, park: park),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, kHealthTapTarget),
      ),
      icon: const AppIcon(Icons.add_rounded),
      label: Text(context.meetupsL10n.postHere),
    );
  }
}

/// "Meetups at this park": its open ads (a tap opens one), and for a saved
/// park the switch "Tell me about new meetups here".
class ParkMeetupsSection extends ConsumerWidget {
  const ParkMeetupsSection({super.key, required this.parkId});

  static const sectionKey = Key('park-meetups');
  static const notifyKey = Key('park-meetups-notify');
  static const saveFirstKey = Key('park-meetups-save-first');
  static Key rowKey(String id) => Key('park-meetup-$id');

  final String parkId;

  Future<void> _notify(BuildContext context, WidgetRef ref, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final words = context.meetupsL10n.notifyFailed;
    try {
      await ref.read(meetupNotifyParksProvider.notifier).set(parkId, on);
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(words)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.meetupsL10n;
    final now = ref.watch(meetupsClockProvider)();
    final blocked = ref.watch(blockedIdsProvider);
    final fetched = ref.watch(parkMeetupsProvider(parkId));
    final ads = [
      for (final ad in fetched.value ?? const <Meetup>[])
        if (ad.isLiveAt(now) && !blocked.contains(ad.authorId)) ad,
    ]..sort((a, b) => (a.time.nextDay(now) ?? DateTime(9999)).compareTo(
        b.time.nextDay(now) ?? DateTime(9999),
      ));
    final saved =
        ref.watch(parkFavoritesProvider).value?.contains(parkId) ?? false;
    final notify =
        ref.watch(meetupNotifyParksProvider).value?.contains(parkId) ?? false;
    return MeetupsKeeper(
      board: false,
      also: [
        parkMeetupsProvider(parkId),
        meetupNotifyParksProvider,
        blockedIdsProvider,
      ],
      child: Column(
        key: sectionKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              l10n.atThisPark,
              style: AppText.label.copyWith(color: AppColors.brown),
            ),
          ),
          const SizedBox(height: 8),
          if (fetched.isLoading && !fetched.hasValue)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else if (ads.isEmpty)
            Text(l10n.noneAtPark, style: AppText.body)
          else
            for (final ad in ads)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MeetupRow(key: rowKey(ad.id), meetup: ad),
              ),
          const SizedBox(height: 4),
          if (saved)
            SwitchListTile(
              key: notifyKey,
              contentPadding: EdgeInsets.zero,
              value: notify,
              onChanged: (on) => _notify(context, ref, on),
              title: Text(l10n.notifyHere, style: AppText.body),
            )
          else
            Text(
              l10n.notifySaveFirst,
              key: saveFirstKey,
              style: AppText.secondary.copyWith(color: AppColors.brown),
            ),
        ],
      ),
    );
  }
}

/// An ad in a short list (a park page, a member page): the pet, the kind,
/// when and who. A tap opens the ad.
class MeetupRow extends ConsumerWidget {
  const MeetupRow({super.key, required this.meetup, this.showPlace = false});

  final Meetup meetup;

  /// The place instead of the author (a member page).
  final bool showPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.meetupsL10n;
    final text = MeetupText(context, ref.watch(weekSettingsProvider));
    final now = ref.watch(meetupsClockProvider)();
    final ad = meetup;
    final pet = ad.pet;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openMeetupPage(context, ad.id, initial: ad),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
          child: Row(
            children: [
              if (pet != null)
                PetAvatar(pet: pet.asPet, size: 40)
              else
                const AppIcon(Icons.person_rounded, color: AppColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          pet?.name ?? l10n.noPet,
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        ParkTag(l10n.kind(ad.kind), color: AppColors.yellow),
                      ],
                    ),
                    Text(
                      dotted([
                        text.when(ad.time, now),
                        if (showPlace)
                          text.place(ad)
                        else
                          context.communityL10n.inLine(
                            text.author(ad.authorName),
                          ),
                      ]),
                      style: AppText.secondary.copyWith(
                        color: AppColors.brown,
                      ),
                    ),
                  ],
                ),
              ),
              const AppIcon(
                Icons.chevron_right_rounded,
                color: AppColors.brown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Meetup today" / "2 meetups this week" on a park card.
class ParkCardMeetups extends ConsumerWidget {
  const ParkCardMeetups({super.key, required this.parkId});

  static Key keyOf(String parkId) => Key('park-card-meetups-$parkId');

  final String parkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MeetupsKeeper(
    board: false,
    also: [parkMeetupSummariesProvider],
    child: Consumer(builder: (context, ref, _) => _build(context, ref)),
  );

  Widget _build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(
      parkMeetupSummariesProvider.select((all) => all[parkId]),
    );
    if (summary == null || summary.thisWeek == 0) {
      return const SizedBox.shrink();
    }
    final l10n = context.meetupsL10n;
    return Padding(
      key: keyOf(parkId),
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ParkTag(
          summary.today
              ? l10n.cardMeetupToday
              : l10n.cardMeetupsWeek(summary.thisWeek),
          icon: Icons.groups_rounded,
          color: AppColors.peach.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// A member page's open ads; nothing when there are none.
class MemberMeetupsSection extends ConsumerWidget {
  const MemberMeetupsSection({super.key, required this.memberId});

  static const sectionKey = Key('member-meetups');

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(meetupsClockProvider)();
    final fetched = ref.watch(memberMeetupsProvider(memberId));
    // A small wheel while loading (and nothing when there are no ads).
    if (fetched.isLoading && !fetched.hasValue) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    final ads = [
      for (final ad in fetched.value ?? const <Meetup>[])
        if (ad.isLiveAt(now)) ad,
    ];
    if (ads.isEmpty) return const SizedBox.shrink();
    return MeetupsKeeper(
      board: false,
      also: [memberMeetupsProvider(memberId)],
      child: Column(
        key: sectionKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              context.meetupsL10n.memberAds,
              style: AppText.label.copyWith(color: AppColors.brown),
            ),
          ),
          const SizedBox(height: 8),
          for (final ad in ads)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MeetupRow(meetup: ad, showPlace: true),
            ),
        ],
      ),
    );
  }
}
