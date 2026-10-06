import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../presentation/health_strings.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../presentation/pets_widgets.dart';
import '../../../services/firstdays/data/first_days_models.dart';
import '../first_days_screen.dart';
import '../../../services/firstdays/state/first_days_logic.dart';
import '../../../services/firstdays/state/first_days_providers.dart';
import 'arrival_question.dart';
import 'first_days_keeper.dart';

/// The first 30 days on the pet's profile: "Start the first 30 days" for a
/// pet that never had them (it asks for the arrival day), otherwise the
/// day and progress with the way to the page, which stays reachable here
/// as a summary once the path ended. Nothing while it loads or when it
/// could not load (the profile does not depend on it).
class FirstDaysProfileEntry extends StatelessWidget {
  const FirstDaysProfileEntry({super.key, required this.pet});

  static const startKey = Key('first-days-start');
  static const openKey = Key('first-days-profile-open');

  final Pet pet;

  @override
  Widget build(BuildContext context) => FirstDaysKeeper(
    petId: pet.id,
    child: Consumer(
      builder: (context, ref, _) {
        final path = ref.watch(firstDaysProvider(pet.id));
        if (!path.hasValue || path.hasError) return const SizedBox.shrink();
        final l10n = context.firstDaysL10n;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PetsLabel(l10n.sectionTitle),
            if (path.value == null)
              _Start(pet: pet)
            else
              _Summary(view: ref.watch(firstDaysViewProvider(pet.id)).value),
          ],
        );
      },
    ),
  );
}

class _Start extends ConsumerStatefulWidget {
  const _Start({required this.pet});

  final Pet pet;

  @override
  ConsumerState<_Start> createState() => _StartState();
}

class _StartState extends ConsumerState<_Start> {
  bool _busy = false;

  Future<void> _start() async {
    final day = await pickArrivalDay(
      context,
      now: ref.read(healthClockProvider)(),
    );
    if (day == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(firstDaysProvider(widget.pet.id).notifier).start(day);
      if (mounted) await openFirstDays(context, widget.pet.id);
    } catch (error) {
      if (mounted) showPetsSnack(context, healthErrorOf(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.firstDaysL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PetsNote(l10n.startNote),
        const SizedBox(height: 10),
        PetsOutlineButton(
          l10n.startPath,
          key: FirstDaysProfileEntry.startKey,
          icon: Icons.home_rounded,
          onPressed: _busy ? null : _start,
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.view});

  /// `null` while the health data that ticks tasks is loading.
  final FirstDaysView? view;

  @override
  Widget build(BuildContext context) {
    final view = this.view;
    if (view == null) {
      return const PetsCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    final l10n = context.firstDaysL10n;
    final format = AppFormat.of(context);
    final closedAt = view.path.closedAt;
    final title = switch (view.stage) {
      FirstDaysStage.closed => l10n.closedOn(format.date(closedAt!)),
      FirstDaysStage.over => l10n.overLine,
      _ => l10n.dayOfTotal(
        format.integer(view.shownDay),
        format.integer(firstDaysLength),
      ),
    };
    void open() => openFirstDays(context, view.pet.id);

    return PetsCard(
      onTap: open,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
      child: Row(
        children: [
          const PetsDisc(Icons.home_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle),
                Text(
                  l10n.doneCount(
                    '${format.integer(view.doneCount)}/${format.integer(view.total)}',
                  ),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PillButton(
            view.hasEnded ? l10n.viewSummary : l10n.open,
            key: FirstDaysProfileEntry.openKey,
            onPressed: open,
          ),
        ],
      ),
    );
  }
}
