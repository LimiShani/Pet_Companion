import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../services/outdoors/data/hazard_models.dart';
import '../../../services/outdoors/state/hazards_providers.dart';
import '../../../theme/app_area.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/area_disc.dart';
import '../outdoors_words.dart';
import 'hazards_screen.dart';

/// The icon of a kind of hazard, in its disc.
IconData hazardIcon(HazardKind kind) => switch (kind) {
  HazardKind.caterpillars => Icons.bug_report_rounded,
  HazardKind.bait => Icons.dangerous_rounded,
  HazardKind.glass => Icons.wine_bar_rounded,
  HazardKind.inspector => Icons.badge_rounded,
  HazardKind.other => Icons.warning_amber_rounded,
};

/// The words of hazard reports.
extension HazardWords on OutdoorsL10n {
  String hazardKind(HazardKind kind) => switch (kind) {
    HazardKind.caterpillars => hazardKindCaterpillars,
    HazardKind.bait => hazardKindBait,
    HazardKind.glass => hazardKindGlass,
    HazardKind.inspector => hazardKindInspector,
    HazardKind.other => hazardKindOther,
  };

  /// A report in a few words: "Caterpillars at Ra'anana Park dog run",
  /// else "Poison bait: by the river path", else "Broken glass in Kfar
  /// Saba".
  String hazardShort(HazardReport report, String language) {
    final kind = hazardKind(report.kind);
    if (report.park case final park?) {
      return hazardAt(kind, parkTitle(park, language));
    }
    final note = report.note.trim();
    if (note.isNotEmpty) return hazardNoted(kind, note);
    final city = localityName(report.localityCode, language);
    return city == null ? kind : hazardIn(kind, city);
  }

  /// Where: the park's name, else "Somewhere in Kfar Saba".
  String hazardPlace(HazardReport report, String language) {
    if (report.park case final park?) return parkTitle(park, language);
    final city = localityName(report.localityCode, language) ?? '';
    return hazardSomewhereIn(city);
  }

  /// "5 h ago", "yesterday", "3 days ago".
  String hazardAge(BuildContext context, DateTime when, DateTime now) {
    final elapsed = now.difference(when);
    if (elapsed.inMinutes < 1) return hazardJustNow;
    if (elapsed.inMinutes < 60) return hazardMinutesAgo(elapsed.inMinutes);
    if (elapsed.inHours < 24) return hazardHoursAgo(elapsed.inHours);
    if (elapsed.inDays == 1) return context.l10n.commonYesterday.toLowerCase();
    return hazardDaysAgo(elapsed.inDays);
  }
}

/// ONE line above the Partners and Parks lists: "2 hazard reports near you
/// this week." and the newest one in a few words, on white with the
/// community disc and a chevron. Nothing when there is none (or no
/// access). A tap opens the list of reports.
class HazardLine extends ConsumerWidget {
  const HazardLine({super.key});

  static const lineKey = Key('outside-hazard-line');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(shownHazardsProvider);
    if (reports.isEmpty) return const SizedBox.shrink();
    final l10n = context.outdoorsL10n;
    final language = languageOf(context);
    final first = l10n.hazardShort(reports.first, language);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: lineKey,
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openHazards(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
              child: Row(
                children: [
                  const AreaDisc(
                    Icons.warning_amber_rounded,
                    area: AppArea.community,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l10n.hazardLineCount(reports.length),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: first,
                            style: const TextStyle(color: AppColors.brown),
                          ),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.secondary.copyWith(color: AppColors.ink),
                    ),
                  ),
                  const Padding(
                      padding: EdgeInsetsDirectional.only(start: 4),
                      child: AppIcon(
                        Icons.chevron_right_rounded,
                        color: AppColors.brown,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
