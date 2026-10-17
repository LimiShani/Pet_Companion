import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/feature_ui.dart';
import '../../../presentation/health_widgets.dart'
    show HealthSheetBody, SheetTitle, kHealthTapTarget;
import '../../../services/meetups/data/meetup_models.dart';
import '../../../services/meetups/state/meetups_providers.dart';
import '../../../services/outdoors/data/park_models.dart';
import '../../../services/outdoors/state/parks_providers.dart'
    show savedParksProvider;
import '../../../state/pets_provider.dart';
import '../../../theme/app_area.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/area_disc.dart';
import '../../../widgets/primary_button.dart';
import '../../community/feed/post_actions.dart' show showCommunitySnack;
import '../../community/safety/safety_flows.dart' show ensureCommunityRules;
import '../../outdoors/outdoors.dart' show PickedPark;
import '../../outdoors/outdoors_words.dart';
import '../meetups_words.dart';

/// The white card at the top of Partners: "Going out soon? Tell people who
/// saved your parks. Lasts 90 min." with an outlined "Going now" (the
/// board's floating "+" stays its one filled button).
class GoingOutCard extends ConsumerWidget {
  const GoingOutCard({super.key});

  static const cardKey = Key('partners-going-card');
  static const buttonKey = Key('partners-going-now');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(capabilityProvider(MeetupCapabilities.post))) {
      return const SizedBox.shrink();
    }
    final l10n = context.meetupsL10n;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.goingSoonTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.cardTitle.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        Text(
          l10n.goingSoonBody,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppText.label.copyWith(color: AppColors.brown),
        ),
      ],
    );
    final button = OutlinedButton(
      key: buttonKey,
      onPressed: () => openGoingNowSheet(context),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, kHealthTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        l10n.goingNowButton,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    const disc = AreaDisc(Icons.directions_walk_rounded, area: AppArea.community);
    final card = Material(
      key: cardKey,
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
        // The button beside the words; under them on a small phone.
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 300
              ? Row(
                  children: [
                    disc,
                    const SizedBox(width: 12),
                    Expanded(child: words),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: button,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        disc,
                        const SizedBox(width: 12),
                        Expanded(child: words),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(alignment: AlignmentDirectional.centerEnd, child: button),
                  ],
                ),
        ),
      ),
    );
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: card);
  }
}

/// "Going out now": a short sheet (the park, leaving in 15 to 60 minutes,
/// walk or play, one optional line), then the ad is up for 90 minutes.
Future<void> openGoingNowSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const HealthSheetBody(child: GoingNowSheet()),
    );

class GoingNowSheet extends ConsumerStatefulWidget {
  const GoingNowSheet({super.key});

  static const otherParkKey = Key('going-other-park');
  static const noteKey = Key('going-note');
  static const postKey = Key('going-post');
  static Key parkKey(String id) => Key('going-park-$id');
  static Key leaveKey(int minutes) => Key('going-leave-$minutes');
  static Key kindKey(MeetupKind kind) => Key('going-kind-${kind.name}');

  @override
  ConsumerState<GoingNowSheet> createState() => _GoingNowSheetState();
}

class _GoingNowSheetState extends ConsumerState<GoingNowSheet> {
  final _note = TextEditingController();
  DogPark? _park;

  /// A park chosen from the list that is not among the saved ones.
  DogPark? _picked;
  var _minutes = MeetupLimits.nowLeaveOptions[1];
  var _kind = MeetupKind.walk;
  var _busy = false;
  var _askPark = false;
  var _defaulted = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickPark() async {
    final picked = await openFeature<PickedPark>(context, 'pick-park', '');
    if (picked == null || !mounted) return;
    setState(() {
      _park = picked.park;
      _askPark = false;
      final saved = ref.read(savedParksProvider).value ?? const <DogPark>[];
      if (!saved.any((p) => p.id == picked.park.id)) _picked = picked.park;
    });
  }

  Future<void> _post() async {
    final l10n = context.meetupsL10n;
    final park = _park;
    if (park == null) {
      setState(() => _askPark = true);
      return;
    }
    if (!await ensureCommunityRules(context, ref)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final pets = ref.read(petsProvider);
    final selected = pets.isEmpty ? null : ref.read(selectedPetProvider);
    final now = ref.read(meetupsClockProvider)();
    setState(() => _busy = true);
    try {
      await ref
          .read(meetupsControllerProvider.notifier)
          .save(
            MeetupDraft(
              kind: _kind,
              pet: selected == null ? null : MeetupPet.of(selected),
              parkId: park.id,
              park: park,
              localityCode: park.localityCode,
              time: NowTime.leavingIn(_minutes, now),
              note: _note.text.trim(),
            ),
          );
      showCommunitySnack(messenger, l10n.goingPosted);
      navigator.pop();
    } catch (e) {
      showCommunitySnack(
        messenger,
        e is MeetupException && e.failure == MeetupFailure.rateLimited
            ? l10n.errNowLimit
            : l10n.failure(e),
      );
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.meetupsL10n;
    final outdoors = context.outdoorsL10n;
    final language = languageOf(context);
    final pets = ref.watch(petsProvider);
    final pet = pets.isEmpty ? null : ref.watch(selectedPetProvider);
    final saved = ref.watch(savedParksProvider).value ?? const <DogPark>[];
    // The first saved park to start with.
    if (!_defaulted && _park == null && saved.isNotEmpty) {
      _defaulted = true;
      _park = saved.first;
    }
    final parks = [...saved.take(4), ?_picked];
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(text, style: AppText.label.copyWith(color: AppColors.brown)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        SheetTitle(
          l10n.addGoingNow,
          subtitle: pet == null ? null : l10n.goingWith(pet.name),
        ),
        label(l10n.goingWhere),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final park in parks)
              ChoiceChip(
                key: GoingNowSheet.parkKey(park.id),
                label: Text(
                  outdoors.parkTitle(park, language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: _park?.id == park.id,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _park = park;
                  _askPark = false;
                }),
              ),
            ActionChip(
              key: GoingNowSheet.otherParkKey,
              avatar: const Icon(Icons.search_rounded, size: 18),
              label: Text(l10n.goingOtherPark),
              onPressed: _pickPark,
            ),
          ],
        ),
        if (_askPark)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.goingPickPark,
              style: AppText.secondary.copyWith(color: AppColors.coralDark),
            ),
          ),
        label(l10n.goingLeavingIn),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final minutes in MeetupLimits.nowLeaveOptions)
              ChoiceChip(
                key: GoingNowSheet.leaveKey(minutes),
                label: Text(l10n.goingMinutes(minutes)),
                selected: _minutes == minutes,
                showCheckmark: false,
                onSelected: (_) => setState(() => _minutes = minutes),
              ),
          ],
        ),
        label(l10n.filterKind),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final kind in MeetupKind.values)
              ChoiceChip(
                key: GoingNowSheet.kindKey(kind),
                label: Text(l10n.kind(kind)),
                selected: _kind == kind,
                showCheckmark: false,
                onSelected: (_) => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: GoingNowSheet.noteKey,
          controller: _note,
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l10n.goingNoteHint),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          key: GoingNowSheet.postKey,
          label: l10n.goingPost,
          loading: _busy,
          onPressed: _post,
        ),
      ],
    );
  }
}
