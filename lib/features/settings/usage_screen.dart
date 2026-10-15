import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../platform/usage.dart';
import '../../platform/usage_summary.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/empty_state.dart';

/// Opens the Usage page (Admin tools), full screen.
Future<void> openUsage(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(builder: (_) => const UsageScreen()));

/// Admin tools > Usage: the last 28 days of usage counts (docs/usage_counts.md).
/// A day per row (active accounts, the share that ticked Today), then each
/// kind of action with its 7-day and 28-day totals. Only permission
/// administrators reach it; the backend refuses everyone else.
class UsageScreen extends ConsumerWidget {
  const UsageScreen({super.key});

  static const screenKey = Key('usage-screen');
  static const daysKey = Key('usage-days');
  static const kindsKey = Key('usage-kinds');

  static Key dayKey(DateTime day) => Key('usage-day-${usageDayKey(day)}');
  static Key kindKey(UsageKind kind) => Key('usage-kind-${kind.key}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(usageSummaryProvider);
    return Scaffold(
      key: screenKey,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: l10n.usageTitle, showBack: true),
          Expanded(
            child: switch (summary) {
              AsyncData(:final value) when value.isEmpty => EmptyState(
                icon: Icons.insights_rounded,
                title: l10n.usageEmptyTitle,
                message: l10n.usageEmptyMessage,
              ),
              AsyncData(:final value) => _UsageBody(summary: value),
              AsyncError() => EmptyState(
                icon: Icons.cloud_off_rounded,
                title: l10n.usageErrorTitle,
                message: l10n.usageErrorMessage,
                actionLabel: l10n.commonTryAgain,
                onAction: () => ref.invalidate(usageSummaryProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

class _UsageBody extends StatelessWidget {
  const _UsageBody({required this.summary});

  final UsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat('dd.MM.yy');
    final percent = NumberFormat.percentPattern(locale);
    final count = NumberFormat.decimalPattern(locale);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        16,
        AppSpacing.screen,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(l10n.usageDaysTitle, style: AppText.sectionTitle),
        const SizedBox(height: 8),
        _TableCard(
          key: UsageScreen.daysKey,
          header: [
            l10n.usageColumnDay,
            l10n.usageColumnActive,
            l10n.usageColumnTicks,
          ],
          rows: [
            for (final day in summary.days)
              _TableRow(
                key: UsageScreen.dayKey(day.day),
                cells: [
                  date.format(day.day),
                  count.format(day.active),
                  day.active == 0 ? '-' : percent.format(day.todayTickShare),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.usageNote, style: AppText.secondary),
        const SizedBox(height: 24),
        Text(l10n.usageKindsTitle, style: AppText.sectionTitle),
        const SizedBox(height: 8),
        _TableCard(
          key: UsageScreen.kindsKey,
          header: [
            l10n.usageKindsTitle,
            l10n.usageColumnWeek,
            l10n.usageColumnMonth,
          ],
          rows: [
            for (final kind in UsageKind.values)
              _TableRow(
                key: UsageScreen.kindKey(kind),
                cells: [
                  usageKindLabel(l10n, kind),
                  count.format(summary.total(kind, 7)),
                  count.format(summary.total(kind, 28)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// A white rounded card with a header line and rows of three cells: the
/// first takes the room left, the numbers line up at the end.
class _TableCard extends StatelessWidget {
  const _TableCard({super.key, required this.header, required this.rows});

  final List<String> header;
  final List<_TableRow> rows;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TableRow(cells: header, header: true),
            const Divider(height: 1, color: AppColors.cream),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({super.key, required this.cells, this.header = false});

  final List<String> cells;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = header
        ? AppText.label.copyWith(color: AppColors.brown)
        : AppText.body.copyWith(color: AppColors.ink);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 3 : 2,
              child: Text(
                cells[i],
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: i == 0 ? TextAlign.start : TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}

/// The name of [kind] on the Usage page.
String usageKindLabel(AppL10n l10n, UsageKind kind) => switch (kind) {
  UsageKind.todayTick => l10n.usageKindTodayTick,
  UsageKind.careLogged => l10n.usageKindCareLogged,
  UsageKind.doseRecorded => l10n.usageKindDoseRecorded,
  UsageKind.recordAdded => l10n.usageKindRecordAdded,
  UsageKind.quickLog => l10n.usageKindQuickLog,
  UsageKind.meetupJoined => l10n.usageKindMeetupJoined,
  UsageKind.meetupPosted => l10n.usageKindMeetupPosted,
  UsageKind.postCreated => l10n.usageKindPostCreated,
  UsageKind.commentCreated => l10n.usageKindCommentCreated,
  UsageKind.chatMessageSent => l10n.usageKindChatMessageSent,
  UsageKind.dealOpened => l10n.usageKindDealOpened,
  UsageKind.dealShared => l10n.usageKindDealShared,
  UsageKind.basketBoughtAgain => l10n.usageKindBasketBoughtAgain,
  UsageKind.expenseAdded => l10n.usageKindExpenseAdded,
  UsageKind.emergencyOpened => l10n.usageKindEmergencyOpened,
  UsageKind.findVetOpened => l10n.usageKindFindVetOpened,
  UsageKind.householdInviteSent => l10n.usageKindHouseholdInviteSent,
  UsageKind.appOpened => l10n.usageKindAppOpened,
};
