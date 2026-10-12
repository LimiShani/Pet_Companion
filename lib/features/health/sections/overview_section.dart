import '../../../access/feature_gate.dart';
import '../../../access/access_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../platform/feature_ui.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/data/species_settings.dart';
import '../emergency/contact_actions.dart';
import '../emergency/health_profile_form.dart';
import '../emergency/vet_picker.dart';
import '../emergency/vets_screen.dart';
import '../../../presentation/health_format.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../services/pet_records/state/schedule_logic.dart';
import '../../../presentation/health_widgets.dart';
import '../widgets/weight_trend.dart';

/// What the Overview's buttons do. The tab wires them to the record form,
/// the Quick log and so on, so this section stays a plain view.
class OverviewActions {
  const OverviewActions({
    this.onQuickLog,
    this.onAddRecord,
    this.onAddDocument,
    this.onAddAppointment,
    this.onAddMedicine,
    this.onRecordDose,
    this.onOpenRecord,
  });

  final VoidCallback? onQuickLog;
  final VoidCallback? onAddRecord;
  final VoidCallback? onAddDocument;
  final VoidCallback? onAddAppointment;
  final VoidCallback? onAddMedicine;
  final void Function(ScheduleEntry entry)? onRecordDose;
  final void Function(HealthRecord record)? onOpenRecord;
}

/// What needs attention now: the next action first, then the two quick
/// actions, the vet, and one card of rows that each open their own page
/// (the health profile, the weight, the records). A block with nothing in
/// it is not shown, and there is no overall "health score". The pet is
/// named by the header's pet chip, so there is no pet card here.
class OverviewSection extends ConsumerWidget {
  const OverviewSection({
    super.key,
    required this.pet,
    required this.data,
    this.actions = const OverviewActions(),
  });

  final Pet pet;
  final PetHealthData data;
  final OverviewActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability:
        'health.records.view|health.schedule.view|health.emergency.view',
    hidden: true,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final now = ref.watch(healthClockProvider)();
    void show(HealthSection section) =>
        ref.read(healthSectionProvider.notifier).show(section);

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
    final review =
        entriesNeedingReview(data.plan, now).length +
        recordsNeedingReview(data.records, now).length;
    final nothingDue = nextEntry == null && nextRecord == null && review == 0;
    final records = ref.watch(capabilityProvider('health.records.view'));

    // One gap between blocks.
    final blocks = <Widget>[
      if (!nothingDue)
        _ComingUp(
          now: now,
          entry: nextEntry,
          record: nextRecord,
          reviewCount: review,
          actions: actions,
          onSchedule: () => show(HealthSection.schedule),
        ),
      if (data.isEmpty) _GettingStarted(pet: pet, actions: actions),
      if (actions.onQuickLog != null || actions.onAddRecord != null)
        _QuickActions(actions: actions),
      _VetCard(pet: pet, vets: data.vets),
      _OverviewRows(
        pet: pet,
        data: data,
        onWeight: records
            ? () {
                ref.read(historyFilterProvider.notifier).showWeight();
                show(HealthSection.records);
              }
            : null,
        onRecords: records
            ? () {
                ref.read(historyFilterProvider.notifier).clear();
                show(HealthSection.records);
              }
            : null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.cardGap),
          blocks[i],
        ],
      ],
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
  Widget build(BuildContext context) => FeatureGate(
    capability:
        'health.records.view|health.schedule.view|health.emergency.view',
    hidden: true,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final divider = Divider(
      height: 16,
      thickness: 1,
      color: AppColors.white.withValues(alpha: 0.55),
    );
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final e = entry;
    final r = record;
    final rows = <Widget>[
      if (e != null)
        _ComingUpRow(
          icon: careKindIcon(e.item.kind),
          title: e.item.title,
          detail: l10n.dayAndTime(
            format.common.commonToday,
            format.timeOfDay(e.item.time),
          ),
          trailing: e.item.isMedication && actions.onRecordDose != null
              ? FilledButton(
                  key: const Key('overview-record-dose'),
                  onPressed: () => actions.onRecordDose!(e),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: AppText.button(14),
                  ),
                  child: Text(l10n.recordDose),
                )
              : null,
          onTap: onSchedule,
        ),
      if (r != null)
        _ComingUpRow(
          icon: recordKindIcon(r.kind),
          title: r.title,
          detail: format.dots([
            format.relativeDayTime(r.scheduledAt, now),
            r.clinic,
          ]),
          onTap: actions.onOpenRecord == null
              ? onSchedule
              : () => actions.onOpenRecord!(r),
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
                    l10n.remindersNeedReview(reviewCount),
                    style: AppText.secondary,
                  ),
                ),
                const AppIcon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.ink,
                ),
              ],
            ),
          ),
        ),
    ];

    return HealthCard(
      key: const Key('overview-coming-up'),
      color: AppColors.peach,
      radius: AppSpacing.cardRadius,
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 12,
        top: 8,
        bottom: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.comingUp,
                  style: AppText.sectionTitle,
                ),
              ),
              HealthLink(
                l10n.sectionSchedule,
                onPressed: onSchedule,
                color: AppColors.ink,
              ),
            ],
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) divider,
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ComingUpRow extends StatelessWidget {
  const _ComingUpRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability:
        'health.records.view|health.schedule.view|health.emergency.view',
    hidden: true,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
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
                  TypedText(
                    title,
                    style: AppText.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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

/// The Overview's two actions: the Quick log (the one filled button) and
/// "Add record".
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});

  final OverviewActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    const size = Size(kHealthTapTarget, kHealthTapTarget);
    const padding = EdgeInsets.symmetric(horizontal: 12);
    final buttons = [
      if (actions.onQuickLog != null)
        FilledButton.icon(
          key: const Key('overview-quick-log'),
          onPressed: actions.onQuickLog,
          style: FilledButton.styleFrom(
            minimumSize: size,
            padding: padding,
            textStyle: AppText.button(15),
          ),
          icon: const AppIcon(Icons.add_rounded, size: 18),
          label: Text(
            l10n.quickLog,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (actions.onAddRecord != null)
        OutlinedButton(
          key: const Key('overview-add-record'),
          onPressed: actions.onAddRecord,
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            padding: padding,
            textStyle: AppText.button(15),
          ),
          child: Text(
            l10n.addRecord,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }
}

class _VetCard extends StatelessWidget {
  const _VetCard({required this.pet, required this.vets});

  final Pet pet;
  final PetVets vets;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'health.emergency.view',
    hidden: true,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final vet = vets.regular ?? vets.emergency;
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    if (vet == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthPromptCard(
            key: const Key('overview-add-vet'),
            icon: Icons.add_call,
            title: l10n.addPetsVet(pet.name),
            message: l10n.vetPromptNote,
            onTap: () => showVetPicker(context, petId: pet.id),
          ),
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 8, top: 4),
            child: _FindVetLink(),
          ),
        ],
      );
    }
    // The opening hours as typed; without them, the address as typed and
    // the phone number left to right.
    final hours = vet.openingHours.trim();
    final detail = hours.isNotEmpty
        ? hours
        : format.dots([
            if (vet.hasAddress) vet.address,
            if (vet.hasPhone) format.ltrInLine(vet.phone),
          ]);
    void details() => VetsScreen.open(context, pet);
    return HealthCard(
      key: const Key('overview-vet'),
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 12,
        top: 6,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.vet, style: AppText.cardTitle)),
              HealthLink(l10n.details, onPressed: details),
            ],
          ),
          InkWell(
            key: const Key('overview-vet-row'),
            onTap: details,
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            child: Row(
              children: [
                const IconDisc(Icons.medical_services_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TypedText(vet.name, style: AppText.cardTitle),
                      if (detail.isNotEmpty)
                        TypedText(
                          detail,
                          style: AppText.secondary.copyWith(
                            color: AppColors.brown,
                          ),
                        ),
                    ],
                  ),
                ),
                const AppIcon(
                  Icons.chevron_right_rounded,
                  color: AppColors.brown,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Call and Message; the map is on the vet's details page.
          ContactActionButtons(
            petId: pet.id,
            tag: 'overview',
            name: vet.name,
            phone: vet.hasPhone ? vet.phone : null,
            onWhatsApp: vet.onWhatsApp,
            onAddPhone: details,
          ),
          const _FindVetLink(),
        ],
      ),
    );
  }
}

/// "Find a vet nearby", under the vet card whether a vet is saved or not:
/// the way to the Find a vet search, for accounts that may use it. The
/// Emergency sheet has its own.
class _FindVetLink extends StatelessWidget {
  const _FindVetLink();

  static const linkKey = Key('overview-find-vet');

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'findvet.search',
    hidden: true,
    builder: (context) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: HealthLink(
        context.healthL10n.overviewFindVet,
        key: linkKey,
        icon: Icons.search_rounded,
        onPressed: () => openFeature<Object>(context, 'find-vet', ''),
      ),
    ),
  );
}

/// One white card of rows, each opening its own page: the health profile,
/// the weight (Records on Weight) and the records (Records on All). The
/// last two need [onWeight] and [onRecords]: without them (no access to
/// the records) they are left out.
class _OverviewRows extends StatelessWidget {
  const _OverviewRows({
    required this.pet,
    required this.data,
    required this.onWeight,
    required this.onRecords,
  });

  final Pet pet;
  final PetHealthData data;
  final VoidCallback? onWeight;
  final VoidCallback? onRecords;

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final rows = <Widget>[
      _OverviewRow(
        key: const Key('overview-profile'),
        title: l10n.healthProfile,
        detail: _profileLine(format, data.profile),
        onTap: () => HealthProfileScreen.open(context, pet),
      ),
      if (onWeight != null) _weightRow(format),
      if (onRecords != null)
        _OverviewRow(
          key: const Key('overview-records'),
          title: l10n.recordsSection,
          detail: _recordsLine(format),
          onTap: onRecords!,
        ),
    ];
    return HealthCard(
      key: const Key('overview-rows'),
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.cream),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// "Allergies: chicken · Arthritis in the hips · Chipped": only what the
  /// owner answered.
  String _profileLine(HealthFormat format, HealthProfile profile) {
    final l10n = format.l10n;
    final parts = [
      if (profile.allergies.isNotEmpty)
        l10n.overviewProfileAllergies(format.commas(profile.allergies))
      else if (profile.allergiesNoneKnown)
        l10n.overviewProfileNoAllergies,
      if (profile.conditions.isNotEmpty) format.commas(profile.conditions),
      if (profile.microchip.trim().isNotEmpty)
        l10n.overviewProfileChipped
      else if (profile.notChipped)
        l10n.notChipped,
    ];
    return parts.isEmpty ? l10n.overviewProfileEmpty : format.dots(parts);
  }

  /// "3 vaccinations · 4 vet visits · 3 documents · 1 medicine".
  String _recordsLine(HealthFormat format) {
    final l10n = format.l10n;
    final history = historyRecords(data.records);
    if (history.isEmpty) return l10n.historyEmpty;
    int count(RecordKind kind) => history.where((r) => r.kind == kind).length;
    // The same records the Records' "Documents" chip shows.
    final documents = history
        .where(
          (r) =>
              r.kind == RecordKind.document ||
              data.documentsOf(r.id).isNotEmpty,
        )
        .length;
    final vaccinations = count(RecordKind.vaccination);
    final visits = count(RecordKind.checkup);
    final medicines = count(RecordKind.medicine);
    final parts = [
      if (vaccinations > 0) l10n.overviewVaccinations(vaccinations),
      if (visits > 0) l10n.overviewVetVisits(visits),
      if (documents > 0) l10n.overviewDocuments(documents),
      if (medicines > 0) l10n.overviewMedicines(medicines),
    ];
    return parts.isEmpty
        ? l10n.recordsCount(history.length)
        : format.dots(parts);
  }

  /// "Weight 23 kg", what changed since the weigh-in before, and a small
  /// line of the weigh-ins.
  Widget _weightRow(HealthFormat format) {
    final l10n = format.l10n;
    final weights = weightEntries(data.observations);
    final grams = SpeciesSettings.of(pet.species).weightInGrams;
    if (weights.isEmpty) {
      return _OverviewRow(
        key: const Key('overview-weight'),
        title: l10n.weight,
        detail: l10n.noWeightYet,
        onTap: onWeight!,
      );
    }
    final latest = weights.last;
    final previous = weights.length > 1 ? weights[weights.length - 2] : null;
    return _OverviewRow(
      key: const Key('overview-weight'),
      title: l10n.overviewWeightRow(format.weight(latest.value!, grams: grams)),
      detail: previous == null
          ? format.date(latest.observedAt)
          : format.weightChangeSince(
              previous.value!,
              latest.value!,
              previous.observedAt,
              grams: grams,
            ),
      trailing: previous == null
          ? null
          : SizedBox(
              width: 64,
              child: WeightTrendChart(
                points: [
                  for (final w in weights) TrendPoint(w.observedAt, w.value!),
                ],
                height: 24,
                showGuides: false,
                semanticsLabel: l10n.smallWeightChart,
              ),
            ),
      onTap: onWeight!,
    );
  }
}

/// A row of the Overview's card: a title, one quieter line, and a chevron.
class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    super.key,
    required this.title,
    required this.detail,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.cardTitle),
                    TypedText(
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
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            const SizedBox(width: 4),
            const AppIcon(Icons.chevron_right_rounded, color: AppColors.brown),
          ],
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
  Widget build(BuildContext context) => FeatureGate(
    capability:
        'health.records.view|health.schedule.view|health.emergency.view',
    hidden: true,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.healthL10n;
    final steps = [
      if (actions.onAddDocument != null)
        HealthPromptStep(
          key: const Key('start-document'),
          icon: Icons.description_rounded,
          title: l10n.startDocument,
          message: l10n.startDocumentNote,
          onTap: actions.onAddDocument!,
        ),
      if (actions.onAddAppointment != null)
        HealthPromptStep(
          key: const Key('start-appointment'),
          icon: Icons.event_rounded,
          title: l10n.startAppointment,
          message: l10n.startAppointmentNote,
          onTap: actions.onAddAppointment!,
        ),
      if (actions.onAddMedicine != null)
        HealthPromptStep(
          key: const Key('start-medicine'),
          icon: Icons.medication_rounded,
          title: l10n.startMedicine,
          message: l10n.startMedicineNote,
          onTap: actions.onAddMedicine!,
        ),
    ];
    return Column(
      key: const Key('getting-started'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthSectionTitle(l10n.startWithOneThing),
        Text(
          l10n.startNote(pet.name),
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
  Widget build(BuildContext context) => FeatureGate(
    capability:
        'health.records.view|health.schedule.view|health.emergency.view',
    hidden: true,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
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
                Text(
                  message,
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const AppIcon(Icons.chevron_right_rounded, color: AppColors.brown),
        ],
      ),
    );
  }
}
