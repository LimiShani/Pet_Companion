import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/feature_ui.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'area_disc.dart';

/// Opens [tab]'s Add sheet (titled [title]) and, once a row is chosen and
/// the sheet has closed, opens what the row adds for [petId]. Nothing
/// happens when the account may use no row.
Future<void> showAddSheet(
  BuildContext context, {
  required String tab,
  required String title,
  required String petId,
}) async {
  final entries = readAddEntries(context, tab);
  if (entries.isEmpty) return;
  final chosen = await showModalBottomSheet<AddEntry>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => AddSheet(
      title: title,
      entries: entries,
      onPick: (entry) => Navigator.of(sheet).pop(entry),
    ),
  );
  if (chosen == null || !context.mounted) return;
  await chosen.open(context, FeatureRequest(petId));
}

/// The one floating "+" of a tab: 56 px, round, coral dark with a white
/// plus. It opens the tab's Add sheet ([showAddSheet]); a screen reader
/// hears [title] ("Add to Health"). Draws nothing when the account may use
/// no row of [tab] (check with [AddFab.available] to leave room for it).
class AddFab extends ConsumerWidget {
  const AddFab({
    super.key = fabKey,
    required this.tab,
    required this.title,
    required this.petId,
  });

  static const fabKey = Key('add-fab');

  final String tab;
  final String title;
  final String petId;

  /// Whether [tab] has a row the account may use, so the "+" shows.
  static bool available(WidgetRef ref, String tab) =>
      addEntriesFor(ref, tab).isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!available(ref, tab)) return const SizedBox.shrink();
    return FloatingActionButton(
      heroTag: null,
      tooltip: title,
      shape: const CircleBorder(),
      backgroundColor: AppColors.coralDark,
      foregroundColor: AppColors.white,
      onPressed: () =>
          showAddSheet(context, tab: tab, title: title, petId: petId),
      child: const AppIcon(Icons.add_rounded, size: 28),
    );
  }
}

/// The sheet behind a tab's "+": its title, then one row per thing to add
/// (an area disc, a label, maybe one quieter line).
class AddSheet extends StatelessWidget {
  const AddSheet({
    super.key = sheetKey,
    required this.title,
    required this.entries,
    required this.onPick,
  });

  static const sheetKey = Key('add-sheet');

  /// The key of the row of the entry named [id].
  static Key rowKey(String id) => ValueKey('add-$id');

  final String title;
  final List<AddEntry> entries;
  final ValueChanged<AddEntry> onPick;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          16 + math.max(media.viewInsets.bottom, media.viewPadding.bottom),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: AppText.heading),
            ),
            const SizedBox(height: 8),
            for (final entry in entries)
              _AddRow(entry: entry, onTap: () => onPick(entry)),
          ],
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.entry, required this.onTap});

  final AddEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = entry.subtitle?.call(context);
    return InkWell(
      key: AddSheet.rowKey(entry.id),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              AreaDisc(entry.icon, area: entry.area),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.label(context),
                      style: AppText.rowTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: AppText.secondary.copyWith(
                          color: AppColors.brown,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
