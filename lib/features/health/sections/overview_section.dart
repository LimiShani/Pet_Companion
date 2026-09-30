import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/health_models.dart';
import '../data/species_settings.dart';
import '../emergency/contact_actions.dart';
import '../emergency/health_profile_form.dart';
import '../emergency/vet_picker.dart';
import '../emergency/vets_screen.dart';
import '../health_format.dart';
import '../state/health_providers.dart';
import '../state/schedule_logic.dart';
import '../widgets/health_widgets.dart';
import '../widgets/weight_trend.dart';

/// What the Overview's buttons do. The tab wires them to the record form,
/// the Quick log and so on, so this section stays a plain view.
class OverviewActions {
  const OverviewActions({
    this.onQuickLog,
    this.onAddRecord,
    this.onShare,
    this.onAddDocument,
    this.onAddAppointment,
    this.onAddMedicine,
    this.onRecordDose,
    this.onOpenRecord,
    this.onOpenMedicine,
  });

  final VoidCallback? onQuickLog;
  final VoidCallback? onAddRecord;
  final VoidCallback? onShare;
  final VoidCallback? onAddDocument;
  final VoidCallback? onAddAppointment;
  final VoidCallback? onAddMedicine;
  final void Function(ScheduleEntry entry)? onRecordDose;
  final void Function(HealthRecord record)? onOpenRecord;
  final void Function(Medication medication)? onOpenMedicine;
}

/// What needs attention now: the next action first, then quick actions,
/// the vet, and the latest facts. A block with nothing in it is not shown,
/// and there is no overall "health score".
class OverviewSection extends ConsumerWidget {
  const OverviewSection({
    super.key,
    required this.pet,
    required this.data,
    this.actions = const OverviewActions(),
    this.reminder,
  });

  final Pet pet;
  final PetHealthData data;
  final OverviewActions actions;

  /// Shown right under the pet summary: the slot for the Pets feature's
  /// "essentials missing" reminder card.
  final Widget? reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(healthClockProvider)();
    void show(HealthSection section) => ref.read(healthSectionProvider.notifier).show(section);

    final today = entriesOn(data.plan, now);
    final open = [
      for (final e in today)
        if (!e.isAnswered) e,
    ];
    // The next thing still ahead today, else the earliest one still open.
    ScheduleEntry? nextEntry;
    for (final e in open) {
      if (!e.due.isBefore(now)) {
        nextEntry = e;
        break;
      }
    }
    nextEntry ??= open.isEmpty ? null : open.first;
    final upcoming = upcomingRecords(data.records, now);
    final nextRecord = upcoming.isEmpty ? null : upcoming.first;
    final review = entriesNeedingReview(data.plan, now).length + recordsNeedingReview(data.records, now).length;
    final nothingDue = nextEntry == null && nextRecord == null && review == 0;

    final history = historyRecords(data.records);
    final weights = weightEntries(data.observations);
    DateTime? lastRecord = history.isEmpty ? null : history.first.when;
    for (final o in data.observations) {
      if (lastRecord == null || o.observedAt.isAfter(lastRecord)) lastRecord = o.observedAt;
    }
    final medicines = data.plan.activeMedications(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PetSummary(
          pet: pet,
          status: nothingDue
              ? 'No scheduled care due'
              : lastRecord == null
              ? null
              : 'Last record ${formatDate(lastRecord)}',
        ),
        if (reminder != null) ...[const SizedBox(height: AppSpacing.cardGap), reminder!],
        if (!nothingDue) ...[
          const SizedBox(height: AppSpacing.cardGap),
          _ComingUp(
            now: now,
            entry: nextEntry,
            record: nextRecord,
            reviewCount: review,
            actions: actions,
            onSchedule: () => show(HealthSection.schedule),
          ),
        ],
        if (data.isEmpty) ...[const SizedBox(height: 8), _GettingStarted(pet: pet, actions: actions)],
        const SizedBox(height: AppSpacing.cardGap),
        _QuickActions(actions: actions),
        const SizedBox(height: AppSpacing.cardGap),
        _VetCard(pet: pet, vets: data.vets),
        if (medicines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.cardGap),
          _MedicinesCard(medicines: medicines, plan: data.plan, now: now, actions: actions),
        ],
        if (weights.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.cardGap),
          _WeightCard(
            weights: weights,
            grams: SpeciesSettings.of(pet.species).weightInGrams,
            onInsights: () => show(HealthSection.insights),
          ),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.cardGap),
          _RecordsCard(
            history: history,
            // The same records the History's "Documents" filter shows.
            documents: history.where((r) => r.kind == RecordKind.document || data.documentsOf(r.id).isNotEmpty).length,
            onKind: (kind) {
              ref.read(historyFilterProvider.notifier).showKind(kind);
              show(HealthSection.history);
            },
            onDocuments: () {
              ref.read(historyFilterProvider.notifier).showDocuments();
              show(HealthSection.history);
            },
          ),
        ],
      ],
    );
  }
}

class _PetSummary extends StatelessWidget {
  const _PetSummary({required this.pet, required this.status});

  final Pet pet;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      key: const Key('overview-pet'),
      onTap: () => HealthProfileScreen.open(context, pet),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 8, top: 12, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.coral, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: pet.photoAsset != null
                ? Image.asset(pet.photoAsset!, fit: BoxFit.cover, excludeFromSemantics: true)
                : const Icon(Icons.pets_rounded, color: AppColors.brown),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: AppText.cardTitle.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(petLine(pet), style: AppText.secondary.copyWith(color: AppColors.brown)),
                if (status != null) Text(status!, style: AppText.secondary.copyWith(color: AppColors.brown)),
                Text(
                  'Health profile',
                  style: AppText.secondary.copyWith(color: AppColors.coralDark, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
        ],
      ),
    );
  }
}

class _ComingUp extends StatelessWidget {
  const _ComingUp({
    required this.now,
    required this.entry,
    required this.record,
    required this.reviewCount,
    required this.actions,
    required this.onSchedule,
  });

  final DateTime now;
  final ScheduleEntry? entry;
  final HealthRecord? record;
  final int reviewCount;
  final OverviewActions actions;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final divider = Divider(height: 16, thickness: 1, color: AppColors.white.withValues(alpha: 0.55));
    final e = entry;
    final r = record;
    final rows = <Widget>[
      if (e != null)
        _ComingUpRow(
          icon: careKindIcon(e.item.kind),
          title: e.item.title,
          detail: 'Today · ${formatTimeOfDay(e.item.time)}',
          trailing: e.item.isMedication && actions.onRecordDose != null
              ? FilledButton(
                  key: const Key('overview-record-dose'),
                  onPressed: () => actions.onRecordDose!(e),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Record'),
                )
              : null,
          onTap: onSchedule,
        ),
      if (r != null)
        _ComingUpRow(
          icon: recordKindIcon(r.kind),
          title: r.title,
          detail: [
            '${formatRelativeDay(r.scheduledAt, now)} · ${formatTime(r.scheduledAt)}',
            if (r.clinic.isNotEmpty) r.clinic,
          ].join(' · '),
          onTap: actions.onOpenRecord == null ? onSchedule : () => actions.onOpenRecord!(r),
        ),
      if (reviewCount > 0)
        InkWell(
          key: const Key('overview-needs-review'),
          onTap: onSchedule,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    reviewCount == 1 ? '1 reminder needs review' : '$reviewCount reminders need review',
                    style: AppText.secondary,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.ink),
              ],
            ),
          ),
        ),
    ];

    return HealthCard(
      key: const Key('overview-coming-up'),
      color: AppColors.peach,
      radius: AppSpacing.cardRadius,
      padding: const EdgeInsetsDirectional.only(start: 16, end: 12, top: 8, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Coming up', style: AppText.cardTitle.copyWith(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              HealthLink('Schedule', onPressed: onSchedule, color: AppColors.ink),
            ],
          ),
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) divider, rows[i]],
        ],
      ),
    );
  }
}

class _ComingUpRow extends StatelessWidget {
  const _ComingUpRow({required this.icon, required this.title, required this.detail, this.trailing, this.onTap});

  final IconData icon;
  final String title;
  final String detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kHealthTapTarget),
        child: Row(
          children: [
            IconDisc(icon, color: AppColors.white.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(detail, style: AppText.secondary),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});

  final OverviewActions actions;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      if (actions.onQuickLog != null)
        _QuickAction(
          key: const Key('overview-quick-log'),
          icon: Icons.add_rounded,
          label: 'Quick log',
          primary: true,
          onTap: actions.onQuickLog!,
        ),
      if (actions.onAddRecord != null)
        _QuickAction(
          key: const Key('overview-add-record'),
          icon: Icons.note_add_rounded,
          label: 'Add record',
          onTap: actions.onAddRecord!,
        ),
      if (actions.onShare != null)
        _QuickAction(
          key: const Key('overview-share'),
          icon: Icons.ios_share_rounded,
          label: 'Share',
          onTap: actions.onShare!,
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: buttons[i])],
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({super.key, required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? AppColors.white : AppColors.ink;
    return Semantics(
      button: true,
      child: Material(
        color: primary ? AppColors.coralDark : AppColors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fg, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.secondary.copyWith(color: fg, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VetCard extends StatelessWidget {
  const _VetCard({required this.pet, required this.vets});

  final Pet pet;
  final PetVets vets;

  @override
  Widget build(BuildContext context) {
    final vet = vets.regular ?? vets.emergency;
    if (vet == null) {
      return HealthPromptCard(
        key: const Key('overview-add-vet'),
        icon: Icons.add_call,
        title: "Add ${pet.name}'s vet",
        message: 'Phone and address, ready for an emergency',
        onTap: () => showVetPicker(context, petId: pet.id),
      );
    }
    final detail = [if (vet.hasAddress) vet.address, if (vet.hasPhone) vet.phone].join(' · ');
    return HealthCard(
      key: const Key('overview-vet'),
      padding: const EdgeInsetsDirectional.only(start: 16, end: 12, top: 6, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Vet', style: AppText.cardTitle)),
              HealthLink('Details', onPressed: () => VetsScreen.open(context, pet)),
            ],
          ),
          Row(
            children: [
              const IconDisc(Icons.medical_services_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vet.name, style: AppText.cardTitle),
                    if (detail.isNotEmpty) Text(detail, style: AppText.secondary.copyWith(color: AppColors.brown)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ContactActionButtons(
            petId: pet.id,
            tag: 'overview',
            name: vet.name,
            phone: vet.hasPhone ? vet.phone : null,
            onWhatsApp: vet.onWhatsApp,
            address: vet.hasAddress ? vet.address : null,
            onAddPhone: () => VetsScreen.open(context, pet),
          ),
        ],
      ),
    );
  }
}

class _MedicinesCard extends StatelessWidget {
  const _MedicinesCard({required this.medicines, required this.plan, required this.now, required this.actions});

  final List<Medication> medicines;
  final CarePlan plan;
  final DateTime now;
  final OverviewActions actions;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      key: const Key('overview-medicines'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Medicines', style: AppText.cardTitle)),
              HealthTag('${medicines.length} active', highlight: true),
            ],
          ),
          for (final m in medicines)
            InkWell(
              onTap: actions.onOpenMedicine == null ? null : () => actions.onOpenMedicine!(m),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconDisc(Icons.medication_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.displayName, style: AppText.cardTitle),
                          if (m.instructionLine.isNotEmpty)
                            Text(m.instructionLine, style: AppText.secondary.copyWith(color: AppColors.brown)),
                          Text(_lastDose(m), style: AppText.secondary.copyWith(color: AppColors.brown)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _lastDose(Medication m) {
    final at = plan.lastDose(m.id)?.doneAt;
    if (at == null) return 'No dose recorded yet';
    return 'Last recorded dose: ${formatRelativeDay(at, now).toLowerCase()} ${formatTime(at)}';
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.weights, required this.grams, required this.onInsights});

  final List<Observation> weights;
  final bool grams;
  final VoidCallback onInsights;

  @override
  Widget build(BuildContext context) {
    final latest = weights.last;
    final previous = weights.length > 1 ? weights[weights.length - 2] : null;
    final detail = previous == null
        ? formatDate(latest.observedAt)
        : '${formatDate(latest.observedAt)} · '
              '${formatWeightChange(previous.value!, latest.value!, grams: grams)} since ${formatDate(previous.observedAt)}';
    final shown = formatWeight(latest.value!, grams: grams).split(' ');

    return HealthCard(
      key: const Key('overview-weight'),
      padding: const EdgeInsetsDirectional.only(start: 16, end: 12, top: 6, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Weight', style: AppText.cardTitle)),
              HealthLink('Insights', onPressed: onInsights),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: shown.first,
                        style: AppText.metric,
                        children: [
                          TextSpan(
                            text: ' ${shown.last}',
                            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Text(detail, style: AppText.secondary.copyWith(color: AppColors.brown)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: WeightTrendChart(
                  points: [for (final w in weights) TrendPoint(w.observedAt, w.value!)],
                  height: 56,
                  showGuides: false,
                  semanticsLabel: 'Small weight chart',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.history, required this.documents, required this.onKind, required this.onDocuments});

  final List<HealthRecord> history;
  final int documents;
  final void Function(RecordKind kind) onKind;
  final VoidCallback onDocuments;

  @override
  Widget build(BuildContext context) {
    int count(RecordKind kind) => history.where((r) => r.kind == kind).length;
    return HealthCard(
      key: const Key('overview-records'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Medical records', style: AppText.cardTitle),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CountTile(
                  count: count(RecordKind.vaccination),
                  label: 'Vaccinations',
                  onTap: () => onKind(RecordKind.vaccination),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CountTile(
                  count: count(RecordKind.checkup),
                  label: 'Vet visits',
                  onTap: () => onKind(RecordKind.checkup),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CountTile(count: documents, label: 'Documents', onTap: onDocuments),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.count, required this.label, required this.onTap});

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$count $label',
      excludeSemantics: true,
      child: Material(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count', style: AppText.pillValue),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The first steps offered for a pet with nothing entered yet. None of
/// them is required, and the full medical history is never asked for.
class _GettingStarted extends StatelessWidget {
  const _GettingStarted({required this.pet, required this.actions});

  final Pet pet;
  final OverviewActions actions;

  @override
  Widget build(BuildContext context) {
    final steps = [
      if (actions.onAddDocument != null)
        HealthPromptStep(
          key: const Key('start-document'),
          icon: Icons.description_rounded,
          title: 'Add a document you already have',
          message: 'A photo or PDF of the vaccination booklet or a vet letter',
          onTap: actions.onAddDocument!,
        ),
      if (actions.onAddAppointment != null)
        HealthPromptStep(
          key: const Key('start-appointment'),
          icon: Icons.event_rounded,
          title: 'Enter an upcoming appointment',
          message: 'So it shows under Coming up',
          onTap: actions.onAddAppointment!,
        ),
      if (actions.onAddMedicine != null)
        HealthPromptStep(
          key: const Key('start-medicine'),
          icon: Icons.medication_rounded,
          title: 'Create a medicine reminder',
          message: "With the vet's instructions and the times",
          onTap: actions.onAddMedicine!,
        ),
    ];
    return Column(
      key: const Key('getting-started'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HealthSectionTitle('Start with one thing'),
        Text(
          "No need to enter ${pet.name}'s whole history. Add things as they come up.",
          style: AppText.body.copyWith(color: AppColors.brown),
        ),
        for (final step in steps) ...[const SizedBox(height: 10), step],
      ],
    );
  }
}

/// A white step card of the getting-started list.
class HealthPromptStep extends StatelessWidget {
  const HealthPromptStep({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HealthCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconDisc(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle),
                Text(message, style: AppText.secondary.copyWith(color: AppColors.brown)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
        ],
      ),
    );
  }
}
