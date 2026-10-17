import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../presentation/health_format.dart';
import '../../../presentation/health_widgets.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/data/issue_models.dart';
import '../../../services/pet_records/state/health_issues.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import 'issue_page.dart';

/// The Health "+" row "Follow a problem": the sheet, then the new
/// problem's page with the Quick log open on it, so the first entry is one
/// tap away.
Future<void> startFollowingProblem(BuildContext context, Pet pet) async {
  final saved = await showHealthSheet<HealthIssue>(
    context,
    FollowProblemSheet(pet: pet),
  );
  if (saved == null || !context.mounted) return;
  await IssuePage.open(context, pet, saved.id, openQuickLog: true);
}

/// Changes a problem's title, start day and body area (the same sheet).
Future<void> renameProblem(BuildContext context, Pet pet, HealthIssue issue) =>
    showHealthSheet<HealthIssue>(
      context,
      FollowProblemSheet(pet: pet, issue: issue),
    );

/// Start following a problem ([issue] is `null`), or change one: what it
/// is (required), when it started (today unless changed, never a future
/// day) and, optionally, where on the body. Pops with the stored problem.
class FollowProblemSheet extends ConsumerStatefulWidget {
  const FollowProblemSheet({super.key, required this.pet, this.issue});

  final Pet pet;
  final HealthIssue? issue;

  @override
  ConsumerState<FollowProblemSheet> createState() => _FollowProblemSheetState();
}

class _FollowProblemSheetState extends ConsumerState<FollowProblemSheet> {
  final _title = TextEditingController();
  final _area = TextEditingController();
  late DateTime _started;
  bool _busy = false;
  Object? _error;

  bool get _editing => widget.issue != null;

  @override
  void initState() {
    super.initState();
    final issue = widget.issue;
    _started = issue?.startedOn ?? dateOnly(ref.read(healthClockProvider)());
    _title.text = issue?.title ?? '';
    _area.text = issue?.bodyArea ?? '';
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _area.dispose();
    super.dispose();
  }

  bool get _ready => _title.text.trim().isNotEmpty;

  Future<void> _pickStart() async {
    final now = ref.read(healthClockProvider)();
    final day = await showDatePicker(
      context: context,
      initialDate: _started,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      currentDate: now,
      helpText: context.healthL10n.issueStartedOn,
    );
    if (day != null && mounted) setState(() => _started = dateOnly(day));
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final old = widget.issue;
    final issue = old == null
        ? HealthIssue(
            id: '',
            petId: widget.pet.id,
            title: _title.text.trim(),
            bodyArea: _area.text.trim(),
            startedOn: _started,
          )
        : old.copyWith(
            title: _title.text.trim(),
            bodyArea: _area.text.trim(),
            startedOn: _started,
          );
    try {
      final saved = await ref
          .read(healthIssuesProvider(widget.pet.id).notifier)
          .save(issue);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'health.records.edit',
    hidden: false,
    builder: (context) => _buildAuthorized(context),
  );

  Widget _buildAuthorized(BuildContext context) {
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final now = ref.watch(healthClockProvider)();
    // Kept loaded while the sheet is open, so saving lands in the list.
    ref.watch(healthIssuesProvider(widget.pet.id));
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(
          _editing ? l10n.issueRenameTitle : l10n.addFollowProblem,
          subtitle: _editing ? null : l10n.issueSheetNote,
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('issue-title'),
          controller: _title,
          autofocus: !_editing,
          maxLength: HealthIssue.maxTitleLength,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.issueFieldTitle,
            hintText: l10n.issueFieldTitleHint,
            // Whole on a small phone.
            hintMaxLines: 2,
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        PickerTile(
          key: const Key('issue-started'),
          icon: Icons.event_rounded,
          label: l10n.issueStartedOn,
          value: format.relativeDay(_started, now),
          onTap: _pickStart,
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('issue-area'),
          controller: _area,
          maxLength: HealthIssue.maxBodyAreaLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.issueFieldBodyArea,
            hintText: l10n.issueFieldBodyAreaHint,
            // Whole on a small phone.
            hintMaxLines: 2,
            counterText: '',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            format.error(error),
            style: AppText.body.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          key: const Key('issue-save'),
          label: _editing ? l10n.saveChanges : l10n.issueStart,
          loading: _busy,
          onPressed: _ready ? _save : null,
        ),
        const SizedBox(height: 10),
        FinePrint(l10n.issueFinePrint),
      ],
    );
  }
}
