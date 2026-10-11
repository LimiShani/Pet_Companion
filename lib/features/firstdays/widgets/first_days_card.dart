import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../presentation/care_widgets.dart';
import '../../../presentation/dashboard_card.dart';
import '../first_days_screen.dart';
import '../first_days_words.dart';
import '../../../services/firstdays/state/first_days_logic.dart';
import '../../../services/firstdays/state/first_days_providers.dart';
import 'first_days_keeper.dart';

/// Home's "The first 30 days of Mitzi" card: the day and the progress as
/// the title's label ("Day 10 · 2/12"), the progress bar, and the next
/// task with "Open" at the end of its line (the `DashboardCard` contract).
/// Shown for [pet] only while its path runs (day 1 to 30, not closed, not
/// finished); otherwise it takes no room at all.
///
/// [margin] is the gap kept above the card when it shows.
class FirstDaysHomeCard extends StatelessWidget {
  const FirstDaysHomeCard({
    super.key,
    required this.pet,
    this.margin = const EdgeInsets.only(top: AppSpacing.cardGap),
  });

  static const cardKey = Key('first-days-card');
  static const openKey = Key('first-days-card-open');

  final Pet pet;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => FirstDaysKeeper(
    petId: pet.id,
    child: Consumer(
      builder: (context, ref, _) {
        final view = ref.watch(firstDaysViewProvider(pet.id)).value;
        if (view == null || !view.isRunning) return const SizedBox.shrink();
        return Padding(
          padding: margin,
          child: _Card(view: view),
        );
      },
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.view});

  final FirstDaysView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.firstDaysL10n;
    final format = AppFormat.of(context);
    final next = view.next;
    void open() => openFirstDays(context, view.pet.id);

    final pill = CarePillButton(
      key: FirstDaysHomeCard.openKey,
      label: l10n.open,
      filled: true,
      onPressed: open,
    );

    return DashboardCard(
      key: FirstDaysHomeCard.cardKey,
      color: AppColors.yellow,
      iconAsset: 'assets/images/icon_first_days.svg',
      iconRing: true,
      title: l10n.cardTitle(view.pet.name),
      trailing:
          '${l10n.cardDay(format.integer(view.shownDay))} · '
          '${isolate('${format.integer(view.doneCount)}/${format.integer(view.total)}')}',
      onTap: open,
      tapLabel: l10n.openTapLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CareProgress(
            value: view.progress,
            track: AppColors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          if (next == null)
            CardActionRow.alone(action: pill)
          else
            CardActionRow(
              text: l10n.cardNext(firstDaysTaskText(l10n, next.task.id)),
              actionLabel: l10n.open,
              action: pill,
              maxLines: 3,
            ),
        ],
      ),
    );
  }
}
