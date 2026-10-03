import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../care/widgets/care_widgets.dart';
import '../first_days_screen.dart';
import '../first_days_words.dart';
import '../state/first_days_logic.dart';
import '../state/first_days_providers.dart';
import 'first_days_keeper.dart';

/// Home's "The first 30 days of Mitzi" card: the day, the progress and the
/// next task, with "Open". Shown for [pet] only while its path runs (day 1
/// to 30, not closed, not finished); otherwise it takes no room at all.
///
/// [margin] is the gap kept above the card when it shows.
class FirstDaysHomeCard extends StatelessWidget {
  const FirstDaysHomeCard({super.key, required this.pet, this.margin = const EdgeInsets.only(top: AppSpacing.cardGap)});

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

    return Material(
      key: FirstDaysHomeCard.cardKey,
      color: AppColors.yellow,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Semantics(
          onTapHint: l10n.openTapLabel,
          child: Padding(
            padding: AppSpacing.card,
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.6), width: 3),
                  ),
                  child: ClipOval(
                    child: SvgPicture.asset(
                      'assets/images/icon_first_days.svg',
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.cardTitle(view.pet.name),
                        style: AppText.cardTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.cardDay(format.integer(view.shownDay)),
                              style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${format.integer(view.doneCount)}/${format.integer(view.total)}',
                            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      CareProgress(value: view.progress, track: AppColors.white.withValues(alpha: 0.7)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              next == null ? '' : l10n.cardNext(firstDaysTaskText(l10n, next.task.id)),
                              style: AppText.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CarePillButton(
                            key: FirstDaysHomeCard.openKey,
                            label: l10n.open,
                            filled: true,
                            onPressed: open,
                          ),
                        ],
                      ),
                    ],
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
