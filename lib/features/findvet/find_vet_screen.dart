import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/coral_segmented_control.dart';
import '../health/emergency/contact_actions.dart' show launchOrExplain;
import '../health/emergency/vet_form_screen.dart' show openVetForm;
import '../health/data/health_models.dart' show Vet, VetRole;
import '../health/widgets/health_widgets.dart' show kHealthTapTarget, showHealthSheet, SheetTitle, FinePrint;
import 'data/location_service.dart';
import 'data/supabase_vet_finder_repository.dart';
import 'data/vet_models.dart';
import 'findvet_words.dart';
import 'regions/regions.dart';
import 'state/find_vet_providers.dart';
import 'widgets/area_picker.dart';
import 'widgets/vet_result_card.dart';

/// Opens Find a vet over the whole app (also from the sign-in screen: it
/// needs no account). With [mode], it opens straight on that path; the
/// Emergency sheet opens it on [VetSearchMode.emergency].
Future<void> openFindVet(BuildContext context, {VetSearchMode? mode}) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(builder: (_) => FindVetScreen(initialMode: mode)));

class FindVetScreen extends ConsumerStatefulWidget {
  const FindVetScreen({super.key, this.initialMode});

  static const screenKey = Key('findvet-screen');
  static const emergencyChoiceKey = Key('findvet-choice-emergency');
  static const longTermChoiceKey = Key('findvet-choice-longterm');
  static const demoBannerKey = Key('findvet-demo-banner');
  static const legendKey = Key('findvet-legend');
  static const widerKey = Key('findvet-search-wider');
  static const retryKey = Key('findvet-retry');
  static const otherAreaKey = Key('findvet-other-area');

  final VetSearchMode? initialMode;

  @override
  ConsumerState<FindVetScreen> createState() => _FindVetScreenState();
}

class _FindVetScreenState extends ConsumerState<FindVetScreen> {
  @override
  void initState() {
    super.initState();
    // Keeps the copy of our own directory on the phone fresh, for a search
    // with no connection. It holds facilities, never the owner's searches.
    final repository = ref.read(findVetRepositoryProvider);
    if (repository is SupabaseVetFinderRepository) {
      for (final region in vetRegions) {
        unawaited(repository.refreshDirectoryCopy(region));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = findVetControllerProvider(widget.initialMode);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final l10n = context.findVetL10n;
    final demo = ref.watch(findVetRepositoryProvider).isDemo;
    final mode = state.mode;
    // Opened on the choice: back from a path returns to the choice.
    final backToChoice = mode != null && widget.initialMode == null;

    return PopScope(
      canPop: !backToChoice,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && backToChoice) controller.backToChoice();
      },
      child: Scaffold(
        key: FindVetScreen.screenKey,
        body: Column(
          children: [
            CoralHeader(
              title: l10n.findVetTitle,
              showBack: true,
              bottom: mode == null
                  ? null
                  : CoralSegmentedControl(
                      labels: [l10n.modeEmergency, l10n.modeLongTerm],
                      selectedIndex: mode == VetSearchMode.emergency ? 0 : 1,
                      onChanged: (i) => controller.chooseMode(i == 0 ? VetSearchMode.emergency : VetSearchMode.longTerm),
                    ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screen,
                  14,
                  AppSpacing.screen,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  if (demo) ...[const _DemoBanner(), const SizedBox(height: 12)],
                  if (mode == null)
                    _Choice(state: state, onChoose: controller.chooseMode, onChangeArea: controller.changeArea)
                  else if (state.area == null)
                    AreaPicker(
                      locating: state.locating,
                      problem: state.problem,
                      onUseLocation: controller.useMyLocation,
                      onOpenSettings: () => ref
                          .read(locationServiceProvider)
                          .openSettings(
                            state.problem == AreaProblem.serviceOff
                                ? LocationOutcome.serviceOff
                                : LocationOutcome.deniedForever,
                          ),
                      onPicked: controller.setArea,
                      lookUp: (query) =>
                          controller.lookUp(query, appLanguage: Localizations.localeOf(context).languageCode),
                    )
                  else ...[
                    AreaBar(
                      area: state.area!,
                      radiusM: state.results?.value?.radiusM,
                      onChange: controller.changeArea,
                    ),
                    const SizedBox(height: 12),
                    _Results(state: state, controller: controller),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: FindVetScreen.demoBannerKey,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 8),
            child: AppIcon(Icons.science_outlined, size: 20, color: AppColors.ink),
          ),
          Expanded(child: Text(context.findVetL10n.demoBanner, style: AppText.secondary.copyWith(color: AppColors.ink))),
        ],
      ),
    );
  }
}

/// The first screen: Emergency care or Long term care.
class _Choice extends StatelessWidget {
  const _Choice({required this.state, required this.onChoose, required this.onChangeArea});

  final FindVetState state;
  final ValueChanged<VetSearchMode> onChoose;
  final VoidCallback onChangeArea;

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(l10n.choiceQuestion, style: AppText.cardTitle.copyWith(fontSize: 19))),
        const SizedBox(height: 12),
        _ChoiceCard(
          key: FindVetScreen.emergencyChoiceKey,
          color: AppColors.coral,
          foreground: AppColors.white,
          icon: Icons.local_hospital_rounded,
          title: l10n.emergencyChoiceTitle,
          body: l10n.emergencyChoiceBody,
          onTap: () => onChoose(VetSearchMode.emergency),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          key: FindVetScreen.longTermChoiceKey,
          color: AppColors.yellow,
          foreground: AppColors.ink,
          icon: Icons.medical_services_rounded,
          title: l10n.longTermChoiceTitle,
          body: l10n.longTermChoiceBody,
          onTap: () => onChoose(VetSearchMode.longTerm),
        ),
        if (state.area != null) ...[
          const SizedBox(height: 16),
          AreaBar(area: state.area!, onChange: onChangeArea),
        ],
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: AppIcon(icon, size: 28, color: AppColors.coralDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.cardTitle.copyWith(fontSize: 19, color: foreground)),
                      const SizedBox(height: 2),
                      Text(body, style: AppText.body.copyWith(color: foreground, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                AppIcon(Icons.chevron_right_rounded, color: foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The results of the chosen path, with every state: searching, failed,
/// nothing found, and the live search being down.
class _Results extends ConsumerStatefulWidget {
  const _Results({required this.state, required this.controller});

  final FindVetState state;
  final FindVetController controller;

  @override
  ConsumerState<_Results> createState() => _ResultsState();
}

class _ResultsState extends ConsumerState<_Results> {
  /// Rebuilds the cards when the first live report expires, so a report
  /// never outlives its validity on screen.
  Timer? _expiry;

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  void _scheduleExpiry(VetSearchResult result, DateTime now) {
    _expiry?.cancel();
    DateTime? next;
    for (final r in result.results) {
      final expires = r.intake.expiresAt;
      if (expires != null && expires.isAfter(now) && (next == null || expires.isBefore(next))) next = expires;
    }
    if (next == null) return;
    _expiry = Timer(next.difference(now) + const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _call(VetResult r) async {
    final launcher = ref.read(vetLauncherProvider);
    await launchOrExplain(
      context,
      launch: () => launcher.call(r.phone!),
      problem: context.healthL10n.couldNotOpenPhone,
      copyLabel: context.healthL10n.copyNumber,
      copyText: r.phone!,
      copyIsNumber: true,
    );
  }

  Future<void> _directions(VetResult r) async {
    final launcher = ref.read(vetLauncherProvider);
    await launchOrExplain(
      context,
      launch: () => launcher.directions(r),
      problem: context.healthL10n.couldNotOpenMaps,
      copyLabel: context.healthL10n.copyAddress,
      copyText: r.address ?? '${r.location.lat}, ${r.location.lng}',
    );
  }

  Future<void> _save(VetResult r) async {
    final l10n = context.findVetL10n;
    final pets = ref.read(petsProvider);
    if (pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.saveNeedsPet)));
      return;
    }
    final pet = pets.length == 1 ? pets.single : await _choosePet(pets);
    if (pet == null || !mounted) return;
    // The owner sees every field in Health's vet form and saves it there:
    // the stored vet is their own contact entry.
    final saved = await openVetForm(
      context,
      petId: pet.id,
      role: VetRole.regular,
      prefill: Vet(id: '', name: r.name, phone: r.phone ?? '', address: r.address ?? ''),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.savedVet)));
    }
  }

  Future<Pet?> _choosePet(List<Pet> pets) => showHealthSheet<Pet>(
    context,
    Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetTitle(context.findVetL10n.saveChoosePet),
          const SizedBox(height: 8),
          for (final pet in pets)
            ListTile(
              key: Key('findvet-save-pet-${pet.id}'),
              minTileHeight: kHealthTapTarget,
              leading: const AppIcon(Icons.pets_rounded, color: AppColors.coralDark),
              title: Text(pet.name),
              onTap: () => Navigator.of(context).pop(pet),
            ),
        ],
      ),
    ),
  );

  Future<void> _openLink(String url) => ref.read(vetLauncherProvider).openLink(url);

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    final value = widget.state.results;
    final mode = widget.state.mode!;
    if (value == null || value.isLoading) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.searching, style: AppText.body.copyWith(color: AppColors.brown)),
            ],
          ),
        ),
      );
    }
    if (value.hasError) {
      return _Message(
        icon: Icons.wifi_off_rounded,
        title: l10n.errorTitle,
        body: l10n.failure(value.error!),
        actions: [
          FilledButton(key: FindVetScreen.retryKey, onPressed: widget.controller.search, child: Text(l10n.tryAgain)),
          OutlinedButton(
            key: FindVetScreen.otherAreaKey,
            onPressed: widget.controller.changeArea,
            child: Text(l10n.tryAnotherArea),
          ),
        ],
      );
    }

    final result = value.value!;
    final now = ref.watch(findVetClockProvider)();
    _scheduleExpiry(result, now);
    final signedIn = ref.watch(authControllerProvider).value != null;
    final wider = widget.controller.widerRadius;

    VetResultCard card(VetResult r, {String? option}) => VetResultCard(
      key: ValueKey(r.key),
      result: r,
      mode: mode,
      now: now,
      optionLabel: option,
      onCall: () => _call(r),
      onDirections: () => _directions(r),
      onOpenLink: _openLink,
      onSave: mode == VetSearchMode.longTerm && signedIn ? () => _save(r) : null,
    );

    final children = <Widget>[];
    if (mode == VetSearchMode.emergency) children.add(const _CallFirstBanner());
    if (result.directoryCopyFrom != null) {
      children.add(_Notice(l10n.noticeDirectoryCopy(AppFormat.of(context).dateTime(result.directoryCopyFrom!.toLocal()))));
    } else if (result.usedFallback) {
      children.add(
        _Notice(mode == VetSearchMode.emergency ? l10n.noticeProviderDown : l10n.noticeProviderDownLongTerm),
      );
    }
    if (result.expanded) children.add(_Notice(l10n.noticeExpanded(radiusKm(result.radiusM))));

    final widerButton = wider == null
        ? null
        : OutlinedButton.icon(
            key: FindVetScreen.widerKey,
            onPressed: widget.controller.searchWider,
            icon: const AppIcon(Icons.zoom_out_map_rounded),
            label: Text(l10n.searchWider(radiusKm(wider))),
          );

    if (result.results.isEmpty) {
      children.add(
        _Message(
          icon: Icons.search_off_rounded,
          title: l10n.noResultsTitle,
          body: mode == VetSearchMode.emergency
              ? l10n.noEmergencyResultsBody(radiusKm(result.radiusM))
              : l10n.noResultsBody(radiusKm(result.radiusM)),
          actions: [
            ?widerButton,
            OutlinedButton(
              key: FindVetScreen.otherAreaKey,
              onPressed: widget.controller.changeArea,
              child: Text(l10n.tryAnotherArea),
            ),
          ],
        ),
      );
    } else if (mode == VetSearchMode.emergency) {
      bool top(VetResult r) {
        final intake = r.intake.effectiveAt(now);
        return r.emergencyState == EmergencyClaimState.advertised ||
            intake == IntakeState.accepting ||
            intake == IntakeState.limited;
      }

      final advertised = result.results.where(top).toList();
      final unverified = result.results
          .where((r) => !top(r) && r.emergencyState == EmergencyClaimState.unverified)
          .toList();
      final others = result.results
          .where((r) => !top(r) && r.emergencyState != EmergencyClaimState.unverified)
          .toList();

      if (advertised.isNotEmpty) {
        children.add(_SectionTitle(l10n.sectionAdvertised));
        for (var i = 0; i < advertised.length; i++) {
          children.add(
            card(
              advertised[i],
              option: i == 0
                  ? l10n.firstOption
                  : i == 1
                  ? l10n.secondOption
                  : null,
            ),
          );
        }
        if (advertised.length == 1) {
          children.add(_Notice(l10n.onlyOneAdvertised(radiusKm(result.radiusM))));
          if (widerButton != null) children.add(Align(alignment: AlignmentDirectional.centerStart, child: widerButton));
        }
      } else {
        children.add(_Notice(l10n.noEmergencyResultsBody(radiusKm(result.radiusM))));
        if (widerButton != null) children.add(Align(alignment: AlignmentDirectional.centerStart, child: widerButton));
      }
      if (unverified.isNotEmpty) {
        children.add(_SectionTitle(l10n.sectionUnverified));
        children.addAll(unverified.map(card));
      }
      if (others.isNotEmpty) {
        children.add(_SectionTitle(l10n.sectionOther, note: l10n.sectionOtherNote));
        children.addAll(others.map(card));
      }
    } else {
      children.addAll(result.results.map(card));
      if (widerButton != null && result.results.length < 3) {
        children.add(Align(alignment: AlignmentDirectional.centerStart, child: widerButton));
      }
    }

    children.add(const SizedBox(height: 8));
    children.add(
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: FindVetScreen.legendKey,
          onPressed: () => showHealthSheet<void>(context, const _Legend()),
          style: TextButton.styleFrom(minimumSize: const Size(kHealthTapTarget, kHealthTapTarget)),
          icon: const AppIcon(Icons.info_outline_rounded, size: 18),
          label: Text(l10n.legendLink),
        ),
      ),
    );
    if (result.anyFromProvider && result.attribution != null) {
      children.add(_Attribution(result.attribution!));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// Always first on the emergency path.
class _CallFirstBanner extends StatelessWidget {
  const _CallFirstBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppSpacing.fieldRadius)),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 10, top: 2),
              child: AppIcon(Icons.phone_in_talk_rounded, color: AppColors.coralDark),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.callFirstTitle, style: AppText.cardTitle.copyWith(fontSize: 16)),
                  Text(l10n.callFirstBody, style: AppText.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.peach.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          ),
          child: Text(text, style: AppText.body),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, bottom: 8, start: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: AppText.cardTitle.copyWith(fontSize: 16))),
          if (note != null) Text(note!, style: AppText.secondary.copyWith(color: AppColors.brown)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, required this.actions});

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
              child: AppIcon(icon, size: 34, color: AppColors.coralDark),
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: AppText.cardTitle.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text(body, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.brown)),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }
}

/// Google's rule: the plain words "Google Maps", untranslated, on one line,
/// next to content that came from it.
class _Attribution extends StatelessWidget {
  const _Attribution(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(context.findVetL10n.listingsFrom, style: AppText.secondary.copyWith(color: AppColors.brown)),
          Text(
            name,
            textDirection: TextDirection.ltr,
            softWrap: false,
            // Roboto where the phone has it (Android); else a sans-serif, as Google allows.
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontFamilyFallback: ['Nunito'],
              fontSize: 13,
              color: Color(0xFF5E5E5E),
            ),
          ),
        ],
      ),
    );
  }
}

/// What each label means and where it comes from.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    Widget entry(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10, top: 2),
              child: AppIcon(icon, size: 20, color: AppColors.coralDark),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
                  Text(body, style: AppText.secondary.copyWith(color: AppColors.ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(l10n.legendLink),
        const SizedBox(height: 12),
        entry(Icons.place_outlined, l10n.evidenceListed, l10n.legendListedBody),
        entry(Icons.verified_outlined, l10n.evidenceAdvertised, l10n.legendAdvertisedBody),
        entry(Icons.schedule_rounded, l10n.evidenceOpenNow, l10n.legendOpenBody),
        entry(Icons.check_circle_rounded, l10n.evidenceAccepting, l10n.legendAcceptingBody),
        entry(Icons.phone_in_talk_rounded, l10n.callToConfirm, l10n.legendCallBody),
        const SizedBox(height: 4),
        FinePrint(context.healthL10n.safetyLine),
      ],
    );
  }
}
