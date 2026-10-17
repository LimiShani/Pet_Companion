import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_strings.dart';
import '../../../presentation/health_widgets.dart';
import '../../../services/pet_records/data/species_settings.dart';
import '../../../services/pet_records/state/health_issues.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/empty_state.dart';
import '../insights/quick_log_sheet.dart';
import '../share/issue_share.dart';
import 'follow_problem_sheet.dart';
import 'issue_widgets.dart';

/// One followed problem: how long it has gone on, its entries (newest
/// first, with their photos), "Add an entry", "Mark as resolved" or "Open
/// again", the PDF report, and in "More": rename and stop following.
class IssuePage extends ConsumerStatefulWidget {
  const IssuePage({
    super.key,
    required this.pet,
    required this.issueId,
    this.openQuickLog = false,
  });

  final Pet pet;
  final String issueId;

  /// Opens the Quick log on this problem once the page shows (a problem
  /// that was just started).
  final bool openQuickLog;

  static Future<void> open(
    BuildContext context,
    Pet pet,
    String issueId, {
    bool openQuickLog = false,
  }) => pushHealthPage<void>(
    context,
    IssuePage(pet: pet, issueId: issueId, openQuickLog: openQuickLog),
  );

  @override
  ConsumerState<IssuePage> createState() => _IssuePageState();
}

class _IssuePageState extends ConsumerState<IssuePage> {
  @override
  void initState() {
    super.initState();
    if (widget.openQuickLog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addEntry();
      });
    }
  }

  Pet get _pet => widget.pet;

  void _addEntry() => showQuickLog(context, _pet, issueId: widget.issueId);

  Future<void> _setResolved(IssueDigest digest, bool resolved) async {
    final issues = ref.read(healthIssuesProvider(_pet.id).notifier);
    try {
      if (resolved) {
        await issues.resolve(digest.issue);
        if (mounted) {
          showHealthSnack(context, context.healthL10n.issueResolvedDone);
        }
      } else {
        await issues.reopen(digest.issue);
      }
    } catch (error) {
      if (mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  Future<void> _stopFollowing(IssueDigest digest) async {
    final l10n = context.healthL10n;
    final confirmed = await confirmDelete(
      context,
      title: l10n.issueStopTitle,
      message: l10n.issueStopMessage(digest.entries.length),
      confirmLabel: l10n.issueStop,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(healthIssuesProvider(_pet.id).notifier)
          .delete(digest.issue);
      navigator.pop();
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.issueStopped)));
    } catch (error) {
      if (mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  Future<void> _more(IssueDigest digest) async {
    final l10n = context.healthL10n;
    final choice = await showHealthSheet<int>(
      context,
      Builder(
        builder: (sheet) {
          Widget option(int value, IconData icon, String label, Key key) =>
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: HealthCard(
                  key: key,
                  onTap: () => Navigator.of(sheet).pop(value),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      IconDisc(icon),
                      const SizedBox(width: 12),
                      Expanded(child: Text(label, style: AppText.cardTitle)),
                    ],
                  ),
                ),
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetTitle(digest.issue.title),
              const SizedBox(height: 12),
              option(
                0,
                Icons.edit_rounded,
                l10n.issueRename,
                const Key('issue-rename'),
              ),
              option(
                1,
                Icons.delete_outline_rounded,
                l10n.issueStop,
                const Key('issue-stop'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted) return;
    if (choice == 0) await renameProblem(context, _pet, digest.issue);
    if (choice == 1) await _stopFollowing(digest);
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'health.records.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.healthL10n;
    final digests = ref.watch(issueDigestsProvider(_pet.id));
    final value = digests.value;
    IssueDigest? digest;
    for (final d in value ?? const <IssueDigest>[]) {
      if (d.issue.id == widget.issueId) digest = d;
    }
    final canEdit = ref.watch(capabilityProvider('health.records.edit'));
    final canShare = ref.watch(capabilityProvider('health.records.export'));

    final Widget body;
    // A failed reload says so too, rather than showing what may be stale.
    if (value == null || (digests.hasError && !digests.isLoading)) {
      body = digests.hasError
          ? HealthLoadError(
              title: l10n.loadFailedIssue,
              error: digests.error!,
              onRetry: () {
                ref.invalidate(healthIssuesProvider(_pet.id));
                ref.invalidate(observationsProvider(_pet.id));
                ref.invalidate(entryPhotosProvider(_pet.id));
              },
            )
          : const HealthLoading();
    } else if (digest == null) {
      body = EmptyState(
        icon: issueIcon,
        title: l10n.issueGone,
        message: l10n.issueStopped,
      );
    } else {
      body = _IssueBody(
        pet: _pet,
        digest: digest,
        canEdit: canEdit,
        onAddEntry: _addEntry,
        onResolved: (resolved) => _setResolved(digest!, resolved),
      );
    }

    final shown = digests.hasError ? null : digest;
    return HealthPage(
      petId: _pet.id,
      title: shown?.issue.title ?? l10n.addFollowProblem,
      actions: [
        if (shown != null && canShare)
          CoralHeaderAction(
            key: const Key('issue-share'),
            icon: Icons.ios_share_rounded,
            tooltip: l10n.issueShare,
            onPressed: () => shareIssuePdf(context, _pet, shown),
          ),
        if (shown != null && canEdit)
          CoralHeaderAction(
            key: const Key('issue-more'),
            icon: Icons.more_vert_rounded,
            tooltip: l10n.issueMore,
            onPressed: () => _more(shown),
          ),
      ],
      child: body,
    );
  }
}

class _IssueBody extends ConsumerWidget {
  const _IssueBody({
    required this.pet,
    required this.digest,
    required this.canEdit,
    required this.onAddEntry,
    required this.onResolved,
  });

  final Pet pet;
  final IssueDigest digest;
  final bool canEdit;
  final VoidCallback onAddEntry;
  final ValueChanged<bool> onResolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final today = ref.watch(currentDayProvider);
    final issue = digest.issue;
    final settings = SpeciesSettings.of(pet.species);
    final entries = digest.entries.reversed.toList();
    final open = issue.isOpen;
    final area = issue.bodyArea.trim();

    final addEntry = open
        ? FilledButton.icon(
            key: const Key('issue-add-entry'),
            onPressed: onAddEntry,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.add_rounded),
            label: Text(l10n.issueAddEntry),
          )
        : OutlinedButton.icon(
            key: const Key('issue-add-entry'),
            onPressed: onAddEntry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(kHealthTapTarget),
            ),
            icon: const AppIcon(Icons.add_rounded),
            label: Text(l10n.issueAddEntry),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        HealthCard(
          key: const Key('issue-summary'),
          color: open ? AppColors.peach : AppColors.sage,
          radius: 28,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusTag(open ? l10n.issueOngoing : l10n.issueResolved),
              const SizedBox(height: 8),
              Text(
                issueSpanLine(format, issue, today),
                style: AppText.cardTitle,
              ),
              TypedText(
                format.dots([
                  if (area.isNotEmpty) format.typed(area),
                  pet.name,
                  issueCounts(format, digest),
                ]),
                style: AppText.secondary.copyWith(color: AppColors.ink),
              ),
            ],
          ),
        ),
        if (canEdit) ...[const SizedBox(height: 14), addEntry],
        const SizedBox(height: 16),
        HealthSectionTitle(
          l10n.issueEntries,
          count: entries.isEmpty ? null : entries.length,
        ),
        if (entries.isEmpty)
          EmptyState(
            icon: Icons.edit_note_rounded,
            title: l10n.issueNoEntries,
            message: l10n.issueNoEntriesNote,
          )
        else
          for (final entry in entries) ...[
            IssueEntryCard(
              entry: entry,
              photos: digest.photosOf(entry.id),
              settings: settings,
              onTap: () => showQuickLog(context, pet, observation: entry),
            ),
            const SizedBox(height: 8),
          ],
        if (canEdit) ...[
          const SizedBox(height: 8),
          if (open)
            OutlinedButton.icon(
              key: const Key('issue-resolve'),
              onPressed: () => onResolved(true),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(kHealthTapTarget),
              ),
              icon: const AppIcon(Icons.check_rounded),
              label: Text(l10n.issueResolve),
            )
          else
            Center(
              child: HealthLink(
                l10n.issueReopen,
                key: const Key('issue-reopen'),
                onPressed: () => onResolved(false),
              ),
            ),
        ],
        const SizedBox(height: 12),
        FinePrint(l10n.quickLogFinePrint),
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: const BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.all(Radius.circular(999)),
    ),
    child: Text(
      label,
      key: const Key('issue-status'),
      style: AppText.label.copyWith(color: AppColors.ink),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
