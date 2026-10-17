import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_widgets.dart';
import '../../../services/pet_records/state/health_issues.dart';
import '../../../theme/app_area.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/area_disc.dart';
import 'issue_page.dart';
import 'issue_widgets.dart';

/// How many open problems the Overview lists before folding the rest.
const overviewIssueRows = 3;

/// The Overview's rows for the open problems of [pet], newest first: up
/// to [overviewIssueRows], then "2 more problems", which [onMore] opens
/// (Records, on the first problem not listed). Empty when nothing is open.
List<Widget> issueOverviewRows(
  BuildContext context,
  Pet pet,
  List<IssueDigest> digests, {
  required ValueChanged<String>? onMore,
}) {
  final open = openIssues(digests);
  final l10n = context.healthL10n;
  final format = HealthFormat.of(context);
  final listed = open.take(overviewIssueRows).toList();
  final rest = open.skip(overviewIssueRows).toList();
  return [
    for (final digest in listed)
      IssueOverviewRow(
        key: ValueKey('overview-issue-${digest.issue.id}'),
        title: digest.issue.title,
        detail: issueOverviewLine(format, digest),
        onTap: () => IssuePage.open(context, pet, digest.issue.id),
      ),
    if (rest.isNotEmpty && onMore != null)
      IssueOverviewRow(
        key: const Key('overview-issues-more'),
        title: l10n.issueMoreProblems(rest.length),
        detail: l10n.issueMoreProblemsNote,
        onTap: () => onMore(rest.first.issue.id),
      ),
  ];
}

/// A row of the Overview's card for a problem: the Health disc, its title,
/// one quieter line, a chevron.
class IssueOverviewRow extends StatelessWidget {
  const IssueOverviewRow({
    super.key,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            const AreaDisc(issueIcon, area: AppArea.health),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TypedText(
                      title,
                      style: AppText.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      detail,
                      style: AppText.secondary.copyWith(
                        color: AppColors.brown,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            const AppIcon(Icons.chevron_right_rounded, color: AppColors.brown),
          ],
        ),
      ),
    );
  }
}
