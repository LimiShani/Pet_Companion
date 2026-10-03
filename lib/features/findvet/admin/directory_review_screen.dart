import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../health/widgets/health_widgets.dart' show HealthPage, HealthLoading, kHealthTapTarget;
import '../data/vet_admin_repository.dart';
import '../findvet_words.dart';
import '../state/find_vet_providers.dart';

/// Opens the directory review page (admins only; the side menu shows the
/// entry only to them, and the server refuses everyone else anyway).
Future<void> openDirectoryReview(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(builder: (_) => const DirectoryReviewScreen()));

final _reviewItemsProvider = FutureProvider.autoDispose<List<ReviewItem>>(
  (ref) => ref.watch(vetAdminRepositoryProvider).reviewItems(),
  retry: (_, _) => null,
);

final _facilitiesProvider = FutureProvider.autoDispose<List<AdminFacility>>(
  (ref) => ref.watch(vetAdminRepositoryProvider).facilities(),
  retry: (_, _) => null,
);

/// The keys a reviewer can correct, in the order the form offers them.
const _factKeys = ['emergency', 'phone', 'address', 'website', 'species', 'services', 'schedule'];

/// "Directory review": what the weekly check flagged (most severe first)
/// and every facility, with Approve, Mark for review, Withdraw, Withdraw
/// emergency and Correct a fact. Each action asks what was checked; the
/// note goes to the audit trail with the reviewer and the time.
class DirectoryReviewScreen extends ConsumerWidget {
  const DirectoryReviewScreen({super.key});

  static const screenKey = Key('directory-review');
  static Key itemKey(String id) => Key('review-item-$id');
  static Key facilityKey(String id) => Key('review-facility-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.findVetL10n;
    final admin = ref.watch(vetIsAdminProvider);
    if (!admin.hasValue) return HealthPage(key: screenKey, title: l10n.adminTitle, child: const HealthLoading());
    if (admin.value != true) {
      return HealthPage(
        key: screenKey,
        title: l10n.adminTitle,
        child: Padding(padding: const EdgeInsets.only(top: 24), child: Text(l10n.adminNotAllowed, style: AppText.body)),
      );
    }

    final items = ref.watch(_reviewItemsProvider);
    final facilities = ref.watch(_facilitiesProvider);

    return HealthPage(
      key: screenKey,
      title: l10n.adminTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(l10n.adminNeedsAttention),
          items.when(
            loading: () => const HealthLoading(),
            error: (_, _) => _Failed(onRetry: () => ref.invalidate(_reviewItemsProvider)),
            data: (list) => list.isEmpty
                ? Text(l10n.adminNoItems, style: AppText.body.copyWith(color: AppColors.brown))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final item in list) _ItemCard(item: item)],
                  ),
          ),
          const SizedBox(height: 16),
          _Heading(l10n.adminFacilities),
          facilities.when(
            loading: () => const HealthLoading(),
            error: (_, _) => _Failed(onRetry: () => ref.invalidate(_facilitiesProvider)),
            data: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final f in list) _FacilityCard(facility: f)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs an admin action, refreshes both lists and says how it went.
Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function(VetAdminRepository repo) action) async {
  final l10n = context.findVetL10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action(ref.read(vetAdminRepositoryProvider));
    messenger.showSnackBar(SnackBar(content: Text(l10n.adminSaved)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionFailed)));
  }
  ref
    ..invalidate(_reviewItemsProvider)
    ..invalidate(_facilitiesProvider);
}

/// Asks what was checked before an action; `null` when cancelled.
Future<String?> _askNote(BuildContext context, String title) =>
    showDialog<String>(context: context, builder: (_) => _NoteDialog(title: title));

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title});

  final String title;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  // Owned by the dialog, so it outlives the closing animation.
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('review-note'),
        controller: _note,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: context.findVetL10n.adminNoteHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.commonCancel)),
        FilledButton(
          key: const Key('review-note-ok'),
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          child: Text(widget.title),
        ),
      ],
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard({required this.item});

  final ReviewItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.findVetL10n;
    final severe = item.severity == 'high';
    Future<void> close(String action, String label) async {
      final note = await _askNote(context, label);
      if (note == null || !context.mounted) return;
      await _act(context, ref, (repo) => repo.resolve(item.id, action, note));
    }

    // A heuristic match the search found: the listing's place id and the
    // facility it looked like. Linking closes the item on the server.
    final candidatePlace = item.details['placeId'];
    final canLink = item.kind == 'link_candidate' && item.facilityId != null && candidatePlace is String;

    return _Box(
      key: DirectoryReviewScreen.itemKey(item.id),
      border: severe ? AppColors.coralDark : null,
      children: [
        Text(l10n.reviewKind(item.kind), style: AppText.cardTitle.copyWith(fontSize: 16)),
        Text(
          '${l10n.severity(item.severity)} · ${item.facilityName ?? ''} · ${AppFormat.of(context).date(item.createdAt.toLocal())}',
          style: AppText.secondary.copyWith(color: AppColors.brown),
        ),
        if (item.details.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              item.details.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
              textDirection: TextDirection.ltr,
              style: AppText.secondary.copyWith(color: AppColors.ink),
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            if (canLink)
              FilledButton.icon(
                key: Key('review-link-${item.id}'),
                onPressed: () => _act(context, ref, (repo) => repo.linkPlace(item.facilityId!, candidatePlace)),
                icon: const AppIcon(Icons.link_rounded, size: 18),
                label: Text(l10n.adminLink),
              ),
            TextButton(
              key: Key('review-resolve-${item.id}'),
              onPressed: () => close('resolve', l10n.adminResolve),
              child: Text(l10n.adminResolve),
            ),
            TextButton(
              key: Key('review-dismiss-${item.id}'),
              onPressed: () => close('dismiss', l10n.adminDismiss),
              child: Text(l10n.adminDismiss),
            ),
          ],
        ),
      ],
    );
  }
}

class _FacilityCard extends ConsumerWidget {
  const _FacilityCard({required this.facility});

  final AdminFacility facility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.findVetL10n;
    final f = facility;
    final format = AppFormat.of(context);
    final emergency = f.claim('emergency');

    Future<void> status(String status, String label) async {
      final note = await _askNote(context, label);
      if (note == null || !context.mounted) return;
      await _act(context, ref, (repo) => repo.setStatus(f.id, status, note));
    }

    Future<void> withdrawEmergency() async {
      final note = await _askNote(context, l10n.adminWithdrawEmergency);
      if (note == null || !context.mounted) return;
      await _act(context, ref, (repo) => repo.withdrawClaim(f.id, 'emergency', note));
    }

    Future<void> correct() async {
      final fact = await showDialog<_Correction>(context: context, builder: (_) => const _CorrectDialog());
      if (fact == null || !context.mounted) return;
      await _act(
        context,
        ref,
        (repo) => repo.setClaim(
          f.id,
          key: fact.key,
          value: fact.value,
          sourceUrl: fact.sourceUrl,
          sourceKind: 'manual',
          note: fact.note,
        ),
      );
    }

    return _Box(
      key: DirectoryReviewScreen.facilityKey(f.id),
      children: [
        Text(f.nameHe == null ? f.name : '${f.name} · ${f.nameHe}', style: AppText.cardTitle.copyWith(fontSize: 16)),
        Text(
          [
            l10n.reviewStatus(f.reviewStatus),
            f.lastCheckedAt == null ? l10n.adminNeverChecked : l10n.adminLastChecked(format.date(f.lastCheckedAt!.toLocal())),
          ].join(' · '),
          style: AppText.secondary.copyWith(color: AppColors.brown, fontWeight: FontWeight.w700),
        ),
        if (f.address != null || f.phone != null)
          Text(
            [?f.address, ?f.city, ?f.phone].join(' · '),
            style: AppText.secondary.copyWith(color: AppColors.ink),
          ),
        const SizedBox(height: 6),
        for (final claim in f.claims)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${l10n.factKey(claim.key)}: ${claim.valueText} (${l10n.claimStatus(claim.status)})'
              '${claim.sourceUrl == null ? '' : '\n${claim.sourceUrl}'}'
              '${claim.checkedAt == null ? '' : ' · ${format.date(claim.checkedAt!.toLocal())}'}',
              style: AppText.secondary.copyWith(color: AppColors.ink),
            ),
          ),
        Wrap(
          spacing: 4,
          children: [
            if (f.reviewStatus != 'approved')
              TextButton(
                key: Key('review-approve-${f.id}'),
                onPressed: () => status('approved', l10n.adminApprove),
                child: Text(l10n.adminApprove),
              ),
            if (f.reviewStatus == 'approved')
              TextButton(
                key: Key('review-mark-${f.id}'),
                onPressed: () => status('needs_review', l10n.adminMarkReview),
                child: Text(l10n.adminMarkReview),
              ),
            TextButton(
              key: Key('review-correct-${f.id}'),
              onPressed: correct,
              child: Text(l10n.adminCorrect),
            ),
            if (emergency != null && emergency.status != 'withdrawn')
              TextButton(
                key: Key('review-withdraw-emergency-${f.id}'),
                onPressed: withdrawEmergency,
                child: Text(l10n.adminWithdrawEmergency),
              ),
            if (f.reviewStatus != 'withdrawn')
              TextButton(
                key: Key('review-withdraw-${f.id}'),
                onPressed: () => status('withdrawn', l10n.adminWithdraw),
                style: TextButton.styleFrom(foregroundColor: AppColors.coralDark),
                child: Text(l10n.adminWithdraw),
              ),
          ],
        ),
      ],
    );
  }
}

class _Correction {
  const _Correction(this.key, this.value, this.sourceUrl, this.note);

  final String key;
  final Object value;
  final String sourceUrl;
  final String note;
}

/// Correct one fact, always with the link it was read on.
class _CorrectDialog extends StatefulWidget {
  const _CorrectDialog();

  @override
  State<_CorrectDialog> createState() => _CorrectDialogState();
}

class _CorrectDialogState extends State<_CorrectDialog> {
  final _form = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _source = TextEditingController();
  final _note = TextEditingController();
  String _key = _factKeys.first;

  @override
  void dispose() {
    for (final c in [_value, _source, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Object _parsedValue() {
    final text = _value.text.trim();
    return switch (_key) {
      'species' || 'services' => [
        for (final part in text.split(','))
          if (part.trim().isNotEmpty) part.trim().toLowerCase(),
      ],
      'emergency' => {'schedule': text},
      _ => text,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.findVetL10n;
    return AlertDialog(
      title: Text(l10n.adminCorrect),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('review-fact-key'),
                initialValue: _key,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.adminFact),
                items: [for (final key in _factKeys) DropdownMenuItem(
                    value: key,
                    child: Text(l10n.factKey(key), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),],
                onChanged: (key) => setState(() => _key = key ?? _key),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('review-fact-value'),
                controller: _value,
                decoration: InputDecoration(labelText: l10n.adminValue, helperText: l10n.adminValueHint),
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.adminValueRequired : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('review-fact-source'),
                controller: _source,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l10n.adminSourceUrl),
                validator: (v) {
                  final uri = Uri.tryParse((v ?? '').trim());
                  return uri != null && uri.isScheme('https') && uri.host.isNotEmpty ? null : l10n.adminSourceRequired;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('review-fact-note'),
                controller: _note,
                decoration: InputDecoration(labelText: l10n.adminNoteHint),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.commonCancel)),
        FilledButton(
          key: const Key('review-fact-save'),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.of(context).pop(_Correction(_key, _parsedValue(), _source.text.trim(), _note.text.trim()));
          },
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Semantics(header: true, child: Text(text, style: AppText.cardTitle.copyWith(fontSize: 18))),
  );
}

class _Box extends StatelessWidget {
  const _Box({super.key, required this.children, this.border});

  final List<Widget> children;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      border: border == null ? null : Border.all(color: border!, width: 2),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(context.findVetL10n.adminLoadFailed, style: AppText.body)),
      IconButton(
        onPressed: onRetry,
        constraints: const BoxConstraints(minWidth: kHealthTapTarget, minHeight: kHealthTapTarget),
        icon: const AppIcon(Icons.refresh_rounded),
        tooltip: context.findVetL10n.tryAgain,
      ),
    ],
  );
}
